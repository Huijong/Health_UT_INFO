import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

// 백그라운드 메시지 수신 시 처리용 핸들러 (반드시 top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background message received: ${message.messageId}");
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
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

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
