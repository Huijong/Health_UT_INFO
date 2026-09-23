import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// 시스템 공유 시트로 ZIP 파일 전달
class ShareService {
  ShareService._();

  static const _channel = MethodChannel('com.samsung.health.client/app_info');

  /// ZIP 파일을 공유 시트로 열기.
  /// 안드로이드 기본 공유 시트를 건너뛰고 퀵 쉐어를 다이렉트로 호출합니다.
  /// 퀵 쉐어가 설치되어 있지 않거나 실패할 경우 기존의 일반 공유 시트로 폴백(Fallback)합니다.
  static Future<void> shareZip(String zipPath, String zipName) async {
    try {
      // 1. 퀵 쉐어 다이렉트 호출 시도
      await _channel.invokeMethod('launchQuickShareDirectly', {
        'filePath': zipPath,
      });
    } catch (e) {
      print('Quick Share direct launch failed: $e. Falling back to default share sheet.');
      // 2. 실패 시(타사 폰이거나 퀵 쉐어 미설치) 기존 share_plus 방식(일반 공유 시트) 호출
      final xFile = XFile(
        zipPath,
        mimeType: 'application/zip',
        name: zipName,
      );
      await Share.shareXFiles(
        [xFile],
        subject: '삼성 헬스 검증 데이터',
      );
    }
  }
}
