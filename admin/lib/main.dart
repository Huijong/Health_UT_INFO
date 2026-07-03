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
                    const Row(
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF3DFFC1), size: 32),
                        SizedBox(width: 12),
                        Text(
                          'HealthPort Admin',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
                                  labelText: '공지 제목 *',
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
                                  labelText: '공지 내용 *',
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(bottom: 90.0),
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
