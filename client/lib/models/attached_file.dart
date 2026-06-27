enum AttachType { fit, cola, capture }

/// 사용자가 선택한 첨부 파일 하나를 나타내는 모델
class AttachedFile {
  final String originalPath; // file_picker/image_picker가 반환한 캐시 경로
  final String name;
  final int sizeBytes;
  final AttachType type;
  String? tempPath; // sh_upload 임시 디렉토리로 복사된 경로 (다음 단계에서 압축에 사용)

  AttachedFile({
    required this.originalPath,
    required this.name,
    required this.sizeBytes,
    required this.type,
    this.tempPath,
  });

  /// 사람이 읽기 쉬운 파일 크기 문자열
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
