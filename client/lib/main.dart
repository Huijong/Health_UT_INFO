import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/prefs_service.dart';
import 'screens/home_screen.dart';
import 'screens/notice_history_screen.dart';

// 전역 Navigator Key (알림 탭 시 화면 이동용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 로컬 노티피케이션 플러그인 전역 인스턴스
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// 로컬 알림 띄우기 공통 함수
Future<void> showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    channelDescription: 'This channel is used for important notifications.',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    icon: '@mipmap/launcher_icon',
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  // payload에서 제목/내용 추출 (Admin 앱이 data로 보냈을 때 대비)
  final title = message.notification?.title ?? message.data['title'] ?? '공지사항';
  final body = message.notification?.body ?? message.data['body'] ?? '새로운 공지사항이 등록되었습니다.';

  final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
  
  await flutterLocalNotificationsPlugin.show(
    id: notificationId,
    title: title,
    body: body,
    notificationDetails: platformChannelSpecifics,
    payload: message.data['notice_id'],
  );
}

// 백그라운드 메시지 수신 시 처리용 핸들러 (반드시 top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background message received: ${message.messageId}");

  // Admin 앱이 notification 필드 없이 data만 보냈을 때, 강제로 로컬 노티피케이션 표시
  if (message.notification == null) {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
    await showLocalNotification(message);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 (FCM 연동)
  try {
    await Firebase.initializeApp();
    
    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    final messaging = FirebaseMessaging.instance;

    // 알림 권한 요청 (Android 13+ 권한 동의 대화상자 호출 목적)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 공용 알림 채널 'notices' 토픽 구독
    await messaging.subscribeToTopic('notices');
    debugPrint("Subscribed to 'notices' topic successfully.");

    // Android 13+ 로컬 알림 권한 추가 요청
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  // flutter_local_notifications 초기화
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
      
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      // 로컬 노티피케이션을 클릭했을 때 처리
      debugPrint("Local notification tapped. Payload: ${response.payload}");
      // 공지사항 히스토리 페이지로 이동
      if (navigatorKey.currentState != null) {
        final prefs = await PrefsService.create();
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (context) => NoticeHistoryScreen(prefs: prefs)),
        );
      }
    },
  );

  // 헤드업 알림을 위한 Android 채널 생성
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const SamsungHealthCollectorApp());
}

class SamsungHealthCollectorApp extends StatelessWidget {
  const SamsungHealthCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 전역 Navigator Key 등록
      title: 'SH 검증 수집기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1429A0), // 삼성 블루
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
