import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'image_detail_screen.dart';
import '../utils/toast_util.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _myNickname;
  String? _myUserId;
  bool _isMuted = false;
  bool _isUploadingImage = false;
  Timestamp? _latestMessageTimestamp;

  @override
  void initState() {
    super.initState();
    _loadUserConfig();
  }

  @override
  void dispose() {
    _saveLatestTimestamp();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveLatestTimestamp() {
    SharedPreferences.getInstance().then((prefs) {
      if (_latestMessageTimestamp != null) {
        prefs.setInt('last_read_chat_timestamp', _latestMessageTimestamp!.millisecondsSinceEpoch);
      } else {
        prefs.setInt('last_read_chat_timestamp', DateTime.now().millisecondsSinceEpoch);
      }
    });
  }

  Future<void> _loadUserConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String? savedUuid = prefs.getString('device_uuid');
      if (savedUuid == null || savedUuid.trim().isEmpty) {
        savedUuid = 'unknown_id_${Random().nextInt(10000)}';
        prefs.setString('device_uuid', savedUuid);
      }
      _myUserId = savedUuid;

      String? savedName = prefs.getString('tester_name');
      if (savedName == null || savedName.trim().isEmpty) {
        _myNickname = '유저_${Random().nextInt(10000)}';
      } else {
        _myNickname = savedName;
      }

      _isMuted = prefs.getBool('chat_is_muted') ?? false;
    });
  }

  Future<void> _toggleMute() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMuted = !_isMuted;
    });
    await prefs.setBool('chat_is_muted', _isMuted);
    
    if (mounted) {
      ToastUtil.showToast(context, _isMuted ? '채팅 알림을 껐습니다.' : '채팅 알림을 켰습니다.');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _myUserId == null) return;

    _messageController.clear();

    try {
      await FirebaseFirestore.instance.collection('global_chat').add({
        'sender_id': _myUserId,
        'sender_name': _myNickname,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("SendMessage Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메시지 전송 실패 (DB 권한 확인 필요): $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile == null || _myUserId == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      File file = File(pickedFile.path);
      String fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}.jpg';
      
      // Upload to Firebase Storage
      Reference ref = FirebaseStorage.instance.ref().child('chat_images').child(fileName);
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Send message with image URL
      await FirebaseFirestore.instance.collection('global_chat').add({
        'sender_id': _myUserId,
        'sender_name': _myNickname,
        'message': '사진을 보냈습니다.',
        'imageUrl': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      _scrollToBottom();
    } catch (e) {
      debugPrint("Image Upload Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 업로드에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB2C7D9), // 카카오톡 배경색
      appBar: AppBar(
        backgroundColor: const Color(0xFFB2C7D9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'HealthPort 오픈 채팅방',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isMuted ? Icons.notifications_off : Icons.notifications,
              color: Colors.black54,
            ),
            onPressed: _toggleMute,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _myUserId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('global_chat')
                        .orderBy('timestamp', descending: true)
                        .limit(100)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        debugPrint("Firestore Stream Error: ${snapshot.error}");
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              '데이터를 불러오지 못했습니다.\nFirebase Console에서 Firestore Database를 생성하고 규칙(Rules)을 확인해주세요.\n\n에러: ${snapshot.error}',
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isNotEmpty) {
                        final data = docs.first.data() as Map<String, dynamic>;
                        final ts = data['timestamp'] as Timestamp?;
                        if (ts != null) {
                          _latestMessageTimestamp = ts;
                        }
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true, // 최신 메시지가 아래로
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final isMe = data['sender_id'] == _myUserId;
                          final message = data['message'] as String? ?? '';
                          final senderName = data['sender_name'] as String? ?? '알 수 없음';
                          final imageUrl = data['imageUrl'] as String?;
                          final timestamp = data['timestamp'] as Timestamp?;
                          
                          DateTime? date = timestamp?.toDate();
                          String timeString = '';
                          if (date != null) {
                            timeString = DateFormat('a h:mm', 'ko_KR').format(date);
                          }

                          return _buildMessageBubble(isMe, message, senderName, timeString, imageUrl);
                        },
                      );
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(bool isMe, String message, String senderName, String timeString, String? imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                senderName.isNotEmpty ? senderName[0] : '?',
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  Text(
                    senderName,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isMe)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 2),
                        child: Text(timeString, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ),
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                      ),
                      padding: EdgeInsets.all(imageUrl != null ? 8 : 10),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFFFEB33) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            )
                          ],
                        ),
                        child: imageUrl != null
                            ? GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ImageDetailScreen(imageUrl: imageUrl)),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl,
                                    width: 180,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (ctx, child, progress) => progress == null
                                        ? child
                                        : Container(
                                            width: 180,
                                            height: 180,
                                            color: Colors.black12,
                                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          ),
                                    errorBuilder: (ctx, err, stack) => Container(
                                      width: 180,
                                      height: 180,
                                      color: Colors.black12,
                                      child: const Icon(Icons.broken_image, color: Colors.black38),
                                    ),
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Linkify(
                                  onOpen: (link) async {
                                    final uri = Uri.parse(link.url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    } else {
                                      debugPrint('Could not launch ${link.url}');
                                    }
                                  },
                                  text: message,
                                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                                  linkStyle: const TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.blue,
                                    decorationThickness: 2.0,
                                  ),
                                ),
                              ),
                        ),
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 2),
                          child: Text(timeString, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            if (_isUploadingImage)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3366FF)),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.black54),
                onPressed: _pickAndUploadImage,
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: '메시지 입력',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF3366FF),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
