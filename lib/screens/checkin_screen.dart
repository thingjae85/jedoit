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
    this.kind = ChallengeKind.tidy,
    this.title = '책상 한 구역 정리',
    this.picker,
    this.videoPicker,
  });

  final RoomService rooms;
  final String roomId;
  final CheckinMode mode;

  /// 챌린지 종류·이름. 정리 챌린지가 아니면 문구를 이름에 맞춘다.
  final ChallengeKind kind;
  final String title;

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
  bool get _tidy => widget.kind == ChallengeKind.tidy;

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
          SnackBar(content: Text(_tidy ? '전 사진을 올렸어요. 정리를 마치면 후 사진을 올려 주세요' : '전 사진을 올렸어요. 다 하고 나면 후 사진을 올려 주세요')),
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
      CheckinMode.result => _tidy ? '오늘 정리 인증' : '오늘 인증',
      CheckinMode.beforeAfter => _tidy
          ? (_beforeStep ? '정리 전 사진' : '정리 후 사진')
          : (_beforeStep ? '시작 전 사진' : '다 한 뒤 사진'),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loadingBefore
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                ...switch (_mode) {
                  CheckinMode.light => _light(),
                  CheckinMode.result => _result(),
                  CheckinMode.beforeAfter => _beforeStep ? _before() : _after(),
                },
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
    );
  }

  Widget _noteField(TextEditingController c, String label, {String? hint}) => TextField(
        controller: c,
        enabled: !_busy,
        maxLength: _noteMax,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: (_) => setState(() {}),
      );

  Widget _doneCheck() => CheckboxListTile(
        value: _checked,
        onChanged: _busy ? null : (v) => setState(() => _checked = v ?? false),
        title: Text(_tidy ? '오늘 5분 정리를 실제로 했어요' : '오늘 ${withObject(widget.title)} 실제로 했어요'),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      );

  Widget _submitButton(String label) => FilledButton(
        style: FilledButton.styleFrom(backgroundColor: JdColors.together),
        onPressed: _canSubmit ? _submit : null,
        child: Text(_busy ? '올리는 중...' : label),
      );

  static const _shareNotice = '· 이 방의 현재 참가자에게 공유돼요\n'
      '· 서버에 저장돼요 (사진의 위치정보는 지우고 올려요)\n'
      '· 방 화면의 내 인증에서 삭제하거나 인증을 취소할 수 있어요\n'
      '· 테스트가 끝나면 7일 안에 삭제돼요\n'
      '얼굴·주소·문서가 찍히지 않았는지 미리보기에서 확인해 주세요.';

  Widget _notice() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(_shareNotice, style: Theme.of(context).textTheme.bodySmall),
        ),
      );

  Widget _photoPreview(Uint8List bytes, {String? label}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Image.memory(bytes, height: 280, width: double.infinity, fit: BoxFit.cover),
              if (label != null) Positioned(left: 10, top: 10, child: _Badge(label)),
            ],
          ),
        ),
      );

  List<Widget> _light() => [
        const Text('사진 없이 오늘 한 일을 한 줄로 남겨요. 방 친구들 피드에 바로 보여요.',
            style: TextStyle(fontSize: 15, color: JdColors.subtle)),
        const SizedBox(height: 16),
        _noteField(_note, '오늘의 한 줄', hint: _tidy ? '예: 책상 왼쪽 서랍 정리 끝!' : '예: 오늘은 조금 더 했어요!'),
        const SizedBox(height: 8),
        _submitButton('했어요'),
      ];

  List<Widget> _result() => [
        const Text('다 한 뒤 사진 한 장이나 5초 미만 동영상을 올려 주세요.',
            style: TextStyle(fontSize: 15, color: JdColors.subtle)),
        const SizedBox(height: 12),
        if (_photo != null) _photoPreview(_photo!),
        if (_video != null)
          Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: JdColors.togetherTint, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam, color: JdColors.together),
                const SizedBox(width: 8),
                Text('동영상 ${_video!.seconds.toStringAsFixed(1)}초 선택됨',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _choosePhoto(),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('사진'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _chooseVideo,
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('동영상 (5초 미만)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _noteField(_note, '한 줄 (선택)', hint: '어땠는지 한 줄 남겨 보세요'),
        _notice(),
        _doneCheck(),
        _submitButton('인증 저장'),
      ];

  List<Widget> _before() => [
        Text(_tidy ? '정리를 시작하기 전에 지금 모습을 찍어 두세요. 끝나면 후 사진을 올려 나란히 보여 줘요.' : '시작하기 전에 한 장 찍어 두세요. 다 하면 후 사진을 올려 나란히 보여 줘요.',
            style: const TextStyle(fontSize: 15, color: JdColors.subtle)),
        const SizedBox(height: 12),
        if (_beforePhoto != null) _photoPreview(_beforePhoto!, label: '전'),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _choosePhoto(before: true),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(_beforePhoto == null ? '전 사진 고르기' : '다른 사진 고르기'),
        ),
        const SizedBox(height: 12),
        _noteField(_beforeNote, '전 한 줄 (선택)', hint: '예: 서랍이 터지기 직전'),
        _notice(),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: JdColors.together),
          onPressed: _beforePhoto != null && !_busy ? _saveBefore : null,
          child: Text(_busy ? '올리는 중...' : '전 사진 올리기'),
        ),
      ];

  List<Widget> _after() {
    final before = _savedBefore!;
    return [
      Text(_tidy ? '정리를 마쳤으면 같은 자리를 다시 찍어 주세요.' : '다 했으면 한 장 더 찍어 주세요.', style: const TextStyle(fontSize: 15, color: JdColors.subtle)),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _halfShot('전', before.note, memory: _beforeImage, url: before.url)),
          const SizedBox(width: 8),
          Expanded(child: _halfShot('후', _note.text.trim(), memory: _photo)),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _choosePhoto(),
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(_photo == null ? '후 사진 고르기' : '다른 사진 고르기'),
      ),
      TextButton(
        onPressed: _busy ? null : () => setState(() => _savedBefore = null),
        child: const Text('전 사진 다시 올리기', style: TextStyle(color: JdColors.subtle)),
      ),
      _noteField(_note, '후 한 줄 (선택)', hint: '예: 서랍이 닫혀요!'),
      _doneCheck(),
      _submitButton('인증 저장'),
    ];
  }

  Widget _halfShot(String label, String? note, {Uint8List? memory, String? url}) {
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
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(fit: StackFit.expand, children: [image, Positioned(left: 8, top: 8, child: _Badge(label))]),
          ),
        ),
        if (note != null && note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(note, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
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
