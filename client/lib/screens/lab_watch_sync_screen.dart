import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:client/services/prefs_service.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LabWatchSyncScreen extends StatefulWidget {
  final bool autoStart;
  final String? hotspotSsid;
  final String? hotspotPwd;
  final String initialSyncMode;
  const LabWatchSyncScreen({super.key, this.autoStart = false, this.initialSyncMode = 'AP', this.hotspotSsid, this.hotspotPwd});

  @override
  State<LabWatchSyncScreen> createState() => _LabWatchSyncScreenState();
}

class _LabWatchSyncScreenState extends State<LabWatchSyncScreen> with TickerProviderStateMixin {
  static const _wifiP2pChannel = MethodChannel("com.samsung.health.client/wifi_p2p");
  static const _wifiP2pEventChannel = EventChannel("com.samsung.health.client/wifi_p2p_events");
  static const _appChannel = MethodChannel("com.samsung.health.client/app_info");

  bool _isSearching = false;
  String? _connectedEndpointId;
  String? _connectedEndpointName;

  // 'BT' (블루투스), 'AP' (공용 Wi-Fi), 'HOTSPOT' (모바일 핫스팟)
  String _syncMode = 'AP'; 

  // List of files fetched from watch
  int _autoSyncStage = 0; // 0: 대기, 1: 연결 중, 2: COLA 수신 중, 3: Log 수신 중, 4: 압축 최적화, 5: 완료
  double _syncProgress = 0.0;
  int? _syncStartTimeMs;
  int _syncTransferredBytes = 0;
  int _syncTotalBytes = 0;
  String? _targetColaFilename;
  String? _targetLogFilename;

  bool _isWatchAppInstalled = true; // Default to true

  // Animation controller for radar pulsing effect
  AnimationController? _radarController;
  AnimationController? _spinController;
  StreamSubscription? _wifiP2pSubscription;

  final List<String> _logs = [];

  void _addLog(String msg) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.add("[$time] $msg");
    });
    debugPrint("[SyncDebug] $msg");
  }

  void _showDebugLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("실시간 연동 디버그 로그", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: _logs.isEmpty
              ? const Center(child: Text("기록된 로그가 없습니다.", style: TextStyle(color: Colors.white30)))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, idx) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(_logs[idx], style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("닫기", style: TextStyle(color: Color(0xFF3366FF))),
          )
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncMode = widget.initialSyncMode;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showGuidePopupIfNeeded();
      if (widget.autoStart) {
        _startDiscovery();
      }
    });
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _checkPermissions();
    _checkWatchAppInstalled();
    _setupWifiP2pEventSubscription();
  }

  Future<void> _showGuidePopupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool dontShowAgain = prefs.getBool('hide_watch_sync_guide') ?? false;

    if (!dontShowAgain) {
      bool localDontShow = false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                title: const Text('워치 연결 가이드(최초 1회 발생)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('스마트폰에서 연결을 시작하면, 워치 화면에 아래와 같은 팝업이 뜹니다.\n워치에서 스크롤을 내려 반드시 [확인]을 눌러주세요!', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: Image.asset('assert/Check_1.png', height: 180, fit: BoxFit.contain)),
                        const Icon(Icons.arrow_forward, color: Colors.white54, size: 24),
                        Expanded(child: Image.asset('assert/Check_2.png', height: 180, fit: BoxFit.contain)),
                      ],
                    ),
                  ],
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: localDontShow,
                              activeColor: const Color(0xFF3366FF),
                              checkColor: Colors.black,
                              onChanged: (val) {
                                setDialogState(() {
                                  localDontShow = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('다시 보지 않기', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3366FF),
                        ),
                        onPressed: () {
                          if (localDontShow) {
                            prefs.setBool('hide_watch_sync_guide', true);
                          }
                          Navigator.pop(dialogCtx);
                        },
                        child: const Text('연결 시작', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              );
            }
          );
        }
      );
    }
  }

  @override
  void dispose() {
    _radarController?.dispose();
    _spinController?.dispose();
    _wifiP2pSubscription?.cancel();
    _wifiP2pChannel.invokeMethod("stopServer");
    super.dispose();
  }

  void _setupWifiP2pEventSubscription() {
    _wifiP2pSubscription = _wifiP2pEventChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event);
      final type = map['type'] as String;
      final data = map['data'];
      _handleWifiP2pEvent(type, data);
    }, onError: (err) {
      _addLog("Event Stream Error: $err");
    });
  }

  void _handleWifiP2pEvent(String type, dynamic data) {
    switch (type) {
      case "connectionStateChanged":
        final connected = data["connected"] as bool;
        if (connected) {
          final deviceName = data["deviceName"] as String? ?? "Smartwatch";
          _addLog("Wi-Fi connected with $deviceName.");
          setState(() {
            _connectedEndpointId = "wifi_p2p_watch";
            _connectedEndpointName = deviceName;
            _isSearching = false;
          });
          _radarController?.stop();
          _sendFileListRequest();
        } else {
          _addLog("Wi-Fi disconnected.");
          setState(() {
            _connectedEndpointId = null;
            _connectedEndpointName = null;
            _autoSyncStage = 0;
          });
        }
        break;

      case "hotspotStarted":
        final ssid = data["ssid"] as String? ?? "healthport";
        final pw   = data["password"] as String? ?? "00000000";
        _addLog("Direct Hotspot Started: SSID=$ssid, PW=$pw");
        break;

      case "fileListReceived":
        final jsonStr = data as String;
        _addLog("Received file list JSON.");
        try {
          final decoded = jsonDecode(jsonStr) as List<dynamic>;
          final fileNames = decoded.map((e) => e['name'] as String).toList();
          fileNames.sort();
          
          setState(() {
            _targetColaFilename = fileNames.where((n) => n.startsWith("COLA_FILE_")).lastOrNull;
            _targetLogFilename = fileNames.where((n) => n.startsWith("log_")).lastOrNull;
          });
          _startNextAutoSyncPhase();
        } catch (e) {
          _addLog("JSON Parse error: $e");
          setState(() => _autoSyncStage = 0);
        }
        break;

      case "compressing":
        _addLog("워치에서 데이터 패키징 중...");
        break;

      case "downloadProgress":
        final progressMap = Map<String, dynamic>.from(data);
        final progress = progressMap["progress"] as double;
        final transferred = progressMap["transferred"] as int?;
        final total = progressMap["total"] as int?;
        
        setState(() {
          _syncProgress = progress;
          if (transferred != null) _syncTransferredBytes = transferred;
          if (total != null) _syncTotalBytes = total;
          _syncStartTimeMs ??= DateTime.now().millisecondsSinceEpoch;
        });
        break;

      case "downloadComplete":
        final completeMap = Map<String, dynamic>.from(data);
        final filename = completeMap["filename"] as String;
        final tempPath = completeMap["path"] as String;
        _addLog("Download finished for $filename.");
        _moveToColaFolder(filename, tempPath).then((_) {
          _startNextAutoSyncPhase();
        });
        break;

      case "downloadFailure":
        final failMap = Map<String, dynamic>.from(data);
        final error = failMap["error"] as String? ?? "Unknown error";
        _addLog("Download failed: $error");
        setState(() => _autoSyncStage = 0);
        break;

      case "error":
        _addLog("Native Error: $data");
        break;
    }
  }

  void _showHotspotInfoDialog(String ssid, String password) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.wifi_tethering, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text("직접 연결 Wi-Fi 정보", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "외부 Wi-Fi 없이 연결하려면\n워치 Wi-Fi 설정에서 아래 네트워크에 연결하세요.",
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _hotspotInfoRow("SSID", ssid),
            const SizedBox(height: 8),
            _hotspotInfoRow("비밀번호", password),
            const SizedBox(height: 12),
            const Text(
              "※ 최초 1회만 연결하면 이후 자동 연결됩니다.",
              style: TextStyle(color: Color(0xFF3366FF), fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              const channel = MethodChannel('com.samsung.health.client/app_info');
              try {
                await channel.invokeMethod('openHotspotSettings');
              } catch (e) {
                debugPrint('Failed to open hotspot settings: $e');
              }
            },
            child: const Text("핫스팟 설정 켜기", style: TextStyle(color: Color(0xFF3366FF), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("닫기", style: TextStyle(color: Color(0xFF3366FF))),
          ),
        ],
      ),
    );
  }

  Widget _hotspotInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3366FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text("$label  ", style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Expanded(
            child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkWatchAppInstalled() async {
    try {
      final bool installed = await _appChannel.invokeMethod("checkWatchAppInstalled");
      setState(() {
        _isWatchAppInstalled = installed;
      });
    } catch (e) {
      debugPrint("Capability check failed: $e");
    }
  }

  Future<void> _remoteInstallWatchApp() async {
    try {
      await _appChannel.invokeMethod("launchWatchPlayStore");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("워치 플레이 스토어로 설치 명령을 전송했습니다.")),
      );
    } catch (e) {
      debugPrint("Remote install failed: $e");
    }
  }

  void _checkPermissions() async {
    try {
      // Calls native Android requestPermissions which requests ACCESS_FINE_LOCATION,
      // ACCESS_COARSE_LOCATION, and NEARBY_WIFI_DEVICES all in one unified dialog.
      await _appChannel.invokeMethod("requestNearbyPermissions");
    } catch (e) {
      debugPrint("Nearby permissions check failed: $e");
    }
  }

  void _startDiscovery() async {
    setState(() {
      _isSearching = true;
    });
    _radarController?.repeat();

    _addLog("Starting synchronization server in mode: $_syncMode...");
    try {
      await _wifiP2pChannel.invokeMethod("startServer", {"mode": _syncMode});
      
      // Request watch to join the custom hotspot
      if (widget.hotspotSsid != null && widget.hotspotPwd != null) {
        _addLog("Waiting for WearOS Data Layer to initialize...");
        await Future.delayed(const Duration(milliseconds: 1500));
        
        _addLog("Sending Wi-Fi Join Request to watch for SSID: ${widget.hotspotSsid}...");
        await _appChannel.invokeMethod("requestWatchWifiJoin", {
          "ssid": widget.hotspotSsid,
          "pwd": widget.hotspotPwd,
        });
      }
      
      if (_syncMode == 'BT') {
        _addLog("Bluetooth mode ready. Waiting for Wear OS communication...");
      } else if (_syncMode == 'HOTSPOT') {
        _addLog("Hotspot Server started. Connect watch to '${widget.hotspotSsid}' and wait...");
      } else {
        _addLog("AP Server started. Connect both to same Wi-Fi and wait...");
      }
    } catch (e) {
      _addLog("Start Server Error: $e");
      setState(() {
        _isSearching = false;
      });
      _radarController?.stop();
    }
  }

  void _sendFileListRequest() async {
    if (_connectedEndpointId == null) return;
    setState(() {
      _autoSyncStage = 1;
    });
    _addLog("Requesting file list from Watch...");
    try {
      await _wifiP2pChannel.invokeMethod("requestFileList");
    } catch (e) {
      _addLog("Failed to request file list: $e");
      setState(() {
        _autoSyncStage = 0;
      });
    }
  }

  Future<void> _moveToColaFolder(String filename, String tempPath) async {
    try {
      final targetFolder = Directory("/sdcard/Documents/COLA_FILE/");
      if (!await targetFolder.exists()) await targetFolder.create(recursive: true);
      
      final targetFile = File("${targetFolder.path}$filename");
      final sourceFile = File(tempPath);
      
      if (await sourceFile.exists()) {
        await sourceFile.copy(targetFile.path);
        await sourceFile.delete();
      }
    } catch (e) {
      _addLog("Move error: $e");
    }
  }

  void _startNextAutoSyncPhase() {
    if (_autoSyncStage <= 1 && _targetColaFilename != null) {
      setState(() {
        _autoSyncStage = 2;
        _syncProgress = 0.0;
        _syncStartTimeMs = null;
      });
      _requestDownload(_targetColaFilename!);
    } else if (_autoSyncStage <= 2 && _targetLogFilename != null) {
      setState(() {
        _autoSyncStage = 3;
        _syncProgress = 0.0;
        _syncStartTimeMs = null;
      });
      _requestDownload(_targetLogFilename!);
    } else {
      _recompressDownloadedFiles();
    }
  }

  Future<void> _recompressDownloadedFiles() async {
    setState(() => _autoSyncStage = 4);
    final targetFolder = "/sdcard/Documents/COLA_FILE/";
    
    try {
      if (_targetColaFilename != null) {
        await compute(_recompressZipIsolate, "$targetFolder${_targetColaFilename!}");
      }
      if (_targetLogFilename != null) {
        await compute(_recompressZipIsolate, "$targetFolder${_targetLogFilename!}");
      }
      
      setState(() => _autoSyncStage = 5);
      _addLog("All sync & compression complete!");
    } catch (e) {
      _addLog("Recompress error: $e");
      setState(() => _autoSyncStage = 0);
    }
  }

  static void _recompressZipIsolate(String zipPath) {
    final file = File(zipPath);
    if (!file.existsSync()) return;
    
    final tempDir = Directory("${zipPath}_unzipped");
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync();
    
    final bytes = file.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File('${tempDir.path}/$filename')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory('${tempDir.path}/$filename').createSync(recursive: true);
      }
    }
    
    final encoder = ZipFileEncoder();
    encoder.zipDirectory(tempDir, filename: zipPath);
    tempDir.deleteSync(recursive: true);
  }

  void _requestDownload(String filename) async {
    if (_connectedEndpointId == null) return;
    _addLog("Requesting download for $filename...");
    try {
      await _wifiP2pChannel.invokeMethod("requestFileDownload", {"filename": filename});
    } catch (e) {
      _addLog("Request download error: $e");
    }
  }

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          _buildModeTab('AP', '와이파이 AP', Icons.wifi_rounded),
          _buildModeTab('HOTSPOT', '모바일 핫스팟', Icons.wifi_tethering_rounded),
          _buildModeTab('BT', '블루투스 (BT)', Icons.bluetooth_rounded),
        ],
      ),
    );
  }

  Widget _buildModeTab(String mode, String label, IconData icon) {
    final isSelected = _syncMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: _isSearching ? null : () {
          setState(() {
            _syncMode = mode;
          });
          _addLog("동기화 모드 변경 ➔ $label");
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3366FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.white30, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.white30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0F0F),
      appBar: AppBar(
        title: const Text('워치 동기화', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: _showDebugLogs,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildModeSelector(),
              _buildConnectionHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: _connectedEndpointId == null
                    ? _buildDiscoveryView()
                    : _buildFileListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionHeader() {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Row(
        children: [
          Icon(
            _connectedEndpointId != null
                ? Icons.watch_rounded
                : Icons.watch_off_rounded,
            color: _connectedEndpointId != null ? const Color(0xFF3366FF) : Colors.white24,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _connectedEndpointId != null ? '워치 연결 완료' : '워치 연결 대기 중',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  _connectedEndpointId != null
                      ? '기기명: $_connectedEndpointName'
                      : '워치 앱을 켜고 연동 시작을 눌러주세요.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          if (_connectedEndpointId != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () {
                _wifiP2pChannel.invokeMethod("stopServer");
                setState(() {
                  _connectedEndpointId = null;
                  _connectedEndpointName = null;
                  _autoSyncStage = 0;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isWatchAppInstalled) ...[
          _buildRemoteInstallBanner(),
          const SizedBox(height: 20),
        ],
        // Pulsing Radar Animation
        Center(
          child: AnimatedBuilder(
            animation: _radarController!,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < 3; i++)
                    Container(
                      width: 160 + (i * 40) * _radarController!.value,
                      height: 160 + (i * 40) * _radarController!.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF3366FF).withOpacity(
                          (0.15 * (1 - _radarController!.value)).clamp(0.0, 1.0),
                        ),
                      ),
                    ),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E8F7A), Color(0xFF3366FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.radar_rounded, color: Colors.white, size: 48),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 40),
        Text(
          _isSearching 
              ? (_syncMode == 'BT' ? '블루투스 페어링 대기 중...' : (_syncMode == 'HOTSPOT' ? '모바일 핫스팟 연동 대기 중...' : '공용 와이파이(AP) 탐색 대기 중...'))
              : '연동할 워치를 찾아주세요.',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          _syncMode == 'BT'
              ? '스마트폰과 워치가 블루투스로 연결되어 있어야 합니다.\n이후 워치 앱에서 [연동 시작]을 눌러주세요.'
              : (_syncMode == 'HOTSPOT'
                  ? '스마트폰 핫스팟을 활성화하고,\n워치가 이 핫스팟에 연결되었는지 확인해 주세요.'
                  : '스마트폰과 워치가 모두 동일한 Wi-Fi 공유기(AP)망에\n연결되어 있어야 무선 고속 연동이 가능합니다.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isSearching ? null : _startDiscovery,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3366FF),
            foregroundColor: Colors.white,
            minimumSize: const Size(180, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          child: Text(_isSearching ? '탐색 진행 중...' : '탐색 시작', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildFileListView() {
    if (_autoSyncStage == 0) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.sync_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('위의 탐색 버튼을 눌러 워치와 연결하세요.', style: TextStyle(color: Colors.white70)),
          ]
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('자동 동기화 진행 상황', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        const SizedBox(height: 20),
        _buildSyncStageRow(1, '워치 연결 및 패키지 요청 중', _autoSyncStage > 1, _autoSyncStage == 1),
        _buildSyncStageRow(2, 'COLA 데이터 수신 중', _autoSyncStage > 2, _autoSyncStage == 2, progress: _autoSyncStage == 2 ? _syncProgress : null, transferred: _autoSyncStage == 2 ? _syncTransferredBytes : null, total: _autoSyncStage == 2 ? _syncTotalBytes : null, startTime: _autoSyncStage == 2 ? _syncStartTimeMs : null),
        _buildSyncStageRow(3, 'Log 데이터 수신 중', _autoSyncStage > 3, _autoSyncStage == 3, progress: _autoSyncStage == 3 ? _syncProgress : null, transferred: _autoSyncStage == 3 ? _syncTransferredBytes : null, total: _autoSyncStage == 3 ? _syncTotalBytes : null, startTime: _autoSyncStage == 3 ? _syncStartTimeMs : null),
        _buildSyncStageRow(4, '폰 단말 최적화 압축 진행 중', _autoSyncStage > 4, _autoSyncStage == 4),
        _buildSyncStageRow(5, '동기화 완료!', _autoSyncStage == 5, false),
      ],
    );
  }

  Widget _buildSyncStageRow(int step, String label, bool isDone, bool isActive, {double? progress, int? transferred, int? total, int? startTime}) {
    String percentStr = "";
    String etaStr = "";
    if (isActive && progress != null) {
      percentStr = " ${(progress * 100).toStringAsFixed(1)}%";
      if (transferred != null && total != null && startTime != null && progress < 1.0 && transferred > 0) {
        final elapsedMs = DateTime.now().millisecondsSinceEpoch - startTime;
        if (elapsedMs > 500) {
          final speedBytesPerSec = (transferred / (elapsedMs / 1000)).round();
          if (speedBytesPerSec > 0) {
            final remainingBytes = total - transferred;
            final remainingSec = (remainingBytes / speedBytesPerSec).ceil();
            final speedMBps = (speedBytesPerSec / (1024 * 1024)).toStringAsFixed(2);
            etaStr = "남은 시간: 약 ${remainingSec}초 ($speedMBps MB/s)";
          }
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDone)
            const Icon(Icons.check_circle, color: Colors.white, size: 24)
          else if (isActive)
            RotationTransition(
              turns: _spinController!,
              child: const Icon(Icons.sync, color: Colors.white, size: 24),
            )
          else
            const Icon(Icons.radio_button_unchecked, color: Colors.white24, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label + percentStr,
                  style: TextStyle(
                    color: isActive || isDone ? Colors.white : Colors.white54,
                    fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                if (isActive && etaStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(etaStr, style: const TextStyle(color: Color(0xFF3366FF), fontSize: 12)),
                ],
                if (isActive && progress != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF3366FF)),
                  ),
                ] else if (isActive && step == 4) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF3366FF)),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteInstallBanner() {
    return _GlassCard(
      padding: const EdgeInsets.all(12),
      radius: 12,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '워치에 연동 전용 앱이 감지되지 않았습니다.',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _remoteInstallWatchApp,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('워치에 원격 설치하기 (Play Store)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3366FF),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── GlassCard Helper (matches styling of the app) ────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const _GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.0,
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

// Helper Extension for lists filtering
extension ListFilter<E> on List<E> {
  List<E> filter(bool Function(E element) test) {
    final result = <E>[];
    for (var element in this) {
      if (test(element)) {
        result.add(element);
      }
    }
    return result;
  }
}
