import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:client/services/prefs_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:client/config/app_config.dart';
import 'package:client/screens/lab_watch_sync_screen.dart';
import 'package:client/config/options.dart';

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
  final bool showEmailGuide;
  const SettingsScreen({
    super.key, 
    required this.prefs, 
    this.highlightUpdate = false,
    this.showEmailGuide = false,
  });

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
    
    if (widget.showEmailGuide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openProfileEditPage(showGuide: true);
      });
    }

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

  Future<void> _openProfileEditPage({bool showGuide = false}) async {
    final result = await Navigator.push(
      context,
      InstantPageRoute(
        page: ProfileEditPage(
          initialName: _name,
          initialHeight: _height,
          initialWeight: _weight,
          initialEmail: widget.prefs.googleEmail,
          showEmailGuide: showGuide,
          prefs: widget.prefs,
        ),
      ),
    );
    if (result != null) {
      final newName = result['name'].toString().trim();
      final oldName = _name.trim();
      final newEmail = (result['email'] ?? '').toString().trim();
      final oldEmail = widget.prefs.googleEmail.trim();

      if (newName.isNotEmpty && oldName.isNotEmpty && (oldName != newName || oldEmail != newEmail)) {
        try {
          final dio = Dio();
          final response = await dio.post(
            '${AppConfig.apiUrl}/api/devices',
            queryParameters: {'rename': 'true'},
            data: {
              'old_name': oldName,
              'new_name': newName,
              'email': newEmail,
              'watch': _watch,
              'custom_watch': _customWatch,
              'strap': _strap,
              'custom_strap': _customStrap,
              'height': double.tryParse(result['height'].toString()) ?? 0.0,
              'weight': double.tryParse(result['weight'].toString()) ?? 0.0,
            },
          );
          if (response.data['status'] == 'success') {
            await widget.prefs.saveName(newName);
            await widget.prefs.saveGoogleEmail(newEmail);
            setState(() {
              _name = newName;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('프로필이 성공적으로 변경되었습니다.'),
                  backgroundColor: Color(0xFF3DFFC1),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('[Rename Error] $e');
        }
      } else {
        await widget.prefs.saveHeight(double.tryParse(result['height'].toString()) ?? 0.0);
        await widget.prefs.saveWeight(double.tryParse(result['weight'].toString()) ?? 0.0);
        setState(() {
          _height = double.tryParse(result['height'].toString());
          _weight = double.tryParse(result['weight'].toString());
        });
      }
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
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          Navigator.pop(context, true);
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
                          onPressed: () => Navigator.pop(context, true),
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
                      _buildSectionHeader('프로필 정보'),
                      const SizedBox(height: 8),
                      _buildMenuCard(
                        title: '프로필 설정',
                        subtitle: '닉네임 정보를 수정합니다.',
                        icon: Icons.person_rounded,
                        onTap: () => _openProfileEditPage(),
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
                            final newWatch = result['watch'];
                            final newCustomWatch = result['customWatch'];

                            await widget.prefs.saveWatch(newWatch);
                            await widget.prefs.saveCustomWatch(newCustomWatch);

                            setState(() {
                              _watch = newWatch;
                              _customWatch = newCustomWatch;
                            });

                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('착용 워치 설정이 저장되었습니다.'),
                                  backgroundColor: Color(0xFF3DFFC1),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
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
                            final newStrap = result['strap'];
                            final newCustomStrap = result['customStrap'];

                            await widget.prefs.saveStrap(newStrap);
                            await widget.prefs.saveCustomStrap(newCustomStrap);

                            setState(() {
                              _strap = newStrap;
                              _customStrap = newCustomStrap;
                            });

                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('착용 스트랩 설정이 저장되었습니다.'),
                                  backgroundColor: Color(0xFF3DFFC1),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
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
                        onTap: _handleHealthPortUpdate,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('실험실'),
                      const SizedBox(height: 8),
                      _buildMenuCard(
                        title: '실험실',
                        subtitle: '워치 연동, 모바일 핫스팟, SysDump 등 연구/검증 기능 목록으로 이동합니다.',
                        icon: Icons.biotech_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LabSubScreen(prefs: widget.prefs),
                            ),
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
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _handleHealthPortUpdate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2020),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3DFFC1)),
              ),
              SizedBox(height: 16),
              Text(
                '최신 버전 확인 중...',
                style: TextStyle(color: Colors.white, fontSize: 14, decoration: TextDecoration.none),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final dio = Dio();
      final response = await dio.get('${AppConfig.apiUrl}/api/devices?latest_apk=true');
      if (mounted) Navigator.pop(context); // Dismiss loading dialog

      String? serverVersion;
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['status'] == 'success') {
          final filename = data['filename'] as String;
          final regExp = RegExp(r'HealthPort_([0-9\.]+)\.apk');
          final match = regExp.firstMatch(filename);
          if (match != null) {
            serverVersion = match.group(1)!;
            final localVersion = AppConfig.appVersion;
            
            if (serverVersion == localVersion) {
              if (mounted) {
                _showUpdateNotNeededDialog(localVersion);
              }
              return;
            }
          }
        }
      }
      
      if (serverVersion != null) {
        _showPlayStoreUpdateDialog(serverVersion);
      } else {
        _showPlayStoreErrorDialog();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading if error
      _showPlayStoreErrorDialog();
    }
  }

  void _showPlayStoreUpdateDialog(String serverVersion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '업데이트 안내',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '새로운 버전(v$serverVersion)이 등록되었습니다.\n구글 플레이 스토어로 이동하여 업데이트를 진행해 주세요.',
          style: const TextStyle(color: Color(0xFFE2E2E2)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchPlayStore();
            },
            child: const Text(
              '업데이트',
              style: TextStyle(color: Color(0xFF3DFFC1), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayStoreErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '업데이트 안내',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '최신 버전을 확인하지 못했습니다.\n구글 플레이 스토어로 이동하여 업데이트가 있는지 확인하시겠습니까?',
          style: TextStyle(color: Color(0xFFE2E2E2)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchPlayStore();
            },
            child: const Text(
              '확인',
              style: TextStyle(color: Color(0xFF3DFFC1), fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('스토어 링크를 열 수 없습니다.')),
          );
        }
      }
    }
  }

  void _showUpdateNotNeededDialog(String version) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '업데이트 안내',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '현재 설치된 버전($version)과 최신 업데이트 버전이 동일합니다.\n업데이트가 필요하지 않습니다.',
          style: const TextStyle(color: Color(0xFFE2E2E2)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '확인',
              style: TextStyle(color: Color(0xFF3DFFC1), fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
  final String initialEmail;
  final bool showEmailGuide;
  final PrefsService? prefs;

  const ProfileEditPage({
    super.key,
    required this.initialName,
    required this.initialHeight,
    required this.initialWeight,
    required this.initialEmail,
    this.showEmailGuide = false,
    this.prefs,
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _emailCtrl;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late bool _showEmailTooltip;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _heightCtrl = TextEditingController(
        text: widget.initialHeight != null ? widget.initialHeight!.toStringAsFixed(1) : '');
    _weightCtrl = TextEditingController(
        text: widget.initialWeight != null ? widget.initialWeight!.toStringAsFixed(1) : '');
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    
    _showEmailTooltip = widget.showEmailGuide;
    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _bounceAnim = Tween<double>(begin: 0, end: 10).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));
    if (_showEmailTooltip) {
      _bounceCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _emailCtrl.dispose();
    _bounceCtrl.dispose();
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
          'email': _emailCtrl.text.trim(),
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
                                '프로필 정보 수정',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _emailCtrl,
                                      decoration: const InputDecoration(
                                        labelText: '이메일 주소(Gmail) *',
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
                                  const SizedBox(width: 8),
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      SizedBox(
                                        height: 56,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2E5BFF),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: 0,
                                          ),
                                          onPressed: () async {
                                            if (_showEmailTooltip) {
                                              setState(() => _showEmailTooltip = false);
                                              if (widget.prefs != null) {
                                                widget.prefs!.saveEmailMigrationDone(true);
                                              }
                                            }
                                            try {
                                              const appChannel = MethodChannel('com.samsung.health.client/app_info');
                                              final email = await appChannel.invokeMethod<String>('getGoogleEmail');
                                              if (email != null && email.isNotEmpty) {
                                                setState(() {
                                                  _emailCtrl.text = email;
                                                });
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('이메일을 성공적으로 가져왔습니다! 저장해주세요!'),
                                                      backgroundColor: Color(0xFF3DFFC1),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('등록된 구글 계정이 없습니다. 직접 입력해 주세요.'),
                                                      backgroundColor: Colors.orangeAccent,
                                                    ),
                                                  );
                                                }
                                              }
                                            } catch (e) {
                                              debugPrint('[getGoogleEmail Error] $e');
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('이메일을 가져오지 못했습니다. 직접 입력해 주세요.'),
                                                    backgroundColor: Colors.redAccent,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text('자동조회', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      if (_showEmailTooltip)
                                        Positioned(
                                          top: -45,
                                          right: -10,
                                          child: AnimatedBuilder(
                                            animation: _bounceAnim,
                                            builder: (context, child) {
                                              return Transform.translate(
                                                offset: Offset(0, -_bounceAnim.value),
                                                child: child,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3DFFC1),
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF3DFFC1).withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.touch_app, size: 16, color: Color(0xFF0C0F0F)),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    '여기를 눌러 연동!',
                                                    style: TextStyle(
                                                      color: Color(0xFF0C0F0F),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
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
                      child: const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      child: const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        _GlassCard(
                          borderColor: Colors.white.withOpacity(0.08),
                          backgroundColor: Colors.white.withOpacity(0.04),
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
                          _GlassCard(
                            borderColor: Colors.white.withOpacity(0.08),
                            backgroundColor: Colors.white.withOpacity(0.04),
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
                        _GlassCard(
                          borderColor: Colors.white.withOpacity(0.08),
                          backgroundColor: Colors.white.withOpacity(0.04),
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
                        */
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
                      child: const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        String errorMsg = '다운로드 실패: $e';
        if (e is DioException && e.response?.statusCode == 404) {
          errorMsg = '서버에 설치 파일(APK)이 존재하지 않습니다. (404 에러)';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
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
              '설치 파일 다운로드',
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

class LabSubScreen extends StatelessWidget {
  final PrefsService prefs;
  const LabSubScreen({super.key, required this.prefs});

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E5BFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF2E5BFF), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: getSettingsTheme(context),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Custom Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        '실험실',
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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildMenuCard(
                      title: '실험실 (워치 연동)',
                      subtitle: '워치에서 운동 데이터를 고속 무선 LAN(P2P)으로 전송받습니다.',
                      icon: Icons.biotech_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LabWatchSyncScreen(prefs: prefs),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      title: '모바일 핫스팟 설정',
                      subtitle: '스마트폰의 [모바일 핫스팟 및 테더링] 설정 화면으로 즉시 이동합니다.',
                      icon: Icons.wifi_tethering_rounded,
                      onTap: () async {
                        const channel = MethodChannel('com.samsung.health.client/app_info');
                        try {
                          await channel.invokeMethod('openHotspotSettings');
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('핫스팟 설정 화면 이동 실패: $e')),
                          );
                        }
                      },
                    ),
                    _buildMenuCard(
                      title: '*#9900# (SysDump)',
                      subtitle: '갤럭시 전용 시스템 디버그(SysDump) 화면으로 이동합니다.',
                      icon: Icons.bug_report_rounded,
                      onTap: () async {
                        const channel = MethodChannel('com.samsung.health.client/app_info');
                        try {
                          await channel.invokeMethod('openSysDump');
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('SysDump 화면 이동 실패: $e')),
                          );
                        }
                      },
                    ),
                    _buildMenuCard(
                      title: '*#9900# (Watch)',
                      subtitle: '연결된 갤럭시 워치에서 SysDump(다이얼러 진입 가이드) 화면을 엽니다.',
                      icon: Icons.watch_rounded,
                      onTap: () async {
                        const channel = MethodChannel('com.samsung.health.client/app_info');
                        try {
                          final bool result = await channel.invokeMethod('openWatchSysDump');
                          if (result) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('워치에 SysDump 호출 요청을 전송했습니다.')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('페어링된 워치 노드를 찾을 수 없습니다.')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('워치 SysDump 호출 실패: $e')),
                          );
                        }
                      },
                    ),
                    _buildMenuCard(
                      title: '워치 와이파이 자동 연결',
                      subtitle: '블루투스로 연결된 갤럭시 워치가 폰의 핫스팟에 자동 접속하도록 유도합니다.',
                      icon: Icons.wifi_find_rounded,
                      onTap: () async {
                        const channel = MethodChannel('com.samsung.health.client/app_info');
                        try {
                          final bool result = await channel.invokeMethod('requestWatchWifiJoin');
                          if (result) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('워치에 와이파이 가입 요청을 전송했습니다.')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('페어링된 워치 노드를 찾을 수 없습니다.')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('가입 요청 전송 실패: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

