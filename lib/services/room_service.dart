import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/room.dart';

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
    'upload_limit': '오늘 사진 올리기 횟수(3회)를 다 썼어요.',
    'date_changed': '날짜가 바뀌어 저장되지 않았습니다. 오늘 활동 후 다시 인증해 주세요.',
    'already_checked_in': '오늘은 이미 인증했어요.',
    'invalid_ticket': '사진 올리기 시간이 지났어요. 다시 시도해 주세요.',
    'not_member': '이 방의 참가자가 아니에요.',
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
  Future<String> create(String nickname);
  Future<String> join(String code, String nickname);
  Future<void> confirmStart(String roomId);
  Future<void> leave(String roomId);

  /// 이미 압축한 JPEG을 올리고 오늘 인증으로 저장한다.
  Future<void> checkIn(String roomId, Uint8List jpeg, String memo);
}

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
  Future<String> create(String nickname) async {
    final row = await _db.rpc('create_room', params: {'nick': nickname});
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
  Future<void> checkIn(String roomId, Uint8List jpeg, String memo) async {
    final ticket = await _db.rpc('issue_upload', params: {'r': roomId}) as Map<String, dynamic>;
    await _db.storage.from('checkins').uploadBinary(
          ticket['path'] as String,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    await _db.rpc('submit_checkin', params: {
      'r': roomId,
      'ticket': ticket['id'],
      'note': memo.isEmpty ? null : memo,
    });
  }
}
