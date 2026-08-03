import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const SamsungHealthAdminApp());
}

class SamsungHealthAdminApp extends StatelessWidget {
  const SamsungHealthAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SH 검증 관리자 발송기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E5BFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AdminNoticeScreen(),
    );
  }
}

class AdminNoticeScreen extends StatefulWidget {
  const AdminNoticeScreen({super.key});

  @override
  State<AdminNoticeScreen> createState() => _AdminNoticeScreenState();
}

class _AdminNoticeScreenState extends State<AdminNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _isSending = false;

  // 서버 API 주소
  final String _apiUrl = 'https://health-port.work/api/notices';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendNotice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': _titleCtrl.text.trim(),
          'content': _contentCtrl.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF3DFFC1), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '공지사항이 푸시 알림과 함께 정상 발송되었습니다! 🚀',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF0F3A30),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF3DFFC1), width: 1.5),
                ),
                elevation: 8,
              ),
            );
          }
          _titleCtrl.clear();
          _contentCtrl.clear();
        } else {
          _showError(decoded['message'] ?? '발송 처리에 실패했습니다.');
        }
      } else {
        _showError('서버 연결 실패 (Status Code: ${response.statusCode})');
      }
    } catch (e) {
      _showError('발송 중 네트워크 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF2C1010),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더 타이틀 영역
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF3DFFC1), size: 32),
                        const SizedBox(width: 12),
                        const Text(
                          'HealthPort Admin',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.people_alt_rounded, color: Color(0xFF3DFFC1), size: 28),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TesterStatusScreen(),
                              ),
                            );
                          },
                          tooltip: '테스터 모니터링',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '테스터 앱 전체 기기로 무선 푸시 공지를 발송합니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 메인 입력 폼 카드 (글래스모피즘 효과)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '공지사항 작성',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3DFFC1),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 제목
                              TextFormField(
                                controller: _titleCtrl,
                                decoration: InputDecoration(
                                  labelText: '공지 제목 입력',
                                  prefixIcon: const Icon(Icons.title_rounded, size: 20),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                  ),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? '공지 제목을 입력해 주세요' : null,
                              ),
                              const SizedBox(height: 16),

                              // 상세 본문
                              TextFormField(
                                controller: _contentCtrl,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  labelText: '공지 내용 입력',
                                  alignLabelWithHint: true,
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(bottom: 120.0),
                                    child: Icon(Icons.description_rounded, size: 20),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                  ),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? '공지 본문 내용을 입력해 주세요' : null,
                              ),
                              const SizedBox(height: 24),

                              // 발송 버튼
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E5BFF),
                                    foregroundColor: Colors.white,
                                    shadowColor: const Color(0xFF2E5BFF).withOpacity(0.4),
                                    elevation: 8,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _isSending ? null : _sendNotice,
                                  child: _isSending
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.send_rounded, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              '공지사항 무선 발송하기 🚀',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TesterStatusScreen extends StatefulWidget {
  const TesterStatusScreen({super.key});

  @override
  State<TesterStatusScreen> createState() => _TesterStatusScreenState();
}

class _TesterStatusScreenState extends State<TesterStatusScreen> {
  List<dynamic> _devices = [];
  List<dynamic> _notices = [];
  List<dynamic> _testerStatus = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _sortBy = 'recent';
  String _latestServerVersion = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. 디바이스 접속 상태 가져오기
      final devRes = await http.get(Uri.parse('https://health-port.work/api/devices'));
      // 2. 공지 리스트 및 ACK 수신 상태 가져오기
      final noticeRes = await http.get(Uri.parse('https://health-port.work/api/notices'));
      // 3. 테스터 데이터 수신 현황 가져오기
      final statusRes = await http.get(Uri.parse('https://health-port.work/api/devices?summary=true'));
      // 4. 최신 APK 정보 가져오기
      final apkRes = await http.get(Uri.parse('https://health-port.work/api/devices?latest_apk=true'));

      if (devRes.statusCode == 200 && noticeRes.statusCode == 200 && statusRes.statusCode == 200) {
        final devDecoded = json.decode(utf8.decode(devRes.bodyBytes));
        final noticeDecoded = json.decode(utf8.decode(noticeRes.bodyBytes));
        final statusDecoded = json.decode(utf8.decode(statusRes.bodyBytes));

        if (devDecoded['status'] == 'success' && 
            noticeDecoded['status'] == 'success' &&
            statusDecoded['status'] == 'success') {
          
          if (apkRes.statusCode == 200) {
            final apkDecoded = json.decode(utf8.decode(apkRes.bodyBytes));
            if (apkDecoded['status'] == 'success') {
              final String filename = apkDecoded['filename'] ?? '';
              final regExp = RegExp(r'HealthPort_([0-9\.]+)\.apk');
              final match = regExp.firstMatch(filename);
              if (match != null) {
                _latestServerVersion = match.group(1) ?? '';
              }
            }
          }

          setState(() {
            _devices = devDecoded['data'] as List<dynamic>;
            _notices = noticeDecoded['data'] as List<dynamic>;
            _testerStatus = statusDecoded['data'] as List<dynamic>;
            _isLoading = false;
          });
          return;
        }
      }
      setState(() {
        _errorMessage = '데이터 로드 실패 (상태 코드 - 접속: ${devRes.statusCode}, 공지: ${noticeRes.statusCode}, 수신: ${statusRes.statusCode})';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '서버 연결 중 네트워크 에러: $e';
        _isLoading = false;
      });
    }
  }

  String _getRelativeTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final difference = DateTime.now().difference(dateTime);
      if (difference.inMinutes < 1) {
        return '방금 전';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}시간 전';
      } else {
        return '${difference.inDays}일 전';
      }
    } catch (_) {
      return isoString;
    }
  }

  bool _isActive(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final difference = DateTime.now().difference(dateTime);
      return difference.inMinutes < 10; // 10분 이내 신호 도달 시 Active
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteDevice(String deviceId, String testerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2336),
        title: const Text('기기 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '$testerName 유저의 단말 기기 접속 기록을 정말로 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('https://health-port.work/api/devices/$deviceId'),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제되었습니다.'), backgroundColor: Color(0xFF10B981)),
        );
        _fetchData();
      } else {
        throw Exception('서버 에러 (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('테스터 모니터링'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.phonelink_setup_rounded),
                text: '단말 접속 현황',
              ),
              Tab(
                icon: Icon(Icons.mark_email_read_rounded),
                text: '공지 수신율 확인',
              ),
              Tab(
                icon: Icon(Icons.storage_rounded),
                text: '데이터 수신 현황',
              ),
            ],
            indicatorColor: Color(0xFF3DFFC1),
            labelColor: Color(0xFF3DFFC1),
            unselectedLabelColor: Colors.white60,
          ),
          backgroundColor: const Color(0xFF1429A0).withOpacity(0.9),
          elevation: 4,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _isLoading ? null : _fetchData,
              tooltip: '새로고침',
            )
          ],
        ),
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3DFFC1)),
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _fetchData,
                            child: const Text('다시 시도'),
                          )
                        ],
                      ),
                    )
                  : TabBarView(
                      children: [
                        _buildDeviceTab(),
                        _buildNoticeTab(),
                        _buildTesterStatusTab(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildDeviceTab() {
    if (_devices.isEmpty) {
      return const Center(
        child: Text(
          '등록된 테스터 단말이 없습니다.',
          style: TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final dev = _devices[index];
        final name = dev['tester_name'] ?? '이름없음';
        final watch = dev['watch'] ?? '미지정';
        final os = dev['os_version'] ?? '알 수 없음';
        final appVersion = dev['app_version'] ?? '알 수 없음';
        final lastActive = dev['last_active_at'] ?? '';
        final active = lastActive.isNotEmpty && _isActive(lastActive);

        bool isOutdated = false;
        if (appVersion != '알 수 없음' && _latestServerVersion.isNotEmpty) {
          isOutdated = appVersion != _latestServerVersion;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white.withOpacity(0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PointHistoryScreen(testerName: name),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOutdated 
                                    ? Colors.redAccent.withOpacity(0.2) 
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: isOutdated 
                                    ? Border.all(color: Colors.redAccent.withOpacity(0.5)) 
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isOutdated) ...[
                                    const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.redAccent),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    'v$appVersion',
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: isOutdated ? Colors.redAccent : Colors.white70,
                                      fontWeight: isOutdated ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '착용 워치: $watch',
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        Text(
                          '단말 환경: $os',
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notification_add_rounded, size: 18),
                              color: const Color(0xFF3DFFC1),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              onPressed: () => _showNudgeConfirmDialog(name),
                              tooltip: '독려 푸시 전송',
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () => _deleteDevice(dev['_id'], name),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              color: Colors.redAccent,
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showPointAdjustmentDialog(context, name),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                          label: const Text('포인트', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E5BFF),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(64, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoticeTab() {
    if (_notices.isEmpty) {
      return const Center(
        child: Text(
          '발송된 공지사항이 없습니다.',
          style: TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notices.length,
      itemBuilder: (context, index) {
        final notice = _notices[index];
        final title = notice['title'] ?? '제목없음';
        final content = notice['content'] ?? '';
        final receivedList = List<String>.from(notice['received_users'] ?? []);
        final createdAt = notice['created_at'] ?? '';

        // 기기 목록 대조하여 수신자 수 계산
        final totalCount = _devices.length;
        final receiveCount = receivedList.length;
        final rate = totalCount > 0 ? (receiveCount / totalCount * 100).toStringAsFixed(0) : '0';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.white.withOpacity(0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: ExpansionTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Text(
              '발송: ${createdAt.isNotEmpty ? _getRelativeTime(createdAt) : ''}  |  수신율: $receiveCount/$totalCount ($rate%)',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            iconColor: const Color(0xFF3DFFC1),
            collapsedIconColor: Colors.white54,
            children: [
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ),
              const Divider(color: Colors.white12),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '기기별 수신(정독) 상세 결과',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3DFFC1)),
                ),
              ),
              if (_devices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('수신 여부를 대조할 단말 정보가 없습니다.', style: TextStyle(fontSize: 12, color: Colors.white30)),
                )
              else
                ..._devices.map((dev) {
                  final String testerName = dev['tester_name'] ?? '';
                  final isReceived = receivedList.contains(testerName);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          isReceived ? Icons.check_circle_rounded : Icons.cancel_outlined,
                          color: isReceived ? const Color(0xFF10B981) : Colors.white24,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          testerName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isReceived ? Colors.white : Colors.white38,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isReceived ? '수신 완료' : '미수신',
                          style: TextStyle(
                            fontSize: 12,
                            color: isReceived ? const Color(0xFF10B981) : Colors.white24,
                            fontWeight: isReceived ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // --- New Methods for Data Reception Status Tab ---
  Color _getStatusColor(String? lastReceivedAt) {
    if (lastReceivedAt == null || lastReceivedAt.isEmpty) {
      return const Color(0xFFEF4444); // Red
    }
    try {
      final parsedDate = DateTime.parse(lastReceivedAt);
      final difference = DateTime.now().difference(parsedDate);

      if (difference.inDays < 2) {
        return const Color(0xFF10B981); // Green
      } else if (difference.inDays < 7) {
        return const Color(0xFFFBBF24); // Yellow
      } else {
        return const Color(0xFFEF4444); // Red
      }
    } catch (_) {
      return const Color(0xFFEF4444);
    }
  }

  String _getStatusText(String? lastReceivedAt) {
    if (lastReceivedAt == null || lastReceivedAt.isEmpty) {
      return '수신 기록 없음 (이탈 위험 🔴)';
    }
    try {
      final parsedDate = DateTime.parse(lastReceivedAt);
      final difference = DateTime.now().difference(parsedDate);

      if (difference.inDays < 2) {
        return '활성 상태 🟢';
      } else if (difference.inDays < 7) {
        return '활동 뜸함 🟡';
      } else {
        return '장기 미활동 (이탈 위험 🔴)';
      }
    } catch (_) {
      return '형식 오류';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF2C1010),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _sendNudge(String testerName, {required String title, required String content}) async {
    try {
      final response = await http.post(
        Uri.parse('https://health-port.work/api/notices'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'content': content,
          'target_tester': testerName,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF3DFFC1), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$testerName님께 알림 푸시 메시지가 발송되었습니다! 📢',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF0F3A30),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF3DFFC1), width: 1.5),
                ),
                elevation: 8,
              ),
            );
          }
          _fetchData();
        } else {
          _showError(decoded['message'] ?? '알림 발송에 실패했습니다.');
        }
      } else {
        _showError('서버 연결 실패 (Status Code: ${response.statusCode})');
      }
    } catch (e) {
      _showError('알림 발송 중 에러가 발생했습니다: $e');
    }
  }

  void _showNudgeConfirmDialog(String testerName) {
    final titleCtrl = TextEditingController(text: '[확인 요청] ${testerName}님 안내 📢');
    final contentCtrl = TextEditingController(
      text: '${testerName}님, 최근 전송된 삼성 헬스 검증 데이터가 확인되지 않아 알림을 드립니다. 단말 연결 및 테스트 업로드를 다시 한번 확인해 주세요! 🚀'
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0F24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.5),
        ),
        title: Text(
          '$testerName님께 개별 메시지 발송',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '알림 제목',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2E5BFF), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '알림 내용',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2E5BFF), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final title = titleCtrl.text.trim();
              final content = contentCtrl.text.trim();
              if (title.isEmpty || content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('제목과 내용을 모두 입력해 주세요.')),
                );
                return;
              }
              Navigator.pop(ctx);
              _sendNudge(testerName, title: title, content: content);
            },
            child: const Text('발송'),
          ),
        ],
      ),
    );
  }

  Widget _buildTesterStatusTab() {
    if (_testerStatus.isEmpty) {
      return const Center(
        child: Text(
          '수집된 데이터가 없습니다.',
          style: TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
        ),
      );
    }

    final filtered = _testerStatus.where((item) {
      final name = (item['tester_name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (_sortBy == 'recent') {
      filtered.sort((a, b) {
        final aTime = a['last_received_at'] ?? '';
        final bTime = b['last_received_at'] ?? '';
        return bTime.compareTo(aTime);
      });
    } else {
      filtered.sort((a, b) {
        final aCount = a['total_count'] ?? 0;
        final bCount = b['total_count'] ?? 0;
        return bCount.compareTo(aCount);
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '테스터 검색...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.4), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: const Color(0xFF0A0F24),
                    icon: const Icon(Icons.sort_rounded, color: Color(0xFF3DFFC1), size: 20),
                    items: const [
                      DropdownMenuItem(
                        value: 'recent',
                        child: Text('최근 수신일 순', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: 'count',
                        child: Text('누적 건수 순', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _sortBy = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    '일치하는 테스터가 없습니다.',
                    style: TextStyle(color: Colors.white38, fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final name = item['tester_name'] ?? '알 수 없음';
                    final count = item['total_count'] ?? 0;
                    final lastTime = item['last_received_at'] ?? '';
                    final statusColor = _getStatusColor(lastTime);
                    final statusText = _getStatusText(lastTime);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white.withOpacity(0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.4),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '누적 제출: $count건  |  $statusText',
                                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                                  ),
                                  Text(
                                    '마지막 전송: ${lastTime.isNotEmpty ? _getRelativeTime(lastTime) : "없음"} (${lastTime.isNotEmpty ? lastTime : "기록 없음"})',
                                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'HealthPort ${item['app_version'] ?? '알 수 없음'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.notification_add_rounded, color: Color(0xFF3DFFC1), size: 24),
                              onPressed: () {
                                _showNudgeConfirmDialog(name);
                              },
                              tooltip: '독려 푸시 전송',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
  void _showPointAdjustmentDialog(BuildContext context, String testerName) {
    showDialog(
      context: context,
      builder: (context) {
        double points = 1.00;
        final memoCtrl = TextEditingController(text: '관리자 가산');
        final pointsCtrl = TextEditingController(text: '1.00');
        final monthStr = DateTime.now().toString().substring(0, 7); // YYYY-MM

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2020),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              title: Text(
                '$testerName님 포인트 가감',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '포인트 설정',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          setDialogState(() {
                            points -= 0.10;
                            points = double.parse(points.toStringAsFixed(2));
                            pointsCtrl.text = points.toStringAsFixed(2);
                          });
                        },
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 28),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: pointsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: points > 0
                                ? const Color(0xFF3DFFC1)
                                : (points < 0 ? Colors.redAccent : Colors.white),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            prefixText: points >= 0 ? '+' : '',
                            prefixStyle: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: points > 0
                                  ? const Color(0xFF3DFFC1)
                                  : (points < 0 ? Colors.redAccent : Colors.white),
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              points = double.tryParse(val.replaceAll('+', '')) ?? 0.00;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () {
                          setDialogState(() {
                            points += 0.10;
                            points = double.parse(points.toStringAsFixed(2));
                            pointsCtrl.text = points.toStringAsFixed(2);
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3DFFC1), size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Plus Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => setDialogState(() {
                          points += 1.00;
                          points = double.parse(points.toStringAsFixed(2));
                          pointsCtrl.text = points.toStringAsFixed(2);
                        }),
                        child: const Text('+1.00', style: TextStyle(color: Color(0xFF3DFFC1), fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          points += 0.50;
                          points = double.parse(points.toStringAsFixed(2));
                          pointsCtrl.text = points.toStringAsFixed(2);
                        }),
                        child: const Text('+0.50', style: TextStyle(color: Color(0xFF3DFFC1), fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          points += 0.10;
                          points = double.parse(points.toStringAsFixed(2));
                          pointsCtrl.text = points.toStringAsFixed(2);
                        }),
                        child: const Text('+0.10', style: TextStyle(color: Color(0xFF3DFFC1), fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          points += 0.01;
                          points = double.parse(points.toStringAsFixed(2));
                          pointsCtrl.text = points.toStringAsFixed(2);
                        }),
                        child: const Text('+0.01', style: TextStyle(color: Color(0xFF3DFFC1), fontSize: 12)),
                      ),
                    ],
                  ),
                  // Minus Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => setDialogState(() {
                          points -= 1.00;
                          points = double.parse(points.toStringAsFixed(2));
                          pointsCtrl.text = points.toStringAsFixed(2);
                        }),
                        child: const Text('-1.00', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          points -= 0.50;
                          points = double.parse(points.toStringAsFixed(2));
                          pointsCtrl.text = points.toStringAsFixed(2);
                        }),
                        child: const Text('-0.50', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          points -= 0.10;
                          points = double.parse(points.toStringAsFixed(2));
                          pointsCtrl.text = points.toStringAsFixed(2);
                        }),
                        child: const Text('-0.10', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          points -= 0.01;
                          points = double.parse(points.toStringAsFixed(2));
                          pointsCtrl.text = points.toStringAsFixed(2);
                        }),
                        child: const Text('-0.01', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: memoCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '사유(메모)를 입력하세요',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final response = await http.post(
                        Uri.parse('https://health-port.work/api/devices'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'tester_name': testerName,
                          'points': points,
                          'memo': memoCtrl.text.trim(),
                          'month': monthStr,
                        }),
                      );
                      if (response.statusCode == 200) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('포인트가 정상적으로 반영되었습니다.'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                        _fetchData(); // 데이터 새로고침
                      } else {
                        throw Exception('서버 에러');
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('실패했습니다: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E5BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class PointHistoryScreen extends StatefulWidget {
  final String testerName;

  const PointHistoryScreen({super.key, required this.testerName});

  @override
  State<PointHistoryScreen> createState() => _PointHistoryScreenState();
}

class _PointHistoryScreenState extends State<PointHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];
  double _totalPoints = 0.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://health-port.work/api/devices?points_history=true&tester_name=${Uri.encodeComponent(widget.testerName)}'),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success') {
          final data = decoded['data'] ?? [];
          double total = 0.0;
          for (var item in data) {
            total += (item['points'] as num).toDouble();
          }
          setState(() {
            _history = data;
            _totalPoints = total;
            _isLoading = false;
          });
          return;
        }
      }
      throw Exception('응답 코드: ${response.statusCode}');
    } catch (e) {
      setState(() {
        _errorMessage = '히스토리를 불러올 수 없습니다.\n$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.testerName}님 포인트 이력'),
        backgroundColor: const Color(0xFF1429A0),
      ),
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3DFFC1)),
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchHistory,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            color: Colors.white.withOpacity(0.06),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '누적 포인트',
                                    style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${_totalPoints.toStringAsFixed(2)} 포인트',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3DFFC1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _history.isEmpty
                              ? const Center(
                                  child: Text(
                                    '포인트 이력이 없습니다.',
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _history.length,
                                  itemBuilder: (context, index) {
                                    final item = _history[index];
                                    final pts = (item['points'] as num).toDouble();
                                    final memo = item['memo'] ?? '';
                                    final date = item['created_at'] ?? '';
                                    final isPositive = pts > 0;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      color: Colors.white.withOpacity(0.03),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: Colors.white.withOpacity(0.05)),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          memo,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            date,
                                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                                          ),
                                        ),
                                        trailing: Text(
                                          isPositive ? '+${pts.toStringAsFixed(2)}' : pts.toStringAsFixed(2),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isPositive ? const Color(0xFF3DFFC1) : Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
