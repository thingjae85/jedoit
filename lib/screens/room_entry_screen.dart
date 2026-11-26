import 'package:flutter/material.dart';

import '../models/room.dart';
import '../services/room_service.dart';
import '../theme.dart';
import '../widgets/jd_widgets.dart';
import '../widgets/pixel_ui.dart';

/// 방 만들기 또는 초대 코드로 참가하기. 방 전용 닉네임(2~10자)을 함께 받는다.
/// 성공하면 방 ID를 반환하며 닫힌다.
///
/// 방 만들기는 위에 "만들 챌린지" 카드를 두고, 아래 네 단계(할 일 → 기간 → 인증 방식 → 닉네임)를
/// 고를 때마다 카드가 바로 바뀐다. 만들기 버튼은 화면 아래에 늘 보인다.
class RoomEntryScreen extends StatefulWidget {
  const RoomEntryScreen({super.key, required this.rooms, this.inviteCode, this.restartFrom, this.nickname});

  final RoomService rooms;

  /// 초대 링크로 들어왔으면 참가 화면으로 시작한다.
  final String? inviteCode;

  /// 끝난 방에서 "다시 하기"로 왔으면 그 방. 설정을 그대로 채워 두고 고칠 수 있게 한다.
  final RoomSummary? restartFrom;

  /// 처음부터 채워 둘 닉네임 (다시 하기에서는 지난 회차 닉네임).
  final String? nickname;

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

  bool get _restart => widget.restartFrom != null;

  @override
  void initState() {
    super.initState();
    _nickname.text = widget.nickname ?? '';
    final prev = widget.restartFrom;
    if (prev != null) {
      _joining = false;
      _kind = prev.kind;
      _mode = prev.checkinMode;
      _title.text = prev.title;
      _days = prev.days.clamp(minChallengeDays, maxChallengeDays);
    }
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

  void _setDays(int d) => setState(() => _days = d.clamp(minChallengeDays, maxChallengeDays));

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
      final prev = widget.restartFrom;
      final id = prev != null
          ? await widget.rooms.restart(prev.id, nick, mode: _mode, kind: _kind, title: _title.text.trim(), days: _days)
          : _joining
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

  /// 기간 빠른 선택.
  static const _dayPresets = [(1, '1일'), (3, '3일'), (7, '7일'), (14, '2주'), (30, '한 달')];

  int get _goalPerPerson => (_days * 2 / 3).ceil();

  String get _submitLabel {
    if (_busy) return '처리 중...';
    if (_restart) return '다시 하기 방 만들기';
    return _joining ? '참가하기' : '방 만들기';
  }

  void _switchToJoin(bool join) {
    if (_busy) return;
    setState(() {
      _joining = join;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_restart ? '다시 하기' : (_joining ? '초대받은 방 참가' : '새 챌린지')),
        actions: [
          if (!_restart)
            TextButton.icon(
              onPressed: () => _switchToJoin(!_joining),
              icon: Icon(_joining ? Icons.add : Icons.login, size: 18),
              label: Text(_joining ? '새로 만들기' : '코드로 참가'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: _joining ? _joinChildren() : _createChildren(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
                ),
              FilledButton(
                style: _joining ? null : FilledButton.styleFrom(backgroundColor: JdColors.together),
                onPressed: _canSubmit ? _submit : null,
                child: Text(_submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────── 방 만들기 ─────────

  List<Widget> _createChildren() {
    return [
      _PreviewCard(
        icon: challengeIcon(_kind),
        title: _title.text.trim().isEmpty ? '챌린지 이름을 적어 주세요' : '$_days일 ${_title.text.trim()}',
        badge: _restart ? '다음 회차' : null,
        lines: [
          '$_days일 동안 하루 한 번 · ${_mode.label}',
          '2~4명 · 1인당 목표 $_goalPerPerson회',
        ],
        days: _days,
        note: _restart ? '지난번 친구들이 함께 들어와 있어요. 바꾸고 싶은 것만 고치세요.' : null,
      ),
      const SizedBox(height: 22),
      const _Step(title: '무엇을 할까요?'),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.5,
        children: [
          for (final k in ChallengeKind.values)
            _Tile(
              icon: challengeIcon(k),
              label: k.label,
              selected: k == _kind,
              onTap: _busy ? null : () => _pickKind(k),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _title,
        enabled: !_busy,
        maxLength: 20,
        decoration: InputDecoration(
          labelText: '챌린지 이름',
          hintText: '예: 물 2L 마시기',
          helperText: '하루에 한 번 할 일을 적어 주세요',
          errorText: _titleError,
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 18),
      const _Step(title: '며칠 동안 할까요?'),
      Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        decoration: const ShapeDecoration(color: JdColors.cream, shape: JdShapes.card),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '하루 줄이기',
                  onPressed: _busy || _days <= minChallengeDays ? null : () => _setDays(_days - 1),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text('$_days일',
                      key: const Key('daysText'),
                      textAlign: TextAlign.center,
                      style: gameText(size: 26, color: JdColors.ink)),
                ),
                IconButton(
                  tooltip: '하루 늘리기',
                  onPressed: _busy || _days >= maxChallengeDays ? null : () => _setDays(_days + 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final (n, label) in _dayPresets)
                  ChoiceChip(
                    label: Text(label),
                    selected: _days == n,
                    onSelected: _busy ? null : (_) => _setDays(n),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      const Padding(
        padding: EdgeInsets.only(left: 4),
        child: Text('1일부터 60일까지 정할 수 있어요', style: TextStyle(fontSize: 12, color: JdColors.subtle)),
      ),
      const SizedBox(height: 18),
      const _Step(title: '어떻게 인증할까요?'),
      Row(
        children: [
          for (final (i, m) in CheckinMode.values.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.25,
                child: _Tile(
                  icon: _modeIcon(m),
                  label: m.label,
                  selected: m == _mode,
                  onTap: _busy ? null : () => setState(() => _mode = m),
                ),
              ),
            ),
          ],
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(_mode.description, style: const TextStyle(fontSize: 13, color: JdColors.subtle)),
      ),
      const SizedBox(height: 22),
      _nicknameField(),
    ];
  }

  // ───────── 코드로 참가 ─────────

  List<Widget> _joinChildren() {
    final p = _preview;
    final open = p != null && p.openAt(DateTime.now());
    return [
      _PreviewCard(
        icon: Icons.mail_outline,
        title: p == null
            ? (_previewMissing ? '초대 코드를 찾지 못했어요' : '친구가 보낸 초대 코드를 넣어 주세요')
            : open
                ? (p.title == null ? '모집 중인 방' : '${p.days}일 ${p.title}')
                : '모집이 끝난 방이에요',
        lines: [
          if (p == null) '코드 8자리를 넣으면 어떤 방인지 바로 보여요',
          if (p != null && open) '모집 중인 방이에요 · 지금 ${p.memberCount}명',
          if (p != null && !open) '새 방을 만들어 보세요',
        ],
      ),
      const SizedBox(height: 22),
      TextField(
        controller: _code,
        enabled: !_busy,
        maxLength: 8,
        textCapitalization: TextCapitalization.characters,
        style: gameText(size: 22, color: JdColors.ink).copyWith(letterSpacing: 4),
        decoration: const InputDecoration(labelText: '초대 코드', hintText: 'ABCD2345'),
        onChanged: (v) {
          setState(() {
            _preview = null;
            _previewMissing = false;
          });
          if (v.trim().length == 8) _loadPreview();
        },
      ),
      const SizedBox(height: 10),
      _nicknameField(),
    ];
  }

  Widget _nicknameField() => TextField(
        controller: _nickname,
        enabled: !_busy,
        maxLength: 10,
        decoration: InputDecoration(
          labelText: '이 방에서 쓸 닉네임',
          helperText: 'Google 이름·이메일 대신 방에는 이 닉네임만 보여요',
          errorText: _nicknameError,
        ),
        onChanged: (_) => setState(() {}),
      );
}

IconData _modeIcon(CheckinMode m) => switch (m) {
      CheckinMode.result => Icons.photo_camera_outlined,
      CheckinMode.beforeAfter => Icons.compare_outlined,
      CheckinMode.light => Icons.edit_note,
    };

/// 단계 제목.
class _Step extends StatelessWidget {
  const _Step({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(title, style: gameText(size: 16)),
    );
  }
}

/// 고르는 칸: 아이콘 위, 이름 아래. 고르면 나무색으로 채우고 테두리가 짙어진다.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = PixelBorder(
      step: 3,
      steps: 2,
      lip: selected ? 0 : 3,
      side: BorderSide(color: selected ? JdColors.woodText : JdColors.edge, width: 1.5),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? JdColors.woodLight : JdColors.cream,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: selected ? JdColors.outline : JdColors.woodText),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? JdColors.outline : JdColors.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 위에 늘 보이는 "만들 챌린지" 카드. 고른 값이 바로 반영된다.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.icon, required this.title, required this.lines, this.badge, this.days, this.note});

  final IconData icon;
  final String title;
  final List<String> lines;
  final String? badge;

  /// 7일 이하면 하루 칸을 그려 기간이 한눈에 보이게 한다.
  final int? days;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final d = days;
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const ShapeDecoration(color: JdColors.togetherChip, shape: JdShapes.soft),
                child: Icon(icon, color: JdColors.together),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: gameText(size: 18, color: JdColors.ink, height: 1.25)),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const ShapeDecoration(color: JdColors.woodLight, shape: JdShapes.tag),
                  child: Text(badge!, style: gameText(size: 12, color: JdColors.woodText)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l, style: const TextStyle(fontSize: 13, color: JdColors.subtle)),
            ),
          if (d != null && d <= 7) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < d; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const ShapeDecoration(color: JdColors.paper, shape: JdShapes.chip),
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: JdColors.faint)),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(note!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: JdColors.woodText)),
          ],
        ],
      ),
    );
  }
}
