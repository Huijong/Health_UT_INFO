import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/prefs_service.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticeHistoryScreen extends StatefulWidget {
  final PrefsService prefs;
  const NoticeHistoryScreen({super.key, required this.prefs});

  @override
  State<NoticeHistoryScreen> createState() => _NoticeHistoryScreenState();
}

class _NoticeHistoryScreenState extends State<NoticeHistoryScreen> {
  List<dynamic> _notices = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  late List<String> _readIds;
  late List<String> _deletedIds;
  bool _isNewestFirst = true;

  @override
  void initState() {
    super.initState();
    _readIds = List<String>.from(widget.prefs.readNoticeIds);
    _deletedIds = List<String>.from(widget.prefs.deletedNoticeIds);
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/api/notices'));
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded['status'] == 'success') {
          setState(() {
            _notices = decoded['data'] as List<dynamic>;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = decoded['message'] ?? '공지사항을 가져오지 못했습니다.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = '서버 연결 실패 (Status: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '네트워크 연결 오류가 발생했습니다.';
        _isLoading = false;
      });
    }
  }

  void _showNoticeDetail(Map<String, dynamic> notice) {
    final String noticeId = notice['_id'] as String;
    if (!_readIds.contains(noticeId)) {
      setState(() {
        _readIds.add(noticeId);
      });
      widget.prefs.saveReadNoticeIds(_readIds);
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2020).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: Color(0xFFFFD043), size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          '공지사항 상세',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    const SizedBox(height: 8),
                    Text(
                      notice['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        child: _buildLinkifiedText(notice['content'] ?? ''),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E5BFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinkifiedText(String text) {
    final RegExp urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );

    final List<String> parts = [];
    
    Iterable<RegExpMatch> matches = urlRegExp.allMatches(text);
    int lastIndex = 0;
    
    for (RegExpMatch match in matches) {
      if (match.start > lastIndex) {
        parts.add(text.substring(lastIndex, match.start));
      }
      parts.add(text.substring(match.start, match.end));
      lastIndex = match.end;
    }
    
    if (lastIndex < text.length) {
      parts.add(text.substring(lastIndex));
    }
    
    if (parts.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5, fontFamily: 'Roboto'),
        children: parts.map((part) {
          final isUrl = urlRegExp.hasMatch(part);
          if (isUrl) {
            return WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse(part.trim());
                  try {
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('링크를 열 수 없습니다: $part')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('오류 발생: $e')),
                    );
                  }
                },
                child: Text(
                  part,
                  style: const TextStyle(
                    color: Color(0xFF3DFFC1), // bright mint for links
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF3DFFC1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          } else {
            return TextSpan(text: part);
          }
        }).toList(),
      ),
    );
  }

  void _deleteNoticeLocally(String noticeId) {
    setState(() {
      _deletedIds.add(noticeId);
    });
    widget.prefs.saveDeletedNoticeIds(_deletedIds);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('공지사항이 목록에서 삭제되었습니다.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 삭제(숨김) 처리되지 않은 공지만 필터링
    final visibleNotices = _notices.where((n) => !_deletedIds.contains(n['_id'])).toList();

    // 날짜별 정렬 적용
    visibleNotices.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
      final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
      return _isNewestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });

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
          child: Column(
            children: [
              // 커스텀 앱바
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '공지사항 히스토리',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    // 정렬 단축키
                    IconButton(
                      icon: Icon(
                        _isNewestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: const Color(0xFF3DFFC1),
                        size: 20,
                      ),
                      tooltip: _isNewestFirst ? '최신순 (누르면 오래된순)' : '오래된순 (누르면 최신순)',
                      onPressed: () {
                        setState(() {
                          _isNewestFirst = !_isNewestFirst;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isNewestFirst ? '최신순으로 정렬되었습니다. ⬇️' : '오래된순으로 정렬되었습니다. ⬆️'),
                            duration: const Duration(milliseconds: 800),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                      onPressed: _fetchNotices,
                    ),
                  ],
                ),
              ),

              // 본문 내용 영역
              Expanded(
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
                                const Icon(Icons.error_outline_rounded, color: Colors.white60, size: 48),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _fetchNotices,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('다시 시도'),
                                ),
                              ],
                            ),
                          )
                        : visibleNotices.isEmpty
                            ? const Center(
                                child: Text(
                                  '등록된 공지사항이 없습니다.',
                                  style: TextStyle(color: Colors.white60, fontSize: 15),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                itemCount: visibleNotices.length,
                                itemBuilder: (context, index) {
                                  final notice = visibleNotices[index];
                                  final String noticeId = notice['_id'] as String;
                                  final bool isUnread = !_readIds.contains(noticeId);
                                  
                                  // 날짜 가공
                                  String dateStr = '';
                                  if (notice['created_at'] != null) {
                                    try {
                                      final dt = DateTime.parse(notice['created_at']).toLocal();
                                      dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                    } catch (_) {}
                                  }

                                  return Dismissible(
                                    key: Key(noticeId),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20.0),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF5252).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFFF5252)),
                                    ),
                                    onDismissed: (dir) => _deleteNoticeLocally(noticeId),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.04),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isUnread 
                                                    ? const Color(0xFF3DFFC1).withOpacity(0.2)
                                                    : Colors.white.withOpacity(0.06),
                                                width: isUnread ? 1.5 : 1.0,
                                              ),
                                            ),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              title: Row(
                                                children: [
                                                  if (isUnread) ...[
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF3DFFC1).withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: const Color(0xFF3DFFC1), width: 1),
                                                      ),
                                                      child: const Text(
                                                        'N',
                                                        style: TextStyle(fontSize: 9, color: Color(0xFF3DFFC1), fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      notice['title'] ?? '',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(top: 6.0),
                                                child: Text(
                                                  dateStr,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white.withOpacity(0.5),
                                                  ),
                                                ),
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                                                onPressed: () => _deleteNoticeLocally(noticeId),
                                                tooltip: '삭제',
                                              ),
                                              onTap: () => _showNoticeDetail(notice),
                                            ),
                                          ),
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
