import 'package:share_plus/share_plus.dart';

/// 시스템 공유 시트로 ZIP 파일 전달
class ShareService {
  ShareService._();

  /// ZIP 파일을 공유 시트로 열기.
  /// 사용자가 Quick Share를 선택하면 삼성 클라우드에 업로드 후 링크 생성.
  static Future<void> shareZip(String zipPath, String zipName) async {
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
