/// 압축 완료 결과 — 다음 단계(공유)에서 zipPath를 사용한다
class PackResult {
  final String zipPath;
  final String zipName;
  final int sizeBytes;

  const PackResult({
    required this.zipPath,
    required this.zipName,
    required this.sizeBytes,
  });

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
