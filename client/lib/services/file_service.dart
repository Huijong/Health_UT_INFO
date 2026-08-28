import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/attached_file.dart';

/// Samsung Health 검증 파일 선택 및 임시 저장소 복사
///
/// FIT / Cola.zip: 전용 MethodChannel을 통해 Android의
/// DocumentsContract.EXTRA_INITIAL_URI로 폴더를 직접 지정한다.
/// (file_picker 8.x는 pickFiles에서 initialDirectory를 Android에 전달하지 않음)
///
/// 캡처 이미지: image_picker 사용 (갤러리 다중 선택)
class FileService {
  FileService._();

  static const _ch = MethodChannel('com.samsung.health.client/file_picker');
  static final _imagePicker = ImagePicker();

  // ── FIT 파일 선택 ─────────────────────────────────────────────
  /// 삼성 헬스 FIT 기본 경로(primary:Download/삼성 헬스/fit)로 바로 이동 후 선택
  static Future<AttachedFile?> pickFit() async {
    final path = await _ch.invokeMethod<String?>('pickFit');
    return _fromLocalPath(path, AttachType.fit);
  }

  // ── Garmin FIT 파일 선택 ─────────────────────────────────────────
  /// Garmin Download 기본 경로(primary:Download/)로 바로 이동 후 선택
  static Future<AttachedFile?> pickGarminFit() async {
    final path = await _ch.invokeMethod<String?>('pickGarminFit');
    return _fromLocalPath(path, AttachType.fit);
  }

  // ── Cola.zip 선택 ─────────────────────────────────────────────
  /// COLA_FILE 경로(primary:Documents/COLA_FILE)로 바로 이동 후 zip 선택
  static Future<AttachedFile?> pickCola() async {
    final path = await _ch.invokeMethod<String?>('pickCola');
    return _fromLocalPath(path, AttachType.cola);
  }

  // ── 로그 파일 선택 ─────────────────────────────────────────────
  /// COLA_FILE 경로(primary:Documents/COLA_FILE)로 바로 이동 후 log_*.zip 선택 (다중 선택 가능)
  static Future<List<AttachedFile>> pickLog() async {
    final paths = await _ch.invokeListMethod<String>('pickLog');
    if (paths == null) return [];
    
    final result = <AttachedFile>[];
    for (final p in paths) {
      final f = await _fromLocalPath(p, AttachType.log);
      if (f != null) result.add(f);
    }
    return result;
  }

  // ── 운동 캡처 다중 선택 ───────────────────────────────────────
  static Future<List<AttachedFile>> pickCaptures() async {
    final images = await _imagePicker.pickMultiImage();

    final result = <AttachedFile>[];
    for (final img in images) {
      final file = File(img.path);
      if (!file.existsSync()) continue;

      final attached = AttachedFile(
        originalPath: img.path,
        name: img.path.split('/').last,
        sizeBytes: file.lengthSync(),
        type: AttachType.capture,
      );
      attached.tempPath = await _copyToTemp(attached);
      result.add(attached);
    }
    return result;
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────

  /// Android에서 캐시로 복사된 로컬 경로 → AttachedFile 변환 + sh_upload/ 재복사
  static Future<AttachedFile?> _fromLocalPath(
    String? path,
    AttachType type,
  ) async {
    if (path == null) return null; // 사용자 취소

    final file = File(path);
    if (!file.existsSync()) return null;

    final attached = AttachedFile(
      originalPath: path,
      name: file.uri.pathSegments.last,
      sizeBytes: file.lengthSync(),
      type: type,
    );
    attached.tempPath = await _copyToTemp(attached);
    return attached;
  }

  /// 파일을 앱 임시 디렉토리의 sh_upload/ 폴더로 복사
  /// 다음 단계에서 이 경로를 zip 압축에 사용
  static Future<String> _copyToTemp(AttachedFile file) async {
    final tmpDir = await getTemporaryDirectory();
    final uploadDir = Directory('${tmpDir.path}/sh_upload');
    await uploadDir.create(recursive: true);

    final dest = '${uploadDir.path}/${file.name}';
    await File(file.originalPath).copy(dest);
    return dest;
  }

  /// 세션 전송 완료 후 임시 파일 정리 (다음 단계 전송 후 호출)
  static Future<void> clearTemp() async {
    final tmpDir = await getTemporaryDirectory();
    final uploadDir = Directory('${tmpDir.path}/sh_upload');
    if (uploadDir.existsSync()) {
      await uploadDir.delete(recursive: true);
    }
  }
}
