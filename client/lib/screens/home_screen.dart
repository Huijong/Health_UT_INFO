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
import 'ranking_screen.dart';
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
    'name': '기본 스트랩',
    'url': ''
  },
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

  // 앱 업데이트 관련 상태 변수 및 애니메이션 컨트롤러
  AnimationController? _updateNoticePulseController;
  bool _hasUpdate = false;
  String _updateVersionName = '';

  // 동의서 관련 상태 변수
  bool _agreePersonal = false;
  bool _agreeLocation = false;

  // 현재 위저드 단계 (1 ~ 6)
  int _currentStep = 1;

  // 현재 하단 탭 인덱스 (0: 홈, 1: 명예의 전당)
  int _currentTab = 0;

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
  final List<AttachedFile> _garminFiles = [];
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
  final _distanceCtrl = TextEditingController();

  final _locationCtrl = TextEditingController();
  final _memoCtrl = TextEditingController(); // 특이 사항

  // 6단계 완료 정보 및 상태
  PackResult? _packResult;
  String? _lastProcessedLink;
  bool _isPackaging = false;
  bool _emailSending = false;
  bool _emailSent = false;
  String? _emailError;
  String _step6State = 'waiting'; // waiting, sending, success
  DateTime? _shareSheetOpenTime;

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

    _updateNoticePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _updateNoticePulseController?.repeat(reverse: true);

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

    // 개인 알림 토픽 구독
    _updateNotificationTopic(prefs.name);

    // 기기 접속 핑 전송
    _sendDevicePing();

    // 앱 업데이트 가능 여부 체크
    _checkAppUpdate();

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

  String _nameToHex(String name) {
    return utf8.encode(name).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  String _lastSubscribedTopic = '';

  Future<void> _updateNotificationTopic(String newName) async {
    try {
      final messaging = FirebaseMessaging.instance;
      // 1. 기존 구독 해제
      if (_lastSubscribedTopic.isNotEmpty) {
        await messaging.unsubscribeFromTopic(_lastSubscribedTopic);
        debugPrint("Unsubscribed from old topic: $_lastSubscribedTopic");
      } else {
        final oldSavedName = _prefs?.name ?? '';
        if (oldSavedName.isNotEmpty && oldSavedName != newName) {
          final oldTopic = 'tester_${_nameToHex(oldSavedName)}';
          await messaging.unsubscribeFromTopic(oldTopic);
          debugPrint("Unsubscribed from fallback old topic: $oldTopic");
        }
      }
      // 2. 신규 구독
      if (newName.isNotEmpty) {
        final newTopic = 'tester_${_nameToHex(newName)}';
        await messaging.subscribeToTopic(newTopic);
        _lastSubscribedTopic = newTopic;
        debugPrint("Subscribed to new topic: $newTopic");
      }
    } catch (e) {
      debugPrint("Failed to update FCM topic: $e");
    }
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

  void _showForceUpdateDialog(String serverVersion) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            radius: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_rounded, color: Color(0xFF3DFFC1), size: 48),
                const SizedBox(height: 16),
                const Text(
                  '필수 업데이트 안내',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'HealthPort의 새로운 버전(v$serverVersion)이 출시되었습니다.\n\n원활한 검증 진행을 위해 반드시 업데이트 후 이용해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          await _prefs?.saveLastPopupDismissedVersion(serverVersion);
                          setState(() {
                            _hasUpdate = true;
                            _updateVersionName = serverVersion;
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('나중에 하기', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return DownloadDialog(
                                latestApkApiUrl: '${AppConfig.apiUrl}/api/devices?latest_apk=true',
                                defaultFileName: 'HealthPort_${AppConfig.appVersion}.apk',
                                defaultUrlPath: '/static/apks/HealthPort_${AppConfig.appVersion}.apk',
                              );
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3DFFC1),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('업데이트 시작', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickShareGuideDialog(VoidCallback onConfirm) {
    int guideIndex = 0;
    bool dontShowAgain = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final images = [
              'assert/Quick_1.png',
              'assert/Quick_2.png',
              'assert/Quick_3.png',
            ];
            final texts = [
              '1. 퀵 쉐어 버튼 누르기',
              '2. QR 코드 또는 링크 누르기',
              '3. 링크 복사 누룬 후 뒤로 가기(Back 키)',
            ];

            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                radius: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '퀵 쉐어 가이드',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${guideIndex + 1} / 3',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 280,
                        width: double.infinity,
                        color: Colors.black26,
                        child: Image.asset(
                          images[guideIndex],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    guideIndex == 2
                        ? Text.rich(
                            const TextSpan(
                              text: '3. 링크 복사 누룬 후 뒤로 가기(',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3DFFC1),
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Back 키',
                                  style: TextStyle(
                                    color: Color(0xFFFF5252),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(text: ')'),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          )
                        : Text(
                            texts[guideIndex],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3DFFC1),
                              height: 1.4,
                            ),
                          ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              dontShowAgain = !dontShowAgain;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: dontShowAgain,
                                  activeColor: const Color(0xFF3DFFC1),
                                  checkColor: Colors.black,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      dontShowAgain = val ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '다시 보지 않기',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (guideIndex < 2)
                          ElevatedButton(
                            onPressed: () {
                              setDialogState(() {
                                guideIndex++;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E5BFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('다음', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        else
                          ElevatedButton(
                            onPressed: () async {
                              if (dontShowAgain) {
                                await _prefs?.saveHideQuickShareGuide(true);
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                              onConfirm();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3DFFC1),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _checkAppUpdate() async {
    try {
      final url = Uri.parse('${AppConfig.apiUrl}/api/devices?latest_apk=true');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final filename = data['filename'] as String;
          final regExp = RegExp(r'HealthPort_([0-9\.]+)\.apk');
          final match = regExp.firstMatch(filename);
          if (match != null) {
            final serverVersion = match.group(1)!;
            final localVersion = AppConfig.appVersion;
            
            bool isNewer = false;
            try {
              final currentParts = localVersion.split('.').map(int.parse).toList();
              final latestParts = serverVersion.split('.').map(int.parse).toList();
              final length = currentParts.length > latestParts.length ? currentParts.length : latestParts.length;
              for (int i = 0; i < length; i++) {
                final currentVal = i < currentParts.length ? currentParts[i] : 0;
                final latestVal = i < latestParts.length ? latestParts[i] : 0;
                if (latestVal > currentVal) {
                  isNewer = true;
                  break;
                }
                if (currentVal > latestVal) {
                  break;
                }
              }
            } catch (_) {
              isNewer = localVersion != serverVersion;
            }

            if (isNewer) {
              setState(() {
                _hasUpdate = true;
                _updateVersionName = serverVersion;
              });
              final lastDismissed = _prefs?.lastDismissedUpdateVersion ?? '';
              final lastPopupDismissed = _prefs?.lastPopupDismissedVersion ?? '';
              if (lastDismissed != serverVersion && lastPopupDismissed != serverVersion) {
                _showForceUpdateDialog(serverVersion);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to check update on home: $e');
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
    _updateNotificationTopic(_prefs!.name);
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
    _distanceCtrl.dispose();
    _locationCtrl.dispose();
    _memoCtrl.dispose();
    _guidePulseController?.dispose();
    _noticePulseController?.dispose();
    _updateNoticePulseController?.dispose();
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
      final isQuickShare = lowerText.contains('quickshare.samsungcloud.com') ||
          lowerText.contains('sharing.samsung') ||
          lowerText.contains('q1team.cc') ||
          lowerText.contains('quickshare');
      if (!isQuickShare) return;

      if (_shareSheetOpenTime != null) {
        final diff = DateTime.now().difference(_shareSheetOpenTime!);
        if (diff.inMilliseconds < 100) return;
      }

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
      _step6State = 'sending';
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
        appVersion: _session?.appVersion ?? AppConfig.appVersion,
        shealthVersion: _session?.shealthVersion ?? '알 수 없음',
        height: _heightCtrl.text.trim(),
        weight: _weightCtrl.text.trim(),
        watch: watchName,
        strap: strapName,
        exercise: _selectedExercise,
        wearingPosition: _wearingPosition,
        wearingTightness: _wearingTightness,
        competitorWatch: compDevice,
        trainingType: tType,
        distance: _distanceCtrl.text.trim().isEmpty ? '-' : _distanceCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        remarks: _memoCtrl.text.trim(),
        consentDate: _prefs?.consentDate ?? '',
      );

      if (mounted) {
        setState(() {
          _emailSending = false;
          _emailSent = true;
          _step6State = 'success';
        });

        // 1초 뒤에 새로운 검증 시작하기 버튼 동작처럼 초기화 후 운동 선택(4단계) 화면으로 이동
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('데이터 제출이 완료되었습니다. 새로운 검증을 시작합니다.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            _resetVerification();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailSending = false;
          _emailError = e.toString();
          _step6State = 'waiting';
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
      final height = double.tryParse(_heightCtrl.text.trim()) ?? 0.0;
      final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0.0;
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
        distance: _distanceCtrl.text.trim().isEmpty ? '-' : _distanceCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        memo: memo,
        session: _session!,
        fitFiles: [..._fitFiles, ..._garminFiles],
        colaFiles: _colaFiles,
        logFiles: _logFiles,
        captureFiles: _captureFiles,
      );

      if (mounted) {
        setState(() {
          _packResult = result;
          _isPackaging = false;
          _step6State = 'waiting';
        });
      }

      // 클립보드 비우기 대신 현재 클립보드 값 읽어와 캐싱 (연결된 기기 복사 토스트 제거)
      try {
        final currentClip = await Clipboard.getData(Clipboard.kTextPlain);
        _lastProcessedLink = currentClip?.text?.trim() ?? '';
      } catch (_) {
        _lastProcessedLink = '';
      }
      _shareSheetOpenTime = DateTime.now();

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
      _garminFiles.clear();
      _colaFiles.clear();
      _logFiles.clear();
      _captureFiles.clear();
      _memoCtrl.clear();
      _locationCtrl.clear();
      _customWatchCtrl.clear();
      _customStrapCtrl.clear();
      _customCompetitorCtrl.clear();
      _customTrainingCtrl.clear();
      _distanceCtrl.clear();
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
      _step6State = 'waiting';
      _shareSheetOpenTime = null;
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
          setState(() => _garminFiles.add(f));
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
        if (!fileName.toLowerCase().startsWith('cola')) {
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
                    child: _currentStep == 4 && _currentTab == 1
                        ? RankingScreen(prefs: _prefs!)
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: _buildCurrentStepView(),
                          ),
                  ),
                  if (_currentStep < 6 && _currentStep != 4) _buildFooterButtons(),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _currentStep == 4 ? _buildBottomNavigationBar() : null,
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
                  style: TextStyle(
                    fontSize: _currentStep == 4 ? 22 : 18,
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
        return 'Health Port';
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
            'HealthPort 서비스 이용을 위한 테스터님의 닉네임을 입력해 주세요.',
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
                    labelText: '닉네임 *',
                    hintText: '예) 기안84',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '닉네임을 입력해 주세요' : null,
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
      final testerName = _prefs?.name ?? '';
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/api/notices?tester_name=${Uri.encodeComponent(testerName)}'));
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
    final card1Options = kStrapOptions.where((opt) => opt['name'] == '기본 스트랩' || opt['name'] == '직접입력').toList();
    final card2Options = kStrapOptions.where((opt) => opt['name'] != '기본 스트랩' && opt['name'] != '직접입력').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1안 카드
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
          child: Text(
            '기본 스트랩/직접 입력',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE2E2E2).withOpacity(0.7),
            ),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ...card1Options.map((strapOpt) {
                final strapName = strapOpt['name']!;
                final isSel = _selectedStrap == strapName;

                return RadioListTile<String>(
                  title: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              strapName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? const Color(0xFF3DFFC1) : const Color(0xFFE2E2E2),
                              ),
                            ),
                          ],
                        ),
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
          const SizedBox(height: 12),
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

        const SizedBox(height: 24),

        // 2안 카드
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
          child: Text(
            '공식/서드파티 스트랩',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE2E2E2).withOpacity(0.7),
            ),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ...card2Options.map((strapOpt) {
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
        if (_hasUpdate) ...[
          AnimatedBuilder(
            animation: _updateNoticePulseController!,
            builder: (context, child) {
              final double val = _updateNoticePulseController?.value ?? 0.0;
              final Color pulseColor = Color.lerp(
                const Color(0xFF2E5BFF),
                const Color(0xFF3DFFC1),
                val,
              )!;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
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
                  await _prefs!.saveLastDismissedUpdateVersion(_updateVersionName);
                }
                setState(() {
                  _hasUpdate = false;
                });
                
                if (!mounted) return;
                await Navigator.push(
                  context,
                  InstantPageRoute(
                    page: SettingsScreen(
                      prefs: _prefs!,
                      highlightUpdate: true,
                    ),
                  ),
                );
                _reloadPrefs();
                _checkAppUpdate();
              },
              borderRadius: BorderRadius.circular(16),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                radius: 16,
                child: Row(
                  children: [
                    const Icon(Icons.system_update_rounded, color: Color(0xFF3DFFC1), size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '앱 업데이트 요청 (v$_updateVersionName 출시) 🆕',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3DFFC1).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3DFFC1), width: 1),
                      ),
                      child: const Text(
                        '업데이트',
                        style: TextStyle(fontSize: 10, color: Color(0xFF3DFFC1), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_latestNotice != null) ...[
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
          const SizedBox(height: 12),
        ],
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
    final bool hasFiles = _fitFiles.isNotEmpty || _garminFiles.isNotEmpty || _colaFiles.isNotEmpty || _logFiles.isNotEmpty || _captureFiles.isNotEmpty;

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
            hint: 'Download/23606307436.zip',
            busy: _fileBusy,
            onTap: _pickGarminFit,
            files: _garminFiles,
          ),
          const SizedBox(height: 10),

          // Cola
          _buildAttachCard(
            icon: Icons.folder_zip_outlined,
            title: 'COLA 파일 추가',
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

          GlassCard(
            radius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('착용 상태', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('착용 위치', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('착용 정도', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 동시에 착용한 타사 모델
          _buildCompetitorSection(),
          const SizedBox(height: 16),

          // 훈련 거리
          _buildDistanceSection(),
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

  Widget _buildDistanceSection() {
    return GlassCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('훈련 거리', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _distanceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.linear_scale_rounded, size: 20),
              hintText: '예) 21.09',
              suffixText: 'km',
            ),
          ),
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
  Future<void> _onReshare() async {
    if (_packResult == null) return;
    try {
      final currentClip = await Clipboard.getData(Clipboard.kTextPlain);
      _lastProcessedLink = currentClip?.text?.trim() ?? '';
    } catch (_) {
      _lastProcessedLink = '';
    }
    _shareSheetOpenTime = DateTime.now();
    await ShareService.shareZip(_packResult!.zipPath, _packResult!.zipName);
  }

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
              if (_isPackaging || _step6State == 'sending')
                const CircularProgressIndicator(
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3DFFC1)),
                )
              else if (_step6State == 'success')
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
                )
              else
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2E5BFF).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFF2E5BFF), width: 3),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF2E5BFF),
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
              : (_step6State == 'sending'
                  ? '이메일로 전송을 완료하는 중...'
                  : (_step6State == 'success'
                      ? '데이터 제출 성공'
                      : 'Quick Share 링크 대기 중...')),
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
                status: _step6State == 'success' ? '발송 완료' : (_step6State == 'sending' ? '발송 중...' : '감지 대기 중'),
                desc: _emailError != null ? '오류: $_emailError' : null,
                isDone: _step6State == 'success',
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

        // 4. 상태별 제어 버튼
        if (_step6State == 'success')
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
          )
        else ...[
          ElevatedButton.icon(
            onPressed: _isPackaging || _step6State == 'sending' ? null : _onReshare,
            icon: const Icon(Icons.share_rounded, color: Colors.black),
            label: const Text(
              '다시 공유하기 (퀵쉐어)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3DFFC1),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isPackaging || _step6State == 'sending' ? null : _resetVerification,
            child: Text(
              '검증 취소 및 초기화',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            ),
          ),
        ],
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
              onPressed: () async {
                if (isStep5) {
                  if (_prefs?.hideQuickShareGuide == true) {
                    _onSend();
                  } else {
                    _showQuickShareGuideDialog(_onSend);
                  }
                } else if (canNext) {
                  if (_currentStep == 1) {
                    if (!_formKey1.currentState!.validate()) return;
                    
                    final nickname = _nameCtrl.text.trim();
                    try {
                      final url = Uri.parse('${AppConfig.apiUrl}/api/devices?check_nickname=${Uri.encodeComponent(nickname)}');
                      final response = await http.get(url);
                      if (response.statusCode == 200) {
                        final res = jsonDecode(response.body);
                        if (res['status'] == 'success' && res['exists'] == true) {
                          if (mounted) {
                            final bool? reuse = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: GlassCard(
                                  padding: const EdgeInsets.all(24),
                                  radius: 20,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: Color(0xFF3DFFC1), size: 24),
                                          const SizedBox(width: 8),
                                          const Text(
                                            '닉네임 연동 확인',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '"$nickname"은(는) 이미 등록된 닉네임입니다.\n\n기존에 이 닉네임을 사용하시던 본인이 맞으신가요?\n"예"를 누르면 기존 수집 내역 및 포인트(명예의 전당)를 유지하며 계속 연동합니다.',
                                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), height: 1.5),
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('아니오', style: TextStyle(color: Colors.white54)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF3DFFC1),
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            child: const Text('예', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            if (reuse != true) return;
                          } else {
                            return;
                          }
                        }
                      }
                    } catch (e) {
                      debugPrint('닉네임 중복 검사 실패: $e');
                    }

                    _prefs?.saveName(nickname);
                    _updateNotificationTopic(nickname);
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
                '1. 개인정보 수집·이용 동의 (필수)\n'
                '[HealthPort] 서비스 제공을 위한 개인정보 수집∙이용에 대한 안내입니다.\n\n'
                '[HealthPort] 은(는) 개인의 운동(달리기, 실외자전거, 트레일 러닝 등) 기록 및 분석 서비스를 제공하며, 이를 위해 아래와 같이 개인정보를 수집∙이용합니다.\n\n'
                '• 이름 (또는 닉네임): 회원 식별 및 서비스 이용 (보유기간: 회원 탈퇴 시까지)\n'
                '• 위치정보 (GPS): 운동 경로, 거리, 속도 기록 및 분석 (보유기간: 회원 탈퇴 시까지)\n\n'
                '※ 위 필수항목 수집·이용에 대한 동의를 거부하실 수 있으나, 이 경우 [HealthPort] 서비스의 핵심 기능 이용이 제한됩니다.\n\n'
                '2. 민감정보 수집·이용 동의 (필수)\n'
                '[HealthPort] 서비스는 운동 강도 분석 등 개인 맞춤형 서비스 제공을 위해 아래와 같이 민감정보를 수집∙이용합니다.\n\n'
                '• 심박수: 운동 중 건강 상태 모니터링 및 운동 강도 분석 (보유기간: 회원 탈퇴 시까지)\n\n'
                '※ 민감정보는 「개인정보 보호법」에 따라 별도의 동의를 받아야 하며, 동의를 거부하실 경우 운동 강도 분석 등 일부 맞춤형 기능 이용이 제한될 수 있습니다.',
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

          // 2. 개인정보 처리방침 동의서
          const Text(
            '개인정보 처리방침 (필수)',
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
                '[HealthPort] 개인정보 처리방침\n\n'
                '제1조 (개인정보의 처리 목적)\n'
                '회사는 다음의 목적을 위하여 개인정보를 처리합니다. 처리하고 있는 개인정보는 다음의 목적 이외의 용도로는 이용되지 않으며, 이용 목적이 변경되는 경우에는 「개인정보 보호법」 제18조에 따라 별도의 동의를 받는 등 필요한 조치를 이행할 예정입니다.\n'
                '- 서비스 제공: 운동 기록(경로, 거리, 속도, 심박수 등) 저장, 통계, 분석 데이터 제공 등 서비스 제공과 관련된 목적으로 개인정보를 처리합니다.\n'
                '- 회원 관리: 회원제 서비스 이용에 따른 본인 확인, 개인 식별, 불량회원의 부정 이용 방지와 비인가 사용 방지, 분쟁 조정을 위한 기록 보존 등을 목적으로 개인정보를 처리합니다.\n\n'
                '제2조 (처리하는 개인정보의 항목 및 보유 기간)\n'
                '회사는 법령에 따른 개인정보 보유·이용기간 또는 정보주체로부터 개인정보를 수집 시에 동의받은 개인정보 보유·이용기간 내에서 개인정보를 처리·보유합니다.\n'
                '- 수집항목: 이름(또는 닉네임), 위치정보(GPS), 심박수\n'
                '- 보유기간: 회원 탈퇴 시까지. (단, 관계 법령 위반에 따른 수사·조사 등이 진행 중인 경우에는 해당 수사·조사 종료 시까지)\n\n'
                '제3조 (개인정보의 제3자 제공)\n'
                '회사는 정보주체의 개인정보를 제1조(개인정보의 처리 목적)에서 명시한 범위 내에서만 처리하며, 원칙적으로 정보주체의 동의 없이 외부에 제공하지 않습니다.\n\n'
                '제4조 (개인정보처리의 위탁)\n'
                '회사는 원활한 개인정보 업무처리를 위하여 다음과 같이 개인정보 처리업무를 위탁할 수 있습니다.\n'
                '- 위탁받는 자 (수탁자): 자체 서버\n'
                '- 위탁하는 업무의 내용: 서비스 제공을 위한 데이터 저장 및 시스템 운영\n\n'
                '제5조 (정보주체와 법정대리인의 권리·의무 및 그 행사방법)\n'
                '이용자는 개인정보주체로서 언제든지 개인정보 열람, 정정, 삭제, 처리정지 요구 등의 권리를 행사할 수 있습니다.\n\n'
                '제6조 (개인정보의 파기)\n'
                '회사는 개인정보 보유기간의 경과, 처리목적 달성 등 개인정보가 불필요하게 되었을 때에는 지체없이 해당 개인정보를 파기합니다.\n\n'
                '제7조 (개인정보의 안전성 확보 조치)\n'
                '회사는 개인정보의 안전성 확보를 위해 기술적/관리적 및 물리적 조치를 하고 있습니다.\n\n'
                '제8조 (개인정보 보호책임자)\n'
                '- 성명: 유희종\n'
                '- 직책: 과장\n'
                '- 연락처: yhj2222@gmail.com\n\n'
                '부칙\n'
                '이 개인정보 처리방침은 2026년 7월 14일부터 적용됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.5),
              ),
            ),
          ),
          CheckboxListTile(
            title: const Text('위 개인정보 처리방침에 동의합니다.', style: TextStyle(fontSize: 12, color: Colors.white70)),
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

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentTab,
      onTap: (index) {
        setState(() {
          _currentTab = index;
        });
      },
      backgroundColor: const Color(0xFF1E2020),
      selectedItemColor: const Color(0xFF3DFFC1),
      unselectedItemColor: Colors.white38,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: '홈',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.emoji_events_rounded),
          label: '명예의 전당',
        ),
      ],
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
