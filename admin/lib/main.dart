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
  bool _isLoading = true;
  String? _errorMessage;

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

      if (devRes.statusCode == 200 && noticeRes.statusCode == 200) {
        final devDecoded = json.decode(utf8.decode(devRes.bodyBytes));
        final noticeDecoded = json.decode(utf8.decode(noticeRes.bodyBytes));

        if (devDecoded['status'] == 'success' && noticeDecoded['status'] == 'success') {
          setState(() {
            _devices = devDecoded['data'] as List<dynamic>;
            _notices = noticeDecoded['data'] as List<dynamic>;
            _isLoading = false;
          });
          return;
        }
      }
      setState(() {
        _errorMessage = '데이터 로드 실패';
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('테스터 모니터링 대시보드'),
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
        final lastActive = dev['last_active_at'] ?? '';
        final active = lastActive.isNotEmpty && _isActive(lastActive);

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
                // 접속등 표시
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF10B981) : Colors.grey,
                    shape: BoxShape.circle,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
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
                    Text(
                      active ? '접속 중' : '오프라인',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: active ? const Color(0xFF10B981) : Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastActive.isNotEmpty ? _getRelativeTime(lastActive) : '신호 없음',
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
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
}
