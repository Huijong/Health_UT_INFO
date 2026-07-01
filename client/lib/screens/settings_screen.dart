import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:client/services/prefs_service.dart';
import 'package:client/screens/home_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
  const SettingsScreen({super.key, required this.prefs});

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
  }

  Future<void> _saveAll() async {
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
                          '설정 메뉴',
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
                
                // 설정 메뉴 목록
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildMenuCard(
                        title: '1. 테스터 프로필 설정',
                        subtitle: '이름, 키, 몸무게 정보를 수정합니다.',
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
                        title: '2. 착용 워치 설정',
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
                        title: '3. 착용 스트랩 설정',
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

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _GlassCard(
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
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.4), size: 16),
            ],
          ),
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

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'name': _nameCtrl.text.trim(),
        'height': double.tryParse(_heightCtrl.text),
        'weight': double.tryParse(_weightCtrl.text),
      });
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
                                '테스터 인적 사항',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: '이름',
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력해주세요' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _heightCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                decoration: const InputDecoration(
                                  labelText: '키 (cm)',
                                  prefixIcon: Icon(Icons.height_rounded, size: 20),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return '키를 입력해주세요';
                                  if (double.tryParse(v) == null) return '올바른 숫자를 입력해주세요';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _weightCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                decoration: const InputDecoration(
                                  labelText: '몸무게 (kg)',
                                  prefixIcon: Icon(Icons.monitor_weight_outlined, size: 20),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return '몸무게를 입력해주세요';
                                  if (double.tryParse(v) == null) return '올바른 숫자를 입력해주세요';
                                  return null;
                                },
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
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 16),
                          child: Text(
                            '테스트 중인 워치 스트랩 종류',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              ...kStrapOptions.map((strapOpt) {
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
                        if (_selectedStrap == '직접입력') ...[
                          const SizedBox(height: 16),
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
