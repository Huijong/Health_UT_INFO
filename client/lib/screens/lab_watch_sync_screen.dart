import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:client/services/prefs_service.dart';
import 'package:geolocator/geolocator.dart';

class LabWatchSyncScreen extends StatefulWidget {
  final PrefsService prefs;
  const LabWatchSyncScreen({super.key, required this.prefs});

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
  List<Map<String, dynamic>> _files = [];
  bool _isLoadingFileList = false;
  bool _isCompressing = false; // 워치에서 COLA 파일 압축 중 상태

  bool _isWatchAppInstalled = true; // Default to true

  // Animation controller for radar pulsing effect
  AnimationController? _radarController;
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
            child: const Text("닫기", style: TextStyle(color: Color(0xFF3DFFC1))),
          )
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _checkPermissions();
    _checkWatchAppInstalled();
    _setupWifiP2pEventSubscription();
  }

  @override
  void dispose() {
    _radarController?.dispose();
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
            _files.clear();
          });
        }
        break;

      case "hotspotStarted":
        final ssid = data["ssid"] as String? ?? "healthport";
        final pw   = data["password"] as String? ?? "00000000";
        _addLog("Direct Hotspot Started: SSID=$ssid, PW=$pw");
        _showHotspotInfoDialog(ssid, pw);
        break;

      case "fileListReceived":
        final jsonStr = data as String;
        _addLog("Received file list JSON.");
        try {
          final decoded = jsonDecode(jsonStr) as List<dynamic>;
          setState(() {
            _files = decoded.map((e) {
              final map = Map<String, dynamic>.from(e);
              map['selected'] = false;
              map['progress'] = 0.0;
              map['status'] = "대기";
              return map;
            }).toList();
            _isLoadingFileList = false;
            _isCompressing = false;
          });
        } catch (e) {
          _addLog("JSON Parse error: $e");
          setState(() {
            _isLoadingFileList = false;
            _isCompressing = false;
          });
        }
        break;

      case "compressing":
        _addLog("워치에서 COLA 파일 압축 중...");
        setState(() {
          _isCompressing = true;
          _isLoadingFileList = true;
        });
        break;

      case "downloadProgress":
        final progressMap = Map<String, dynamic>.from(data);
        final filename = progressMap["filename"] as String;
        final progress = progressMap["progress"] as double;
        final transferred = progressMap["transferred"] as int;
        final total = progressMap["total"] as int;

        _updateFileStatus(
          filename,
          "다운로드 중...",
          progress,
          transferredBytes: transferred,
          totalBytes: total,
        );
        break;

      case "downloadComplete":
        final completeMap = Map<String, dynamic>.from(data);
        final filename = completeMap["filename"] as String;
        final tempPath = completeMap["path"] as String;
        _addLog("Download finished for $filename. Processing...");
        _processDownloadedFile(filename, tempPath);
        break;

      case "downloadFailure":
        final failMap = Map<String, dynamic>.from(data);
        final filename = failMap["filename"] as String?;
        final error = failMap["error"] as String? ?? "Unknown error";
        _addLog("Download failed: $error");
        if (filename != null) {
          _updateFileStatus(filename, "실패", 0.0);
        }
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
            Icon(Icons.wifi_tethering, color: Color(0xFF3DFFC1), size: 22),
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
              style: TextStyle(color: Color(0xFF3DFFC1), fontSize: 11),
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
            child: const Text("핫스팟 설정 켜기", style: TextStyle(color: Color(0xFF2E5BFF), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("닫기", style: TextStyle(color: Color(0xFF3DFFC1))),
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
        border: Border.all(color: const Color(0xFF3DFFC1).withOpacity(0.3)),
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
      if (_syncMode == 'BT') {
        _addLog("Bluetooth mode ready. Waiting for Wear OS communication...");
      } else if (_syncMode == 'HOTSPOT') {
        _addLog("Hotspot Server started. Connect watch to 'healthport' (00000000) and wait...");
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
      _isLoadingFileList = true;
    });
    _addLog("Requesting file list from Watch...");
    try {
      await _wifiP2pChannel.invokeMethod("requestFileList");
    } catch (e) {
      _addLog("Failed to request file list: $e");
      setState(() {
        _isLoadingFileList = false;
      });
    }
  }

  Future<void> _processDownloadedFile(String filename, String tempPath) async {
    try {
      _addLog("Locating target folder: /sdcard/Documents/COLA_FILE/...");
      final targetFolder = Directory("/sdcard/Documents/COLA_FILE/");
      if (!await targetFolder.exists()) {
        _addLog("Target folder does not exist. Creating...");
        await targetFolder.create(recursive: true);
      }

      final targetFile = File("${targetFolder.path}$filename");
      final sourceFile = File(tempPath);
      
      final srcExists = await sourceFile.exists();
      if (srcExists) {
        _addLog("Copying file to target path: ${targetFile.path}...");
        await sourceFile.copy(targetFile.path);
        
        _addLog("Deleting temporary cache file...");
        await sourceFile.delete();

        _addLog("File transfer workflow successfully completed.");
        _updateFileStatus(filename, "완료", 1.0);
      } else {
        _addLog("Error: Source cache file does not exist at $tempPath!");
        _updateFileStatus(filename, "실패", 0.0);
      }
    } catch (e) {
      _addLog("Exception in _processDownloadedFile: $e");
      _updateFileStatus(filename, "실패", 0.0);
    }
  }

  void _updateFileStatus(
    String filename, 
    String status, 
    double progress, {
    int transferredBytes = 0, 
    int totalBytes = 0
  }) {
    setState(() {
      for (var f in _files) {
        if (f['name'] == filename) {
          f['status'] = status;
          f['progress'] = progress;
          f['transferred'] = transferredBytes;
          f['total'] = totalBytes;
          break;
        }
      }
    });
  }

  void _requestDownload(String filename) async {
    if (_connectedEndpointId == null) return;

    setState(() {
      for (var f in _files) {
        if (f['name'] == filename) {
          f['status'] = "다운로드 중...";
          f['progress'] = 0.0;
        }
      }
    });

    _addLog("Requesting download for $filename...");
    try {
      await _wifiP2pChannel.invokeMethod("requestFileDownload", {"filename": filename});
    } catch (e) {
      _addLog("Request download error: $e");
    }
  }

  void _downloadSelectedFiles() {
    final selected = _files.where((f) => f['selected'] == true && f['status'] != "완료").toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("다운로드할 파일을 선택해 주세요.")),
      );
      return;
    }

    for (var f in selected) {
      final filename = f['name'] as String;
      _requestDownload(filename);
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
            color: isSelected ? const Color(0xFF2E5BFF) : Colors.transparent,
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
        title: const Text('실험실 - 워치 동기화', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Color(0xFF3DFFC1)),
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
            color: _connectedEndpointId != null ? const Color(0xFF3DFFC1) : Colors.white24,
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
                  _files.clear();
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
                        color: const Color(0xFF2E5BFF).withOpacity(
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
                        colors: [Color(0xFF2E5BFF), Color(0xFF3DFFC1)],
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
                  ? '스마트폰 핫스팟(healthport / 00000000)을 활성화하고,\n워치가 이 핫스팟에 연결되었는지 확인해 주세요.'
                  : '스마트폰과 워치가 모두 동일한 Wi-Fi 공유기(AP)망에\n연결되어 있어야 무선 고속 연동이 가능합니다.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isSearching ? null : _startDiscovery,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E5BFF),
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
    if (_isLoadingFileList) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF3DFFC1))),
            const SizedBox(height: 16),
            Text(
              _isCompressing
                  ? 'COLA 파일 압축 중...\n잠시만 기다려 주세요.'
                  : '워치에서 운동 데이터 목록을 가져오는 중...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            if (_isCompressing) ...[  
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.compress_rounded, size: 14, color: Color(0xFF3DFFC1)),
                  const SizedBox(width: 4),
                  Text(
                    'COLA_FILE_[버전]_[날짜]_[시간].zip 형식으로 변환 중',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              '워치에 저장된 운동 데이터 파일(.zip)이 없습니다.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '워치 앱에서 운동을 완료하여 데이터를 생성해 주세요.',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _sendFileListRequest,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('목록 새로고침'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E5BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '워치 운동 파일 목록',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            TextButton(
              onPressed: _sendFileListRequest,
              child: const Row(
                children: [
                  Icon(Icons.refresh, size: 16, color: Color(0xFF3DFFC1)),
                  SizedBox(width: 4),
                  Text('새로고침', style: TextStyle(color: Color(0xFF3DFFC1))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _files.length,
            itemBuilder: (context, index) {
              final file = _files[index];
              final String name = file['name'];
              final int size = file['size'];
              final double progress = file['progress'] ?? 0.0;
              final String status = file['status'] ?? "대기";
              final bool selected = file['selected'] ?? false;
              final int transferred = file['transferred'] ?? 0;
              final int total = file['total'] ?? 0;

              // Size formatting
              final String sizeText = size > 1024 * 1024
                  ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
                  : '${(size / 1024).toStringAsFixed(1)} KB';

              String displayStatus = status;
              if (status == "다운로드 중...") {
                final double percent = progress * 100;
                final double txMB = transferred / (1024 * 1024);
                final double totalMB = total / (1024 * 1024);
                displayStatus = "${percent.toStringAsFixed(1)}% (${txMB.toStringAsFixed(1)}MB/${totalMB.toStringAsFixed(1)}MB)";
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _GlassCard(
                  padding: const EdgeInsets.all(12),
                  radius: 12,
                  child: Row(
                    children: [
                      Checkbox(
                        value: selected,
                        activeColor: const Color(0xFF3DFFC1),
                        checkColor: Colors.black,
                        onChanged: status == "완료" || status == "다운로드 중..."
                            ? null
                            : (val) {
                                setState(() {
                                  file['selected'] = val;
                                });
                              },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  sizeText,
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                ),
                                Text(
                                  displayStatus,
                                  style: TextStyle(
                                    color: status == "완료"
                                        ? const Color(0xFF3DFFC1)
                                        : status == "다운로드 중..."
                                            ? const Color(0xFF2E5BFF)
                                            : status.startsWith("실패")
                                                ? const Color(0xFFFF5252)
                                                : Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (status == "다운로드 중...") ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFF2E5BFF)),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _downloadSelectedFiles,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3DFFC1),
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text(
            '선택 파일 가져오기',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
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
              backgroundColor: const Color(0xFF2E5BFF),
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
