import 'package:flutter/material.dart';

import '../models/room.dart';
import '../services/room_service.dart';
import '../theme.dart';

/// 방 만들기 또는 초대 코드로 참가하기. 방 전용 닉네임(2~10자)을 함께 받는다.
/// 성공하면 방 ID를 반환하며 닫힌다.
class RoomEntryScreen extends StatefulWidget {
  const RoomEntryScreen({super.key, required this.rooms, this.inviteCode});

  final RoomService rooms;

  /// 초대 링크로 들어왔으면 참가 화면으로 시작한다.
  final String? inviteCode;

  @override
  State<RoomEntryScreen> createState() => _RoomEntryScreenState();
}

class _RoomEntryScreenState extends State<RoomEntryScreen> {
  final _nickname = TextEditingController();
  final _code = TextEditingController();
  late bool _joining = widget.inviteCode != null;
  InvitePreview? _preview;
  bool _previewMissing = false;
  bool _busy = false;
  CheckinMode _mode = CheckinMode.result;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null) {
      _code.text = widget.inviteCode!;
      _loadPreview();
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    _code.dispose();
    super.dispose();
  }

  String? get _nicknameError {
    final n = _nickname.text.trim();
    if (n.isEmpty) return null;
    return n.length < 2 || n.length > 10 ? '닉네임은 2~10자로 정해 주세요' : null;
  }

  bool get _canSubmit {
    final n = _nickname.text.trim();
    if (_busy || n.length < 2 || n.length > 10) return false;
    return !_joining || _code.text.trim().length == 8;
  }

  Future<void> _loadPreview() async {
    try {
      final p = await widget.rooms.preview(_code.text.trim());
      if (!mounted) return;
      setState(() {
        _preview = p;
        _previewMissing = p == null;
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final nick = _nickname.text.trim();
      final id = _joining
          ? await widget.rooms.join(_code.text.trim().toUpperCase(), nick)
          : await widget.rooms.create(nick, mode: _mode);
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = roomErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(_joining ? '초대받은 방 참가' : '3일 정리 챌린지',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text(
            _joining
                ? '친구가 보낸 초대 코드 8자리로 방에 들어가요.'
                : '2~4명이 3일 동안 각자 같은 구역을 하루 5분씩 정리해요.\n방을 만들고 친구를 초대하세요.',
            style: const TextStyle(fontSize: 15, height: 1.45, color: JdColors.subtle),
          ),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: JdColors.ink,
              selectedForegroundColor: Colors.white,
              side: const BorderSide(color: JdColors.box),
              textStyle: const TextStyle(fontFamily: jdFont, fontWeight: FontWeight.w700),
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('방 만들기')),
              ButtonSegment(value: true, label: Text('코드로 참가')),
            ],
            selected: {_joining},
            onSelectionChanged: _busy ? null : (s) => setState(() => _joining = s.first),
          ),
          const SizedBox(height: 24),
          if (_joining) ...[
            TextField(
              controller: _code,
              enabled: !_busy,
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: '초대 코드', floatingLabelBehavior: FloatingLabelBehavior.always, counterText: ''),
              onChanged: (v) {
                setState(() => _preview = null);
                if (v.trim().length == 8) _loadPreview();
              },
            ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  preview.openAt(DateTime.now())
                      ? '모집 중인 방이에요 · 지금 ${preview.memberCount}명'
                      : '모집이 끝난 방이에요. 새 방을 만들어 보세요.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              )
            else if (_previewMissing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('초대 코드를 찾지 못했어요.'),
              ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _nickname,
            enabled: !_busy,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: '이 방에서 쓸 닉네임',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: '2~10자',
              helperText: '방에는 Google 이름 대신 이 닉네임만 보여요',
              errorText: _nicknameError,
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (!_joining) ...[
            const SizedBox(height: 24),
            const Text('인증 방식', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final m in CheckinMode.values)
              _ModeCard(
                mode: m,
                selected: m == _mode,
                onTap: _busy ? null : () => setState(() => _mode = m),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: JdColors.together,
              disabledBackgroundColor: JdColors.empty,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _canSubmit ? _submit : null,
            child: Text(_busy ? '처리 중...' : (_joining ? '참가하기' : '방 만들기')),
          ),
        ),
      ),
    );
  }
}

/// 인증 방식 고르기 카드
class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.selected, this.onTap});

  final CheckinMode mode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (mode) {
      CheckinMode.result => Icons.photo_camera_outlined,
      CheckinMode.beforeAfter => Icons.compare_outlined,
      CheckinMode.light => Icons.edit_note,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? JdColors.togetherTint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? JdColors.together : JdColors.line, width: selected ? 2 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? JdColors.together : JdColors.panel,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: selected ? Colors.white : JdColors.subtle),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(mode.description, style: const TextStyle(fontSize: 13, color: JdColors.subtle)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? JdColors.together : JdColors.box),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
