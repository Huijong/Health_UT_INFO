import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../models/attached_file.dart';
import '../models/device_session.dart';
import '../models/pack_result.dart';
import '../services/file_service.dart';
import '../services/packing_service.dart';
import '../services/prefs_service.dart';
import '../services/share_service.dart';
import '../services/email_service.dart';
import '../widgets/attached_file_tile.dart';
import 'settings_screen.dart';
import 'location_picker_screen.dart';
import 'notice_history_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:url_launcher/url_launcher.dart';

/// Galaxy Watch 드롭다운 선택지 (2단계 전용)
const List<String> kWatchOptions = [
  'Galaxy Watch 9 Small',
  'Galaxy Watch 9 Large',
  'Galaxy Watch Ultra2',
  'Galaxy Watch 9 FE',
  'Galaxy Watch 8 small',
  'Galaxy Watch 8 large',
  'Galaxy Watch 8 Classic',
  'Galaxy Watch 8 FE',
  'Galaxy Watch 7 Small',
  'Galaxy Watch 7 Large',
  'Galaxy Watch Ultra',
  'Galaxy Watch 7 FE',
  '직접입력',
];

/// 워치 스트랩 선택지 (3단계 전용)
const List<Map<String, String>> kStrapOptions = [
  {
    'name': '갤럭시 워치8 시리즈 하이브리드 밴드 (S/M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/hybrid-band-for-galaxy-watch-8/ET-SLL50LWEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 스포츠 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/sports-band-slim-sm-for-galaxy-watch-8/ET-SNL32SNEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 스포츠 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/sports-band-wide-ml-for-galaxy-watch-8/ET-SNL33LBEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 애슬레저 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/athleisure-band-slim-sm-for-galaxy-watch-8/ET-SOL32SNEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 애슬레저 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/athleisure-band-wide-ml-for-galaxy-watch-8/ET-SOL33LNEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 패브릭 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/fabric-band-slim-sm-for-galaxy-watch-8/ET-SVL32SNEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 패브릭 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/fabric-band-wide-ml-for-galaxy-watch-8/ET-SVL33LNEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 프리미엄 레더 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/premium-leather-band-for-galaxy-watch-8/GP-TYL505AMBBK/'
  },
  {
    'name': '갤럭시 워치8 시리즈 슬림 레더 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/slim-leather-band-for-galaxy-watch-8/GP-TYL325AMBBK/'
  },
  {
    'name': '갤럭시 워치8 시리즈 나토 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/nato-band-galaxy-watch-8/GP-TYL335AMBJK/'
  },
  {
    'name': '갤럭시 워치8 시리즈 벨크로 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/velcro-band-for-galaxy-watch-8/GP-TYL335HICNK/'
  },
  {
    'name': '갤럭시 워치 울트라 마린 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/marine-band-galaxy-watch-ultra/ET-SNL70MNEGKR/'
  },
  {
    'name': '갤럭시 워치 울트라 트레일 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/trail-band-galaxy-watch-ultra/ET-SVL70MNEGKR/'
  },
  {
    'name': '갤럭시 워치 울트라 픽폼 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/peakform-band-for-galaxy-watch-ultra/ET-SBL70MBEGKR/'
  },
  {
    'name': '갤럭시 워치7 스포츠 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/sports-band-wide-ml-for-galaxy-watch-7/ET-SNL31LKEGKR/'
  },
  {
    'name': '갤럭시 워치7 스포츠 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/sports-band-slim-sm-for-galaxy-watch-7/ET-SNL30SOEGKR/'
  },
  {
    'name': '갤럭시 워치7 애슬레저 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/athleisure-band-slim-sm-for-galaxy-watch-7/ET-SOL31LLEGKR/'
  },
  {
    'name': '갤럭시 워치7 애슬레저 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/athleisure-band-wide-ml-for-galaxy-watch-7/ET-SOL30SPEGKR/'
  },
  {
    'name': '갤럭시 워치7 패브릭 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/fabric-band-wide-ml-for-galaxy-watch-7/ET-SVL31LWEGKR/'
  },
  {
    'name': '갤럭시 워치7 패브릭 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/fabric-band-slim-sm-for-galaxy-watch-7/ET-SVL30SWEGKR/'
  },
  {
    'name': '직접입력',
    'url': ''
  }
];

/// 운동 종류 선택지 (4단계 전용)
const List<Map<String, dynamic>> kExerciseOptions = [
  {'name': '야외 걷기', 'icon': Icons.directions_walk_rounded},
  {'name': '야외 달리기', 'icon': Icons.directions_run_rounded},
  {'name': '러닝머신 걷기', 'icon': Icons.directions_walk_outlined},
  {'name': '러닝머신 달리기', 'icon': Icons.directions_run_outlined},
  {'name': '하이킹', 'icon': Icons.terrain_rounded},
  {'name': '트레일 러닝', 'icon': Icons.forest_rounded},
  {'name': '실외 자전거', 'icon': Icons.directions_bike_rounded},
  {'name': '실내 수영', 'icon': Icons.pool_rounded},
  {'name': '야외 수영', 'icon': Icons.water_rounded},
  {'name': '근력 운동', 'icon': Icons.fitness_center_rounded},
  {'name': '기타운동', 'icon': Icons.sports_rounded},
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final _formKey1 = GlobalKey<FormState>();
  final _formKey5 = GlobalKey<FormState>();

  // 가이드 영상 관련 상태 변수 및 애니메이션 컨트롤러
  AnimationController? _guidePulseController;
  bool _hasWatchedGuide = false;

  // 공지사항 관련 상태 변수 및 애니메이션 컨트롤러
  Map<String, dynamic>? _latestNotice;
  bool _isNoticeBlinking = false;
  AnimationController? _noticePulseController;
  bool _pendingNoticeHistory = false;

  // 동의서 관련 상태 변수
  bool _agreePersonal = false;
  bool _agreeLocation = false;

  // 현재 위저드 단계 (1 ~ 6)
  int _currentStep = 1;

  // 1단계 컨트롤러
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  // 2단계 워치
  String _selectedWatch = kWatchOptions.first;
  final _customWatchCtrl = TextEditingController();

  // 3단계 스트랩
  String _selectedStrap = kStrapOptions.first['name']!;
  final _customStrapCtrl = TextEditingController();

  // 4단계 운동
  String _selectedExercise = kExerciseOptions.first['name'];

  // 5단계 디테일 및 첨부파일
  final List<AttachedFile> _fitFiles = [];
  final List<AttachedFile> _colaFiles = [];
  final List<AttachedFile> _logFiles = [];
  final List<AttachedFile> _captureFiles = [];

  bool _fileBusy = false;
  String _wearingPosition = '왼쪽'; // 왼쪽 / 오른쪽
  String _wearingTightness = '적당히'; // 충분히 / 적당히 / 느슨하게
  String _competitorWatch = '없음'; // 가민 / 애플 / 크로스 / 없음 / 직접입력
  final _customCompetitorCtrl = TextEditingController();

  String _trainingType = '조깅'; // 조깅 / 인터벌 / LSD / 변속주 / 지속주 / 직접입력
  final _customTrainingCtrl = TextEditingController();

  final _locationCtrl = TextEditingController();
  final _memoCtrl = TextEditingController(); // 특이 사항

  // 6단계 완료 정보 및 상태
  PackResult? _packResult;
  String? _lastProcessedLink;
  bool _isPackaging = false;
  bool _emailSending = false;
  bool _emailSent = false;
  String? _emailError;

  DeviceSession? _session;
  PrefsService? _prefs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    final savedWatch = prefs.watch;
    final savedStrap = prefs.strap;
    if (savedWatch.isNotEmpty) _selectedWatch = savedWatch;
    _customWatchCtrl.text = prefs.customWatch;
    if (savedStrap.isNotEmpty) _selectedStrap = savedStrap;
    _customStrapCtrl.text = prefs.customStrap;

    final hasWatched = prefs.hasWatchedGuide;
    _guidePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (!hasWatched) {
      _guidePulseController?.repeat(reverse: true);
    }

    _noticePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Foreground FCM 수신 대기 설정
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null && mounted) {
        // 공지사항 푸시 수신 시 실시간으로 공지 카드도 갱신
        _fetchLatestNotice();

        final noticeId = message.data['notice_id'] as String?;
        final testerName = _prefs?.name.trim() ?? '';
        if (noticeId != null && testerName.isNotEmpty) {
          _sendNoticeAck(noticeId, testerName);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Color(0xFF3DFFC1)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(notification.title ?? '공지사항', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(notification.body ?? '', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: const Color(0xFF1429A0).withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    // 백그라운드 상태에서 푸시 알림을 탭하여 앱을 열었을 때 공지사항 즉시 갱신 및 히스토리 이동
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("[FCM] Notification tapped from background. Reloading notices & navigating to history.");
      _fetchLatestNotice();
      _navigateToNoticeHistory();

      final noticeId = message.data['notice_id'] as String?;
      final testerName = _prefs?.name.trim() ?? '';
      if (noticeId != null && testerName.isNotEmpty) {
        _sendNoticeAck(noticeId, testerName);
      }
    });

    // 앱이 완전히 종료된 상태에서 푸시 알림을 탭하여 앱을 시작했을 때 공지사항 즉시 갱신 및 히스토리 이동
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("[FCM] App launched from terminated state via notification. Reloading notices & navigating to history.");
        _fetchLatestNotice();
        _navigateToNoticeHistory();

        final noticeId = message.data['notice_id'] as String?;
        final testerName = _prefs?.name.trim() ?? '';
        if (noticeId != null && testerName.isNotEmpty) {
          _sendNoticeAck(noticeId, testerName);
        }
      }
    });

    setState(() {
      _prefs = prefs;
      _session = session;
      _hasWatchedGuide = hasWatched;
      _currentStep = prefs.onboardingComplete ? 4 : 1;
      _isLoading = false;
    });

    // 최신 공지사항 로드
    _fetchLatestNotice();

    // 기기 접속 핑 전송
    _sendDevicePing();

    // 펜딩된 히스토리 이동 요청 처리
    if (_pendingNoticeHistory) {
      _navigateToNoticeHistory();
    }
  }

  void _navigateToNoticeHistory() {
    if (!mounted) return;
    if (_prefs == null) {
      _pendingNoticeHistory = true;
      return;
    }
    _pendingNoticeHistory = false;
    
    // 이미 히스토리 화면이 위에 열려있는지 여부를 체크하지 않고 단순히 push하면 다중으로 쌓일 수 있으므로 안전하게 push합니다.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoticeHistoryScreen(prefs: _prefs!),
      ),
    ).then((_) => _fetchLatestNotice());
  }

  Future<void> _sendDevicePing() async {
    if (!mounted || _prefs == null || _session == null) return;
    final testerName = _prefs!.name.trim();
    if (testerName.isEmpty) return;

    try {
      final watchName = _selectedWatch == '직접입력'
          ? _customWatchCtrl.text.trim()
          : _selectedWatch;
      final url = Uri.parse('${AppConfig.apiUrl}/api/devices/ping');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tester_name': testerName,
          'watch': watchName.isEmpty ? '미지정' : watchName,
          'os_version': 'Android ${_session!.androidVersion} (Model: ${_session!.deviceModel})',
        }),
      );
      debugPrint("[PING] Device ping sent successfully for $testerName");
    } catch (e) {
      debugPrint("[PING] Failed to send device ping: $e");
    }
  }

  Future<void> _sendNoticeAck(String noticeId, String testerName) async {
    if (noticeId.isEmpty || testerName.isEmpty) return;
    try {
      final url = Uri.parse('${AppConfig.apiUrl}/api/notices/$noticeId/ack');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tester_name': testerName}),
      );
      debugPrint("[ACK] Notice ACK sent successfully for $testerName on notice $noticeId");
    } catch (e) {
      debugPrint("[ACK] Failed to send notice ACK: $e");
    }
  }

  void _reloadPrefs() {
    if (_prefs == null) return;
    setState(() {
      _nameCtrl.text = _prefs!.name;
      final h = _prefs!.height;
      final w = _prefs!.weight;
      if (h != null) _heightCtrl.text = h.toStringAsFixed(1);
      if (w != null) _weightCtrl.text = w.toStringAsFixed(1);

      final savedWatch = _prefs!.watch;
      final savedStrap = _prefs!.strap;
      if (savedWatch.isNotEmpty) _selectedWatch = savedWatch;
      _customWatchCtrl.text = _prefs!.customWatch;
      if (savedStrap.isNotEmpty) _selectedStrap = savedStrap;
      _customStrapCtrl.text = _prefs!.customStrap;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _customWatchCtrl.dispose();
    _customStrapCtrl.dispose();
    _customCompetitorCtrl.dispose();
    _customTrainingCtrl.dispose();
    _locationCtrl.dispose();
    _memoCtrl.dispose();
    _guidePulseController?.dispose();
    _noticePulseController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── 클립보드 감시 및 이메일 전송 ──────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _packResult != null) {
      Future.delayed(const Duration(milliseconds: 400), _checkClipboard);
    }
  }

  Future<void> _checkClipboard() async {
    if (!mounted || _packResult == null || _emailSent) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return;
      if (text == _lastProcessedLink) return;
      if (!text.startsWith('http')) return;

      final lowerText = text.toLowerCase();
      final pattern = AppConfig.quickSharePattern.toLowerCase();
      final isQuickShare = lowerText.contains(pattern) ||
          lowerText.contains('samsungcloud.com') ||
          lowerText.contains('quickshare') ||
          lowerText.contains('sharing.samsung') ||
          lowerText.contains('q1team.cc');
      if (!isQuickShare) return;

      setState(() {
        _lastProcessedLink = text;
      });

      // 클립보드 링크가 감지되면 자동으로 이메일 전송 트리거
      await _sendEmail(text);
    } catch (_) {}
  }

  Future<void> _sendEmail(String link) async {
    if (!mounted) return;
    setState(() {
      _emailSending = true;
      _emailError = null;
    });

    try {
      final watchName = _selectedWatch == '직접입력'
          ? _customWatchCtrl.text.trim()
          : _selectedWatch;
      final strapName = _selectedStrap == '직접입력'
          ? _customStrapCtrl.text.trim()
          : _selectedStrap;
      final compDevice = _competitorWatch == '직접입력'
          ? _customCompetitorCtrl.text.trim()
          : _competitorWatch;
      final tType = _trainingType == '직접입력'
          ? _customTrainingCtrl.text.trim()
          : _trainingType;

      await EmailService.send(
        link: link,
        sessionId: _session?.sessionId ?? '',
        testerName: _nameCtrl.text.trim(),
        deviceModel: _session?.deviceModel ?? 'Unknown',
        androidVersion: _session?.androidVersion ?? 'Unknown',
        height: _heightCtrl.text.trim(),
        weight: _weightCtrl.text.trim(),
        watch: watchName,
        strap: strapName,
        exercise: _selectedExercise,
        wearingPosition: _wearingPosition,
        wearingTightness: _wearingTightness,
        competitorWatch: compDevice,
        trainingType: tType,
        location: _locationCtrl.text.trim(),
        remarks: _memoCtrl.text.trim(),
        consentDate: _prefs?.consentDate ?? '',
      );

      if (mounted) {
        setState(() {
          _emailSending = false;
          _emailSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailSending = false;
          _emailError = e.toString();
        });
      }
    }
  }

  // ── 압축 및 전송 시작 ───────────────────────────────────────
  Future<void> _onSend() async {
    if (!_formKey5.currentState!.validate()) return;

    setState(() {
      _isPackaging = true;
      _currentStep = 6;
      _emailSent = false;
      _emailError = null;
      _lastProcessedLink = null;
    });

    try {
      final newSession = await DeviceSession.collect();
      if (!mounted) return;
      setState(() {
        _session = newSession;
      });

      final name = _nameCtrl.text.trim();
      final height = double.parse(_heightCtrl.text.trim());
      final weight = double.parse(_weightCtrl.text.trim());
      final watchName = _selectedWatch == '직접입력'
          ? _customWatchCtrl.text.trim()
          : _selectedWatch;
      final strapName = _selectedStrap == '직접입력'
          ? _customStrapCtrl.text.trim()
          : _selectedStrap;
      final compDevice = _competitorWatch == '직접입력'
          ? _customCompetitorCtrl.text.trim()
          : _competitorWatch;
      final tType = _trainingType == '직접입력'
          ? _customTrainingCtrl.text.trim()
          : _trainingType;
      final memo = _memoCtrl.text.trim();

      await _prefs?.saveName(name);
      await _prefs?.saveHeight(height);
      await _prefs?.saveWeight(weight);

      final result = await PackingService.pack(
        name: name,
        heightCm: height,
        weightKg: weight,
        watch: watchName,
        strap: strapName,
        exercise: _selectedExercise,
        wearingPosition: _wearingPosition,
        wearingTightness: _wearingTightness,
        competitorWatch: compDevice,
        trainingType: tType,
        location: _locationCtrl.text.trim(),
        memo: memo,
        session: _session!,
        fitFiles: _fitFiles,
        colaFiles: _colaFiles,
        logFiles: _logFiles,
        captureFiles: _captureFiles,
      );

      if (mounted) {
        setState(() {
          _packResult = result;
          _isPackaging = false;
        });
      }

      // 압축 성공 후 자동으로 Quick Share 호출
      await ShareService.shareZip(result.zipPath, result.zipName);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPackaging = false;
          _currentStep = 5; // 실패 시 다시 5단계로 복귀
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('압축 실패: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  // ── 데이터 초기화 후 1단계로 리셋 ──────────────────────────────
  void _resetVerification() {
    setState(() {
      _currentStep = (_prefs?.onboardingComplete ?? false) ? 4 : 1;
      _fitFiles.clear();
      _colaFiles.clear();
      _logFiles.clear();
      _captureFiles.clear();
      _memoCtrl.clear();
      _locationCtrl.clear();
      _customWatchCtrl.clear();
      _customStrapCtrl.clear();
      _customCompetitorCtrl.clear();
      _customTrainingCtrl.clear();
      _wearingPosition = '왼쪽';
      _wearingTightness = '적당히';
      _competitorWatch = '없음';
      _trainingType = '조깅';
      _packResult = null;
      _lastProcessedLink = null;
      _isPackaging = false;
      _emailSending = false;
      _emailSent = false;
      _emailError = null;
    });
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

  Future<void> _pickGarminFit() async {
    final String? action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            radius: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, color: Color(0xFF3DFFC1), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Garmin Fit 파일 다운로드',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                const SizedBox(height: 8),
                const Text(
                  '웹페이지에 접속하여 Fit 파일을 다운로드하시겠습니까?',
                  style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 24),
                // 가이드 영상 버튼 (상단에 단독 가로형 배치)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3DFFC1)),
                      foregroundColor: const Color(0xFF3DFFC1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx, 'video'),
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: const Text('가이드 영상', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx, 'no'),
                        child: const Text('아니오'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E5BFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx, 'yes'),
                        child: const Text('예'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null) return;

    if (action == 'video') {
      // Garmin 가이드 영상 재생 다이얼로그 호출
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => const _GuideVideoDialog(videoPath: 'assert/202607115.mp4'),
      );
      // 영상 종료 후 다시 다이얼로그 팝업 호출 (재귀)
      _pickGarminFit();
      return;
    }

    if (action == 'yes') {
      await _launchUrl('https://connect.garmin.com/app/');
    } else if (action == 'no') {
      if (_fileBusy) return;
      setState(() => _fileBusy = true);
      try {
        final f = await FileService.pickGarminFit();
        if (f != null && mounted) {
          final fileName = f.originalPath.split('/').last.split('\\').last;
          if (!fileName.toLowerCase().endsWith('.zip')) {
            _showFileError('Garmin FIT 파일', '선택한 파일이 .zip 파일이 아닙니다.');
            return;
          }
          setState(() => _fitFiles.add(f));
        }
      } catch (e) {
        _showFileError('Garmin FIT 파일', e);
      } finally {
        if (mounted) setState(() => _fileBusy = false);
      }
    }
  }

  Future<void> _pickCola() async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);
    try {
      final f = await FileService.pickCola();
      if (f != null && mounted) {
        final fileName = f.originalPath.split('/').last.split('\\').last;
        if (!fileName.toLowerCase().startsWith('cola_file')) {
          _showFileError('Cola.zip', '선택한 파일이 COLA_FILE로 시작하는 zip 파일이 아닙니다.');
          return;
        }
        setState(() => _colaFiles.add(f));
      }
    } catch (e) {
      _showFileError('Cola.zip', e);
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _pickLog() async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);
    try {
      final f = await FileService.pickLog();
      if (f != null && mounted) {
        final fileName = f.originalPath.split('/').last.split('\\').last;
        if (!fileName.toLowerCase().startsWith('log_')) {
          _showFileError('로그 파일', '선택한 파일이 log_로 시작하는 zip 파일이 아닙니다.');
          return;
        }
        setState(() => _logFiles.add(f));
      }
    } catch (e) {
      _showFileError('로그 파일', e);
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
        backgroundColor: const Color(0xFFFF5252),
      ),
    );
  }

  // ── 빌드 영역 ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0F0F),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3DFFC1)),
          ),
        ),
      );
    }

    final mainTheme = ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0F0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2E5BFF),
          secondary: Color(0xFF3DFFC1),
          surface: Color(0xFF1E2020),
          error: Color(0xFFFF5252),
        ),
        textTheme: Theme.of(context).textTheme.apply(
              fontFamily: 'Plus_Jakarta_Sans',
              bodyColor: const Color(0xFFE2E2E2),
              displayColor: Colors.white,
            ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2E5BFF), width: 1.5),
          ),
          labelStyle: TextStyle(color: const Color(0xFFE2E2E2).withOpacity(0.7)),
        ),
      );

    if (_prefs != null && !_prefs!.consentGiven) {
      return Theme(
        data: mainTheme,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1429A0),
                  Color(0xFF0A0F24),
                  Color(0xFF05060C),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              child: _buildConsentView(),
            ),
          ),
        ),
      );
    }

    return Theme(
      data: mainTheme,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (_currentStep == 6) {
            setState(() => _currentStep = 4);
          } else if (_currentStep == 4 || _currentStep == 1) {
            SystemNavigator.pop();
          } else if (_currentStep > 1) {
            setState(() => _currentStep--);
          } else {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1429A0),
                  Color(0xFF0A0F24),
                  Color(0xFF05060C),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: _buildCurrentStepView(),
                    ),
                  ),
                  if (_currentStep < 6 && _currentStep != 4) _buildFooterButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 헤더 빌더 ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (_currentStep == 4)
                const SizedBox(width: 40)
              else
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () {
                    if (_currentStep == 6) {
                      setState(() => _currentStep = 4);
                    } else if (_currentStep > 1) {
                      setState(() => _currentStep--);
                    } else {
                      SystemNavigator.pop();
                    }
                  },
                ),
              Expanded(
                child: Text(
                  _getStepTitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (_currentStep == 4)
                IconButton(
                  icon: const Icon(Icons.settings_rounded, size: 22, color: Color(0xFF3DFFC1)),
                  onPressed: () async {
                    if (_prefs == null) return;
                    final updated = await Navigator.push(
                      context,
                      InstantPageRoute(
                        page: SettingsScreen(prefs: _prefs!),
                      ),
                    );
                    if (updated == true) {
                      _reloadPrefs();
                    }
                  },
                )
              else
                const SizedBox(width: 40), // 균형
            ],
          ),
          if (_currentStep <= 3) ...[
            const SizedBox(height: 12),
            // 가로형 프리미엄 스태퍼
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Container(
                height: 6,
                width: double.infinity,
                color: Colors.white.withOpacity(0.1),
                child: Row(
                  children: [
                    Expanded(
                      flex: _currentStep,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2E5BFF), Color(0xFF3DFFC1)],
                          ),
                        ),
                      ),
                    ),
                    if (3 - _currentStep > 0)
                      Expanded(
                        flex: 3 - _currentStep,
                        child: const SizedBox(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step $_currentStep of 3',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFFE2E2E2).withOpacity(0.6),
                  ),
                ),
                Text(
                  '${((_currentStep / 3.0) * 100).toInt().clamp(0, 100)}% 완료',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF3DFFC1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return '테스트 프로필 입력';
      case 2:
        return '착용 워치 기종 선택';
      case 3:
        return '착용 스트랩 종류 선택';
      case 4:
        return '운동 종목 선택';
      case 5:
        return '검증 파일 및 디테일 등록';
      case 6:
        return '패키징 및 전송 완료';
      default:
        return 'SH 검증 수집기';
    }
  }

  // ── 단계별 뷰 분기 ──────────────────────────────────────────────
  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Profile();
      case 2:
        return _buildStep2Watch();
      case 3:
        return _buildStep3Strap();
      case 4:
        return _buildStep4Exercise();
      case 5:
        return _buildStep5Details();
      case 6:
        return _buildStep6Completion();
      default:
        return _buildStep1Profile();
    }
  }

  // ── Step 1: 테스터 프로필 ──────────────────────────────────────
  Widget _buildStep1Profile() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '정밀한 피트니스 분석을 위해 테스터님의 신체 스펙을 입력해 주세요.',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFFE2E2E2).withOpacity(0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          GlassCard(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '이름 *',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력해 주세요' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _heightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '키 (cm) *',
                    prefixIcon: Icon(Icons.height_rounded, size: 20),
                  ),
                  validator: _validatePositiveNumber,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '몸무게 (kg) *',
                    prefixIcon: Icon(Icons.monitor_weight_outlined, size: 20),
                  ),
                  validator: _validatePositiveNumber,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: 착용 워치 선택 ──────────────────────────────────────
  Widget _buildStep2Watch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '테스트 시 착용한 Galaxy Watch 기종을 목록에서 골라주세요.',
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFFE2E2E2).withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ...kWatchOptions.map((watch) {
                final isSel = _selectedWatch == watch;
                return RadioListTile<String>(
                  title: Text(
                    watch,
                    style: TextStyle(
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? const Color(0xFF3DFFC1) : const Color(0xFFE2E2E2),
                    ),
                  ),
                  value: watch,
                  activeColor: Colors.white,
                  groupValue: _selectedWatch,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedWatch = val);
                    }
                  },
                );
              }),
            ],
          ),
        ),
        if (_selectedWatch == '직접입력') ...[
          const SizedBox(height: 16),
          GlassCard(
            child: TextFormField(
              controller: _customWatchCtrl,
              decoration: const InputDecoration(
                labelText: '워치 모델 직접 입력 *',
                prefixIcon: Icon(Icons.edit_rounded, size: 20),
              ),
              validator: (v) {
                if (_selectedWatch == '직접입력' && (v == null || v.trim().isEmpty)) {
                  return '워치 기종명을 입력해 주세요';
                }
                return null;
              },
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('링크를 열 수 없습니다: $urlString')),
        );
      }
    }
  }

  Future<void> _fetchLatestNotice() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/api/notices'));
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded['status'] == 'success' && decoded['data'] != null) {
          final notices = decoded['data'] as List<dynamic>;
          final deletedIds = _prefs?.deletedNoticeIds ?? [];
          final readIds = _prefs?.readNoticeIds ?? [];
          
          // 삭제되지 않은 가장 최신 공지 찾기
          Map<String, dynamic>? activeNotice;
          for (var item in notices) {
            final noticeMap = item as Map<String, dynamic>;
            final id = noticeMap['_id'] as String;
            if (!deletedIds.contains(id)) {
              activeNotice = noticeMap;
              break;
            }
          }

          if (activeNotice != null) {
            final noticeId = activeNotice['_id'] as String;
            final isUnread = !readIds.contains(noticeId);
            
            setState(() {
              _latestNotice = activeNotice;
              _isNoticeBlinking = isUnread;
            });
            
            if (_isNoticeBlinking) {
              _noticePulseController?.repeat(reverse: true);
            } else {
              _noticePulseController?.stop();
            }
          } else {
            setState(() {
              _latestNotice = null;
              _isNoticeBlinking = false;
            });
            _noticePulseController?.stop();
          }
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch latest notice: $e");
    } finally {
      _sendDevicePing();
    }
  }

  void _showNoticeDialog(Map<String, dynamic> notice) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            radius: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Color(0xFFFFD043), size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      '공지사항',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                const SizedBox(height: 8),
                Text(
                  notice['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      notice['content'] ?? '',
                      style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E5BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final noticeId = notice['_id'] as String;
                      await _prefs?.saveLastReadNoticeId(noticeId);
                      _noticePulseController?.stop();
                      setState(() {
                        _isNoticeBlinking = false;
                      });
                    },
                    child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Step 3: 착용 스트랩 선택 ────────────────────────────────────
  Widget _buildStep3Strap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '테스트 시 부착한 공식/서드파티 스트랩 디자인을 고르세요.',
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFFE2E2E2).withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ...kStrapOptions.map((strapOpt) {
                final strapName = strapOpt['name']!;
                final url = strapOpt['url']!;
                final isSel = _selectedStrap == strapName;

                return RadioListTile<String>(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          strapName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? const Color(0xFF3DFFC1) : const Color(0xFFE2E2E2),
                          ),
                        ),
                      ),
                      if (url.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          color: isSel ? const Color(0xFF3DFFC1) : Colors.white60,
                          onPressed: () => _launchUrl(url),
                        ),
                    ],
                  ),
                  value: strapName,
                  activeColor: Colors.white,
                  groupValue: _selectedStrap,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedStrap = val);
                    }
                  },
                );
              }),
            ],
          ),
        ),
        if (_selectedStrap == '직접입력') ...[
          const SizedBox(height: 16),
          GlassCard(
            child: TextFormField(
              controller: _customStrapCtrl,
              decoration: const InputDecoration(
                labelText: '스트랩 직접 입력 *',
                prefixIcon: Icon(Icons.edit_rounded, size: 20),
              ),
              validator: (v) {
                if (_selectedStrap == '직접입력' && (v == null || v.trim().isEmpty)) {
                  return '스트랩 정보 명칭을 적어주세요';
                }
                return null;
              },
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showGuideVideo() async {
    if (!_hasWatchedGuide) {
      await _prefs?.saveHasWatchedGuide(true);
      _guidePulseController?.stop();
      setState(() {
        _hasWatchedGuide = true;
      });
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _GuideVideoDialog(),
    );
  }

  // ── Step 4: 운동 선택 ──────────────────────────────────────────
  Widget _buildStep4Exercise() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '공지 및 가이드 안내',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFE2E2E2).withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _guidePulseController!,
          builder: (context, child) {
            final double val = _guidePulseController?.value ?? 0.0;
            final Color pulseColor = Color.lerp(
              const Color(0xFF2E5BFF),
              const Color(0xFF3DFFC1),
              val,
            )!;

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: _hasWatchedGuide
                    ? null
                    : [
                        BoxShadow(
                          color: pulseColor.withOpacity(0.3 * val),
                          blurRadius: 10 + (8 * val),
                          spreadRadius: 1 + (2 * val),
                        )
                      ],
              ),
              child: child,
            );
          },
          child: InkWell(
            onTap: _showGuideVideo,
            borderRadius: BorderRadius.circular(16),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              radius: 16,
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded, color: Color(0xFF3DFFC1), size: 26),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '가이드 영상 시청하기 📺',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (!_hasWatchedGuide)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3DFFC1).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3DFFC1), width: 1),
                      ),
                      child: const Text(
                        '필독',
                        style: TextStyle(fontSize: 10, color: Color(0xFF3DFFC1), fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_latestNotice != null) ...[
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _noticePulseController!,
            builder: (context, child) {
              final double val = _noticePulseController?.value ?? 0.0;
              final Color pulseColor = Color.lerp(
                const Color(0xFFFFAE2E),
                const Color(0xFFFF4E2E),
                val,
              )!;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: !_isNoticeBlinking
                      ? null
                      : [
                          BoxShadow(
                            color: pulseColor.withOpacity(0.3 * val),
                            blurRadius: 10 + (8 * val),
                            spreadRadius: 1 + (2 * val),
                          )
                        ],
                ),
                child: child,
              );
            },
            child: InkWell(
              onTap: () async {
                if (_prefs != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoticeHistoryScreen(prefs: _prefs!),
                    ),
                  );
                  // 히스토리 화면에서 돌어오면 안 읽은 공지나 삭제(숨김) 정보 갱신
                  _fetchLatestNotice();
                }
              },
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                radius: 16,
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Color(0xFFFFD043), size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '공지사항: ${_latestNotice!['title'] ?? ''} 📢',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_isNoticeBlinking)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD043).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD043), width: 1),
                        ),
                        child: const Text(
                          '새소식',
                          style: TextStyle(fontSize: 10, color: Color(0xFFFFD043), fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          '검증을 위해 테스트를 수행한 운동 대상을 골라주세요.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFE2E2E2).withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kExerciseOptions.length,
          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
          itemBuilder: (ctx, idx) {
            final ex = kExerciseOptions[idx];
            final name = ex['name'] as String;
            final icon = ex['icon'] as IconData;
            final isSel = _selectedExercise == name;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedExercise = name;
                  _currentStep = 5; // 즉시 다음 단계 이동
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                radius: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF3DFFC1).withOpacity(0.15) : Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: isSel ? const Color(0xFF3DFFC1) : Colors.white60, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? const Color(0xFF3DFFC1) : Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: isSel ? const Color(0xFF3DFFC1) : Colors.white30,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Step 5: 파일 첨부 및 디테일 입력 ─────────────────────────────────
  Widget _buildStep5Details() {
    final bool hasFiles = _fitFiles.isNotEmpty || _colaFiles.isNotEmpty || _logFiles.isNotEmpty || _captureFiles.isNotEmpty;

    return Form(
      key: _formKey5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_run_rounded, color: Color(0xFF3DFFC1), size: 16),
              const SizedBox(width: 4),
              Text(
                '선택된 운동: $_selectedExercise',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF3DFFC1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 파일 첨부 카드 섹션 ──
          const Text(
            '1. 검증 데이터 첨부',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 10),

          // FIT
          _buildAttachCard(
            icon: Icons.fitness_center_rounded,
            title: 'FIT 파일 추가',
            hint: 'Download/삼성 헬스/fit',
            busy: _fileBusy,
            onTap: _pickFit,
            files: _fitFiles,
          ),
          const SizedBox(height: 10),

          // Garmin FIT
          _buildAttachCard(
            icon: Icons.directions_bike_rounded,
            title: 'Garmin FIT 파일 추가',
            hint: 'Download/ (zip)',
            busy: _fileBusy,
            onTap: _pickGarminFit,
            files: _fitFiles,
          ),
          const SizedBox(height: 10),

          // Cola
          _buildAttachCard(
            icon: Icons.folder_zip_outlined,
            title: 'Cola.zip 추가',
            hint: 'Documents/COLA_FILE/COLA_FILE*.zip',
            busy: _fileBusy,
            onTap: _pickCola,
            files: _colaFiles,
          ),
          const SizedBox(height: 10),

          // Logs
          _buildAttachCard(
            icon: Icons.article_outlined,
            title: '로그 파일 추가',
            hint: 'Documents/COLA_FILE/log_*.zip',
            busy: _fileBusy,
            onTap: _pickLog,
            files: _logFiles,
          ),
          const SizedBox(height: 10),

          // Captures (Multi)
          _buildCaptureAttachCard(),
          const SizedBox(height: 14),

          if (!hasFiles) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.12), style: BorderStyle.none),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 36, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  Text(
                    '필수 검증 파일을 한 개 이상 첨부해 주세요.',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          const Divider(height: 32, color: Colors.white10),

          // ── 디테일 선택 영역 ──
          const Text(
            '2. 착용 상태 및 환경 설정',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 16),

          // 착용 위치 (스위치 UI)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('착용 위치', style: TextStyle(fontSize: 14)),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildSwitchTab('왼쪽', _wearingPosition == '왼쪽'),
                    _buildSwitchTab('오른쪽', _wearingPosition == '오른쪽'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 착용 정도 (세그먼트 3버튼 UI)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('착용 정도', style: TextStyle(fontSize: 14)),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildSegmentTab('충분히', _wearingTightness == '충분히'),
                    _buildSegmentTab('적당히', _wearingTightness == '적당히'),
                    _buildSegmentTab('느슨하게', _wearingTightness == '느슨하게'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 동시에 착용한 타사 모델
          _buildCompetitorSection(),
          const SizedBox(height: 16),

          // 훈련 종류
          _buildTrainingSection(),
          const SizedBox(height: 16),

          // 장소 입력
          TextFormField(
            controller: _locationCtrl,
            decoration: InputDecoration(
              labelText: '운동 장소 직접 입력 (예: 공원, 실내체육관)',
              prefixIcon: const Icon(Icons.place_outlined, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.gps_fixed_rounded, color: Color(0xFF3DFFC1), size: 20),
                onPressed: () async {
                  final selectedAddress = await Navigator.push<String>(
                    context,
                    InstantPageRoute(
                      page: const LocationPickerScreen(),
                    ),
                  );
                  if (selectedAddress != null && selectedAddress.isNotEmpty) {
                    setState(() {
                      _locationCtrl.text = selectedAddress;
                    });
                  }
                },
                tooltip: '지도에서 장소 선택',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 특이 사항 TextArea
          TextFormField(
            controller: _memoCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '특이 사항 및 메모',
              alignLabelWithHint: true,
              hintText: '특이 사항이 있다면 적어주세요. (착용감 흔들림, 센서 오작동 등)',
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSwitchTab(String text, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _wearingPosition = text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2E5BFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentTab(String text, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _wearingTightness = text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2E5BFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildAttachCard({
    required IconData icon,
    required String title,
    required String hint,
    required bool busy,
    required VoidCallback onTap,
    required List<AttachedFile> files,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF3DFFC1), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(hint, style: const TextStyle(fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: busy ? null : onTap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: const BorderSide(color: Color(0xFF3DFFC1)),
                  foregroundColor: const Color(0xFF3DFFC1),
                ),
                child: busy
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(Color(0xFF3DFFC1))),
                      )
                    : const Text('추가', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...files.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: AttachedFileTile(
                  file: e.value,
                  onDelete: () => _removeFile(files, e.key),
                ),
              );
            }),
          ]
        ],
      ),
    );
  }

  Widget _buildCaptureAttachCard() {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, color: Color(0xFF3DFFC1), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('운동 캡처 선택 (다중)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('갤러리 다중 이미지 첨부 가능', style: TextStyle(fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: _fileBusy ? null : _pickCaptures,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: const BorderSide(color: Color(0xFF3DFFC1)),
                  foregroundColor: const Color(0xFF3DFFC1),
                ),
                child: const Text('선택', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (_captureFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _captureFiles.length,
              itemBuilder: (ctx, index) {
                final file = _captureFiles[index];
                final path = file.tempPath ?? file.originalPath;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removeFile(_captureFiles, index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCompetitorSection() {
    final List<String> compOptions = ['가민', '애플', '크로스', '없음', '직접입력'];
    return GlassCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('동시 착용 타사 모델', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _competitorWatch,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.compare_arrows_rounded, size: 20),
            ),
            items: compOptions
                .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _competitorWatch = val);
              }
            },
          ),
          if (_competitorWatch == '직접입력') ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _customCompetitorCtrl,
              decoration: const InputDecoration(
                labelText: '타사 기기 직접 입력 *',
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTrainingSection() {
    final List<String> trOptions = ['조깅', '인터벌', 'LSD', '변속주', '지속주', '직접입력'];
    return GlassCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('훈련 종류', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _trainingType,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.sports_score_rounded, size: 20),
            ),
            items: trOptions
                .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _trainingType = val);
              }
            },
          ),
          if (_trainingType == '직접입력') ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _customTrainingCtrl,
              decoration: const InputDecoration(
                labelText: '훈련 종류 직접 입력 *',
              ),
            ),
          ]
        ],
      ),
    );
  }

  // ── Step 6: 압축 & 전송 완료 (Dashboard) ─────────────────────────
  Widget _buildStep6Completion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        // 1. 상태 아이콘 및 모션 원
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isPackaging || _emailSending)
                const CircularProgressIndicator(
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3DFFC1)),
                )
              else
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3DFFC1).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFF3DFFC1), width: 3),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF3DFFC1),
                    size: 52,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isPackaging
              ? '파일을 압축 중입니다...'
              : (_emailSending
                  ? '이메일로 전송을 완료하는 중...'
                  : '데이터 제출 성공'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        // 2. 압축 완료 정보 카드
        if (_packResult != null)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Color(0xFF2E5BFF), size: 18),
                    SizedBox(width: 8),
                    Text('압축 결과 리포트', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 20, color: Colors.white10),
                _buildInfoRow('파일명', _packResult!.zipName),
                _buildInfoRow('파일 크기', _packResult!.sizeLabel),
                _buildInfoRow('압축된 파일', '${_fitFiles.length + _colaFiles.length + _logFiles.length + _captureFiles.length}개'),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // 3. 전송 상태 타임라인 패널
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('전송 완료 상태', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const Divider(height: 20, color: Colors.white10),

              // Timeline Step 1: 압축 성공
              _buildTimelineStep(
                title: '검증 정보 로컬 압축',
                status: _isPackaging ? '진행 중' : '완료',
                isDone: !_isPackaging,
              ),

              // Timeline Step 2: 클립보드 Quick Share 링크 감지
              _buildTimelineStep(
                title: 'Quick Share 링크 감지',
                status: _lastProcessedLink != null
                    ? '성공'
                    : (_packResult == null ? '대기 중' : '클립보드 복사 대기 중...'),
                desc: _lastProcessedLink != null
                    ? (_lastProcessedLink!.length > 40 ? '${_lastProcessedLink!.substring(0, 40)}…' : _lastProcessedLink)
                    : '공유 창에서 Quick Share 링크를 복사해 주세요.',
                isDone: _lastProcessedLink != null,
                isWarning: _lastProcessedLink == null,
              ),

              // Timeline Step 3: 백엔드 이메일 발송
              _buildTimelineStep(
                title: '이메일 발송 상태',
                status: _emailSent ? '발송 완료' : (_emailSending ? '발송 중...' : '감지 대기 중'),
                desc: _emailError != null ? '오류: $_emailError' : null,
                isDone: _emailSent,
                isError: _emailError != null,
              ),

              if (!_emailSending && _lastProcessedLink != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _sendEmail(_lastProcessedLink!),
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF2E5BFF)),
                      label: const Text('메일 다시 보내기', style: TextStyle(fontSize: 12, color: Color(0xFF2E5BFF))),
                    ),
                  ),
                )
            ],
          ),
        ),
        const SizedBox(height: 30),

        // 4. 새로운 검증 시작하기 버튼
        ElevatedButton.icon(
          onPressed: _resetVerification,
          icon: const Icon(Icons.restart_alt_rounded, color: Colors.black),
          label: const Text(
            '새로운 검증 시작하기',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3DFFC1),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildInfoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String status,
    String? desc,
    bool isDone = false,
    bool isWarning = false,
    bool isError = false,
  }) {
    IconData icon = Icons.circle_outlined;
    Color color = Colors.white30;
    if (isDone) {
      icon = Icons.check_circle_rounded;
      color = const Color(0xFF3DFFC1);
    } else if (isWarning) {
      icon = Icons.hourglass_empty_rounded;
      color = const Color(0xFFFFB300);
    } else if (isError) {
      icon = Icons.error_rounded;
      color = const Color(0xFFFF5252);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(status, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (desc != null) ...[
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 하단 버튼 패널 빌더 (Step 1~5 공통) ────────────────────────────────
  Widget _buildFooterButtons() {
    final isStep5 = _currentStep == 5;
    final bool canNext = _currentStep < 5;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0F0F).withOpacity(0.4),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 1) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep--);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  foregroundColor: Colors.white,
                ),
                child: const Text('이전'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                if (isStep5) {
                  _onSend();
                } else if (canNext) {
                  if (_currentStep == 1) {
                    if (!_formKey1.currentState!.validate()) return;
                    _prefs?.saveName(_nameCtrl.text.trim());
                    _prefs?.saveHeight(double.tryParse(_heightCtrl.text) ?? 0.0);
                    _prefs?.saveWeight(double.tryParse(_weightCtrl.text) ?? 0.0);
                  } else if (_currentStep == 2) {
                    if (_selectedWatch == '직접입력' && _customWatchCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('워치 기종명을 입력해 주세요')),
                      );
                      return;
                    }
                    _prefs?.saveWatch(_selectedWatch);
                    _prefs?.saveCustomWatch(_customWatchCtrl.text.trim());
                  } else if (_currentStep == 3) {
                    if (_selectedStrap == '직접입력' && _customStrapCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('스트랩 종류를 입력해 주세요')),
                      );
                      return;
                    }
                    _prefs?.saveStrap(_selectedStrap);
                    _prefs?.saveCustomStrap(_customStrapCtrl.text.trim());
                    _prefs?.saveOnboardingComplete(true);
                  }
                  setState(() => _currentStep++);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E5BFF),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isStep5 ? '압축 및 보내기' : '다음 단계로',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _validatePositiveNumber(String? v) {
    if (v == null || v.trim().isEmpty) return '값을 입력해 주세요';
    final num = double.tryParse(v.trim());
    if (num == null || num <= 0) return '올바른 숫자를 입력해 주세요';
    return null;
  }

  Widget _buildConsentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Center(
            child: Icon(Icons.security_rounded, color: Color(0xFF3DFFC1), size: 48),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'HealthPort 서비스 동의',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '서비스 이용을 위해 아래 동의가 필요합니다.',
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
            ),
          ),
          const SizedBox(height: 32),

          // 1. 개인정보 & 민감정보 동의서
          const Text(
            '개인정보 및 민감정보 수집·이용 동의 (필수)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const SingleChildScrollView(
              child: Text(
                '1. 수집 및 이용 목적: 피트니스 알고리즘 분석, 연구개발(R&D) 및 제품 검증\n'
                '2. 수집 항목: 이름, 키, 몸무게, 기기 정보, 운동 데이터(심박수 등 신체 기능 정보)\n'
                '3. 보유 및 이용 기간: 검증 목적 달성 시 또는 테스터의 파기 요청 시까지\n'
                '4. 동의 거부 권리: 동의를 거부할 수 있으나, 거부 시 HealthPort 앱을 통한 검증 참여가 불가합니다.',
                style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.5),
              ),
            ),
          ),
          CheckboxListTile(
            title: const Text('위 개인정보 및 민감정보 수집·이용에 동의합니다.', style: TextStyle(fontSize: 12, color: Colors.white70)),
            value: _agreePersonal,
            activeColor: const Color(0xFF2E5BFF),
            checkColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (val) {
              setState(() => _agreePersonal = val ?? false);
            },
          ),
          const SizedBox(height: 24),

          // 2. 개인위치정보 동의서
          const Text(
            '개인위치정보 수집·이용 동의 (필수)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const SingleChildScrollView(
              child: Text(
                '1. 수집 및 이용 목적: 실외 운동 검증 시 정밀 위치 경로 분석 및 검증 데이터 패키징\n'
                '2. 수집 항목: GPS 위도, 경도 좌표 정보 및 이동 경로\n'
                '3. 보유 및 이용 기간: 피트니스 데이터 정밀 분석 즉시 파기 및 R&D 연구 완료 시 파기\n'
                '4. 동의 거부 권리: 동의를 거부할 수 있으나, 거부 시 실외 운동 데이터 검증 및 앱 서비스 제공이 불가능합니다.',
                style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.5),
              ),
            ),
          ),
          CheckboxListTile(
            title: const Text('위 개인위치정보 수집·이용에 동의합니다.', style: TextStyle(fontSize: 12, color: Colors.white70)),
            value: _agreeLocation,
            activeColor: const Color(0xFF2E5BFF),
            checkColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (val) {
              setState(() => _agreeLocation = val ?? false);
            },
          ),
          const SizedBox(height: 40),

          // 동의 완료 버튼
          ElevatedButton(
            onPressed: (_agreePersonal && _agreeLocation)
                ? () async {
                    if (_prefs == null) return;
                    final nowStr = DateTime.now().toString().substring(0, 19); // YYYY-MM-DD HH:MM:SS
                    await _prefs!.saveConsentGiven(true);
                    await _prefs!.saveConsentDate(nowStr);
                    setState(() {});
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3DFFC1),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white.withOpacity(0.12),
              disabledForegroundColor: Colors.white38,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              '동의하고 시작하기',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 글래스모피즘 카드 위젯 ────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(radius ?? 24),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GuideVideoDialog extends StatefulWidget {
  final String videoPath;
  const _GuideVideoDialog({this.videoPath = 'assert/Demo_7.mp4'});

  @override
  State<_GuideVideoDialog> createState() => _GuideVideoDialogState();
}

class _GuideVideoDialogState extends State<_GuideVideoDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    setState(() {
      _initialized = false;
      _errorMessage = null;
    });

    // 기기 내부에 준비된 로컬 비디오 파일을 직접 읽어 무제한 데이터/인터넷 환경에 구애받지 않고 오프라인에서도 100% 정상 작동하도록 설정
    _controller = VideoPlayerController.asset(
      widget.videoPath,
    )..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _initialized = true;
        });
        _controller.play(); // 자동 재생
        _controller.setLooping(true); // 반복 재생
      }).catchError((error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = "영상을 불러오지 못했습니다.\n에셋 설정을 확인해 주세요.";
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isPortrait = mediaQuery.orientation == Orientation.portrait;
    
    // 모단말 하단 네비게이션 바 침범을 확실히 차단하도록 다이내믹 세로 제한 높이 계산
    final double maxVideoHeight = isPortrait 
        ? (mediaQuery.size.height * 0.65 - mediaQuery.padding.bottom - mediaQuery.viewInsets.bottom)
        : (mediaQuery.size.height * 0.5);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: SafeArea(
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          radius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.ondemand_video_rounded, color: Color(0xFF3DFFC1), size: 20),
                      SizedBox(width: 8),
                      Text(
                        '가이드 영상 시청',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxVideoHeight,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: _initialized ? _controller.value.aspectRatio : 9 / 16,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_initialized)
                          VideoPlayer(_controller)
                    else if (_errorMessage != null)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.white60, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _initVideo,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('재시도', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E5BFF),
                                minimumSize: const Size(80, 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                          ],
                        ),
                      )
                    else
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3DFFC1)),
                        ),
                      ),
                    if (_initialized)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _controller.value.isPlaying ? _controller.pause() : _controller.play();
                          });
                        },
                        child: Container(
                          color: Colors.transparent,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _controller.value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: const Color(0xFF3DFFC1),
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
            const SizedBox(height: 12),
            if (_initialized)
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF3DFFC1),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
}
