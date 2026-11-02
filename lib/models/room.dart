/// 방 상태. 서버의 room_status와 같은 값이다.
enum RoomStatus { recruiting, scheduled, active, finished, cancelled, expired }

/// 방장이 방을 만들 때 고르는 인증 방식. 서버 값은 [serverName].
enum CheckinMode {
  /// 다 한 뒤 사진 한 장 또는 5초 미만 동영상 + 한 줄
  result('result', '결과 인증', '다 한 뒤 사진이나 5초 미만 동영상에 한 줄을 붙여요'),

  /// 시작할 때 '전' 사진 + 한 줄, 끝나고 '후' 사진 + 한 줄
  beforeAfter('before_after', '전후 인증', '시작 전·끝난 뒤 사진을 한 줄씩 붙여 나란히 보여 줘요'),

  /// 사진 없이 '했어요' + 한 줄
  light('light', '가벼운 인증', '사진 없이 "했어요"와 한 줄만 남겨요');

  const CheckinMode(this.serverName, this.label, this.description);
  final String serverName;
  final String label;
  final String description;

  static CheckinMode fromServer(String? value) =>
      values.firstWhere((m) => m.serverName == value, orElse: () => result);
}

RoomStatus _status(String value) =>
    RoomStatus.values.firstWhere((s) => s.name == value, orElse: () => RoomStatus.expired);

/// 방 화면에 보여 줄 값. T·G·H는 서버가 계산한다.
class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.status,
    required this.inviteCode,
    required this.isHost,
    required this.recruitExpiresAt,
    this.startsAt,
    this.endsAt,
    this.startCount,
    required this.activeCount,
    required this.totalElements,
    this.goal,
    required this.earned,
    required this.validCount,
    this.goalReachedAt,
    this.checkinMode = CheckinMode.result,
  });

  final String id;
  final RoomStatus status;
  final String inviteCode;
  final bool isHost;
  final DateTime recruitExpiresAt;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// 시작 인원 N0
  final int? startCount;

  /// 현재 참가 인원 A
  final int activeCount;

  /// 현재 책상 요소 수 T = 3×A + L
  final int totalElements;

  /// 공동 목표 G
  final int? goal;

  /// 정리된 요소(누적 획득 보상) H
  final int earned;

  /// 현재 유효 인증 수 C
  final int validCount;
  final DateTime? goalReachedAt;
  final CheckinMode checkinMode;

  /// 예약된 방은 시작 시각이 지나면 진행 중으로 본다(서버는 첫 인증 때 바꾼다).
  RoomStatus statusAt(DateTime now) {
    if (status == RoomStatus.scheduled && startsAt != null && !now.isBefore(startsAt!)) {
      return now.isBefore(endsAt!) ? RoomStatus.active : RoomStatus.finished;
    }
    if (status == RoomStatus.active && endsAt != null && !now.isBefore(endsAt!)) {
      return RoomStatus.finished;
    }
    if (status == RoomStatus.recruiting && !now.isBefore(recruitExpiresAt)) {
      return RoomStatus.expired;
    }
    return status;
  }

  factory RoomSummary.fromJson(Map<String, dynamic> j) {
    DateTime? t(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    return RoomSummary(
      id: j['id'] as String,
      status: _status(j['status'] as String),
      inviteCode: j['invite_code'] as String,
      isHost: j['is_host'] as bool,
      recruitExpiresAt: t('recruit_expires_at')!,
      startsAt: t('starts_at'),
      endsAt: t('ends_at'),
      startCount: j['n0'] as int?,
      activeCount: j['active_count'] as int,
      totalElements: j['total_elements'] as int,
      goal: j['goal'] as int?,
      earned: j['earned'] as int,
      validCount: j['valid_count'] as int,
      goalReachedAt: t('goal_reached_at'),
      checkinMode: CheckinMode.fromServer(j['checkin_mode'] as String?),
    );
  }
}

class RoomMember {
  const RoomMember({
    required this.nickname,
    required this.nicknameNo,
    required this.isMe,
    required this.isHost,
    required this.checkins,
  });

  final String nickname;
  final int nicknameNo;
  final bool isMe;
  final bool isHost;
  final int checkins;

  /// 동명 닉네임은 방 안 구분 번호를 붙인다.
  String get displayName => nicknameNo > 1 ? '$nickname $nicknameNo' : nickname;

  factory RoomMember.fromJson(Map<String, dynamic> j) => RoomMember(
        nickname: j['nickname'] as String,
        nicknameNo: j['nickname_no'] as int,
        isMe: j['is_me'] as bool,
        isHost: j['is_host'] as bool,
        checkins: j['checkins'] as int,
      );
}

class InvitePreview {
  const InvitePreview({required this.status, required this.memberCount, required this.recruitExpiresAt});

  final RoomStatus status;
  final int memberCount;
  final DateTime recruitExpiresAt;

  bool openAt(DateTime now) =>
      status == RoomStatus.recruiting && now.isBefore(recruitExpiresAt) && memberCount < 4;

  factory InvitePreview.fromJson(Map<String, dynamic> j) => InvitePreview(
        status: _status(j['status'] as String),
        memberCount: j['member_count'] as int,
        recruitExpiresAt: DateTime.parse(j['recruit_expires_at'] as String),
      );
}

/// 내 날짜별 인증. 사진 삭제는 완료 체크·보상을 남기고, 인증 취소는 완료 체크를 무효로 한다.
class MyCheckin {
  const MyCheckin({required this.date, required this.valid, required this.hasPhoto, this.memo});

  final DateTime date;
  final bool valid;
  final bool hasPhoto;
  final String? memo;

  factory MyCheckin.fromJson(Map<String, dynamic> j) => MyCheckin(
        date: DateTime.parse(j['slot_date'] as String),
        valid: j['valid'] as bool,
        hasPhoto: j['has_photo'] as bool,
        memo: j['memo'] as String?,
      );
}

enum FeedMedia { photo, video, none }

/// 방 피드의 인증 카드 하나. 파일 주소는 서버가 잠깐 쓸 수 있게 발급한 주소다.
class FeedItem {
  const FeedItem({
    required this.nickname,
    required this.nicknameNo,
    required this.isMe,
    required this.date,
    required this.checkedAt,
    required this.media,
    this.mediaUrl,
    this.note,
    this.beforeUrl,
    this.beforeNote,
  });

  final String nickname;
  final int nicknameNo;
  final bool isMe;
  final DateTime date;
  final DateTime checkedAt;
  final FeedMedia media;
  final String? mediaUrl;
  final String? note;
  final String? beforeUrl;
  final String? beforeNote;

  String get displayName => nicknameNo > 1 ? '$nickname $nicknameNo' : nickname;

  /// 전후 인증 카드: 전 사진과 후 사진이 모두 남아 있을 때
  bool get isBeforeAfter => beforeUrl != null && mediaUrl != null;
}

/// 오늘 찍어 둔 전후 인증의 '전' 사진
class BeforeShot {
  const BeforeShot({required this.url, this.note});
  final String url;
  final String? note;
}
