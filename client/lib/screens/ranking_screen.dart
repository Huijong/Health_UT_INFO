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
    final now = DateTime.now();
    final list = <String>[];
    for (int i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final mStr = "${d.year}-${d.month.toString().padLeft(2, '0')}";
      list.add(mStr);
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
                          
                          // 랭킹 리스트 타이틀
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
                          
                          // 전체 순위 테이블 목록
                          if (_rankings.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text(
                                  '해당 월의 수집 데이터가 없습니다.',
                                  style: TextStyle(color: Colors.white38, fontSize: 14),
                                ),
                              ),
                            )
                          else
                            ...List.generate(_rankings.length, (index) {
                              final item = _rankings[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildRankingItem(item, index),
                              );
                            }),
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
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Column(
                children: [
                  const Text('전체 인원', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    '$totalTesters명',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3DFFC1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Column(
                children: [
                  const Text('평균 제출', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    '$avgSubmissions건',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3DFFC1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyRankHighlightCard() {
    final myRank = _meta['my_rank'];
    final myCount = _meta['my_count'] ?? 0;
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
      motivationText = '$myName님은 현재 공동 $myRank위입니다. $rankName ($aboveName님)까지 앞으로 단 $diff건 남았습니다! 조금만 더 힘내세요! 🔥';
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
                    '$myCount포인트',
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

  Widget _buildRankingItem(dynamic item, int index) {
    final name = item['tester_name'] ?? '알 수 없음';
    final count = item['count'] ?? 0;
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

    return _GlassCard(
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
              '$count건',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                color: isMe ? const Color(0xFF3DFFC1) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
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
