/// 미션을 마친 뒤 남기는 개인 기록. 사진·메모는 남기고 싶을 때만 있고, 나만 본다.
class MissionRecord {
  const MissionRecord({
    required this.id,
    required this.missionId,
    required this.startedAt,
    required this.completedAt,
    this.memo = '',
    this.title,
    this.theme,
    this.photo,
  });

  final String id;
  final String missionId;
  final DateTime startedAt;
  final DateTime completedAt;
  final String memo;

  /// 직접 만든 미션의 이름. 미션을 지워도 기록에는 이름이 남는다.
  final String? title;

  /// 오늘의 발견 주제 id.
  final String? theme;

  /// 작게 줄인 사진(JPEG, base64). 이 기기에만 저장하고 서버에는 올리지 않는다.
  final String? photo;

  bool get hasPhoto => photo != null && photo!.isNotEmpty;

  /// 서버나 임시 초안에 보낼 때는 사진을 뺀다.
  MissionRecord withoutPhoto() => MissionRecord(
        id: id,
        missionId: missionId,
        startedAt: startedAt,
        completedAt: completedAt,
        memo: memo,
        title: title,
        theme: theme,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'missionId': missionId,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt.toIso8601String(),
        'memo': memo,
        if (title != null) 'title': title,
        if (theme != null) 'theme': theme,
        if (photo != null) 'photo': photo,
      };

  /// 형식이 맞지 않으면 예외를 던진다. 저장소에서 잡아서 해당 기록만 건너뛴다.
  factory MissionRecord.fromJson(Map<String, dynamic> json) {
    return MissionRecord(
      id: json['id'] as String,
      missionId: json['missionId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      memo: (json['memo'] as String?) ?? '',
      title: json['title'] as String?,
      theme: json['theme'] as String?,
      photo: json['photo'] as String?,
    );
  }
}
