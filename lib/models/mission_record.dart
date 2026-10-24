/// 미션을 마친 뒤 남기는 개인 기록(텍스트만, 사진 없음).
class MissionRecord {
  const MissionRecord({
    required this.id,
    required this.missionId,
    required this.startedAt,
    required this.completedAt,
    this.memo = '',
  });

  final String id;
  final String missionId;
  final DateTime startedAt;
  final DateTime completedAt;
  final String memo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'missionId': missionId,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt.toIso8601String(),
        'memo': memo,
      };

  /// 형식이 맞지 않으면 예외를 던진다. 저장소에서 잡아서 해당 기록만 건너뛴다.
  factory MissionRecord.fromJson(Map<String, dynamic> json) {
    return MissionRecord(
      id: json['id'] as String,
      missionId: json['missionId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      memo: (json['memo'] as String?) ?? '',
    );
  }
}
