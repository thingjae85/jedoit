import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/room.dart';
import '../utils/video.dart';

/// 서버 함수가 보낸 오류 코드를 사용자 문구로 바꾼다.
String roomErrorMessage(Object error) {
  final text = error is PostgrestException ? error.message : error.toString();
  const messages = {
    'already_in_room': '이미 참여 중인 방이 있어요. 한 번에 한 방만 참여할 수 있어요.',
    'invite_not_found': '초대 코드를 찾지 못했어요. 코드를 다시 확인해 주세요.',
    'invite_closed': '모집이 끝난 방이에요.',
    'room_full': '방이 가득 찼어요 (최대 4명).',
    'need_two_members': '2명 이상 모여야 시작할 수 있어요.',
    'not_host': '방장만 시작을 확정할 수 있어요.',
    'not_recruiting': '모집 중인 방이 아니에요.',
    'room_not_active': '지금은 인증 기간이 아니에요.',
    'upload_limit': '오늘 파일 올리기 횟수를 다 썼어요.',
    'date_changed': '날짜가 바뀌어 저장되지 않았습니다. 오늘 활동 후 다시 인증해 주세요.',
    'already_checked_in': '오늘은 이미 인증했어요.',
    'invalid_ticket': '사진 올리기 시간이 지났어요. 다시 시도해 주세요.',
    'not_member': '이 방의 참가자가 아니에요.',
    'before_required': '먼저 정리 전 사진을 올려 주세요.',
    'note_required': '한 줄을 적어 주세요.',
    'bad_media': '이 방에서는 올릴 수 없는 파일이에요.',
    'media_required': '사진이나 동영상을 골라 주세요.',
    'wrong_mode': '이 방의 인증 방식과 맞지 않아요.',
    'bad_title': '챌린지 이름은 2~20자로 정해 주세요.',
    'bad_days': '기간은 3일부터 60일까지 정할 수 있어요.',
    'own_checkin': '내 인증에는 응원할 수 없어요.',
    'checkin_not_found': '취소된 인증이에요.',
  };
  for (final entry in messages.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return '잠시 후 다시 시도해 주세요.';
}

/// 방 생성·참가·시작·인증·이탈. 모든 규칙 계산은 서버 DB 함수가 한다.
abstract class RoomService {
  Future<String?> myRoomId();
  Future<RoomSummary> summary(String roomId);
  Future<List<RoomMember>> members(String roomId);
  Future<InvitePreview?> preview(String code);
  Future<String> create(
    String nickname, {
    CheckinMode mode = CheckinMode.result,
    ChallengeKind kind = ChallengeKind.tidy,
    String title = '책상 한 구역 정리',
    int days = 3,
  });
  Future<String> join(String code, String nickname);
  Future<void> confirmStart(String roomId);
  Future<void> leave(String roomId);

  /// 오늘 인증을 저장한다. 사진은 이미 압축한 JPEG, 동영상은 확인을 마친 파일.
  /// 가벼운 인증은 [photo]·[video] 없이 한 줄만 보낸다. 전후 인증은 [photo]가 '후' 사진이다.
  Future<void> checkIn(String roomId, {Uint8List? photo, CheckinVideo? video, required String note});

  /// 전후 인증의 '전' 사진과 한 줄을 올려 둔다.
  Future<void> saveBefore(String roomId, Uint8List jpeg, String note);

  /// 오늘 올려 둔 '전' 사진. 없으면 null.
  Future<BeforeShot?> beforeToday(String roomId);

  /// 방 피드: 참가자들의 인증 카드, 최신순.
  Future<List<FeedItem>> feed(String roomId);

  /// 응원 리액션 누르기/취소. 눌린 상태면 true.
  Future<bool> toggleReaction(String roomId, FeedItem item, Reaction reaction);

  Future<List<MyCheckin>> myCheckins(String roomId);

  /// 사진·메모만 지운다. 완료 체크와 획득 보상은 남는다.
  Future<void> deletePhoto(String roomId, DateTime date);

  /// 완료 체크를 무효로 하고 사진·메모를 지운다. 획득 보상은 남는다.
  Future<void> cancelCheckin(String roomId, DateTime date);
}

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class SupabaseRoomService implements RoomService {
  SupabaseClient get _db => Supabase.instance.client;

  Map<String, dynamic> _first(dynamic rows) => (rows as List).first as Map<String, dynamic>;

  @override
  Future<String?> myRoomId() async => await _db.rpc('my_room_id') as String?;

  @override
  Future<RoomSummary> summary(String roomId) async =>
      RoomSummary.fromJson(_first(await _db.rpc('room_summary', params: {'r': roomId})));

  @override
  Future<List<RoomMember>> members(String roomId) async {
    final rows = await _db.rpc('room_members_view', params: {'r': roomId}) as List;
    return rows.map((r) => RoomMember.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<InvitePreview?> preview(String code) async {
    final rows = await _db.rpc('invite_preview', params: {'code': code}) as List;
    return rows.isEmpty ? null : InvitePreview.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<String> create(
    String nickname, {
    CheckinMode mode = CheckinMode.result,
    ChallengeKind kind = ChallengeKind.tidy,
    String title = '책상 한 구역 정리',
    int days = 3,
  }) async {
    final row = await _db.rpc('create_room', params: {
      'nick': nickname,
      'mode': mode.serverName,
      'category': kind.serverName,
      'title': title,
      'days': days,
    });
    return (row as Map<String, dynamic>)['id'] as String;
  }

  @override
  Future<String> join(String code, String nickname) async =>
      await _db.rpc('join_room', params: {'code': code, 'nick': nickname}) as String;

  @override
  Future<void> confirmStart(String roomId) => _db.rpc('confirm_start', params: {'r': roomId});

  @override
  Future<void> leave(String roomId) => _db.rpc('leave_room', params: {'r': roomId});

  @override
  Future<List<MyCheckin>> myCheckins(String roomId) async {
    final rows = await _db.rpc('my_checkins', params: {'r': roomId}) as List;
    return rows.map((r) => MyCheckin.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> deletePhoto(String roomId, DateTime date) => _removeAfter(
      _db.rpc('delete_checkin_photo', params: {'r': roomId, 'd': _day(date)}));

  @override
  Future<void> cancelCheckin(String roomId, DateTime date) => _removeAfter(
      _db.rpc('cancel_checkin', params: {'r': roomId, 'd': _day(date)}));

  /// 서버에서 목록 제외가 끝난 뒤 파일을 지운다. 파일 삭제가 실패해도
  /// 이미 아무도 볼 수 없고, 남은 파일은 운영 점검에서 7일 안에 정리한다.
  Future<void> _removeAfter(Future<dynamic> call) async {
    final result = await call;
    final paths = result is List ? result.cast<String>() : [if (result is String) result];
    if (paths.isEmpty) return;
    try {
      await _db.storage.from('checkins').remove(paths);
    } catch (_) {}
  }

  /// 서버가 발급한 경로에 파일을 올리고 그 경로의 발급 ID를 돌려준다.
  Future<String> _upload(String roomId, Uint8List bytes, String ext, String contentType) async {
    final ticket = await _db.rpc('issue_upload', params: {'r': roomId, 'ext': ext}) as Map<String, dynamic>;
    await _db.storage.from('checkins').uploadBinary(
          ticket['path'] as String,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return ticket['id'] as String;
  }

  @override
  Future<void> saveBefore(String roomId, Uint8List jpeg, String note) async {
    final ticket = await _upload(roomId, jpeg, 'jpg', 'image/jpeg');
    await _removeAfter(_db.rpc('save_before', params: {'r': roomId, 'ticket': ticket, 'note': note}));
  }

  @override
  Future<BeforeShot?> beforeToday(String roomId) async {
    final rows = await _db.rpc('my_before_today', params: {'r': roomId}) as List;
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    final url = await _db.storage.from('checkins').createSignedUrl(row['path'] as String, 3600);
    return BeforeShot(url: url, note: row['note'] as String?);
  }

  @override
  Future<List<FeedItem>> feed(String roomId) async {
    final rows = (await _db.rpc('room_feed', params: {'r': roomId}) as List).cast<Map<String, dynamic>>();
    final paths = <String>{
      for (final r in rows) ...[
        if (r['media_path'] != null) r['media_path'] as String,
        if (r['before_path'] != null) r['before_path'] as String,
      ],
    }.toList();
    // 자동 새로고침 때마다 주소가 바뀌면 사진이 다시 로드되므로, 50분 동안은 같은 주소를 쓴다.
    final now = DateTime.now();
    _urlCache.removeWhere((_, v) => now.isAfter(v.$2));
    final missing = paths.where((p) => !_urlCache.containsKey(p)).toList();
    if (missing.isNotEmpty) {
      for (final s in await _db.storage.from('checkins').createSignedUrlsResult(missing, 3600)) {
        if (s is SignedUrlSuccess) _urlCache[s.path] = (s.signedUrl, now.add(const Duration(minutes: 50)));
      }
    }
    final urls = {for (final p in paths) if (_urlCache[p] != null) p: _urlCache[p]!.$1};
    return [
      for (final r in rows)
        FeedItem(
          nickname: r['nickname'] as String,
          nicknameNo: r['nickname_no'] as int,
          isMe: r['is_me'] as bool,
          date: DateTime.parse(r['slot_date'] as String),
          checkedAt: DateTime.parse(r['checked_at'] as String),
          media: switch (r['media_type']) {
            'video' => FeedMedia.video,
            'none' => FeedMedia.none,
            _ => FeedMedia.photo,
          },
          mediaUrl: urls[r['media_path']],
          note: r['note'] as String?,
          beforeUrl: urls[r['before_path']],
          beforeNote: r['before_note'] as String?,
          claps: (r['clap_count'] as int?) ?? 0,
          fires: (r['fire_count'] as int?) ?? 0,
          myClap: (r['my_clap'] as bool?) ?? false,
          myFire: (r['my_fire'] as bool?) ?? false,
        ),
    ];
  }

  final _urlCache = <String, (String, DateTime)>{};

  @override
  Future<bool> toggleReaction(String roomId, FeedItem item, Reaction reaction) async {
    final d = item.date;
    return await _db.rpc('toggle_reaction', params: {
      'r': roomId,
      'nick': item.nickname,
      'nick_no': item.nicknameNo,
      'd': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      'emoji': reaction.serverName,
    }) as bool;
  }

  @override
  Future<void> checkIn(String roomId, {Uint8List? photo, CheckinVideo? video, required String note}) async {
    String? ticket;
    if (video != null) {
      ticket = await _upload(roomId, video.bytes, video.ext, video.contentType);
    } else if (photo != null) {
      ticket = await _upload(roomId, photo, 'jpg', 'image/jpeg');
    }
    await _db.rpc('submit_checkin', params: {
      'r': roomId,
      'ticket': ticket,
      'note': note.isEmpty ? null : note,
    });
  }
}
