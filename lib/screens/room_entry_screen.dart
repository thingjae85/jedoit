import 'package:flutter/material.dart';

import '../models/room.dart';
import '../services/room_service.dart';
import '../widgets/jd_widgets.dart';

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
  ChallengeKind _kind = ChallengeKind.tidy;
  final _title = TextEditingController(text: ChallengeKind.tidy.defaultTitle);
  int _days = 3;
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
    _title.dispose();
    super.dispose();
  }

  String? get _nicknameError {
    final n = _nickname.text.trim();
    if (n.isEmpty) return null;
    return n.length < 2 || n.length > 10 ? '닉네임은 2~10자로 정해 주세요' : null;
  }

  String? get _titleError {
    final t = _title.text.trim();
    if (t.isEmpty) return null;
    return t.length < 2 || t.length > 20 ? '챌린지 이름은 2~20자로 정해 주세요' : null;
  }

  bool get _canSubmit {
    final n = _nickname.text.trim();
    if (_busy || n.length < 2 || n.length > 10) return false;
    if (_joining) return _code.text.trim().length == 8;
    final t = _title.text.trim();
    return t.length >= 2 && t.length <= 20;
  }

  void _pickKind(ChallengeKind k) {
    setState(() {
      _kind = k;
      _title.text = k.defaultTitle;
      // 정리 챌린지는 사진 인증이 어울리고, 나머지는 기본값을 그대로 둔다.
    });
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
          : await widget.rooms.create(nick, mode: _mode, kind: _kind, title: _title.text.trim(), days: _days);
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
      appBar: AppBar(title: Text(_joining ? '초대받은 방 참가' : '챌린지 방 만들기')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('방 만들기'), icon: Icon(Icons.add_home)),
              ButtonSegment(value: true, label: Text('코드로 참가'), icon: Icon(Icons.login)),
            ],
            selected: {_joining},
            onSelectionChanged: _busy ? null : (s) => setState(() => _joining = s.first),
          ),
          const SizedBox(height: 20),
          Text(
            _joining
                ? '친구가 보낸 초대 코드 8자리로 방에 들어가요.'
                : '2~4명이 $_days일 동안 같은 챌린지를 하루 한 번씩 인증해요. 방을 만들고 친구를 초대하세요.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_joining) ...[
            TextField(
              controller: _code,
              enabled: !_busy,
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: '초대 코드', border: OutlineInputBorder()),
              onChanged: (v) {
                setState(() => _preview = null);
                if (v.trim().length == 8) _loadPreview();
              },
            ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  preview.openAt(DateTime.now())
                      ? '모집 중인 방이에요 · ${preview.title == null ? '' : '${preview.days}일 ${preview.title} · '}지금 ${preview.memberCount}명'
                      : '모집이 끝난 방이에요. 새 방을 만들어 보세요.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              )
            else if (_previewMissing)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('초대 코드를 찾지 못했어요.'),
              ),
          ],
          if (!_joining) ...[
            Text('어떤 챌린지를 할까요?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in ChallengeKind.values)
                  ChoiceChip(
                    label: Text(k.label),
                    avatar: Icon(challengeIcon(k), size: 18),
                    showCheckmark: false,
                    selected: k == _kind,
                    onSelected: _busy ? null : (_) => _pickKind(k),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              enabled: !_busy,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: '챌린지 이름',
                hintText: '예: 물 2L 마시기',
                helperText: '하루에 한 번 할 일을 적어 주세요',
                errorText: _titleError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text('기간', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [for (final d in challengeDays) ButtonSegment(value: d, label: Text('$d일'))],
              selected: {_days},
              onSelectionChanged: _busy ? null : (s) => setState(() => _days = s.first),
            ),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _nickname,
            enabled: !_busy,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: '이 방에서 쓸 닉네임',
              helperText: 'Google 이름·이메일 대신 방에는 이 닉네임만 보여요',
              errorText: _nicknameError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (!_joining) ...[
            const SizedBox(height: 8),
            Text('인증 방식', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            RadioGroup<CheckinMode>(
              groupValue: _mode,
              onChanged: (v) {
                if (!_busy && v != null) setState(() => _mode = v);
              },
              child: Column(
                children: [
                  for (final m in CheckinMode.values)
                    RadioListTile<CheckinMode>(
                      value: m,
                      title: Text(m.label),
                      subtitle: Text(m.description),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: Text(_busy ? '처리 중...' : (_joining ? '참가하기' : '방 만들기')),
          ),
        ],
      ),
    );
  }
}
