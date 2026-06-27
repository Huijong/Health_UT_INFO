import 'package:flutter/material.dart';
import '../models/attached_file.dart';
import '../models/device_session.dart';
import '../models/pack_result.dart';
import '../services/file_service.dart';
import '../services/packing_service.dart';
import '../services/prefs_service.dart';
import '../widgets/attached_file_tile.dart';

/// Galaxy Watch 드롭다운 선택지
const List<String> kWatchOptions = [
  'Galaxy Watch 4',
  'Galaxy Watch 4 Classic',
  'Galaxy Watch 5',
  'Galaxy Watch 5 Pro',
  'Galaxy Watch 6',
  'Galaxy Watch 6 Classic',
  'Galaxy Watch 7',
  'Galaxy Watch Ultra',
  'Galaxy Watch FE',
  '직접입력',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();

  // 텍스트 컨트롤러
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _customWatchCtrl = TextEditingController();

  String _selectedWatch = kWatchOptions.first;

  // 첨부 파일 목록
  final List<AttachedFile> _fitFiles = [];
  final List<AttachedFile> _colaFiles = [];
  final List<AttachedFile> _captureFiles = [];

  // 파일 선택/복사 진행 중일 때 true → 버튼 비활성화
  bool _fileBusy = false;

  PackResult? _packResult; // 압축 완료 후 결과 보관 (다음 단계 공유에 사용)

  DeviceSession? _session;
  PrefsService? _prefs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await PrefsService.create();
    final session = await DeviceSession.collect();

    _nameCtrl.text = prefs.name;
    final h = prefs.height;
    final w = prefs.weight;
    if (h != null) _heightCtrl.text = h.toStringAsFixed(1);
    if (w != null) _weightCtrl.text = w.toStringAsFixed(1);

    setState(() {
      _prefs = prefs;
      _session = session;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _memoCtrl.dispose();
    _customWatchCtrl.dispose();
    super.dispose();
  }

  // ── 파일 선택 핸들러 ──────────────────────────────────────────

  Future<void> _pickFit() async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);
    try {
      final f = await FileService.pickFit();
      if (f != null && mounted) setState(() => _fitFiles.add(f));
    } catch (e) {
      _showFileError('FIT 파일', e);
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _pickCola() async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);
    try {
      final f = await FileService.pickCola();
      if (f != null && mounted) setState(() => _colaFiles.add(f));
    } catch (e) {
      _showFileError('Cola.zip', e);
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _pickCaptures() async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);
    try {
      final files = await FileService.pickCaptures();
      if (files.isNotEmpty && mounted) {
        setState(() => _captureFiles.addAll(files));
      }
    } catch (e) {
      _showFileError('운동 캡처', e);
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  void _removeFile(List<AttachedFile> list, int index) {
    setState(() => list.removeAt(index));
  }

  void _showFileError(String label, Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 선택 오류: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ── 보내기 버튼 핸들러 ─────────────────────────────────────────
  Future<void> _onSend() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final height = double.parse(_heightCtrl.text.trim());
    final weight = double.parse(_weightCtrl.text.trim());
    final watchName = _selectedWatch == '직접입력'
        ? _customWatchCtrl.text.trim()
        : _selectedWatch;
    final memo = _memoCtrl.text.trim();

    await _prefs?.saveName(name);
    await _prefs?.saveHeight(height);
    await _prefs?.saveWeight(weight);

    if (!mounted) return;

    // 압축 진행 다이얼로그 (뒤로가기로 닫기 불가)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('파일 압축 중...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await PackingService.pack(
        name: name,
        heightCm: height,
        weightKg: weight,
        watch: watchName,
        memo: memo,
        session: _session!,
        fitFiles: _fitFiles,
        colaFiles: _colaFiles,
        captureFiles: _captureFiles,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // 다이얼로그 닫기
      setState(() => _packResult = result);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('압축 완료: ${result.zipName} (${result.sizeLabel})'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('압축 실패: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ── 빌드 ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Samsung Health 검증 수집기'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── 사용자 정보 ──────────────────────────────────────
            _SectionHeader('사용자 정보'),
            _nameField(),
            const SizedBox(height: 12),
            _heightWeightRow(),
            const SizedBox(height: 12),
            _watchDropdown(),
            if (_selectedWatch == '직접입력') ...[
              const SizedBox(height: 12),
              _customWatchField(),
            ],
            const SizedBox(height: 12),
            _memoField(),
            const SizedBox(height: 24),

            // ── 파일 첨부 ─────────────────────────────────────────
            _SectionHeader('파일 첨부'),

            // FIT
            _AttachButton(
              icon: Icons.fitness_center,
              label: 'FIT 파일 추가',
              hint: '삼성 헬스 → 다운로드/삼성 헬스/fit',
              busy: _fileBusy,
              onTap: _fileBusy ? null : _pickFit,
            ),
            ..._fitFiles.asMap().entries.map(
              (e) => AttachedFileTile(
                file: e.value,
                onDelete: () => _removeFile(_fitFiles, e.key),
              ),
            ),
            const SizedBox(height: 8),

            // Cola.zip
            _AttachButton(
              icon: Icons.folder_zip_outlined,
              label: 'Cola.zip 추가',
              hint: 'Documents/COLA_FILE 폴더 → COLA_FILE*.zip',
              busy: _fileBusy,
              onTap: _fileBusy ? null : _pickCola,
            ),
            ..._colaFiles.asMap().entries.map(
              (e) => AttachedFileTile(
                file: e.value,
                onDelete: () => _removeFile(_colaFiles, e.key),
              ),
            ),
            const SizedBox(height: 8),

            // 운동 캡처
            _AttachButton(
              icon: Icons.photo_library_outlined,
              label: '운동 캡처 선택 (다중)',
              hint: '갤러리에서 여러 장 선택 가능',
              busy: _fileBusy,
              onTap: _fileBusy ? null : _pickCaptures,
            ),
            ..._captureFiles.asMap().entries.map(
              (e) => AttachedFileTile(
                file: e.value,
                onDelete: () => _removeFile(_captureFiles, e.key),
              ),
            ),
            const SizedBox(height: 24),

            // ── 자동 수집 정보 ────────────────────────────────────
            _SectionHeader('자동 수집 정보'),
            _DeviceInfoCard(session: _session!),

            // ── 압축 결과 (보내기 완료 후 표시) ───────────────────
            if (_packResult != null) ...[
              const SizedBox(height: 24),
              _PackResultCard(result: _packResult!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _SendBar(onSend: _onSend),
    );
  }

  // ── 개별 필드 빌더 ────────────────────────────────────────────
  Widget _nameField() {
    return TextFormField(
      controller: _nameCtrl,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: '테스터 이름 *',
        prefixIcon: Icon(Icons.person_outline),
        border: OutlineInputBorder(),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return '이름을 입력하세요';
        return null;
      },
    );
  }

  Widget _heightWeightRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _heightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '키 (cm) *',
              prefixIcon: Icon(Icons.height),
              border: OutlineInputBorder(),
            ),
            validator: _validatePositiveNumber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '몸무게 (kg) *',
              prefixIcon: Icon(Icons.monitor_weight_outlined),
              border: OutlineInputBorder(),
            ),
            validator: _validatePositiveNumber,
          ),
        ),
      ],
    );
  }

  Widget _watchDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedWatch,
      decoration: const InputDecoration(
        labelText: '착용 워치',
        prefixIcon: Icon(Icons.watch_outlined),
        border: OutlineInputBorder(),
      ),
      items: kWatchOptions
          .map((w) => DropdownMenuItem(value: w, child: Text(w)))
          .toList(),
      onChanged: (v) =>
          setState(() => _selectedWatch = v ?? kWatchOptions.first),
    );
  }

  Widget _customWatchField() {
    return TextFormField(
      controller: _customWatchCtrl,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: '워치 이름 직접입력 *',
        prefixIcon: Icon(Icons.edit_outlined),
        border: OutlineInputBorder(),
      ),
      validator: (v) {
        if (_selectedWatch == '직접입력' && (v == null || v.trim().isEmpty)) {
          return '워치 이름을 입력하세요';
        }
        return null;
      },
    );
  }

  Widget _memoField() {
    return TextFormField(
      controller: _memoCtrl,
      maxLines: 3,
      textInputAction: TextInputAction.newline,
      decoration: const InputDecoration(
        labelText: '세션 메모',
        prefixIcon: Icon(Icons.notes_outlined),
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }

  String? _validatePositiveNumber(String? v) {
    if (v == null || v.trim().isEmpty) return '값을 입력하세요';
    final num = double.tryParse(v.trim());
    if (num == null || num <= 0) return '올바른 숫자를 입력하세요';
    return null;
  }
}

// ── 재사용 위젯들 ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback? onTap;
  final bool busy;

  const _AttachButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null && !busy;
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).disabledColor;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(color: color),
        foregroundColor: color,
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final DeviceSession session;
  const _DeviceInfoCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('기기 모델', session.deviceModel),
      ('Android 버전', session.androidVersion),
      ('앱 버전', session.appVersion),
      ('생성 일시', session.createdAt),
      ('세션 ID', session.sessionId),
    ];

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: rows.map((r) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      r.$1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.$2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── 압축 결과 카드 ────────────────────────────────────────────────

class _PackResultCard extends StatelessWidget {
  final PackResult result;
  const _PackResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '압축 완료',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row('파일명', result.zipName),
            _row('크기', result.sizeLabel),
            const Divider(height: 20),
            Text(
              '다음 단계: 공유하기로 관리자에게 전송',
              style: TextStyle(
                fontSize: 12,
                color: cs.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendBar extends StatelessWidget {
  final VoidCallback onSend;
  const _SendBar({required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: onSend,
          icon: const Icon(Icons.send_rounded),
          label: const Text(
            '보내기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ),
    );
  }
}
