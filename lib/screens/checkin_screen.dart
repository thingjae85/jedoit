import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/room.dart';
import '../services/room_service.dart';
import '../theme.dart';
import '../utils/photo.dart';
import '../utils/video.dart';

/// 고른 파일. 동영상은 이름의 확장자로 mp4·mov를 구분한다.
class PickedFile {
  const PickedFile(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

typedef FilePicker = Future<PickedFile?> Function();

Future<PickedFile?> _pickImage() async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery);
  return f == null ? null : PickedFile(await f.readAsBytes(), f.name);
}

Future<PickedFile?> _pickVideo() async {
  final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 5));
  return f == null ? null : PickedFile(await f.readAsBytes(), f.name);
}

const _noteMax = 100;

/// 오늘 인증. 방 인증 방식에 따라
/// - 결과: 사진 또는 5초 미만 동영상 + 한 줄
/// - 전후: '전' 사진 + 한 줄을 먼저 올리고, 끝나면 '후' 사진 + 한 줄
/// - 가벼운: "했어요" + 한 줄
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({
    super.key,
    required this.rooms,
    required this.roomId,
    this.mode = CheckinMode.result,
    this.picker,
    this.videoPicker,
  });

  final RoomService rooms;
  final String roomId;
  final CheckinMode mode;

  /// 테스트에서 사진·동영상 고르기를 바꿔 끼운다.
  final FilePicker? picker;
  final FilePicker? videoPicker;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _note = TextEditingController();
  final _beforeNote = TextEditingController();
  Uint8List? _photo;
  CheckinVideo? _video;
  Uint8List? _beforePhoto;
  BeforeShot? _savedBefore;
  bool _loadingBefore = false;
  bool _checked = false;
  bool _busy = false;
  String? _error;

  CheckinMode get _mode => widget.mode;

  /// 전후 인증에서 아직 '전' 사진을 올리지 않았으면 '전' 단계
  bool get _beforeStep => _mode == CheckinMode.beforeAfter && _savedBefore == null;

  @override
  void initState() {
    super.initState();
    if (_mode == CheckinMode.beforeAfter) _loadBefore();
  }

  @override
  void dispose() {
    _note.dispose();
    _beforeNote.dispose();
    super.dispose();
  }

  Future<void> _loadBefore() async {
    setState(() => _loadingBefore = true);
    try {
      final shot = await widget.rooms.beforeToday(widget.roomId);
      if (mounted) setState(() => _savedBefore = shot);
    } catch (_) {
      // 못 불러오면 '전' 단계부터 다시 한다. 다시 올리면 서버가 바꿔 끼운다.
    } finally {
      if (mounted) setState(() => _loadingBefore = false);
    }
  }

  Future<void> _choosePhoto({bool before = false}) async {
    setState(() => _error = null);
    try {
      final file = await (widget.picker ?? _pickImage)();
      if (file == null) return;
      final prepared = prepareCheckinPhoto(file.bytes);
      if (!mounted) return;
      setState(() {
        if (before) {
          _beforePhoto = prepared;
        } else {
          _photo = prepared;
          _video = null;
        }
      });
    } on PhotoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 불러오지 못했어요. 다른 사진을 골라 주세요.');
    }
  }

  Future<void> _chooseVideo() async {
    setState(() => _error = null);
    try {
      final file = await (widget.videoPicker ?? _pickVideo)();
      if (file == null) return;
      final video = prepareCheckinVideo(file.bytes, file.name);
      if (!mounted) return;
      setState(() {
        _video = video;
        _photo = null;
      });
    } on PhotoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '동영상을 불러오지 못했어요. 다른 동영상을 골라 주세요.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = roomErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveBefore() => _run(() async {
        await widget.rooms.saveBefore(widget.roomId, _beforePhoto!, _beforeNote.text.trim());
        if (!mounted) return;
        setState(() {
          _savedBefore = BeforeShot(url: '', note: _beforeNote.text.trim());
          _beforeImage = _beforePhoto;
          _beforePhoto = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전 사진을 올렸어요. 정리를 마치면 후 사진을 올려 주세요')),
        );
      });

  /// 이 화면에서 방금 올린 '전' 사진 (서버 주소 없이 바로 보여 줌)
  Uint8List? _beforeImage;

  Future<void> _submit() => _run(() async {
        await widget.rooms.checkIn(widget.roomId, photo: _photo, video: _video, note: _note.text.trim());
        if (mounted) Navigator.of(context).pop(true);
      });

  bool get _canSubmit {
    if (_busy) return false;
    return switch (_mode) {
      CheckinMode.light => _note.text.trim().isNotEmpty,
      CheckinMode.result => _checked && (_photo != null || _video != null),
      CheckinMode.beforeAfter => _checked && _photo != null && _savedBefore != null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      CheckinMode.light => '오늘 했어요',
      CheckinMode.result => '오늘 정리 인증',
      CheckinMode.beforeAfter => _beforeStep ? '정리 전 사진' : '정리 후 사진',
    };
    final subtitle = switch (_mode) {
      CheckinMode.light => '사진 없이 오늘 한 일을 한 줄로 남겨요.\n방 친구들 피드에 바로 보여요.',
      CheckinMode.result => '다 한 뒤 사진 한 장이나 5초 미만 동영상을 올려 주세요.',
      CheckinMode.beforeAfter => _beforeStep
          ? '정리를 시작하기 전에 지금 모습을 찍어 두세요.\n끝나면 후 사진과 나란히 보여 줘요.'
          : '정리를 마쳤으면 같은 자리를 다시 찍어 주세요.',
    };
    final step = _mode == CheckinMode.beforeAfter ? (_beforeStep ? '1 / 2 단계' : '2 / 2 단계') : null;
    return Scaffold(
      appBar: AppBar(),
      body: _loadingBefore
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                if (step != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(step,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: JdColors.together)),
                  ),
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(fontSize: 15, height: 1.45, color: JdColors.subtle)),
                const SizedBox(height: 20),
                ...switch (_mode) {
                  CheckinMode.light => _light(),
                  CheckinMode.result => _result(),
                  CheckinMode.beforeAfter => _beforeStep ? _before() : _after(),
                },
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
      bottomNavigationBar: _loadingBefore
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _beforeStep
                    ? _primary('전 사진 올리기', _beforePhoto != null && !_busy ? _saveBefore : null)
                    : _primary(_mode == CheckinMode.light ? '했어요' : '인증 저장', _canSubmit ? _submit : null),
              ),
            ),
    );
  }

  Widget _primary(String label, VoidCallback? onPressed) => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: JdColors.together,
          disabledBackgroundColor: JdColors.empty,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: onPressed,
        child: Text(_busy ? '올리는 중...' : label),
      );

  Widget _noteField(TextEditingController c, String label, {String? hint}) => TextField(
        controller: c,
        enabled: !_busy,
        maxLength: _noteMax,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          counterText: '',
        ),
        onChanged: (_) => setState(() {}),
      );

  Widget _doneCheck() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Material(
          color: _checked ? JdColors.togetherTint : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _checked ? JdColors.togetherFill : JdColors.line, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: CheckboxListTile(
            value: _checked,
            onChanged: _busy ? null : (v) => setState(() => _checked = v ?? false),
            title: const Text('오늘 5분 정리를 실제로 했어요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: JdColors.together,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      );

  bool _noticeOpen = false;

  static const _shareNotice = '· 이 방의 현재 참가자에게 공유돼요\n'
      '· 서버에 저장돼요 (사진의 위치정보는 지우고 올려요)\n'
      '· 방 화면의 내 인증에서 삭제하거나 인증을 취소할 수 있어요\n'
      '· 테스트가 끝나면 7일 안에 삭제돼요\n'
      '얼굴·주소·문서가 찍히지 않았는지 미리보기에서 확인해 주세요.';

  Widget _notice() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _noticeOpen = !_noticeOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 16, color: JdColors.faint),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('방 친구에게만 보여요 · 위치정보는 지우고 올려요',
                          style: TextStyle(fontSize: 13, color: JdColors.faint)),
                    ),
                    Icon(_noticeOpen ? Icons.expand_less : Icons.expand_more, size: 18, color: JdColors.faint),
                  ],
                ),
              ),
            ),
            if (_noticeOpen)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: JdColors.panel, borderRadius: BorderRadius.circular(14)),
                child: const Text(_shareNotice, style: TextStyle(fontSize: 13, height: 1.5, color: JdColors.subtle)),
              ),
          ],
        ),
      );

  /// 고른 사진 미리보기. 오른쪽 위 버튼으로 다시 고른다.
  Widget _photoPreview(Uint8List bytes, {String? label, required VoidCallback onChange}) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(bytes, fit: BoxFit.cover),
              if (label != null) Positioned(left: 12, top: 12, child: _Badge(label)),
              Positioned(right: 10, top: 10, child: _ChangeButton(onTap: _busy ? null : onChange)),
            ],
          ),
        ),
      );

  List<Widget> _light() => [
        _noteField(_note, '오늘의 한 줄', hint: '예: 책상 왼쪽 서랍 정리 끝!'),
      ];

  List<Widget> _result() => [
        if (_photo != null)
          _photoPreview(_photo!, onChange: () => _choosePhoto())
        else if (_video != null)
          Container(
            height: 160,
            decoration: BoxDecoration(color: JdColors.ink, borderRadius: BorderRadius.circular(20)),
            child: Stack(
              children: [
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                      const SizedBox(width: 10),
                      Text('동영상 ${_video!.seconds.toStringAsFixed(1)}초 선택됨',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Positioned(right: 10, top: 10, child: _ChangeButton(onTap: _busy ? null : _chooseVideo)),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _PickTile(
                  icon: Icons.add_photo_alternate_outlined,
                  label: '사진',
                  onTap: _busy ? null : () => _choosePhoto(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickTile(
                  icon: Icons.videocam_outlined,
                  label: '동영상',
                  sub: '5초 미만',
                  onTap: _busy ? null : _chooseVideo,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        _noteField(_note, '한 줄 (선택)', hint: '어땠는지 한 줄 남겨 보세요'),
        _doneCheck(),
        _notice(),
      ];

  List<Widget> _before() => [
        if (_beforePhoto != null)
          _photoPreview(_beforePhoto!, label: '전', onChange: () => _choosePhoto(before: true))
        else
          AspectRatio(
            aspectRatio: 4 / 3,
            child: _PickTile(
              icon: Icons.add_a_photo_outlined,
              label: '전 사진 고르기',
              onTap: _busy ? null : () => _choosePhoto(before: true),
            ),
          ),
        const SizedBox(height: 16),
        _noteField(_beforeNote, '전 한 줄 (선택)', hint: '예: 서랍이 터지기 직전'),
        _notice(),
      ];

  List<Widget> _after() {
    final before = _savedBefore!;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _halfShot('전', before.note, memory: _beforeImage, url: before.url)),
          const SizedBox(width: 10),
          Expanded(
            child: _photo == null
                ? AspectRatio(
                    aspectRatio: 3 / 4,
                    child: _PickTile(
                      icon: Icons.add_a_photo_outlined,
                      label: '후 사진 고르기',
                      onTap: _busy ? null : () => _choosePhoto(),
                    ),
                  )
                : _halfShot('후', _note.text.trim(), memory: _photo, onChange: () => _choosePhoto()),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _noteField(_note, '후 한 줄 (선택)', hint: '예: 서랍이 닫혀요!'),
      _doneCheck(),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _busy ? null : () => setState(() => _savedBefore = null),
          child: const Text('전 사진 다시 올리기', style: TextStyle(color: JdColors.subtle)),
        ),
      ),
    ];
  }

  Widget _halfShot(String label, String? note, {Uint8List? memory, String? url, VoidCallback? onChange}) {
    final Widget image;
    if (memory != null) {
      image = Image.memory(memory, fit: BoxFit.cover);
    } else if (url != null && url.isNotEmpty) {
      image = Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _Blank());
    } else {
      image = const _Blank();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(fit: StackFit.expand, children: [
              image,
              Positioned(left: 8, top: 8, child: _Badge(label)),
              if (onChange != null) Positioned(right: 6, top: 6, child: _ChangeButton(onTap: _busy ? null : onChange)),
            ]),
          ),
        ),
        if (note != null && note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(note, style: const TextStyle(fontSize: 14)),
          ),
      ],
    );
  }
}

/// 비어 있는 사진·동영상 자리. 눌러서 고른다.
class _PickTile extends StatelessWidget {
  const _PickTile({required this.icon, required this.label, this.sub, this.onTap});

  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: JdColors.togetherTint,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 132),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: JdColors.togetherEmpty, width: 1.5),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 34, color: JdColors.together),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: JdColors.togetherText)),
                if (sub != null) Text(sub!, style: const TextStyle(fontSize: 12, color: JdColors.subtle)),
              ],
            ),
          ),
        ),
      );
}

class _ChangeButton extends StatelessWidget {
  const _ChangeButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black54,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('다시 고르기', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      );
}

class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: JdColors.empty,
        child: Center(child: Icon(Icons.image_outlined, color: JdColors.faint)),
      );
}
