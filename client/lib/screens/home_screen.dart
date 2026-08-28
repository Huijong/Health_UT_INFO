import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../widgets/custom_file_picker.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math';
import '../widgets/custom_file_picker.dart';
import 'lab_watch_sync_screen.dart';
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
import '../widgets/custom_file_picker.dart';
import '../widgets/attached_file_tile.dart';
import 'settings_screen.dart';
import 'location_picker_screen.dart';
import 'notice_history_screen.dart';
import 'ranking_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:confetti/confetti.dart';
import 'package:client/utils/toast_util.dart';
import '../main.dart'; // To use showLocalNotification


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
  String? _hotspotSsid;
  String? _hotspotPwd;
  bool _isHotspotOn = false;
  bool _wentToHotspotSettings = false;
  StateSetter? _wizardSetState;
  static const _appChannel = MethodChannel('com.samsung.health.client/app_info');
  bool _watchLogsAddedToZip = false;
  final _formKey1 = GlobalKey<FormState>();

  Future<void> _checkHotspotStatus() async {
    try {
      final isEnabled = await _appChannel.invokeMethod('isHotspotEnabled') ?? false;
      if (mounted) {
        setState(() {
          _isHotspotOn = isEnabled;
          if (isEnabled) _isNetworkExpanded = true;
        });
        if (_wizardSetState != null) {
          _wizardSetState!(() {
            _isHotspotOn = isEnabled;
            if (isEnabled) _isNetworkExpanded = true;
          });
        }
      }
    } catch (e) {
      print('Hotspot check error: $e');
    }
  }

  static const EventChannel _capabilityEventChannel = EventChannel('watch_capability');
  StreamSubscription? _capabilitySubscription;

  Future<void> _handleWatchSyncClick() async {
    final prefs = await SharedPreferences.getInstance();
    final bool showTbdPopup = prefs.getBool('show_tbd_popup') ?? false;
    final bool hideGuide = prefs.getBool('hide_log_sync_guide') ?? false;

    void proceedToNext() {
      if (hideGuide) {
        _showWatchSyncWizard();
        return;
      }

      bool dontShowAgain = false;
      showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E2640),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    const Icon(Icons.menu_book, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    const Text('COLA / Log 동기화 가이드', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () {
                        if (dontShowAgain) prefs.setBool('hide_log_sync_guide', true);
                        Navigator.pop(ctx);
                        _showWatchSyncWizard();
                      },
                    )
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '스마트폰과 워치를 연결하여 Log 파일을 동기화하려면 기기 간 설정이 필요합니다.\n\n상세한 진행 방법은 웹 가이드 문서를 참고해 주세요!',
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              dontShowAgain = !dontShowAgain;
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                dontShowAgain ? Icons.check_box : Icons.check_box_outline_blank,
                                color: dontShowAgain ? Colors.blueAccent : Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text('다시 보지 않기', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3366FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            if (dontShowAgain) prefs.setBool('hide_log_sync_guide', true);
                            Navigator.pop(ctx);
                            
                            final Uri url = Uri.parse('https://huijong.github.io/Health_UT_INFO/');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                            
                            _showWatchSyncWizard();
                          },
                          child: const Text('가이드 보기', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    if (showTbdPopup) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2640),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text('준비 중 (TBD)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: '해당 기능은 COLA/Log 파일을 원터치로 가져올 수 있도록 향후 업데이트될 예정입니다.\n\n현재 SDK 문제로 인해 워치 앱의 정식 스토어(Google Play Store, Galaxy Store) 등록이 제한된 상태입니다.\n\n사용자분들께서 쉽게 앱을 설치하실 수 있도록 우회 방법 및 대안을 적극적으로 찾고 있습니다. 조금만 기다려 주세요!\n\n'),
                TextSpan(
                  text: '💡 기능 릴리즈 전, 먼저 앱을 사용해보고 싶으신 분은 [유희종 프로]님에게 오시면 워치에 직접 설치해 드립니다!',
                  style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3366FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                proceedToNext();
              },
              child: const Text('사용해 보기', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    // Check if watch app installed
    final bool isInstalled = await _appChannel.invokeMethod('checkWatchAppInstalled') ?? false;
    if (isInstalled) {
      proceedToNext();
      return;
    }

    // Show install popup
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _capabilitySubscription = _capabilityEventChannel.receiveBroadcastStream().listen((event) {
          if (event == true) {
            _capabilitySubscription?.cancel();
            _capabilitySubscription = null;
            if (Navigator.canPop(ctx)) {
              Navigator.pop(ctx);
              proceedToNext();
            }
          }
        });

        return AlertDialog(
          backgroundColor: const Color(0xFF1E2640),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.watch, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('워치 앱 설치 필요', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            '단말과 워치의 파일(COLA/Log)을 간편하게 자동 동기화하려면 워치용 HealthPort Sync 앱이 필요합니다.\n아래 버튼을 눌러 워치로 설치 링크를 전송해 주세요.\n\n(💡 워치에 앱 설치가 완료되면 이 창은 자동으로 닫힙니다.)',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _capabilitySubscription?.cancel();
                _capabilitySubscription = null;
                Navigator.pop(ctx);
              },
              child: const Text('취소', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3366FF)),
              onPressed: () {
                _appChannel.invokeMethod('launchWatchPlayStore', {'url': 'market://details?id=com.samsung.health.client'});
              },
              child: const Text('워치로 설치 링크 보내기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ).then((_) {
      _capabilitySubscription?.cancel();
      _capabilitySubscription = null;
    });
  }

  final _formKey5 = GlobalKey<FormState>();

  // 가이드 영상 관련 상태 변수 및 애니메이션 컨트롤러
  AnimationController? _guidePulseController;
  bool _hasWatchedGuide = false;
  late ConfettiController _confettiController;

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
  AnimationController? _emptyFieldPulseController;
  bool _agreePersonal = false;
  bool _agreeLocation = false;
  bool _isNetworkExpanded = true;

  // 현재 위저드 단계 (1 ~ 6)
  int _currentStep = 1;

  // 현재 하단 탭 인덱스 (0: 홈, 1: 명예의 전당)
  int _currentTab = 0;

  // 1단계 컨트롤러
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _ssidFocusNode = FocusNode();
  final _ssidCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _isEmailReadOnly = true;
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
  List<String> _favoriteSports = [];

  void _toggleFavorite(String sportName) {
    setState(() {
      if (_favoriteSports.contains(sportName)) {
        _favoriteSports.remove(sportName);
      } else {
        _favoriteSports.add(sportName);
      }
    });
    _prefs?.saveFavoriteSports(_favoriteSports);
  }

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
  final _distanceFocusNode = FocusNode();

  final _locationCtrl = TextEditingController();
  final _memoCtrl = TextEditingController(); // 특이 사항

  // 정밀 검증 4대 항목 상태 및 메모
  String _gpsStatus = '정상'; // 정상 / 확인 필요 / N/A
  final _gpsMemoCtrl = TextEditingController();
  String _hrStatus = '정상'; // 정상 / 확인 필요 / N/A
  final _hrMemoCtrl = TextEditingController();
  String _paceStatus = '정상'; // 정상 / 확인 필요 / N/A
  final _paceMemoCtrl = TextEditingController();
  String _altitudeStatus = '정상'; // 정상 / 확인 필요 / N/A
  final _altitudeMemoCtrl = TextEditingController();

  final GlobalKey _precisionCardKey = GlobalKey();

  // 6단계 완료 정보 및 상태
  PackResult? _packResult;
  String? _lastProcessedLink;
  bool _isPackaging = false;
  bool _emailSending = false;
  bool _emailSent = false;
  String? _emailError;
  String _step6State = 'waiting'; // waiting, sending, success
  DateTime? _shareSheetOpenTime;
  late TabController _deviceTabController;
  

  DeviceSession? _session;
  PrefsService? _prefs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _deviceTabController = TabController(length: 2, vsync: this);
    _deviceTabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadHotspotConfig();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _appChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSyncCompleteNotificationTapped') {
        if (mounted) {
          setState(() {
            _currentStep = 5;
            _currentTab = 0;
          });
        }
      }
    });
    
    _init();
    _customCompetitorCtrl.addListener(_saveSportDetails);
    _customTrainingCtrl.addListener(_saveSportDetails);
  }

  bool _isResettingOrLoading = false;

  void _loadSportDetails(String sport) {
    if (_prefs == null) return;
    
    // 정밀 검증 항목들은 저장소에서 불러오지 않고, 항상 진입할 때마다 디폴트로 초기화합니다.
    final isGpsAltitudeNA = (sport == '러닝머신 걷기' ||
        sport == '러닝머신 달리기' ||
        sport == '실내 수영' ||
        sport == '야외 수영' ||
        sport == '근력 운동');

    setState(() {
      _isResettingOrLoading = true;
      _gpsStatus = isGpsAltitudeNA ? 'N/A' : '정상';
      _gpsMemoCtrl.clear();
      _hrStatus = '정상';
      _hrMemoCtrl.clear();
      _paceStatus = '정상';
      _paceMemoCtrl.clear();
      _altitudeStatus = isGpsAltitudeNA ? 'N/A' : '정상';
      _altitudeMemoCtrl.clear();
      
      // 운동 거리는 진입 시마다 디폴트(비어있음, 내부적으론 0 또는 입력 필수 처리)
      _distanceCtrl.clear();
      // 운동 장소 역시 진입 시마다 빈 값 및 힌트 상태로 초기화
      _locationCtrl.clear();
      _fitFiles.clear();
      _garminFiles.clear();
      _colaFiles.clear();
      _logFiles.clear();
      _captureFiles.clear();
    });

    final details = _prefs!.getSportDetail(sport);
    if (details != null) {
      setState(() {
        _wearingPosition = details['wearingPosition'] ?? '왼쪽';
        _wearingTightness = details['wearingTightness'] ?? '적당히';
        _competitorWatch = details['competitorWatch'] ?? '없음';
        _customCompetitorCtrl.text = details['customCompetitor'] ?? '';
        _trainingType = details['trainingType'] ?? '조깅';
        _customTrainingCtrl.text = details['customTraining'] ?? '';
      });
    } else {
      setState(() {
        _wearingPosition = '왼쪽';
        _wearingTightness = '적당히';
        _competitorWatch = '없음';
        _customCompetitorCtrl.clear();
        _trainingType = '조깅';
        _customTrainingCtrl.clear();
      });
    }
    setState(() {
      _isResettingOrLoading = false;
    });
  }

  void _saveSportDetails() {
    if (_prefs == null || _isResettingOrLoading) return;
    final details = {
      'wearingPosition': _wearingPosition,
      'wearingTightness': _wearingTightness,
      'competitorWatch': _competitorWatch,
      'customCompetitor': _customCompetitorCtrl.text,
      'trainingType': _trainingType,
      'customTraining': _customTrainingCtrl.text,
    };
    _prefs!.saveSportDetail(_selectedExercise, details);
  }

  Future<void> _init() async {
    try {
      final prefs = await PrefsService.create();
      final session = await DeviceSession.collect();

      // Android ID 획득 (앱 삭제 후 재설치 시에도 동일 기기 유지 가능)
      String uuidStr = '';
      try {
        uuidStr = await _appChannel.invokeMethod<String>('getAndroidId') ?? '';
      } catch (e) {
        debugPrint('[Android ID] Failed to get native ID: $e');
      }
      if (uuidStr.isEmpty) {
        uuidStr = prefs.deviceUuid;
        if (uuidStr.isEmpty) {
          uuidStr = const Uuid().v4();
        }
      }
      await prefs.saveDeviceUuid(uuidStr);

      /*
      if (prefs.consentGiven && !prefs.onboardingComplete) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkDeviceUuidAndPrompt();
        });
      }
      */

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

      final savedExercise = prefs.lastSelectedExercise;
      if (savedExercise.isNotEmpty) {
        _selectedExercise = savedExercise;
      }
      
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

      _emptyFieldPulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      _emptyFieldPulseController?.repeat(reverse: true);

      // Foreground FCM 수신 대기 설정
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (mounted) {
          // 공지사항 푸시 수신 시 실시간으로 공지 카드도 갱신
          _fetchLatestNotice();

          final noticeId = message.data['notice_id'] as String?;
          final testerName = _prefs?.name.trim() ?? '';
          if (noticeId != null && testerName.isNotEmpty) {
            _sendNoticeAck(noticeId, testerName);
          }

          // 포그라운드 상태에서도 무조건 시스템 노티피케이션 (헤드업 알림) 띄우기
          showLocalNotification(message);
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

      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _session = session;
        _hasWatchedGuide = hasWatched;
        _favoriteSports = List.from(prefs.favoriteSports);
        _currentStep = prefs.onboardingComplete ? 4 : 1;
        _isLoading = false;
      });

      // 최신 공지사항 로드
      _fetchLatestNotice();

      // 개인 알림 토픽 구독
      _updateNotificationTopic(prefs.name);

      // 기기 접속 핑 전송
      _sendDevicePing();

      // 1. 앱 업데이트 체크 및 팝업 대기
      await _checkAppUpdate();

      // 2. 메인 화면(Step 4)일 경우 명예의 전당 -> 이메일 팝업 체이닝 대기
      if (_currentStep == 4) {
        await _checkMonthlyResultPopup();
      }

      // 기본 선택된 운동 대상의 디테일 설정 불러오기
      _loadSportDetails(_selectedExercise);

      // 펜딩된 히스토리 이동 요청 처리
      if (_pendingNoticeHistory) {
        _navigateToNoticeHistory();
      }
    } catch (e) {
      debugPrint('[_init] Exception during initialization: $e');
      // 어떤 예외가 발생하더라도 로딩 화면을 해제하여 앱 진입을 막지 않음
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }





  Future<void> _checkDeviceUuidAndPrompt() async {
    if (_prefs == null) return;
    final uuidStr = _prefs!.deviceUuid;
    if (uuidStr.isEmpty) return;

    try {
      final url = Uri.parse('${AppConfig.apiUrl}/api/devices?check_uuid=$uuidStr');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success' && decoded['exists'] == true) {
          final String savedName = decoded['tester_name'] ?? '';
          if (savedName.isNotEmpty && mounted) {
            _showRestoreDialog(savedName);
          }
        }
      }
    } catch (e) {
      debugPrint("[UUID CHECK] Failed to check UUID on server: $e");
    }
  }

  void _showRestoreDialog(String savedName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          radius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_rounded, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                '이전 등록 정보 발견',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                '이 기기에 이전에 등록했던 닉네임("$savedName")이 존재합니다.\n\n해당 닉네임으로 로그인을 진행하시겠습니까, 아니면 새 프로필을 만드시겠습니까?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx), // Close dialog & start new profile
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white60,
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('새로 만들기', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx); // Close dialog
                        await _prefs!.saveName(savedName);
                        await _prefs!.saveOnboardingComplete(true);
                        await _updateNotificationTopic(savedName);
                        _sendDevicePing();
                        if (mounted) {
                          setState(() {
                            _nameCtrl.text = savedName;
                            _currentStep = 4;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3366FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('기존 닉네임 사용', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
      final appVersion = AppConfig.appVersion;

      final watchName = _selectedWatch == '직접입력'
          ? _customWatchCtrl.text.trim()
          : _selectedWatch;
      final strapName = _selectedStrap == '직접입력'
          ? _customStrapCtrl.text.trim()
          : _selectedStrap;
      final url = Uri.parse('${AppConfig.apiUrl}/api/devices/ping');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tester_name': testerName,
          'email': _emailCtrl.text.trim(),
          'last_seen_fame_month': _prefs!.lastSeenFameMonth,
          'watch': watchName.isEmpty ? '미지정' : watchName,
          'strap': strapName.isEmpty ? '미지정' : strapName,
          'os_version': 'Android ${_session!.androidVersion} (Model: ${_session!.deviceModel})',
          'device_uuid': _prefs!.deviceUuid,
          'app_version': appVersion,
        }),
      );
      debugPrint("[PING] Device ping sent successfully for $testerName");
    } catch (e) {
      debugPrint("[PING] Failed to send device ping: $e");
    }
  }

  Future<void> _showForceUpdateDialog(String serverVersion) async {
    if (!mounted) return;
    await showDialog(
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
                const Icon(Icons.system_update_rounded, color: Colors.white, size: 48),
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
                          Navigator.pop(ctx);
                          _launchPlayStore();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3366FF),
                          foregroundColor: Colors.white,
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

  Future<void> _launchPlayStore() async {
    const playStoreUrl = 'market://details?id=com.samsung.health.client';
    const webUrl = 'https://play.google.com/store/apps/details?id=com.samsung.health.client';
    try {
      final Uri uri = Uri.parse(playStoreUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ToastUtil.showToast(context, '스토어 링크를 열 수 없습니다.');
        }
      }
    }
  }

  void _showQuickShareGuideDialog(VoidCallback onConfirm) {
    int guideIndex = 0;
    bool dontShowAgain = false;
    final PageController pageController = PageController(initialPage: 0);

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
              '1. 「퀵 쉐어」 버튼 클릭',
              '2. 「QR 코드 또는 링크」 클릭',
              '3. 「링크 복사」 클릭 후 뒤로 가기(Back 키)',
            ];

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2640),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
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
                        height: 380,
                        width: double.infinity,
                        color: Colors.black26,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PageView.builder(
                              controller: pageController,
                              itemCount: images.length,
                              onPageChanged: (index) {
                                setDialogState(() {
                                  guideIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                return Image.asset(
                                  images[index],
                                  fit: BoxFit.contain,
                                );
                              },
                            ),
                            if (guideIndex > 0)
                              Positioned(
                                left: 4,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.chevron_left_rounded, color: Colors.white,
                                    size: 36,
                                  ),
                                  onPressed: () {
                                    pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            if (guideIndex < 2)
                              Positioned(
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.chevron_right_rounded, color: Colors.white,
                                    size: 36,
                                  ),
                                  onPressed: () {
                                    pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: guideIndex == 2
                            ? Text.rich(
                                const TextSpan(
                                  text: '3. 링크 복사 클릭 후 뒤로 가기(',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Back 키',
                                      style: TextStyle(
                                        color: Colors.amberAccent,
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
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 8),
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
                                  activeColor: const Color(0xFF3366FF),
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
                        if (guideIndex == 2)
                          ElevatedButton(
                            onPressed: () async {
                              if (dontShowAgain) {
                                await _prefs?.saveHideQuickShareGuide(true);
                              }
                              pageController.dispose();
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                              onConfirm();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3366FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        else
                          ElevatedButton(
                            onPressed: () {
                              pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text('다음', style: TextStyle(fontWeight: FontWeight.bold)),
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
                await _showForceUpdateDialog(serverVersion);
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

  Future<void> _checkEmailMigrationPopup() async {
    if (!mounted || _prefs == null) return;
    if (_prefs!.emailMigrationDone) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2128).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: const Text(
            '🔔 앱 업데이트 필수 안내 🔔',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '소중한 포인트와 기록을 안전하게 보호를 위해\n구글 이메일 연동이 필수로 변경되었습니다.\n\n지금 바로 연동하고 기록을 안전하게 보관하세요!',
                style: TextStyle(fontSize: 14, color: Colors.white, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Icon(Icons.security_rounded, size: 40, color: const Color(0xFF3366FF).withOpacity(0.8)),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    InstantPageRoute(
                      page: SettingsScreen(prefs: _prefs!, showEmailGuide: true),
                    ),
                  ).then((_) {
                    _reloadPrefs();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3366FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                ),
                child: const Text('이메일 연동하러 가기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkMonthlyResultPopup() async {
    if (!mounted || _prefs == null) return;
    
    final now = DateTime.now();
    final currentMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    // 이미 이번 달 팝업을 봤다면 스킵
    if (_prefs!.lastSeenFameMonth == currentMonthStr) {
      _checkEmailMigrationPopup();
      return;
    }
    
    // 이전 달 계산
    final prevYear = now.month == 1 ? now.year - 1 : now.year;
    final prevMonthNum = now.month == 1 ? 12 : now.month - 1;
    final prevMonthStr = '$prevYear-${prevMonthNum.toString().padLeft(2, '0')}';
    
    // 이름이 있어야 순위 검색 가능
    final testerName = _prefs!.name.trim();
    if (testerName.isEmpty) {
      _checkEmailMigrationPopup();
      return;
    }

    try {
      final url = Uri.parse('${AppConfig.apiUrl}/api/devices?rankings=true&month=$prevMonthStr&tester_name=$testerName');
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final rankingsList = data['data']['rankings'] as List<dynamic>? ?? [];
          final top3 = rankingsList.take(3).toList();
          
          final meta = data['data']['meta'];
          if (meta != null && mounted) {
            await _showFameResultDialog(meta, top3, prevMonthStr, currentMonthStr);
            _checkEmailMigrationPopup();
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[FAME] 팝업 조회 실패: $e');
    }
    
    _checkEmailMigrationPopup();
  }

  Future<void> _showFameResultDialog(Map<String, dynamic> meta, List<dynamic> top3, String prevMonth, String currentMonth) async {
    final myRank = meta['my_rank'];
    final myPoints = meta['my_count'] ?? 0;
    
    final bool hasParticipated = myRank != null;
    
    // 폭죽 무조건 실행 (참여 여부 관계없이 1~3등 축하용)
    Future.delayed(const Duration(milliseconds: 300), () {
      _confettiController.play();
    });
    
    String feedbackText = '';
    if (!hasParticipated) {
      feedbackText = '👀 남들 점수 올릴 때 뭐 하셨나요!(농담) 이번 달은 주인공이 되어보세요! 화이팅!!';
    } else if (myRank <= 3) {
      feedbackText = '🎊 명예의 전당 최상위권 등극! 당신이 진정한 챔피언입니다! 🎊';
    } else if (myRank <= 10) {
      feedbackText = '🔥 아깝다! 조금만 더 뛰면 TOP 3 진입 가능! 이번 달은 왕관을 노려보세요!';
    } else {
      feedbackText = '👟 꾸준함이 생명! 이번 달도 힘차게 달려볼까요? 화이팅!';
    }
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Stack(
          alignment: Alignment.center,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
            AlertDialog(
              backgroundColor: const Color(0xFF1E2128).withOpacity(0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              title: Text(
                '🏆 $prevMonth 명예의 전당 결과 🏆',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('지난달의 영웅들', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white70)),
                  const SizedBox(height: 10),
                  // Top 3 Podium
                  if (top3.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          if (top3.isNotEmpty) _buildPodiumRow(1, '🥇', top3[0]),
                          if (top3.length > 1) const SizedBox(height: 6),
                          if (top3.length > 1) _buildPodiumRow(2, '🥈', top3[1]),
                          if (top3.length > 2) const SizedBox(height: 6),
                          if (top3.length > 2) _buildPodiumRow(3, '🥉', top3[2]),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Divider(color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 10),
                  // My Result
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 20),
                      const SizedBox(width: 5),
                      const Text('나의 성적표', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (hasParticipated) ...[
                    Text('총 $myPoints P 획득', style: const TextStyle(fontSize: 15, color: Colors.white)),
                    const SizedBox(height: 5),
                    Text('순위: $myRank 위', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3366FF))),
                    const SizedBox(height: 15),
                  ],
                  Text(
                    feedbackText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFFFB74D)),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confettiController.stop();
                      _prefs?.saveLastSeenFameMonth(currentMonth);
                      _sendDevicePing();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3366FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                    ),
                    child: const Text('확인', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            // 폭죽 무조건 렌더링
            Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: true,
                  colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPodiumRow(int rank, String medal, dynamic user) {
    // 폰트 크기 및 메달 크기를 15px로 동일하게 통일
    const double baseSize = 15;
    final bool isFirst = rank == 1;
    
    // 1등은 두껍게(w900) + 흰색, 나머지는 얇게(w500) + 살짝 투명하게
    final FontWeight fontWeight = isFirst ? FontWeight.w900 : FontWeight.w500;
    final Color textColor = isFirst ? Colors.white : Colors.white70;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(medal, style: const TextStyle(fontSize: baseSize)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            user['tester_name'] ?? '알 수 없음',
            style: TextStyle(fontWeight: fontWeight, fontSize: baseSize, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${user['points']} P',
          style: TextStyle(fontWeight: fontWeight, fontSize: baseSize, color: textColor),
        ),
      ],
    );
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
    
    // 로컬 저장소가 갱신되었으므로 서버 쪽에도 변경된 워치/스트랩 정보를 전송하여 동기화
    _sendDevicePing();
  }

  @override
  void dispose() {
    _deviceTabController.dispose();
    _confettiController.dispose();
    _customCompetitorCtrl.removeListener(_saveSportDetails);
    _customTrainingCtrl.removeListener(_saveSportDetails);
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _ssidFocusNode.dispose();
    _ssidCtrl.dispose();
    _pwdCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _customWatchCtrl.dispose();
    _customStrapCtrl.dispose();
    _customCompetitorCtrl.dispose();
    _customTrainingCtrl.dispose();
    _distanceCtrl.dispose();
    _distanceFocusNode.dispose();
    _locationCtrl.dispose();
    _memoCtrl.dispose();
    _guidePulseController?.dispose();
    _noticePulseController?.dispose();
    _updateNoticePulseController?.dispose();
    _emptyFieldPulseController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── 클립보드 감시 및 이메일 전송 ──────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_wentToHotspotSettings) {
        _wentToHotspotSettings = false;
        _checkHotspotStatus();
      }
      if (_currentStep == 4) _scanGarminFilesFromDownload();
    }
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
        hasFit: _fitFiles.isNotEmpty,
        hasGarmin: _garminFiles.isNotEmpty,
        hasCola: _colaFiles.isNotEmpty,
        hasLog: _logFiles.isNotEmpty,
        captureCount: _captureFiles.length,
        gpsStatus: _gpsStatus,
        gpsMemo: _gpsMemoCtrl.text.trim(),
        hrStatus: _hrStatus,
        hrMemo: _hrMemoCtrl.text.trim(),
        paceStatus: _paceStatus,
        paceMemo: _paceMemoCtrl.text.trim(),
        altitudeStatus: _altitudeStatus,
        altitudeMemo: _altitudeMemoCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _emailSending = false;
          _emailSent = true;
          _step6State = 'success';
        });

        // 1초 뒤에 새로운 검증 시작하기 버튼 동작처럼 초기화 후 운동 선택(4단계) 화면으로 이동
        Future.delayed(const Duration(seconds: 1), () async {
          if (mounted) {
            _watchLogsAddedToZip = false; // Reset the flag unconditionally
            _resetVerification();
            
            final prefs = await SharedPreferences.getInstance();
            final bool hidePopup = prefs.getBool('hide_log_cleanup_popup') ?? false;
            
            if (hidePopup) {
              if (mounted) {
                ToastUtil.showToast(context, '데이터 제출이 완료되었습니다. 새로운 검증을 시작합니다.');
              }
              return;
            }
            
            bool dontShowAgain = false;
            int? myRank;
            
            // Fetch real-time rank
            try {
              final now = DateTime.now();
              final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
              final rankUrl = Uri.parse('${AppConfig.apiUrl}/api/devices?rankings=true&month=$monthStr&tester_name=${Uri.encodeComponent(prefs.getString('name') ?? '')}');
              final response = await http.get(rankUrl).timeout(const Duration(seconds: 3));
              if (response.statusCode == 200) {
                final res = jsonDecode(response.body);
                if (res['status'] == 'success') {
                  myRank = res['data']['meta']['my_rank'];
                }
              }
            } catch (e) {
              debugPrint('[Rank Fetch Error] $e');
            }
            
            String _randomMsg = '제출 완료! 오늘 하루도 고생 많으셨습니다 👏';
            String _randomEmoji = '🎉';
            
            final Random rand = Random();
            if (myRank == 1) {
              final msgs = [
                {'msg': '👑 전 우주 1등! 외계인도 당신의 데이터를 탐냅니다!', 'emoji': '👑'},
                {'msg': '🥇 1위의 공기는 좀 다를까요? 완벽 그 자체입니다!', 'emoji': '🥇'},
                {'msg': '전설의 레전드 등극! 뒤에서 2위가 매섭게 쫓아오고 있어요!', 'emoji': '🔥'},
                {'msg': '왕관의 무게를 견디는 자! 데이터의 신입니다.', 'emoji': '👑'},
                {'msg': '더 이상 올라갈 곳이 없네요. 완벽한 1위입니다!', 'emoji': '💯'},
                {'msg': '타의 추종을 불허하는 압도적 1위! 폼 미쳤다!', 'emoji': '⭐'},
              ];
              final item = msgs[rand.nextInt(msgs.length)];
              _randomMsg = item['msg']!;
              _randomEmoji = item['emoji']!;
            } else if (myRank != null && myRank <= 3) {
              final msgs = [
                {'msg': '🥇 메달권 진입! 1등의 숨결이 느껴지는 거리입니다.', 'emoji': '🥈'},
                {'msg': '은빛, 동빛 찬란한 당신의 데이터! 1위가 코앞이에요.', 'emoji': '✨'},
                {'msg': '시상대의 공기를 만끽하세요! 훌륭한 순위입니다.', 'emoji': '🏆'},
                {'msg': 'TOP 3 달성! 멈추지 않는 열정에 박수를 보냅니다.', 'emoji': '👏'},
                {'msg': '거의 다 왔어요! 다음 제출로 1위를 노려볼까요?', 'emoji': '🎯'},
                {'msg': '포디움 입성 축하드려요! 조금만 더 엑셀을 밟아주세요!', 'emoji': '🚀'},
              ];
              final item = msgs[rand.nextInt(msgs.length)];
              _randomMsg = '현재 $myRank위! ' + item['msg']!;
              _randomEmoji = item['emoji']!;
            } else if (myRank != null && myRank <= 10) {
              final msgs = [
                {'msg': '🔥 TOP 10! 상위 1%의 미친 열정! 조금만 더 쥐어짜볼까요?', 'emoji': '🔥'},
                {'msg': '이 구역의 데이터 수집기! 순위권이 코앞입니다.', 'emoji': '🔋'},
                {'msg': '한 단계만 더! 어제보다 강해진 당신의 순위입니다.', 'emoji': '📈'},
                {'msg': '대단한 끈기입니다! TOP 3 진입을 응원합니다.', 'emoji': '🏃‍♂️'},
                {'msg': '당신의 기록이 상위권을 뒤흔들고 있어요!', 'emoji': '🌪️'},
                {'msg': '폭발적인 스퍼트! 순위표가 당신 덕분에 요동칩니다.', 'emoji': '⚡'},
              ];
              final item = msgs[rand.nextInt(msgs.length)];
              _randomMsg = '현재 $myRank위! ' + item['msg']!;
              _randomEmoji = item['emoji']!;
            } else if (myRank != null && myRank <= 50) {
              final msgs = [
                {'msg': '🏃‍♂️ 달리는 인간 백과사전! 데이터가 쌓일수록 랭킹도 쑥쑥!', 'emoji': '📚'},
                {'msg': '폭풍 성장 중! 매일매일 랭킹이 쑥쑥 오르고 있어요.', 'emoji': '🌪️'},
                {'msg': '지치지 않는 체력! 조만간 TOP 10에서 뵙겠습니다.', 'emoji': '💪'},
                {'msg': '데이터가 쌓일수록 당신의 가치도 올라갑니다 🚀', 'emoji': '🚀'},
                {'msg': '좋은 페이스입니다! 멈추지 말고 계속 달려주세요!', 'emoji': '⏱️'},
                {'msg': '무서운 기세로 치고 올라가는 중! 랭커들이 긴장하고 있어요.', 'emoji': '🔥'},
              ];
              final item = msgs[rand.nextInt(msgs.length)];
              _randomMsg = '현재 $myRank위! ' + item['msg']!;
              _randomEmoji = item['emoji']!;
            } else {
              final msgs = [
                {'msg': '🌱 위대한 여정의 시작! 오늘의 땀방울이 내일의 순위를 바꿉니다.', 'emoji': '🌱'},
                {'msg': '아직 보여줄 게 많잖아요? 숨겨둔 에너지를 폭발시켜 보세요!', 'emoji': '💥'},
                {'msg': '한 걸음씩 꾸준하게! 조용히 순위표를 등반해 봅시다.', 'emoji': '🧗‍♂️'},
                {'msg': '시작이 반! 꾸준함이 모여 기적을 만듭니다.', 'emoji': '✨'},
                {'msg': '오늘의 제출이 내일의 레전드를 만듭니다!', 'emoji': '🌟'},
                {'msg': '천리길도 한 걸음부터! 당신의 첫 데이터가 세상을 바꿀지도 몰라요.', 'emoji': '🐾'},
              ];
              final item = msgs[rand.nextInt(msgs.length)];
              _randomMsg = (myRank != null ? '현재 $myRank위! ' : '') + item['msg']!;
              _randomEmoji = item['emoji']!;
            }
            
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => StatefulBuilder(
                builder: (context, setDialogState) => AlertDialog(
                backgroundColor: const Color(0xFF1E2640),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    const Text('🎉 데이터 제출 완료!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () {
                        if (dontShowAgain) prefs.setBool('hide_log_cleanup_popup', true);
                        Navigator.pop(ctx);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    BouncingEmojiWidget(emoji: _randomEmoji),
                    const SizedBox(height: 20),
                    Text(
                      _randomMsg,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cleaning_services_rounded, color: Colors.amberAccent, size: 20),
                              const SizedBox(width: 8),
                              const Text('워치 저장공간 비우기 (권장)', style: TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '제출된 데이터는 워치에서 지워주셔야\n빠르게 로그를 전송할 수 있습니다.',
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '① 아래 버튼 클릭 ➡️ ② *#9900# 입력\n➡️ ③ DELETE DUMPSTATE 클릭!',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 말풍선 애니메이션
                      BouncingWidget(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amberAccent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))
                                ],
                              ),
                              child: const Text(
                                '👇 클릭하고 워치 확인!',
                                style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            // 꼬리 부분
                            Padding(
                              padding: const EdgeInsets.only(right: 32),
                              child: Transform.translate(
                                offset: const Offset(0, -4),
                                child: Transform.rotate(
                                  angle: 3.141592 / 4,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 체크박스와 버튼
                      Transform.translate(
                        offset: const Offset(0, -8), // 꼬리가 버튼에 살짝 겹치도록 위로 당김
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () {
                                setDialogState(() {
                                  dontShowAgain = !dontShowAgain;
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    dontShowAgain ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: dontShowAgain ? Colors.blueAccent : Colors.white54,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('다시 보지 않기', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: -0.5)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3366FF),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                if (dontShowAgain) prefs.setBool('hide_log_cleanup_popup', true);
                                Navigator.pop(ctx);
                                const channel = MethodChannel('com.samsung.health.client/app_info');
                                try {
                                  await channel.invokeMethod('openWatchSysDump');
                                } catch (e) {
                                  debugPrint('워치 다이얼러 호출 실패: $e');
                                }
                              },
                              child: const Text('로그 삭제하러 가기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              )),
            );
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

  // ── 데이터 정밀 검증 요약 컨펌 다이얼로그 ──────────────────────
  // ── 데이터 정밀 검증 요약 컨펌 다이얼로그 ──────────────────────
  Future<bool> _showVerificationConfirmDialog() async {
    final hideGpsAltitude = (_selectedExercise == '러닝머신 걷기' ||
        _selectedExercise == '러닝머신 달리기' ||
        _selectedExercise == '실내 수영' ||
        _selectedExercise == '야외 수영' ||
        _selectedExercise == '근력 운동');

    final bool? result = await showDialog<bool>(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '센서/데이터 이슈 메모',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx, false);
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: const Icon(Icons.close_rounded, color: Colors.white54, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '입력하신 센서/데이터 이슈 메모를 확인해 주세요.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      if (!hideGpsAltitude) ...[
                        _buildConfirmItem('GPS', _gpsStatus, _gpsMemoCtrl.text),
                        const Divider(color: Colors.white12, height: 16),
                      ],
                      _buildConfirmItem('심박수(HR)', _hrStatus, _hrMemoCtrl.text),
                      const Divider(color: Colors.white12, height: 16),
                      _buildConfirmItem('속도/페이스', _paceStatus, _paceMemoCtrl.text),
                      if (!hideGpsAltitude) ...[
                        const Divider(color: Colors.white12, height: 16),
                        _buildConfirmItem('고도', _altitudeStatus, _altitudeMemoCtrl.text),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx, false);
                          FocusManager.instance.primaryFocus?.unfocus();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final ctx = _precisionCardKey.currentContext;
                            if (ctx != null) {
                              Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('다시 수정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3366FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('확인 및 전송', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
    return result ?? false;
  }

  Widget _buildConfirmItem(String label, String status, String memo) {
    final bool isNormal = status == '정상';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isNormal ? Colors.white.withOpacity(0.15) : const Color(0xFFFFAE2E).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: isNormal ? Colors.white : const Color(0xFFFFAE2E),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (!isNormal && memo.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              '└ $memo',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }

  // ── 압축 및 전송 시작 ───────────────────────────────────────
  Future<void> _onSend() async {
    if (!_formKey5.currentState!.validate()) return;

    final hideGpsAltitude = (_selectedExercise == '러닝머신 걷기' ||
        _selectedExercise == '러닝머신 달리기' ||
        _selectedExercise == '실내 수영' ||
        _selectedExercise == '야외 수영' ||
        _selectedExercise == '근력 운동');

    // 사용자가 1개 이상 수정을 했는지 판별 (디폴트값인 '정상' 또는 'N/A'에서 변경되었거나 '확인 필요' 상태가 되었는지 확인)
    final String defaultGpsAltitude = hideGpsAltitude ? 'N/A' : '정상';
    bool isGpsModified = _gpsStatus != defaultGpsAltitude;
    bool isHrModified = _hrStatus != '정상';
    bool isPaceModified = _paceStatus != '정상';
    bool isAltitudeModified = _altitudeStatus != defaultGpsAltitude;

    bool anyModified = isGpsModified || isHrModified || isPaceModified || isAltitudeModified;

    // 모든 항목이 디폴트 값('정상' 또는 'N/A')일 때만 확인 팝업을 보여줌.
    // 1개라도 수정(정상/NA가 아닌 상태, 즉 확인 필요 등)이 된 경우 팝업을 띄우지 않고 통과.
    if (!anyModified) {
      final bool isConfirmed = await _showVerificationConfirmDialog();
      if (!isConfirmed) return;
    }

    // 팝업 통과(혹은 확인 완료) 후 퀵 쉐어 가이드를 보여주거나 바로 패키징을 실행합니다.
    if (_prefs?.hideQuickShareGuide == true) {
      _executePackaging();
    } else {
      _showQuickShareGuideDialog(_executePackaging);
    }
  }

  Future<void> _executePackaging() async {
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
        email: _emailCtrl.text.trim(),
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
        gpsStatus: _gpsStatus,
        gpsMemo: _gpsMemoCtrl.text.trim(),
        hrStatus: _hrStatus,
        hrMemo: _hrMemoCtrl.text.trim(),
        paceStatus: _paceStatus,
        paceMemo: _paceMemoCtrl.text.trim(),
        altitudeStatus: _altitudeStatus,
        altitudeMemo: _altitudeMemoCtrl.text.trim(),
        session: _session!,
        fitFiles: [..._fitFiles, ..._garminFiles],
        colaFiles: _colaFiles,
        logFiles: _logFiles,
        captureFiles: _captureFiles,
      );

      final locationText = _locationCtrl.text.trim();
      if (locationText.isNotEmpty) {
        await _prefs?.saveRecentLocation(locationText);
      }

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
        ToastUtil.showToast(context, '압축 실패: $e');
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
      final f = await CustomFilePicker.showPicker(
        context: context,
        title: '자사 FIT 파일 선택',
        directoryPath: '/sdcard/Download/삼성 헬스/fit',
        extensionFilter: '.fit',
        onFreeSelect: () => FileService.pickFit(),
      );
      if (f != null && mounted)         if (f is File) {
          final stat = f.statSync();
          final name = f.path.split('/').last.split('\\').last;
          setState(() => _fitFiles.add(AttachedFile(originalPath: f.path, name: name, sizeBytes: stat.size, type: AttachType.fit)));
        } else {
          setState(() => _fitFiles.add(f));
        }
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
        // Stream을 통해 자동 닫기 구현 (필요시)
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Garmin Fit 파일 다운로드',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, null),
                      child: const Icon(Icons.close_rounded, color: Colors.white54, size: 24),
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
                      side: BorderSide(color: Colors.white.withOpacity(0.5)),
                      foregroundColor: Colors.white,
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
                          backgroundColor: const Color(0xFF3366FF),
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
      // await _launchUrl('https://connect.garmin.com/app/');
      await _launchUrl('https://connect.garmin.com/signin/');
    } else if (action == 'no') {
      if (_fileBusy) return;
      setState(() => _fileBusy = true);
      try {
        final f = await CustomFilePicker.showPicker(
          context: context,
          title: 'Garmin Fit 파일 선택',
          directoryPath: '/sdcard/Download',
          extensionFilter: '.zip',
          onFreeSelect: () => FileService.pickGarminFit(),
        );
        if (f != null && mounted) {
          final pathStr = f is File ? f.path : f.originalPath;
          final fileName = pathStr.split('/').last.split('\\').last;
          if (!fileName.toLowerCase().endsWith('.zip')) {
            _showFileError('Garmin FIT 파일', '선택한 파일이 .zip 파일이 아닙니다.');
            return;
          }
                  if (f is File) {
          final stat = f.statSync();
          final name = f.path.split('/').last.split('\\').last;
          setState(() => _garminFiles.add(AttachedFile(originalPath: f.path, name: name, sizeBytes: stat.size, type: AttachType.fit)));
        } else {
          setState(() => _garminFiles.add(f));
        }
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
      final f = await CustomFilePicker.showPicker(
        context: context,
        title: 'Cola 파일 선택',
        directoryPath: '/sdcard/Documents/COLA_FILE',
        prefixFilters: ['COLA_FILE', 'log_'],
        priorityPrefix: 'COLA_FILE',
        onFreeSelect: () => FileService.pickCola(),
      );
      if (f != null && mounted) {
        final pathStr = f is File ? f.path : f.originalPath;
        final fileName = pathStr.split('/').last.split('\\').last;
        if (!fileName.toLowerCase().startsWith('cola')) {
          _showFileError('Cola.zip', '선택한 파일이 COLA_FILE로 시작하는 zip 파일이 아닙니다.');
          return;
        }
                if (f is File) {
          final stat = f.statSync();
          final name = f.path.split('/').last.split('\\').last;
          setState(() => _colaFiles.add(AttachedFile(originalPath: f.path, name: name, sizeBytes: stat.size, type: AttachType.cola)));
        } else {
          setState(() => _colaFiles.add(f));
        }
      }
    } catch (e) {
      _showFileError('Cola.zip', e);
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _pickLog({String? initialDirectory}) async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);
    try {
      final f = await CustomFilePicker.showPicker(
        context: context,
        title: initialDirectory != null ? 'Log(Sensorlog 포함) 파일 선택' : '단말 Log 파일 선택',
        directoryPath: initialDirectory ?? '/sdcard/Documents/COLA_FILE',
        prefixFilters: initialDirectory != null ? null : ['COLA_FILE', 'log_', 'GearLog'],
        priorityPrefix: 'log_',
        allowMultiple: true,
        onFreeSelect: () => FileService.pickLog(),
      );
      if (f != null && mounted) {
        final List<dynamic> items = f is List ? f : [f];
        for (final item in items) {
          final pathStr = item is File ? item.path : (item as AttachedFile).originalPath;
          final fileName = pathStr.split('/').last.split('\\').last;
          
          // Watch 탭인 경우(initialDirectory == null)에만 log_ 접두어 검사
          if (initialDirectory == null && !fileName.toLowerCase().startsWith('log_')) {
            _showFileError('단말 Log 파일', '선택한 파일($fileName)이 log_로 시작하는 zip 파일이 아닙니다.');
            continue;
          }
          
          if (item is File) {
            final stat = item.statSync();
            setState(() => _logFiles.add(AttachedFile(originalPath: item.path, name: fileName, sizeBytes: stat.size, type: AttachType.log)));
          } else {
            setState(() => _logFiles.add(item));
          }
        }
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
    ToastUtil.showToast(context, '$label 선택 오류: $e');
  }

  // ── 빌드 영역 ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0F0F),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3366FF)),
          ),
        ),
      );
    }

    final mainTheme = ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0F0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3366FF),
          secondary: Color(0xFF3366FF),
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
            borderSide: const BorderSide(color: Color(0xFF3366FF), width: 1.5),
          ),
          labelStyle: TextStyle(color: const Color(0xFFE2E2E2).withOpacity(0.7)),
        ),
      );

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
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_rounded, size: 22, color: Colors.white),
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
                        setState(() {}); // Refresh badge state after returning
                      },
                    ),
                    if (_prefs?.hasSeenNewLabMenu == false)
                      Container(
                        margin: const EdgeInsets.only(top: 8, right: 8),
                        padding: const EdgeInsets.all(3.5),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Text('N', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, height: 1.0)),
                      ),
                  ],
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
                            colors: [Color(0xFF3366FF), Color(0xFF3366FF)],
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
                    color: Color(0xFF3366FF),
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
        return '프로필 입력';
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

  void _showEmailActionDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2640),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.email_outlined, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                const Text('구글 이메일 자동 조회', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('안드로이드 설정에 등록된 구글 계정을 가져오시겠습니까?', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _isEmailReadOnly = false;
                          });
                          _emailFocusNode.requestFocus();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('직접 입력'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            final email = await _appChannel.invokeMethod<String>('getGoogleEmail');
                            if (email != null && email.isNotEmpty) {
                              setState(() {
                                _emailCtrl.text = email;
                              });
                              ToastUtil.showToast(context, '이메일을 성공적으로 가져왔습니다!');
                              _checkEmailAndReuse(email);
                            } else {
                              ToastUtil.showToast(context, '등록된 구글 계정이 없습니다. 직접 입력해 주세요.');
                              setState(() {
                                _isEmailReadOnly = false;
                              });
                              _emailFocusNode.requestFocus();
                            }
                          } catch (e) {
                            debugPrint('[getGoogleEmail Error] $e');
                            ToastUtil.showToast(context, '이메일을 가져오지 못했습니다. 직접 입력해 주세요.');
                            setState(() {
                              _isEmailReadOnly = false;
                            });
                            _emailFocusNode.requestFocus();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3366FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('자동 조회 (추천)', style: TextStyle(fontWeight: FontWeight.bold)),
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
  }


  Future<void> _checkEmailAndReuse(String email) async {
    try {
      final emailUrl = Uri.parse('${AppConfig.apiUrl}/api/devices?check_email=${Uri.encodeComponent(email)}');
      final emailResponse = await http.get(emailUrl);
      if (emailResponse.statusCode == 200) {
        final emailRes = jsonDecode(emailResponse.body);
        if (emailRes['status'] == 'success' && emailRes['exists'] == true) {
          final String savedName = emailRes['tester_name'] ?? '';
          final String savedWatch = emailRes['watch'] ?? '미지정';
          final String savedStrap = emailRes['strap'] ?? '미지정';

          if (savedName.isNotEmpty && mounted) {
            final bool? reuse = await _showEmailProfileDialog(savedName);
            if (reuse == true) {
              _applyReusedProfile(email, savedName, savedWatch, savedStrap);
            } else {
              setState(() { _nameCtrl.clear(); });
              _nameFocusNode.requestFocus();
            }
          }
        }
      }
    } catch (apiError) {
      debugPrint('[check_email Error] $apiError');
      setState(() { _nameCtrl.clear(); });
      _nameFocusNode.requestFocus();
    }
  }

  void _applyReusedProfile(String email, String savedName, String savedWatch, String savedStrap) {
    _prefs?.saveGoogleEmail(email);
    _prefs?.saveName(savedName);
    
    String cleanWatch = savedWatch.trim();
    bool isWatchInList = kWatchOptions.any((opt) => opt.trim() == cleanWatch);
    if (!isWatchInList && cleanWatch != '미지정' && cleanWatch.isNotEmpty) {
      _prefs?.saveWatch('직접입력');
      _prefs?.saveCustomWatch(cleanWatch);
      _selectedWatch = '직접입력';
      _customWatchCtrl.text = cleanWatch;
    } else {
      _prefs?.saveWatch(cleanWatch);
      _selectedWatch = cleanWatch;
    }

    String cleanStrap = savedStrap.trim();
    bool isStrapInList = kStrapOptions.any((opt) => opt['name']?.trim() == cleanStrap);
    if (!isStrapInList && cleanStrap != '미지정' && cleanStrap.isNotEmpty) {
      _prefs?.saveStrap('직접입력');
      _prefs?.saveCustomStrap(cleanStrap);
      _selectedStrap = '직접입력';
      _customStrapCtrl.text = cleanStrap;
    } else {
      _prefs?.saveStrap(cleanStrap);
      _selectedStrap = cleanStrap;
    }
    
    _prefs?.saveOnboardingComplete(true);
    _prefs?.saveEmailMigrationDone(true);

    setState(() {
      _nameCtrl.text = savedName;
      _currentStep = 4;
    });
    _sendDevicePing();
    _checkMonthlyResultPopup();
  }

  Future<bool?> _showEmailProfileDialog(String savedName) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E2640),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_rounded, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              '기존 닉네임 발견',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              '이 구글 계정에 등록된 닉네임("$savedName")이 존재합니다.\n해당 닉네임으로 계속하시겠습니까, 아니면 새 프로필을 만드시겠습니까?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), height: 1.5),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('새로 만들기', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3366FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('기존 닉네임 사용', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 10),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showNicknameProfileDialog(String nickname) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E2640),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
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
            const SizedBox(height: 32),
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
                    backgroundColor: const Color(0xFF3366FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('예', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 10),
          ],
        ),
      ),
    );
  }
  // ── Step 1: 테스터 프로필 ──────────────────────────────────────
  Widget _buildStep1Profile() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HealthPort 서비스 이용을 위해 구글 이메일과 닉네임을 입력해 주세요.\n※ 설정 > 프로필 설정에서도 수정할 수 있습니다.',
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emailCtrl,
                        focusNode: _emailFocusNode,
                        readOnly: _isEmailReadOnly,
                        onTap: () {
                          if (_isEmailReadOnly) {
                            _showEmailActionDialog();
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: '구글 이메일 주소(Gmail) *',
                          hintText: '예) tester@gmail.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return '이메일을 입력해 주세요';
                          }
                          final clean = v.trim();
                          if (!clean.contains('@') || !clean.endsWith('.com')) {
                            return '올바른 이메일 주소를 입력해 주세요';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  focusNode: _nameFocusNode,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    hintText: '예) 기안84',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '닉네임을 입력해 주세요' : null,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7), height: 1.5),
                      children: [
                        const TextSpan(text: '💡 닉네임은 언제든 자유롭게 변경할 수 있으며 포인트와 기록도 유지돼요!\n\n단, 기준이 되는 구글 이메일을 변경할 경우 '),
                        TextSpan(
                          text: '모든 데이터가 초기화',
                          style: TextStyle(
                            color: const Color(0xFFFF6B6B),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFFFF6B6B),
                          ),
                        ),
                        const TextSpan(text: '되니 주의해 주세요.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _showNicknameFinderBottomSheet,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFF5E8BFF),
                      width: 1.0,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(bottom: 1),
                child: const Text(
                  '닉네임이 기억나지 않나요? 닉네임 찾기',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5E8BFF),
                  ),
                ),
              ),
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
                      color: isSel ? const Color(0xFF3366FF) : const Color(0xFFE2E2E2),
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
    try {
      final String res = await _appChannel.invokeMethod('launchSamsungBrowser', {'url': urlString});
      debugPrint('[LaunchUrl] Custom channel response: $res');
    } catch (e) {
      debugPrint('[LaunchUrl] Custom channel failed, falling back to url_launcher: $e');
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ToastUtil.showToast(context, '링크를 열 수 없습니다: $urlString');
        }
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
                      backgroundColor: const Color(0xFF3366FF),
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
                                color: isSel ? const Color(0xFF3366FF) : const Color(0xFFE2E2E2),
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

        /*
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
                            color: isSel ? const Color(0xFF3366FF) : const Color(0xFFE2E2E2),
                          ),
                        ),
                      ),
                      if (url.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          color: isSel ? const Color(0xFF3366FF) : Colors.white60,
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
        */
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
                const Color(0xFF3366FF),
                const Color(0xFF3366FF),
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
                    const Icon(Icons.system_update_rounded, color: Colors.white, size: 26),
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
                        color: const Color(0xFF3366FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3366FF), width: 1),
                      ),
                      child: const Text(
                        '업데이트',
                        style: TextStyle(fontSize: 10, color: Color(0xFF3366FF), fontWeight: FontWeight.bold),
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
              const Color(0xFF3366FF),
              const Color(0xFF3366FF),
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
                  const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 26),
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
                        color: const Color(0xFFFFD043).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD043), width: 1),
                      ),
                      child: const Text(
                        '필독',
                        style: TextStyle(fontSize: 10, color: Color(0xFFFFD043), fontWeight: FontWeight.bold),
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
        // 1. 내 즐겨찾기 영역 (상단 고정 및 순서 변경 가능)
        if (_favoriteSports.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFFFB74D), size: 18),
              SizedBox(width: 6),
              Text('즐겨찾는 운동', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              Spacer(),
              Text('길게 눌러서 순서 변경', style: TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 10),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _favoriteSports.removeAt(oldIndex);
                _favoriteSports.insert(newIndex, item);
              });
              _prefs?.saveFavoriteSports(_favoriteSports);
            },
            children: _favoriteSports.map((sportName) {
              final ex = kExerciseOptions.firstWhere((e) => e['name'] == sportName, orElse: () => kExerciseOptions.first);
              return Padding(
                key: ValueKey(sportName),
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildExerciseCard(ex, true),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
        ],
        
        // 2. 전체 운동 영역
        const Text('모든 운동', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kExerciseOptions.where((e) => !_favoriteSports.contains(e['name'])).length,
          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
          itemBuilder: (ctx, idx) {
            final otherSports = kExerciseOptions.where((e) => !_favoriteSports.contains(e['name'])).toList();
            return _buildExerciseCard(otherSports[idx], false, key: ValueKey(otherSports[idx]['name']));
          },
        ),
      ],
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> ex, bool isFavorite, {Key? key}) {
    final name = ex['name'] as String;
    final icon = ex['icon'] as IconData;
    final isSel = _selectedExercise == name;

    return InkWell(
      key: key,
      onTap: () {
        setState(() {
          _selectedExercise = name;
          _prefs?.saveLastSelectedExercise(name);
          _currentStep = 5; // 즉시 다음 단계 이동
        });
        _loadSportDetails(name);
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
                color: isSel ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSel ? Colors.white : Colors.white60, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w700,
                  color: isSel ? Colors.white : Colors.white.withOpacity(0.9),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // 즐겨찾기 토글 버튼 (별모양)
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFavorite ? const Color(0xFFFFB74D) : Colors.white30,
              ),
              onPressed: () => _toggleFavorite(name),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            if (isFavorite) ...[
              const Icon(Icons.drag_handle_rounded, size: 20, color: Colors.white30),
            ] else ...[
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isSel ? Colors.white : Colors.white30),
            ],
          ],
        ),
      ),
    );
  }

  // ── Step 5: 파일 첨부 및 디테일 입력 ─────────────────────────────────

  Future<void> _loadHotspotConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hotspotSsid = prefs.getString('hotspot_ssid') ?? '';
      _hotspotPwd = prefs.getString('hotspot_pwd') ?? '';
      _ssidCtrl.text = _hotspotSsid!;
      _pwdCtrl.text = _hotspotPwd!;
    });
  }

  Future<void> _saveHotspotConfig(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _openHotspotSettings({bool skipGuidePopup = false}) async {
    if (!_isHotspotOn && !skipGuidePopup) {
      bool? goNext = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            backgroundColor: const Color(0xFF1E2640),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wifi_tethering, color: Colors.white, size: 24),
                          SizedBox(width: 10),
                          Text('핫스팟 설정 안내', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context, false),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assert/hotspot_guide_2.png',
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    '핫스팟 화면에서 네트워크 이름과 비밀번호를\n확인한 후, 앱에 똑같이 입력해 주세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5B512).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5B512).withOpacity(0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt, color: Color(0xFFE5B512), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              const TextSpan(
                                text: "빠른 전송을 위해 밴드는 ",
                                style: TextStyle(color: Color(0xFFE5B512), fontSize: 14, fontWeight: FontWeight.bold),
                                children: [
                                  TextSpan(
                                    text: "'5GHz 우선'",
                                    style: TextStyle(
                                      fontSize: 16, 
                                      fontWeight: FontWeight.w900, 
                                      color: Colors.white,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: "을 강력 추천합니다!!",
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3366FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (goNext != true) return;
    }
    await _launchHotspotIntent();
  }

  Future<void> _launchHotspotIntent() async {
    _wentToHotspotSettings = true;
    if (Platform.isAndroid) {
      final intent = const AndroidIntent(
        action: 'android.settings.TETHER_SETTINGS',
      );
      await intent.launch();
    }
  }

  Future<void> _triggerDialer9900() async {
    const channel = MethodChannel('com.samsung.health.client/app_info');
    try {
      final bool result = await channel.invokeMethod('openWatchSysDump');
      if (result) {
        if (mounted) {
          ToastUtil.showToast(context, '워치에 SysDump 호출 요청을 전송했습니다.');
        }
      } else {
        if (mounted) {
          ToastUtil.showToast(context, '페어링된 워치 노드를 찾을 수 없습니다.');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showToast(context, '워치 SysDump 호출 실패: $e');
      }
    }
  }

  void _scanGarminFilesFromDownload() {
    final dir = Directory('/storage/emulated/0/Download');
    if (dir.existsSync()) {
      final files = dir.listSync();
      for (var f in files) {
        if (f is File) {
          final name = f.path.split('/').last.toLowerCase();
          if ((name.endsWith('.fit') || name.endsWith('.zip')) && name.contains('garmin')) {
            bool exists = _garminFiles.any((e) => e.originalPath == f.path);
            if (!exists) {
              setState(() {
                _garminFiles.add(AttachedFile(originalPath: f.path, name: f.path.split('/').last, sizeBytes: f.lengthSync(), type: AttachType.fit));
              });
            }
          }
        }
      }
    }
  }

  Map<String, int> _getSnapshotFiles() {
    final dir = Directory('/storage/emulated/0/Documents/COLA_FILE');
    if (!dir.existsSync()) return {};
    return {
      for (var f in dir.listSync().whereType<File>())
        f.path.split('/').last: f.lastModifiedSync().millisecondsSinceEpoch
    };
  }

  bool _addNewFiles(Map<String, int> oldFiles) {
    bool added = false;
    final dir = Directory('/storage/emulated/0/Documents/COLA_FILE');
    if (dir.existsSync()) {
      final files = dir.listSync();
      for (var f in files) {
        if (f is File) {
          final fileName = f.path.split('/').last;
          final oldTime = oldFiles[fileName];
          final newTime = f.lastModifiedSync().millisecondsSinceEpoch;
          
          if (oldTime == null || newTime > oldTime) {
            final nameLowerCase = fileName.toLowerCase();
            if (nameLowerCase.endsWith('.zip')) {
              if (nameLowerCase.startsWith('cola_file')) {
                _colaFiles.removeWhere((e) => e.name == fileName);
                setState(() {
                  _colaFiles.add(AttachedFile(originalPath: f.path, name: fileName, sizeBytes: f.lengthSync(), type: AttachType.cola));
                });
                added = true;
              } else if (nameLowerCase.startsWith('log_')) {
                _logFiles.removeWhere((e) => e.name == fileName);
                setState(() {
                  _logFiles.add(AttachedFile(originalPath: f.path, name: fileName, sizeBytes: f.lengthSync(), type: AttachType.log));
                });
                added = true;
              }
            }
          }
        }
      }
    }
    return added;
  }

  Future<void> _showWatchSyncWizard() async {
    await _checkHotspotStatus();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          _wizardSetState = setModalState;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rocket_launch, color: Colors.white),
                    const SizedBox(width: 10),
                    const Text('워치 자동 동기화', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () async {
                        final Uri url = Uri.parse('https://huijong.github.io/Health_UT_INFO/');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.orangeAccent, size: 14),
                            SizedBox(width: 4),
                            Text('가이드 다시 보기', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                    )
                  ],
                ),
                const Divider(color: Colors.white12, height: 30),
                
                // Step 1 GlassCard
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          const Text('핫스팟 설정 (워치 연결용)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('데이터 무료 🛡️', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_prefs?.hideP2pBanner != true) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1429A0).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF3366FF).withOpacity(0.5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Text(
                                  '💡 안심하세요! 워치와 스마트폰을 P2P(직접 연결) 방식으로 연결하므로, 모바일 데이터소모되거나 요금이 절대 발생하지 않습니다.',
                                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await _prefs?.saveHideP2pBanner(true);
                                  if (_wizardSetState != null) _wizardSetState!(() {});
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.close, color: Colors.redAccent, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Status Area
                      const Text('핫스팟 설정 상태', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _isHotspotOn ? const Color(0xFF3366FF).withOpacity(0.1) : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _isHotspotOn ? const Color(0xFF3366FF).withOpacity(0.5) : Colors.white12),
                        ),
                        child: Row(
                          children: [
                            if (_isHotspotOn)
                              const Icon(Icons.check_circle, color: Colors.lightBlueAccent, size: 20)
                            else
                              const Icon(Icons.wifi_off, color: Colors.white54, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isHotspotOn ? '핫스팟 켜져 있음!' : '핫스팟 꺼져 있음!',
                                style: TextStyle(
                                  color: _isHotspotOn ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.15),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                minimumSize: const Size(60, 32),
                              ),
                              onPressed: _openHotspotSettings,
                              icon: const Icon(Icons.settings, color: Colors.white, size: 14),
                              label: const Text('핫스팟 설정 열기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      
                      // Input Area Group (Collapsible)
                      GestureDetector(
                        onTap: () {
                          if (_wizardSetState != null) {
                            _wizardSetState!(() { _isNetworkExpanded = !_isNetworkExpanded; });
                          } else {
                            setState(() { _isNetworkExpanded = !_isNetworkExpanded; });
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('네트워크 정보', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                Text(_isNetworkExpanded ? '접기' : '클릭하여 펼치기', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                                const SizedBox(width: 4),
                                Icon(_isNetworkExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white30, size: 16),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_isNetworkExpanded) ...[
                        const SizedBox(height: 12),
                        AnimatedBuilder(
                          animation: _emptyFieldPulseController!,
                          builder: (context, child) {
                            final blinkColor = const Color(0xFF3366FF).withOpacity(0.1 + 0.9 * _emptyFieldPulseController!.value);
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4, bottom: 4),
                                        child: Text('네트워크 이름 (SSID)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                      ),
                                      TextFormField(
                                        controller: _ssidCtrl,
                                        focusNode: _ssidFocusNode,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: '본인의 핫스팟 ID 입력',
                                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.04),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: _ssidCtrl.text.isEmpty
                                                ? BorderSide(color: blinkColor, width: 3.0)
                                                : BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF3366FF), width: 1.5),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          if (_wizardSetState != null) _wizardSetState!((){});
                                          _hotspotSsid = val;
                                          _saveHotspotConfig('hotspot_ssid', val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4, bottom: 4),
                                        child: Text('비밀번호', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                      ),
                                      TextFormField(
                                        controller: _pwdCtrl,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: '본인의 비밀번호 입력',
                                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.04),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: _pwdCtrl.text.isEmpty
                                                ? BorderSide(color: blinkColor, width: 3.0)
                                                : BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF3366FF), width: 1.5),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          if (_wizardSetState != null) _wizardSetState!((){});
                                          _hotspotPwd = val;
                                          _saveHotspotConfig('hotspot_pwd', val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                const Center(child: BouncingArrow()),
                const SizedBox(height: 16),

                // Step 2 GlassCard
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      radius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              const Text('워치 연결 시작', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3366FF),
                                disabledBackgroundColor: Colors.white12,
                                disabledForegroundColor: Colors.white38,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: (!_isHotspotOn || _ssidCtrl.text.trim().isEmpty || _pwdCtrl.text.trim().isEmpty) ? null : () async {
                                final oldFiles = _getSnapshotFiles();
                                Navigator.pop(ctx);
                                await Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => LabWatchSyncScreen(
                                    autoStart: true,
                                    initialSyncMode: 'HOTSPOT',
                                    hotspotSsid: _hotspotSsid ?? 'healthport',
                                    hotspotPwd: _hotspotPwd ?? '12345678',
                                  ),
                                ));
                                if (_addNewFiles(oldFiles)) {
                                  _watchLogsAddedToZip = true;
                                }
                              },
                              child: const Text('워치와 연결 시작', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isHotspotOn || _ssidCtrl.text.trim().isEmpty || _pwdCtrl.text.trim().isEmpty)
                      Positioned(
                        right: 16,
                        bottom: 56,
                        child: BouncingTooltip(
                          text: !_isHotspotOn ? '💡 먼저 핫스팟을 켜주세요' : '💡 ID와 비밀번호를 입력해주세요',
                          buttonText: !_isHotspotOn ? '핫스팟 켜기' : '입력하기',
                          onTap: () {
                            if (!_isHotspotOn) {
                              _openHotspotSettings(skipGuidePopup: true);
                            } else {
                              _ssidFocusNode.requestFocus();
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    ).then((_) => _wizardSetState = null);
  }

  Widget _buildStep5Details() {
    final bool hasFiles = _fitFiles.isNotEmpty || _garminFiles.isNotEmpty || _colaFiles.isNotEmpty || _logFiles.isNotEmpty || _captureFiles.isNotEmpty;

    return Form(
      key: _formKey5,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TabBar
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white12, width: 1.5),
              ),
            ),
            child: TabBar(
              controller: _deviceTabController,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Color(0xFF3366FF), width: 3.0),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              unselectedLabelColor: Colors.white54,
              unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              tabs: const [
                Tab(text: 'Watch', height: 44),
                Tab(text: 'Band', height: 44),
              ],
            ),
          ),
          
          // --- SECTION 1: 자사 운동 데이터 ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF3366FF).withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 4, 
                  height: 18, 
                  decoration: BoxDecoration(color: const Color(0xFF3366FF), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 10),
                const Text('섹션 1: 자사 운동 데이터', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildAttachCard(icon: Icons.watch, title: '1. 자사 FIT 파일', hint: '(비어 있음) 터치하여 수동 선택', busy: _fileBusy, onTap: _pickFit, files: _fitFiles),
          const SizedBox(height: 12),
          
          if (_deviceTabController.index == 0) ...[
            // 2. 워치 COLA / Log 파일 동기화
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: () {
                  _handleWatchSyncClick();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(color: const Color(0xFF3366FF).withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.cloud_sync, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('2. 워치 COLA / Log 파일 동기화', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orangeAccent),
                                  ),
                                  child: const Text('TBD', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('터치 한 번으로 워치의 파일(COLA/Log) 자동 추가', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -12,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: const Text('Cola Manager 없이 자동 동기화 🚀', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAttachCard(icon: Icons.bar_chart, title: '3. COLA 파일', hint: '(비어 있음) 터치하여 수동 선택', busy: _fileBusy, onTap: _pickCola, files: _colaFiles),
          const SizedBox(height: 12),
          _buildAttachCard(icon: Icons.article_outlined, title: '4. Log 파일', hint: '(비어 있음) 터치하여 수동 선택', busy: _fileBusy, onTap: _pickLog, files: _logFiles),
          const SizedBox(height: 12),
          _buildCaptureAttachCard(title: '5. 캡처 이미지'), // 5. 캡처 이미지
          ] else ...[
            _buildAttachCard(
              icon: Icons.article_outlined, 
              title: '2. Log(Sensorlog 포함) 파일', 
              hint: '(비어 있음) 터치하여 수동 선택', 
              busy: _fileBusy, 
              onTap: () => _pickLog(initialDirectory: '/sdcard/Download/log/GearLog/'), 
              files: _logFiles
            ),
            const SizedBox(height: 12),
            _buildCaptureAttachCard(title: '3. 캡처 이미지'),
          ],
          const SizedBox(height: 30),
          
          // --- SECTION 2: 타사 운동 데이터 ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFB8860B).withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 4, 
                  height: 18, 
                  decoration: BoxDecoration(color: const Color(0xFFB8860B), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 10),
                const Text('섹션 2: 타사 운동 데이터', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildAttachCard(
            icon: Icons.file_copy, 
            title: _deviceTabController.index == 0 ? '6. Garmin Fit 파일' : '4. Garmin Fit 파일', 
            hint: 'Download 폴더 자동 스캔됨', 
            busy: _fileBusy, 
            onTap: _pickGarminFit, 
            files: _garminFiles
          ),
          const SizedBox(height: 30),

          // --- SECTION 3: 운동 종합 데이터 및 특이사항 ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 4, 
                  height: 18, 
                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 10),
                const Text('섹션 3: 운동 종합 데이터 입력', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 그룹 A: 착용 상태 및 디바이스 환경
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('착용 상태', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('착용 위치', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
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
                    const Text('착용 정도', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
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
                const Divider(height: 32, color: Colors.white10),
                const Text('동시 착용 타사 모델', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _competitorWatch,
                  dropdownColor: const Color(0xFF1E1E2C),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.compare_arrows_rounded, size: 20, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  items: ['가민', '애플', '크로스', '없음', '직접입력']
                      .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _competitorWatch = val);
                      _saveSportDetails();
                    }
                  },
                ),
                if (_competitorWatch == '직접입력') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customCompetitorCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: '타사 기기 직접 입력 *',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 그룹 B: 운동 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('운동 정보', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                const Text('운동 거리', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _distanceCtrl,
                  focusNode: _distanceFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.linear_scale_rounded, size: 20, color: Colors.white54),
                    hintText: '예) 21.09',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    suffixText: 'km',
                    suffixStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const Divider(height: 32, color: Colors.white10),
                const Text('운동 종류', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _trainingType,
                  dropdownColor: const Color(0xFF1E1E2C),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.sports_score_rounded, size: 20, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  items: ['조깅', '인터벌', 'LSD', '변속주', '지속주', '직접입력']
                      .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _trainingType = val);
                      _saveSportDetails();
                    }
                  },
                ),
                if (_trainingType == '직접입력') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customTrainingCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: '운동 종류 직접 입력 *',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
                const Divider(height: 32, color: Colors.white10),
                const Text('운동 장소', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '예: 금오산 X코스, 헬스장 등 직접 입력',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.place_outlined, size: 20, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                if (_prefs != null && _prefs!.getRecentLocations().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    '최근 사용한 장소 (탭하여 자동 입력)',
                    style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _prefs!.getRecentLocations().map((loc) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _locationCtrl.text = loc;
                          });
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                loc,
                                style: const TextStyle(color: Color(0xFF3366FF), fontSize: 11),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () async {
                                  await _prefs!.removeRecentLocation(loc);
                                  setState(() {});
                                },
                                child: const Icon(Icons.close, size: 13, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildPrecisionVerificationSection(),
          const SizedBox(height: 16),

          // 특이 사항 TextArea
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('특이 사항 및 메모', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _memoCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '특이 사항이 있다면 적어주세요. (착용감 흔들림, 센서 오작동 등)',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          Text('첨부 내역', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: const Color(0xFF3366FF).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // FIT Files
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 80, child: Text('[자사 FIT]', style: TextStyle(color: Color(0xFF3366FF), fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(
                        child: _fitFiles.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _fitFiles.map((f) => Text(f.name, style: const TextStyle(color: Colors.white70, fontSize: 12))).toList(),
                              )
                            : const Text('첨부 안됨', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // Garmin Files
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 80, child: Text('[Garmin FIT]', style: TextStyle(color: Color(0xFF3366FF), fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(
                        child: _garminFiles.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _garminFiles.map((f) => Text(f.name, style: const TextStyle(color: Colors.white70, fontSize: 12))).toList(),
                              )
                            : const Text('첨부 안됨', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // COLA Files
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 80, child: Text('[COLA]', style: TextStyle(color: Color(0xFF3366FF), fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(
                        child: _colaFiles.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _colaFiles.map((f) => Text(f.name, style: const TextStyle(color: Colors.white70, fontSize: 12))).toList(),
                              )
                            : const Text('첨부 안됨', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // Log Files
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 80, child: Text('[Log]', style: TextStyle(color: Color(0xFF3366FF), fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(
                        child: _logFiles.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _logFiles.map((f) => Text(f.name, style: const TextStyle(color: Colors.white70, fontSize: 12))).toList(),
                              )
                            : const Text('첨부 안됨', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // Capture Files
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 80, child: Text('[Capture]', style: TextStyle(color: Color(0xFF3366FF), fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(
                        child: _captureFiles.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _captureFiles.map((f) => Text(f.name, style: const TextStyle(color: Colors.white70, fontSize: 12))).toList(),
                              )
                            : const Text('첨부 안됨', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildPrecisionVerificationSection() {
    final hideGpsAltitude = (_selectedExercise == '러닝머신 걷기' ||
        _selectedExercise == '러닝머신 달리기' ||
        _selectedExercise == '실내 수영' ||
        _selectedExercise == '야외 수영' ||
        _selectedExercise == '근력 운동');

    return GlassCard(
      key: _precisionCardKey,
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('센서/데이터 이슈 메모', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (!hideGpsAltitude) ...[
            _buildVerificationRow(
              'GPS',
              _gpsStatus,
              (val) => setState(() {
                _gpsStatus = val;
                _saveSportDetails();
              }),
              _gpsMemoCtrl,
              'GPS 궤적 튐, 신호 이탈, 끊김 현상 등의 내용을 적어주세요.',
            ),
            const Divider(height: 24, color: Colors.white10),
          ],
          _buildVerificationRow(
            'HR',
            _hrStatus,
            (val) => setState(() {
              _hrStatus = val;
              _saveSportDetails();
            }),
            _hrMemoCtrl,
            '심박수 튀는 현상, 고정 현상, 측정 끊김 등의 내용을 적어주세요.',
          ),
          const Divider(height: 24, color: Colors.white10),
          _buildVerificationRow(
            '속도/페이스',
            _paceStatus,
            (val) => setState(() {
              _paceStatus = val;
              _saveSportDetails();
            }),
            _paceMemoCtrl,
            '실제 속도와 앱에 표기된 페이스 간의 편차 등을 적어주세요.',
          ),
          if (!hideGpsAltitude) ...[
            const Divider(height: 24, color: Colors.white10),
            _buildVerificationRow(
              '고도',
              _altitudeStatus,
              (val) => setState(() {
                _altitudeStatus = val;
                _saveSportDetails();
              }),
              _altitudeMemoCtrl,
              '고도 데이터 누락이나 고도 수치 변화 이상 등의 내용을 적어주세요.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationRow(
    String label,
    String currentStatus,
    ValueChanged<String> onChanged,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildVerifTab('정상', currentStatus == '정상', const Color(0xFF3366FF), () => onChanged('정상')),
                  _buildVerifTab('확인 필요', currentStatus == '확인 필요', const Color(0xFFFFAE2E), () => onChanged('확인 필요')),
                ],
              ),
            ),
          ],
        ),
        if (currentStatus == '확인 필요') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '$label 상세 메모 *',
              hintText: hint,
              labelStyle: const TextStyle(color: Color(0xFFFFAE2E)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFAE2E), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVerifTab(String text, bool active, Color activeColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
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

  Widget _buildSwitchTab(String text, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() => _wearingPosition = text);
        _saveSportDetails();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3366FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
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
      onTap: () {
        setState(() => _wearingTightness = text);
        _saveSportDetails();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3366FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(hint, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      ],
                    ),
                  ),
                  if (busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  else
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white54),
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
        ),
      ),
    );
  }

  Widget _buildCaptureAttachCard({String title = '5. 캡처 이미지'}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _fileBusy ? null : _pickCaptures,
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('갤러리 다중 이미지 첨부 가능', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      ],
                    ),
                  ),
                  if (_fileBusy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  else
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white54),
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
        ),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3366FF)),
                )
              else if (_step6State == 'success')
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3366FF).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFF3366FF), width: 3),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded, color: Colors.white,
                    size: 52,
                  ),
                )
              else
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3366FF).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFF3366FF), width: 3),
                  ),
                  child: const Icon(
                    Icons.link_rounded, color: Colors.white,
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
                    Icon(Icons.inventory_2_outlined, color: Colors.white, size: 18),
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
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF3366FF)),
                      label: const Text('메일 다시 보내기', style: TextStyle(fontSize: 12, color: Color(0xFF3366FF))),
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
              backgroundColor: const Color(0xFF3366FF),
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
              backgroundColor: const Color(0xFF3366FF),
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
      color = const Color(0xFF3366FF);
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
                  if (_selectedExercise != '근력 운동') {
                    final distText = _distanceCtrl.text.trim();
                    final parsedDist = double.tryParse(distText) ?? 0.0;
                    if (distText.isEmpty || parsedDist <= 0) {
                      ToastUtil.showToast(context, '운동 거리를 입력해 주세요 (0보다 커야 합니다)');
                      _distanceFocusNode.requestFocus();
                      return;
                    }
                  }
                  _onSend();
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
                            final bool? reuse = await _showNicknameProfileDialog(nickname);
                            if (reuse != true) return;
                            
                            final String savedWatch = res['watch'] ?? '미지정';
                            final String savedStrap = res['strap'] ?? '미지정';
                            
                            String cleanWatch = savedWatch.trim();
                            bool isWatchInList = kWatchOptions.any((opt) => opt.trim() == cleanWatch);
                            if (!isWatchInList && cleanWatch != '미지정' && cleanWatch.isNotEmpty) {
                              _prefs?.saveWatch('직접입력');
                              _prefs?.saveCustomWatch(cleanWatch);
                              _selectedWatch = '직접입력';
                              _customWatchCtrl.text = cleanWatch;
                            } else {
                              _prefs?.saveWatch(cleanWatch);
                              _selectedWatch = cleanWatch;
                            }

                            String cleanStrap = savedStrap.trim();
                            bool isStrapInList = kStrapOptions.any((opt) => opt['name']?.trim() == cleanStrap);
                            if (!isStrapInList && cleanStrap != '미지정' && cleanStrap.isNotEmpty) {
                              _prefs?.saveStrap('직접입력');
                              _prefs?.saveCustomStrap(cleanStrap);
                              _selectedStrap = '직접입력';
                              _customStrapCtrl.text = cleanStrap;
                            } else {
                              _prefs?.saveStrap(cleanStrap);
                              _selectedStrap = cleanStrap;
                            }
                            
                            _prefs?.saveOnboardingComplete(true);
                            setState(() {
                              _currentStep = 4;
                            });
                          } else {
                            return;
                          }
                        }
                      }
                    } catch (e) {
                      debugPrint('닉네임 중복 검사 실패: $e');
                    }

                    final newEmail = _emailCtrl.text.trim();
                    if (_prefs != null && _prefs!.googleEmail != newEmail) {
                      _prefs!.saveConsentGiven(false);
                      _prefs!.saveConsentDate('');
                    }
                    
                    _prefs?.saveName(nickname);
                    _prefs?.saveGoogleEmail(newEmail);
                    _updateNotificationTopic(nickname);
                    _sendDevicePing(); // Bind UUID immediately
                    _prefs?.saveHeight(double.tryParse(_heightCtrl.text) ?? 0.0);
                    _prefs?.saveWeight(double.tryParse(_weightCtrl.text) ?? 0.0);
                    
                    if (_currentStep == 4) return;
                    await _verifyConsentAndProceed();
                    return;
                  } else if (_currentStep == 2) {
                    if (_selectedWatch == '직접입력' && _customWatchCtrl.text.trim().isEmpty) {
                      ToastUtil.showToast(context, '워치 기종명을 입력해 주세요');
                      return;
                    }
                    _prefs?.saveWatch(_selectedWatch);
                    _prefs?.saveCustomWatch(_customWatchCtrl.text.trim());
                  } else if (_currentStep == 3) {
                    if (_selectedStrap == '직접입력' && _customStrapCtrl.text.trim().isEmpty) {
                      ToastUtil.showToast(context, '스트랩 종류를 입력해 주세요');
                      return;
                    }
                    _prefs?.saveStrap(_selectedStrap);
                    _prefs?.saveCustomStrap(_customStrapCtrl.text.trim());
                    _prefs?.saveOnboardingComplete(true);
                    _prefs?.saveEmailMigrationDone(true);
                  }
                  setState(() => _currentStep++);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3366FF),
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

  
  Future<void> _verifyConsentAndProceed() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    
    bool serverHasAgreed = false;
    try {
      final emailUrl = Uri.parse('${AppConfig.apiUrl}/api/devices?check_email=${Uri.encodeComponent(email)}');
      final emailResponse = await http.get(emailUrl);
      if (emailResponse.statusCode == 200) {
        final emailRes = jsonDecode(emailResponse.body);
        if (emailRes['status'] == 'success' && emailRes['has_agreed'] == true) {
          serverHasAgreed = true;
        }
      }
    } catch (e) {
      debugPrint('[Consent Check Error] $e');
    }

    if (serverHasAgreed || (_prefs != null && _prefs!.consentGiven)) {
      if (_prefs != null) {
        final nowStr = DateTime.now().toString().substring(0, 19);
        await _prefs!.saveConsentGiven(true);
        if (_prefs!.consentDate.isEmpty) {
          await _prefs!.saveConsentDate(nowStr);
        }
      }
      setState(() => _currentStep = 2);
    } else {
      await _showConsentDialog();
    }
  }

    Future<void> _showConsentDialog() async {
    bool localAgreePersonal = false;
    bool localAgreeLocation = false;
    final ScrollController scrollController = ScrollController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.90,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2640),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Center(
                    child: Icon(Icons.security_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'HealthPort 서비스 동의',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      '서비스 이용을 위해 아래 동의가 필요합니다.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. 개인정보 & 민감정보 동의서
                          const Text(
                            '개인정보 및 민감정보 수집·이용 동의 (필수)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 150,
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
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
                                style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
                              ),
                            ),
                          ),
                          CheckboxListTile(
                            title: const Text('위 개인정보 및 민감정보 수집·이용에 동의합니다.', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            value: localAgreePersonal,
                            activeColor: const Color(0xFF3366FF),
                            checkColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) {
                              setModalState(() => localAgreePersonal = val ?? false);
                              if (val == true) {
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  if (scrollController.hasClients) {
                                    scrollController.animateTo(
                                      scrollController.position.maxScrollExtent,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                
                          // 2. 개인정보 처리방침 동의서
                          const Text(
                            '개인정보 처리방침 (필수)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 150,
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
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
                                style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
                              ),
                            ),
                          ),
                          CheckboxListTile(
                            title: const Text('위 개인정보 처리방침에 동의합니다.', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            value: localAgreeLocation,
                            activeColor: const Color(0xFF3366FF),
                            checkColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) {
                              setModalState(() => localAgreeLocation = val ?? false);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: (localAgreePersonal && localAgreeLocation)
                        ? () async {
                            if (_prefs == null) return;
                            final nowStr = DateTime.now().toString().substring(0, 19);
                            await _prefs!.saveConsentGiven(true);
                            await _prefs!.saveConsentDate(nowStr);
                            Navigator.pop(ctx);
                            setState(() {
                              _currentStep = 2;
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3366FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withOpacity(0.12),
                      disabledForegroundColor: Colors.white38,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      '동의하고 다음 단계로',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
                ],
              ),
            );
          },
        );
      },
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
      selectedItemColor: const Color(0xFFFFD043),
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

  Future<void> _showNicknameFinderBottomSheet() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3366FF),
        ),
      ),
    );

    List<String> nicknames = [];
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/api/devices'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == 'success') {
          final List<dynamic> devices = decoded['data'] ?? [];
          nicknames = devices
              .map((d) => (d['tester_name'] as String?)?.trim() ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();
          nicknames.sort();
        }
      }
    } catch (e) {
      debugPrint('[Nickname Finder] Error fetching nicknames: $e');
    }

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (nicknames.isEmpty) {
      ToastUtil.showToast(context, '등록된 닉네임이 없거나 서버 연결에 실패했습니다.');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      isScrollControlled: true,
      builder: (context) {
        return _NicknameFinderSheetContent(
          nicknames: nicknames,
          onSelect: (selectedName) {
            setState(() {
              _nameCtrl.text = selectedName;
            });
          },
        );
      },
    );
  }

  void _showWatchLogCleanupSnackBar() {
    ToastUtil.showToast(context, '동기화가 완료되어 기존 로그는 필요가 없습니다.');
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
      borderRadius: BorderRadius.circular(radius ?? 28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(radius ?? 28),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
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
                      Icon(Icons.ondemand_video_rounded, color: Colors.white, size: 20),
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
                                backgroundColor: const Color(0xFF3366FF),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3366FF)),
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
                                      : Icons.play_arrow_rounded, color: Colors.white,
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
                  playedColor: Color(0xFF3366FF),
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

class _NicknameFinderSheetContent extends StatefulWidget {
  final List<String> nicknames;
  final ValueChanged<String> onSelect;

  const _NicknameFinderSheetContent({
    required this.nicknames,
    required this.onSelect,
  });

  @override
  State<_NicknameFinderSheetContent> createState() => _NicknameFinderSheetContentState();
}

class _NicknameFinderSheetContentState extends State<_NicknameFinderSheetContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _filteredNames = [];

  @override
  void initState() {
    super.initState();
    _filteredNames = widget.nicknames;
  }

  void _filterList(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredNames = widget.nicknames;
      } else {
        _filteredNames = widget.nicknames
            .where((name) => name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2020),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '등록된 닉네임 찾기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            onChanged: _filterList,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '닉네임 검색...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white60),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '목록에서 본인의 닉네임을 선택하면 자동으로 입력됩니다.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filteredNames.isEmpty
                ? const Center(
                    child: Text(
                      '일치하는 닉네임이 없습니다.',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredNames.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.white.withOpacity(0.06),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final name = _filteredNames[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                        onTap: () {
                          widget.onSelect(name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class BouncingArrow extends StatefulWidget {
  const BouncingArrow({super.key});

  @override
  State<BouncingArrow> createState() => _BouncingArrowState();
}

class _BouncingArrowState extends State<BouncingArrow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 10).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: const Icon(Icons.keyboard_double_arrow_down, color: Colors.white38, size: 30),
    );
  }
}

class BouncingTooltip extends StatefulWidget {
  final VoidCallback onTap;
  final String text;
  final String buttonText;
  const BouncingTooltip({super.key, required this.onTap, required this.text, required this.buttonText});

  @override
  State<BouncingTooltip> createState() => _BouncingTooltipState();
}

class _BouncingTooltipState extends State<BouncingTooltip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 6).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2640),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF3366FF).withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3366FF).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3366FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(widget.buttonText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class BouncingEmojiWidget extends StatefulWidget {
  final String emoji;
  const BouncingEmojiWidget({Key? key, required this.emoji}) : super(key: key);

  @override
  State<BouncingEmojiWidget> createState() => _BouncingEmojiWidgetState();
}

class _BouncingEmojiWidgetState extends State<BouncingEmojiWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: -15.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutQuad,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: Text(
        widget.emoji,
        style: const TextStyle(fontSize: 48),
      ),
    );
  }
}

class BouncingWidget extends StatefulWidget {
  final Widget child;
  const BouncingWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: -6.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
