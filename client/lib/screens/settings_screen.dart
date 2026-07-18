import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:client/services/prefs_service.dart';
import 'package:client/screens/home_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:client/config/app_config.dart';

ThemeData getSettingsTheme(BuildContext context) {
  return ThemeData.dark().copyWith(
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
}

class SettingsScreen extends StatefulWidget {
  final PrefsService prefs;
  final bool highlightUpdate;
  const SettingsScreen({super.key, required this.prefs, this.highlightUpdate = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _name;
  late double? _height;
  late double? _weight;
  late String _watch;
  late String _customWatch;
  late String _strap;
  late String _customStrap;
  bool _hasUpdate = false;

  bool _blinkHighlightActive = false;
  bool _blinkState = false;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _name = widget.prefs.name;
    _height = widget.prefs.height;
    _weight = widget.prefs.weight;
    _watch = widget.prefs.watch;
    _customWatch = widget.prefs.customWatch;
    _strap = widget.prefs.strap;
    _customStrap = widget.prefs.customStrap;

    if (_watch.isEmpty) _watch = kWatchOptions.first;
    if (_strap.isEmpty) _strap = kStrapOptions.first['name']!;
    
    _checkForUpdate();

    _blinkHighlightActive = widget.highlightUpdate;
    if (_blinkHighlightActive) {
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _blinkState = !_blinkState;
        });
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _blinkHighlightActive = false;
            _blinkTimer?.cancel();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveAll() async {
    final oldName = widget.prefs.name.trim();
    final newName = _name.trim();

    if (newName.isNotEmpty && oldName.isNotEmpty && oldName != newName) {
      try {
        final dio = Dio();
        final response = await dio.post(
          '${AppConfig.apiUrl}/api/devices',
          queryParameters: {'rename': 'true'},
          data: {
            'old_name': oldName,
            'new_name': newName,
          },
        );
        debugPrint('[Rename] Server response: ${response.data}');
      } catch (e) {
        debugPrint('[Rename] Failed to rename nickname on server: $e');
      }
    }

    await widget.prefs.saveName(_name);
    await widget.prefs.saveHeight(_height ?? 0.0);
    await widget.prefs.saveWeight(_weight ?? 0.0);
    await widget.prefs.saveWatch(_watch);
    await widget.prefs.saveCustomWatch(_customWatch);
    await widget.prefs.saveStrap(_strap);
    await widget.prefs.saveCustomStrap(_customStrap);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final dio = Dio();
      final response = await dio.get('${AppConfig.apiUrl}/api/devices?latest_apk=true');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['status'] == 'success') {
          final filename = data['filename'] as String;
          final regExp = RegExp(r'HealthPort_([0-9\.]+)\.apk');
          final match = regExp.firstMatch(filename);
          if (match != null) {
            final serverVersion = match.group(1)!;
            final localVersion = AppConfig.appVersion;
            if (_isVersionNewer(localVersion, serverVersion)) {
              if (mounted) {
                setState(() {
                  _hasUpdate = true;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[Update Check] Failed to check for update: $e');
    }
  }

  bool _isVersionNewer(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();
      final length = currentParts.length > latestParts.length 
          ? currentParts.length 
          : latestParts.length;
      for (int i = 0; i < length; i++) {
        final currentVal = i < currentParts.length ? currentParts[i] : 0;
        final latestVal = i < latestParts.length ? latestParts[i] : 0;
        if (latestVal > currentVal) return true;
        if (currentVal > latestVal) return false;
      }
    } catch (_) {
      return current != latest;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: getSettingsTheme(context),
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
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '설정',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                
                // 설정 목록
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSectionHeader('테스터 프로필 정보'),
                      const SizedBox(height: 8),
                      _buildMenuCard(
                        title: '테스터 프로필 설정',
                        subtitle: '닉네임 정보를 수정합니다.',
                        icon: Icons.person_rounded,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            InstantPageRoute(
                              page: ProfileEditPage(
                                initialName: _name,
                                initialHeight: _height,
                                initialWeight: _weight,
                              ),
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              _name = result['name'];
                              _height = result['height'];
                              _weight = result['weight'];
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildMenuCard(
                        title: '착용 워치 설정',
                        subtitle: '테스트 시 착용하는 갤럭시 워치 모델을 선택합니다.',
                        icon: Icons.watch_rounded,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            InstantPageRoute(
                              page: WatchEditPage(
                                initialWatch: _watch,
                                initialCustomWatch: _customWatch,
                              ),
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              _watch = result['watch'];
                              _customWatch = result['customWatch'];
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildMenuCard(
                        title: '착용 스트랩 설정',
                        subtitle: '테스트 시 사용하는 스트랩 종류를 선택합니다.',
                        icon: Icons.style_rounded,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            InstantPageRoute(
                              page: StrapEditPage(
                                initialStrap: _strap,
                                initialCustomStrap: _customStrap,
                              ),
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              _strap = result['strap'];
                              _customStrap = result['customStrap'];
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('추가 애플리케이션 설치'),
                      const SizedBox(height: 8),
                      _buildMenuCard(
                        title: 'Cola Manager 설치',
                        subtitle: 'Cola Manager(APK) 최신버전을 스마트폰에 다운로드하고 설치합니다.',
                        icon: Icons.install_mobile_rounded,
                        onTap: () {
                          _downloadAndInstallApk(
                            defaultFileName: 'GPT_com_sec_cola_release_1_2_5_phone.apk',
                            defaultUrlPath: '/static/apks/GPT_com_sec_cola_release_1_2_5_phone.apk',
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuCard(
                        title: 'HealthPort 업데이트',
                        subtitle: 'HealthPort(APK) 최신버전을 스마트폰에 다운로드하고 설치합니다.',
                        icon: Icons.system_update_rounded,
                        showBadge: _hasUpdate,
                        isHighlighted: _blinkHighlightActive,
                        onTap: () {
                          _downloadAndInstallApk(
                            latestApkApiUrl: '${AppConfig.apiUrl}/api/devices?latest_apk=true',
                            defaultFileName: 'HealthPort_${AppConfig.appVersion}.apk',
                            defaultUrlPath: '/static/apks/HealthPort_${AppConfig.appVersion}.apk',
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('HealthPort 버전'),
                      const SizedBox(height: 8),
                      _buildVersionCard(
                        title: 'HealthPort 버전',
                        subtitle: 'HealthPort ${AppConfig.appVersion}',
                        icon: Icons.info_outline_rounded,
                      ),
                    ],
                  ),
                ),

                // 하단 저장 버튼
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saveAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E5BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        '변경사항 저장',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _downloadAndInstallApk({
    String? latestApkApiUrl,
    required String defaultFileName,
    required String defaultUrlPath,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return DownloadDialog(
          latestApkApiUrl: latestApkApiUrl,
          defaultFileName: defaultFileName,
          defaultUrlPath: defaultUrlPath,
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFE2E2E2).withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool showBadge = false,
    bool isHighlighted = false,
  }) {
    return _GlassCard(
      borderColor: isHighlighted
          ? (_blinkState ? const Color(0xFF3DFFC1) : const Color(0xFF2E5BFF))
          : null,
      backgroundColor: isHighlighted
          ? (_blinkState ? const Color(0xFF3DFFC1).withOpacity(0.12) : const Color(0xFF2E5BFF).withOpacity(0.08))
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Icon(icon, color: const Color(0xFF3DFFC1), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (showBadge) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'N',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.4), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Icon(icon, color: const Color(0xFF3DFFC1), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 1. 프로필 수정 페이지 ──────────────────────────────────────────
class ProfileEditPage extends StatefulWidget {
  final String initialName;
  final double? initialHeight;
  final double? initialWeight;

  const ProfileEditPage({
    super.key,
    required this.initialName,
    required this.initialHeight,
    required this.initialWeight,
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _heightCtrl = TextEditingController(
        text: widget.initialHeight != null ? widget.initialHeight!.toStringAsFixed(1) : '');
    _weightCtrl = TextEditingController(
        text: widget.initialWeight != null ? widget.initialWeight!.toStringAsFixed(1) : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _onSave() async {
    if (_formKey.currentState!.validate()) {
      final nickname = _nameCtrl.text.trim();
      if (nickname != widget.initialName) {
        try {
          final url = Uri.parse('${AppConfig.apiUrl}/api/devices?check_nickname=${Uri.encodeComponent(nickname)}');
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final res = jsonDecode(response.body);
            if (res['status'] == 'success' && res['exists'] == true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('이미 등록된 닉네임입니다. 다른 닉네임을 입력해 주세요.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
              return;
            }
          }
        } catch (e) {
          debugPrint('닉네임 중복 검사 실패: $e');
        }
      }
      
      if (mounted) {
        Navigator.pop(context, {
          'name': nickname,
          'height': double.tryParse(_heightCtrl.text) ?? 0.0,
          'weight': double.tryParse(_weightCtrl.text) ?? 0.0,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: getSettingsTheme(context),
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
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '프로필 수정',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
  
                // 본문
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '닉네임 수정',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: '닉네임',
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? '닉네임을 입력해주세요' : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
  
                // 하단 완료 버튼
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E5BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 2. 워치 수정 페이지 ─────────────────────────────────────────────
class WatchEditPage extends StatefulWidget {
  final String initialWatch;
  final String initialCustomWatch;

  const WatchEditPage({
    super.key,
    required this.initialWatch,
    required this.initialCustomWatch,
  });

  @override
  State<WatchEditPage> createState() => _WatchEditPageState();
}

class _WatchEditPageState extends State<WatchEditPage> {
  late String _selectedWatch;
  late TextEditingController _customWatchCtrl;

  @override
  void initState() {
    super.initState();
    _selectedWatch = widget.initialWatch;
    _customWatchCtrl = TextEditingController(text: widget.initialCustomWatch);
  }

  @override
  void dispose() {
    _customWatchCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    Navigator.pop(context, {
      'watch': _selectedWatch,
      'customWatch': _customWatchCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: getSettingsTheme(context),
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
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '착용 워치 수정',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
  
                // 본문
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '보유 중인 갤럭시 워치 모델',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ...kWatchOptions.map((model) {
                              return RadioListTile<String>(
                                title: Text(
                                  model,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _selectedWatch == model
                                        ? const Color(0xFF3DFFC1)
                                        : Colors.white,
                                  ),
                                ),
                                value: model,
                                groupValue: _selectedWatch,
                                activeColor: Colors.white,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _selectedWatch = v);
                                  }
                                },
                              );
                            }),
                            if (_selectedWatch == '직접입력') ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _customWatchCtrl,
                                decoration: const InputDecoration(
                                  labelText: '기기명 직접 입력',
                                  hintText: '예: Galaxy Watch Active 2',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
  
                // 하단 완료 버튼
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E5BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 3. 스트랩 수정 페이지 ─────────────────────────────────────────────
class StrapEditPage extends StatefulWidget {
  final String initialStrap;
  final String initialCustomStrap;

  const StrapEditPage({
    super.key,
    required this.initialStrap,
    required this.initialCustomStrap,
  });

  @override
  State<StrapEditPage> createState() => _StrapEditPageState();
}

class _StrapEditPageState extends State<StrapEditPage> {
  late String _selectedStrap;
  late TextEditingController _customStrapCtrl;

  @override
  void initState() {
    super.initState();
    _selectedStrap = widget.initialStrap;
    _customStrapCtrl = TextEditingController(text: widget.initialCustomStrap);
  }

  @override
  void dispose() {
    _customStrapCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    Navigator.pop(context, {
      'strap': _selectedStrap,
      'customStrap': _customStrapCtrl.text.trim(),
    });
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: getSettingsTheme(context),
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
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '착용 스트랩 수정',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
  
                // 본문
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
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
                              ...kStrapOptions
                                  .where((opt) => opt['name'] == '기본 스트랩' || opt['name'] == '직접입력')
                                  .map((strapOpt) {
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
                                            if (strapName == '기본 스트랩') ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF3DFFC1).withOpacity(0.15),
                                                  border: Border.all(color: const Color(0xFF3DFFC1), width: 1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  '추천',
                                                  style: TextStyle(
                                                    color: Color(0xFF3DFFC1),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
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
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: TextField(
                                controller: _customStrapCtrl,
                                decoration: const InputDecoration(
                                  labelText: '스트랩 정보 직접 입력',
                                  hintText: '예: 메탈 체인 스트랩',
                                ),
                              ),
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
                              ...kStrapOptions
                                  .where((opt) => opt['name'] != '기본 스트랩' && opt['name'] != '직접입력')
                                  .map((strapOpt) {
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
                    ),
                  ),
                ),
  
                // 하단 완료 버튼
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E5BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 공통 글래스 카드 ──────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final Color? backgroundColor;

  const _GlassCard({
    required this.child,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.08),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class InstantPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  InstantPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
        );
}

class DownloadDialog extends StatefulWidget {
  final String? latestApkApiUrl;
  final String defaultFileName;
  final String defaultUrlPath;

  const DownloadDialog({
    super.key,
    this.latestApkApiUrl,
    required this.defaultFileName,
    required this.defaultUrlPath,
  });

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  double _progress = 0.0;
  String _progressText = '준비 중...';
  final CancelToken _cancelToken = CancelToken();

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    try {
      final dio = Dio();
      String fileName = widget.defaultFileName;
      String urlPath = widget.defaultUrlPath;

      if (widget.latestApkApiUrl != null) {
        setState(() {
          _progressText = '최신 업데이트 정보 조회 중...';
        });
        final response = await dio.get(widget.latestApkApiUrl!);
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data['status'] == 'success') {
            fileName = data['filename'];
            urlPath = data['url'];
          }
        }
      }

      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$fileName';

      // Ensure directory exists
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      final fullUrl = urlPath.startsWith('http')
          ? urlPath
          : '${AppConfig.apiUrl}$urlPath';

      await dio.download(
        fullUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final double p = received / total;
            final double receivedMb = received / (1024 * 1024);
            final double totalMb = total / (1024 * 1024);
            setState(() {
              _progress = p;
              _progressText = '${receivedMb.toStringAsFixed(1)} MB / ${totalMb.toStringAsFixed(1)} MB (${(p * 100).toStringAsFixed(0)}%)';
            });
          } else {
            setState(() {
              _progressText = '다운로드 중... (${(received / (1024 * 1024)).toStringAsFixed(1)} MB)';
            });
          }
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // Close dialog

      // Open the downloaded file to install
      final result = await OpenFilex.open(savePath);
      debugPrint('[APK Install] Open file result: ${result.message}');
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('설치 관리자를 실행할 수 없습니다: ${result.message}'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      if (e is DioException && e.type == DioExceptionType.cancel) {
        debugPrint('[APK Install] Download cancelled.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('다운로드 실패: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2020),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.downloading_rounded, color: Color(0xFF3DFFC1), size: 40),
            const SizedBox(height: 16),
            const Text(
              '부속 도구 설치 파일 다운로드',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E5BFF)),
            ),
            const SizedBox(height: 12),
            Text(
              _progressText,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _cancelToken.cancel();
                Navigator.pop(context);
              },
              child: const Text('취소', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }
}
