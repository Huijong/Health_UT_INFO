import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../services/prefs_service.dart';

class RankingScreen extends StatefulWidget {
  final PrefsService prefs;

  const RankingScreen({super.key, required this.prefs});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late List<String> _months;
  late String _selectedMonth;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _rankings = [];
  Map<String, dynamic> _meta = {};

  @override
  void initState() {
    super.initState();
    _months = _getRecentMonths();
    _selectedMonth = _months.first;
    _fetchRankings();
  }

  List<String> _getRecentMonths() {
    final start = DateTime(2026, 7, 1);
    final now = DateTime.now();
    if (now.isBefore(start)) {
      return ['2026-07'];
    }
    final list = <String>[];
    var temp = DateTime(now.year, now.month, 1);
    while (temp.isAfter(start) || temp.isAtSameMomentAs(start)) {
      final mStr = "${temp.year}-${temp.month.toString().padLeft(2, '0')}";
      list.add(mStr);
      temp = DateTime(temp.year, temp.month - 1, 1);
    }
    return list;
  }

  Future<void> _fetchRankings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = Dio();
      final url = '${AppConfig.apiUrl}/api/devices';
      final response = await dio.get(
        url,
        queryParameters: {
          'rankings': 'true',
          'month': _selectedMonth,
          'tester_name': widget.prefs.name.trim(),
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final res = response.data;
        if (res['status'] == 'success') {
          setState(() {
            _rankings = res['data']['rankings'] ?? [];
            _meta = res['data']['meta'] ?? {};
            _isLoading = false;
          });
          return;
        }
      }
      throw Exception(response.data?['message'] ?? '서버 응답이 올바르지 않습니다.');
    } catch (e) {
      setState(() {
        _errorMessage = '랭킹 정보를 불러오지 못했습니다.\n$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 월별 가로 필터 선택기
        _buildMonthSelector(),
        
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3DFFC1)),
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchRankings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E5BFF),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchRankings,
                      color: const Color(0xFF3DFFC1),
                      backgroundColor: const Color(0xFF1E2020),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        children: [
                          // 상단 요약 보드
                          _buildSummaryBoard(),
                          const SizedBox(height: 16),
                          
                          // 내 랭킹 하이라이트 카드
                          _buildMyRankHighlightCard(),
                          const SizedBox(height: 24),
                          
                          // 랭킹 리스트 타이틀 및 포디움 / 목록
                          if (_rankings.isEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 12),
                              child: Text(
                                '전체 순위',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text(
                                  '해당 월의 수집 데이터가 없습니다.',
                                  style: TextStyle(color: Colors.white38, fontSize: 14),
                                ),
                              ),
                            ),
                          ] else ...[
                            _buildPodiumWidget(),
                            const SizedBox(height: 24),
                            
                            if (_rankings.length > 3) ...[
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 12),
                                child: Text(
                                  '전체 순위 (4위 ~)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              ...List.generate(_rankings.length - 3, (index) {
                                final actualIndex = index + 3;
                                final item = _rankings[actualIndex];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildRankingItem(item, actualIndex),
                                );
                              }),
                            ],
                          ],
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _months.length,
        itemBuilder: (context, index) {
          final m = _months[index];
          final isSelected = m == _selectedMonth;
          
          final yr = m.substring(2, 4);
          final mon = m.substring(5, 7);
          final label = '$yr년 $mon월';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedMonth = m;
                  });
                  _fetchRankings();
                }
              },
              selectedColor: const Color(0xFF3DFFC1),
              backgroundColor: Colors.white.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF3DFFC1) : Colors.white.withOpacity(0.08),
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryBoard() {
    final totalTesters = _meta['total_testers'] ?? 0;
    final avgSubmissions = _meta['avg_submissions'] ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                children: [
                  const Text('전체 인원', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 6),
                  Text(
                    '$totalTesters명',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3DFFC1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                children: [
                  const Text('평균 포인트', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatPoints(avgSubmissions)}P',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3DFFC1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: _showRankingRulesDialog,
            child: _GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Column(
                  children: [
                    const Text('랭킹 기준', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF3DFFC1)),
                        SizedBox(width: 4),
                        Text(
                          '상세 보기',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3DFFC1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRankingRulesDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return DefaultTabController(
              length: 3,
              child: Dialog(
                backgroundColor: const Color(0xFF161819),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Row(
                          children: const [
                            Icon(Icons.stars_rounded, color: Color(0xFF3DFFC1), size: 24),
                            SizedBox(width: 8),
                            Text(
                              '포인트 적립 기준 안내',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tab Bar (Text Only for saving space)
                      const TabBar(
                        indicatorColor: Color(0xFF3DFFC1),
                        labelColor: Color(0xFF3DFFC1),
                        unselectedLabelColor: Colors.white38,
                        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        tabs: [
                          Tab(text: '러닝/걷기/하이킹'),
                          Tab(text: '실외 자전거'),
                          Tab(text: '기타 모든 운동'),
                        ],
                      ),
                      // Tab Content
                      SizedBox(
                        height: 430,
                        child: TabBarView(
                          children: [
                            _buildGroupARules(),
                            _buildGroupBRules(),
                            _buildOtherExerciseRules(),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      // Footer Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF3DFFC1),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupARules() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildInfoBox('💡 아래 거리별 예시값은 건당 [기본 점수 1.0P (하이킹 3.0P)]가 미리 합산되어 최종 수령할 총 포인트 기준입니다.'),
        const SizedBox(height: 16),
        _buildTableHeader(),
        _buildTableItem('1 ~ 10 km', '1km당 +0.1P', '10km = 2.00P'),
        _buildTableItem('11 ~ 20 km', '1km당 +0.15P', '20km = 3.50P'),
        _buildTableItem('21 ~ 30 km', '1km당 +0.2P', '30km = 5.50P'),
        _buildTableItem('31 ~ 40 km', '1km당 +0.3P', '40km = 8.50P'),
        _buildTableItem('41 ~ 99 km', '40~100km 구간 등간격 가산', '41km=8.71P ... 99km=20.79P'),
        _buildTableItem('100 km 이상', '기본 20.0P + 1km당 +0.2P', '110km = 23.00P'),
      ],
    );
  }

  Widget _buildGroupBRules() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildInfoBox('💡 아래 거리별 예시값은 건당 [기본 점수 1.0P]가 미리 합산되어 최종 수령할 총 포인트 기준입니다.'),
        const SizedBox(height: 16),
        _buildTableHeader(),
        _buildTableItem('1 ~ 40 km', '1km당 +0.1P', '40km = 5.00P'),
        _buildTableItem('41 ~ 50 km', '1km당 +0.1P', '50km = 6.00P'),
        _buildTableItem('51 ~ 99 km', '50~100km 구간 등간격 가산', '51km=6.14P ... 99km=12.86P'),
        _buildTableItem('100 km 이상', '기본 12.0P + 1km당 +0.16P', '110km = 14.60P'),
      ],
    );
  }

  Widget _buildOtherExerciseRules() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildInfoBox('💡 수영, 근력 운동, 요가 등 기타 종목 대상\n💡 기본 점수 외에 거리 가산은 제외됩니다.'),
        const SizedBox(height: 16),
        _buildTableHeader(),
        _buildTableItem('수영 (실내/외)', '건당 +1.00P 고정', '활동당 1.00P'),
        _buildTableItem('근력 운동', '건당 +1.00P 고정', '활동당 1.00P'),
        _buildTableItem('기타 웰니스', '건당 +1.00P 고정', '활동당 1.00P'),
        _buildTableItem('마스터 특별(JY)', '수동 가감에 따른 보너스', '지정된 가산P'),
      ],
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2E5BFF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E5BFF).withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF8AB4F8), fontSize: 12, height: 1.5, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('거리 구간', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 4, child: Text('구간 가산 규칙', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text('예시 값', textAlign: TextAlign.right, style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildTableItem(String range, String rule, String example) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(range, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(flex: 4, child: Text(rule, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11))),
          Expanded(flex: 3, child: Text(example, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF3DFFC1), fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildMyRankHighlightCard() {
    final myRank = _meta['my_rank'];
    final myCount = _meta['my_count'] ?? 0;
    final mySubmissions = _meta['my_submissions'] ?? 0;
    final nextRank = _meta['next_rank'];

    final myName = widget.prefs.name.trim();

    if (myRank == null) {
      return Container();
    }

    String medalEmoji = '';
    if (myRank == 1) medalEmoji = '🥇';
    else if (myRank == 2) medalEmoji = '🥈';
    else if (myRank == 3) medalEmoji = '🥉';

    String rankText = medalEmoji.isNotEmpty ? '$medalEmoji 공동 $myRank위' : '$myRank위';
    
    String motivationText = '';
    if (myRank == 1) {
      motivationText = '대단합니다! 명예로운 1위 자리를 굳건히 지키고 있습니다! 🏆';
    } else if (nextRank != null) {
      final aboveName = nextRank['tester_name'] ?? '상위 랭커';
      final diff = nextRank['diff'] ?? 0;
      final aboveRank = nextRank['rank'] ?? 1;
      
      String targetMedal = '';
      if (aboveRank == 1) targetMedal = '🥇';
      else if (aboveRank == 2) targetMedal = '🥈';
      else if (aboveRank == 3) targetMedal = '🥉';

      final rankName = targetMedal.isNotEmpty ? '$targetMedal $aboveRank위' : '$aboveRank위';
      motivationText = '$myName님은 현재 공동 $myRank위입니다. $rankName ($aboveName님)까지 앞으로 단 ${_formatPoints(diff)}포인트 남았습니다! 조금만 더 힘내세요! 🔥';
    } else {
      motivationText = '첫 제출을 완료하셨네요! 상위 랭킹을 향해 조금 더 도전해 보세요! 🚀';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2E5BFF).withOpacity(0.35),
            const Color(0xFF1429A0).withOpacity(0.1),
            const Color(0xFF3DFFC1).withOpacity(0.05),
          ],
        ),
        border: Border.all(color: const Color(0xFF2E5BFF).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E5BFF).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$myName님의 랭킹',
                      style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rankText,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3DFFC1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3DFFC1).withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_formatPoints(myCount)}포인트 ($mySubmissions건)',
                    style: const TextStyle(
                      color: Color(0xFF3DFFC1),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.white.withOpacity(0.1), height: 1),
            const SizedBox(height: 14),
            Text(
              motivationText,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumWidget() {
    final rank1 = _rankings.isNotEmpty ? _rankings[0] : null;
    final rank2 = _rankings.length > 1 ? _rankings[1] : null;
    final rank3 = _rankings.length > 2 ? _rankings[2] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '명예의 전당 (Top 3)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),
        _GlassCard(
          child: Padding(
            padding: const EdgeInsets.only(top: 28, bottom: 16, left: 12, right: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildPodiumColumn(rank2, 2, 60),
                _buildPodiumColumn(rank1, 1, 85),
                _buildPodiumColumn(rank3, 3, 50),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumColumn(dynamic item, int rank, double barHeight) {
    if (item == null) {
      return Expanded(
        child: Opacity(
          opacity: 0.15,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: rank == 1 ? 28 : 24,
                backgroundColor: Colors.white10,
                child: const Text('-', style: TextStyle(color: Colors.white30)),
              ),
              const SizedBox(height: 8),
              const Text('-', style: TextStyle(color: Colors.white30, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                height: barHeight,
                width: 60,
                decoration: const BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final name = item['tester_name'] ?? '';
    final points = item['points'] ?? 0;
    final submissions = item['submissions'] ?? 0;
    final isMe = name == widget.prefs.name.trim();

    Color themeColor;
    Color glowColor;
    String badgeEmoji;
    double avatarRadius;

    if (rank == 1) {
      themeColor = const Color(0xFFFFD700); // Gold
      glowColor = const Color(0xFFFFD700).withOpacity(0.2);
      badgeEmoji = '👑';
      avatarRadius = 28;
    } else if (rank == 2) {
      themeColor = const Color(0xFFC0C0C0); // Silver
      glowColor = Colors.white.withOpacity(0.1);
      badgeEmoji = '🥈';
      avatarRadius = 24;
    } else {
      themeColor = const Color(0xFFCD7F32); // Bronze
      glowColor = const Color(0xFFCD7F32).withOpacity(0.15);
      badgeEmoji = '🥉';
      avatarRadius = 24;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _showTesterHistory(name),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: isMe ? const Color(0xFF3DFFC1) : themeColor.withOpacity(0.15),
              child: CircleAvatar(
                radius: avatarRadius - 2,
                backgroundColor: const Color(0xFF1E2020),
                child: Text(
                  rank == 1
                      ? '🥇'
                      : rank == 2
                          ? '🥈'
                          : '🥉',
                  style: TextStyle(
                    fontSize: rank == 1 ? 22 : 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                color: isMe ? const Color(0xFF3DFFC1) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_formatPoints(points)}P (${submissions}건)',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: barHeight,
            width: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  themeColor.withOpacity(0.4),
                  themeColor.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(
                color: themeColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: rank == 1 ? 18 : 14,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }


  Widget _buildRankingItem(dynamic item, int index) {
    final name = item['tester_name'] ?? '알 수 없음';
    final points = item['points'] ?? 0;
    final submissions = item['submissions'] ?? 0;
    final rank = item['rank'] ?? (index + 1);
    final change = item['change'] ?? '0';

    final isMe = name == widget.prefs.name.trim();

    Widget rankWidget;
    if (rank == 1) {
      rankWidget = const Text('🥇', style: TextStyle(fontSize: 22));
    } else if (rank == 2) {
      rankWidget = const Text('🥈', style: TextStyle(fontSize: 22));
    } else if (rank == 3) {
      rankWidget = const Text('🥉', style: TextStyle(fontSize: 22));
    } else {
      rankWidget = Container(
        width: 24,
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white60),
        ),
      );
    }

    Widget changeWidget;
    if (change == 'new') {
      changeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFF2E5BFF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF2E5BFF).withOpacity(0.4), width: 0.8),
        ),
        child: const Text(
          'NEW',
          style: TextStyle(color: Color(0xFF5E8BFF), fontSize: 9, fontWeight: FontWeight.bold),
        ),
      );
    } else if (change.startsWith('+')) {
      changeWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_drop_up_rounded, color: Color(0xFF10B981), size: 18),
          Text(
            change.substring(1),
            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
          )
        ],
      );
    } else if (change.startsWith('-') && change != '0') {
      changeWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFEF4444), size: 18),
          Text(
            change.substring(1),
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
          )
        ],
      );
    } else {
      changeWidget = const Text(
        '-',
        style: TextStyle(color: Colors.white30, fontSize: 13),
      );
    }

    return GestureDetector(
      onTap: () => _showTesterHistory(name),
      child: _GlassCard(
        borderColor: isMe ? const Color(0xFF3DFFC1).withOpacity(0.5) : null,
        backgroundColor: isMe ? const Color(0xFF3DFFC1).withOpacity(0.04) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              rankWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        color: isMe ? const Color(0xFF3DFFC1) : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    changeWidget,
                  ],
                ),
              ),
              Text(
                '$submissions건 / ${_formatPoints(points)}포인트',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                  color: isMe ? const Color(0xFF3DFFC1) : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTesterHistory(String testerName) async {
    if (testerName.isEmpty || testerName == '알 수 없음') return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3DFFC1),
        ),
      ),
    );

    List<dynamic> history = [];
    try {
      final dio = Dio();
      final response = await dio.get(
        '${AppConfig.apiUrl}/api/devices',
        queryParameters: {
          'points_history': 'true',
          'tester_name': testerName.trim(),
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        if (response.data['status'] == 'success') {
          history = response.data['data'] ?? [];
        }
      }
    } catch (e) {
      debugPrint('[History] Error fetching points history: $e');
    }

    if (!mounted || !context.mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

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
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
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
                  Expanded(
                    child: Text(
                      '$testerName님의 포인트 내역',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: history.isEmpty
                    ? const Center(
                        child: Text(
                          '적립된 포인트 이력이 없습니다.',
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.white.withOpacity(0.06),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final item = history[index];
                          final points = item['points'] ?? 0;
                          final memo = item['memo'] ?? '';
                          final createdAt = item['created_at'] ?? '';
                          final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;

                          final isPositive = points >= 0;
                          final pointsStr = isPositive ? '+${_formatPoints(points)} P' : '${_formatPoints(points)} P';
                          final pointsColor = isPositive ? const Color(0xFF3DFFC1) : Colors.redAccent;
                          final isBigBonus = points >= 4;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        memo,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isBigBonus) ...[
                                      const Text('🔥 ', style: TextStyle(fontSize: 14)),
                                    ],
                                    Text(
                                      pointsStr,
                                      style: TextStyle(
                                        color: pointsColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF3DFFC1), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '포인트는 [기본 점수 1.0P(하이킹 3.0P) + 거리별 보너스 가산P]가 합산되어 자동 적립됩니다. (예: 10km 완주 시 2.00P)',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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

String _formatPoints(dynamic value) {
  if (value == null) return "0.00";
  if (value is num) {
    return value.toStringAsFixed(2);
  }
  final double? parsed = double.tryParse(value.toString());
  if (parsed != null) {
    return parsed.toStringAsFixed(2);
  }
  return value.toString();
}
