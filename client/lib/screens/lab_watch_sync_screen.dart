import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart' as nc;
import 'package:client/services/prefs_service.dart';
import 'package:client/config/app_config.dart';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';

class LabWatchSyncScreen extends StatefulWidget {
  final PrefsService prefs;
  const LabWatchSyncScreen({super.key, required this.prefs});

  @override
  State<LabWatchSyncScreen> createState() => _LabWatchSyncScreenState();
}

class _LabWatchSyncScreenState extends State<LabWatchSyncScreen> with TickerProviderStateMixin {
  static const String _serviceId = "com.samsung.health.client.sync";

  bool _isSearching = false;
  String? _connectedEndpointId;
  String? _connectedEndpointName;

  // Discovered devices: endpointId -> name
  final Map<String, String> _discoveredDevices = {};

  // List of files fetched from watch
  List<Map<String, dynamic>> _files = [];
  bool _isLoadingFileList = false;

  // Active file transfers tracking: payloadId -> tempFilePath
  final Map<int, String> _activeTransfers = {};
  
  // Received MD5 checksum mapping: filename -> md5Hex
  final Map<String, String> _incomingMd5Map = {};

  // Current transferring payloadId -> progress (0.0 to 1.0)
  final Map<int, double> _transferProgress = {};
  final Map<int, String> _payloadToFilename = {};
  String? _nextExpectedFilename;

  static const _appChannel = MethodChannel("com.samsung.health.client/app_info");
  bool _isWatchAppInstalled = true; // Default to true

  // Animation controller for radar pulsing effect
  AnimationController? _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _checkPermissions();
    _checkWatchAppInstalled();
  }

  @override
  void dispose() {
    _radarController?.dispose();
    nc.Nearby().stopDiscovery();
    if (_connectedEndpointId != null) {
      nc.Nearby().disconnectFromEndpoint(_connectedEndpointId!);
    }
    super.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("원격 설치 실패: $e")),
      );
    }
  }

  Future<void> _checkPermissions() async {
    // Check location permission using Geolocator
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    // Check/request Bluetooth & Nearby Wifi permissions natively
    try {
      await _appChannel.invokeMethod("requestNearbyPermissions");
    } catch (e) {
      debugPrint("Nearby permissions check failed: $e");
    }
  }

  void _startDiscovery() async {
    try {
      await _appChannel.invokeMethod("requestNearbyPermissions");
    } catch (e) {
      debugPrint("Nearby permissions check failed: $e");
    }

    setState(() {
      _discoveredDevices.clear();
      _isSearching = true;
    });
    _radarController?.repeat();

    try {
      await nc.Nearby().startDiscovery(
        widget.prefs.name.isNotEmpty ? widget.prefs.name : "Smartphone",
        nc.Strategy.P2P_POINT_TO_POINT,
        onEndpointFound: (endpointId, name, serviceId) {
          debugPrint("[Nearby] Discovered endpoint: $endpointId ($name)");
          setState(() {
            _discoveredDevices[endpointId] = name;
          });
          // Auto connect when watch is found
          _connectToDevice(endpointId);
        },
        onEndpointLost: (endpointId) {
          debugPrint("[Nearby] Lost endpoint: $endpointId");
          setState(() {
            _discoveredDevices.remove(endpointId);
          });
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      debugPrint("[Nearby] Error starting discovery: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("탐색 시작 실패: $e")),
      );
      setState(() {
        _isSearching = false;
      });
      _radarController?.stop();
    }
  }

  void _connectToDevice(String endpointId) async {
    nc.Nearby().stopDiscovery();
    setState(() {
      _isSearching = false;
    });
    _radarController?.stop();

    try {
      await nc.Nearby().requestConnection(
        widget.prefs.name.isNotEmpty ? widget.prefs.name : "Smartphone",
        endpointId,
        onConnectionInitiated: (id, info) async {
          debugPrint("[Nearby] Connection initiated with $id (${info.endpointName})");
          // Accept connection
          await nc.Nearby().acceptConnection(
            id,
            onPayLoadRecieved: _onPayloadReceived,
            onPayloadTransferUpdate: _onPayloadTransferUpdate,
          );
        },
        onConnectionResult: (id, status) {
          if (status == nc.Status.CONNECTED) {
            debugPrint("[Nearby] Connected to $id");
            setState(() {
              _connectedEndpointId = id;
              _connectedEndpointName = _discoveredDevices[id] ?? "Smartwatch";
            });
            // Request file list immediately upon connection
            _sendFileListRequest();
          } else {
            debugPrint("[Nearby] Connection failed with status: $status");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("워치 연결에 실패했습니다.")),
            );
          }
        },
        onDisconnected: (id) {
          debugPrint("[Nearby] Disconnected from $id");
          if (_connectedEndpointId == id) {
            setState(() {
              _connectedEndpointId = null;
              _connectedEndpointName = null;
              _files.clear();
            });
          }
        },
      );
    } catch (e) {
      debugPrint("[Nearby] Error requesting connection: $e");
    }
  }

  void _sendFileListRequest() {
    if (_connectedEndpointId == null) return;
    setState(() {
      _isLoadingFileList = true;
    });
    nc.Nearby().sendBytesPayload(
      _connectedEndpointId!,
      Uint8List.fromList(utf8.encode("GET_FILE_LIST")),
    );
  }

  void _onPayloadReceived(String endpointId, nc.Payload payload) {
    if (payload.type == nc.PayloadType.BYTES) {
      final bytes = payload.bytes;
      if (bytes != null) {
        final text = utf8.decode(bytes);
        debugPrint("[Nearby] Payload BYTES received: $text");
        if (text.startsWith("FILE_MD5:")) {
          // Format: FILE_MD5:[filename]:[md5]:[payloadId]
          final parts = text.split(":");
          if (parts.length >= 4) {
            final filename = parts[1];
            final md5 = parts[2];
            final payloadIdStr = parts[3];
            final payloadId = int.tryParse(payloadIdStr);

            _incomingMd5Map[filename] = md5;
            _nextExpectedFilename = filename;
            if (payloadId != null) {
              _payloadToFilename[payloadId] = filename;
              debugPrint("[Nearby] Registered payload ID mapping: $payloadId -> $filename");
            }
          } else if (parts.length >= 3) {
            // Fallback for older versions
            final filename = parts[1];
            final md5 = parts[2];
            _incomingMd5Map[filename] = md5;
            _nextExpectedFilename = filename;
            debugPrint("[Nearby] Registered MD5 (legacy) for $filename: $md5");
          }
        } else if (text.startsWith("ERROR:")) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("워치 오류: ${text.substring(6)}")),
          );
          setState(() {
            _isLoadingFileList = false;
          });
        } else {
          // Parse File list JSON
          try {
            final decoded = jsonDecode(text) as List<dynamic>;
            setState(() {
              _files = decoded.map((e) {
                final map = Map<String, dynamic>.from(e);
                map['selected'] = false;
                map['progress'] = 0.0;
                map['status'] = "대기";
                return map;
              }).toList();
              _isLoadingFileList = false;
            });
          } catch (e) {
            debugPrint("[Nearby] JSON Parse error: $e");
            setState(() {
              _isLoadingFileList = false;
            });
          }
        }
      }
    } else if (payload.type == nc.PayloadType.FILE) {
      final String? tempPath = payload.filePath;
      if (tempPath != null) {
        _activeTransfers[payload.id] = tempPath;
        if (_nextExpectedFilename != null && !_payloadToFilename.containsKey(payload.id)) {
          _payloadToFilename[payload.id] = _nextExpectedFilename!;
          _nextExpectedFilename = null;
        }
        debugPrint("[Nearby] Incoming file payload: id=${payload.id}, path=$tempPath, filename=${_payloadToFilename[payload.id]}");
      }
    }
  }

  void _onPayloadTransferUpdate(String endpointId, nc.PayloadTransferUpdate update) async {
    final payloadId = update.id;
    final progress = update.totalBytes > 0 ? update.bytesTransferred / update.totalBytes : 0.0;

    setState(() {
      _transferProgress[payloadId] = progress;
    });

    final filename = _payloadToFilename[payloadId];

    if (update.status == nc.PayloadStatus.SUCCESS) {
      final tempPath = _activeTransfers[payloadId];
      if (tempPath != null && filename != null) {
        debugPrint("[Nearby] File payload transfer complete. ID=$payloadId, Name=$filename");
        await _processDownloadedFile(filename, tempPath);
      }
    } else if (update.status == nc.PayloadStatus.FAILURE) {
      if (filename != null) {
        _updateFileStatus(filename, "실패", 0.0);
      }
    } else if (update.status == nc.PayloadStatus.IN_PROGRESS) {
      if (filename != null) {
        _updateFileStatus(
          filename, 
          "다운로드 중...", 
          progress, 
          transferredBytes: update.bytesTransferred, 
          totalBytes: update.totalBytes
        );
      }
    }
  }

  Future<void> _processDownloadedFile(String filename, String tempPath) async {
    try {
      final targetFolder = Directory("/sdcard/Documents/COLA_FILE/");
      if (!await targetFolder.exists()) {
        await targetFolder.create(recursive: true);
      }

      final targetFile = File("${targetFolder.path}$filename");
      final sourceFile = File(tempPath);

      if (await sourceFile.exists()) {
        // Calculate MD5 true MD5 using crypto package
        final bytes = await sourceFile.readAsBytes();
        final calculatedMd5 = md5.convert(bytes).toString();

        final expectedMd5 = _incomingMd5Map[filename];

        if (expectedMd5 != null && expectedMd5.toLowerCase() != calculatedMd5.toLowerCase()) {
          debugPrint("[Sync] MD5 verification failed! Expected: $expectedMd5, Calculated: $calculatedMd5");
          _updateFileStatus(filename, "실패 (손상됨)", 0.0);
          return;
        }

        // Copy/Move to target path
        await sourceFile.copy(targetFile.path);
        await sourceFile.delete(); // Delete temp cache file

        debugPrint("[Sync] File successfully saved and verified: ${targetFile.path}");
        _updateFileStatus(filename, "완료", 1.0);
      }
    } catch (e) {
      debugPrint("[Sync] Error saving file: $e");
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

  void _requestDownload(String filename) {
    if (_connectedEndpointId == null) return;

    setState(() {
      for (var f in _files) {
        if (f['name'] == filename) {
          f['status'] = "다운로드 중...";
          f['progress'] = 0.0;
        }
      }
    });

    _payloadToFilename[filename.hashCode] = filename;
    _incomingMd5Map.remove(filename);

    nc.Nearby().sendBytesPayload(
      _connectedEndpointId!,
      Uint8List.fromList(utf8.encode("DOWNLOAD_FILE:$filename")),
    );
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
      _payloadToFilename[filename.hashCode] = filename; 
      _requestDownload(filename);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0F0F),
      appBar: AppBar(
        title: const Text('실험실 - 워치 동기화', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
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
                nc.Nearby().disconnectFromEndpoint(_connectedEndpointId!);
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
          _isSearching ? '블루투스 기반 기기 탐색 중...' : '연동할 워치를 찾아주세요.',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          '워치 앱에서 [연동 시작] 버튼을 누르면 탐색에 노출됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isSearching ? null : _startDiscovery,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E5BFF),
            foregroundColor: Colors.white,
            minimumSize: const Size(200, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_isSearching ? '탐색 진행 중' : '워치 탐색 시작'),
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
              '워치에서 운동 데이터 목록을 가져오는 중...',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
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
