import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/attached_file.dart';
import '../models/device_session.dart';
import '../models/pack_result.dart';

/// 검증 데이터 압축 서비스
///
/// zip 파일명 규칙 (세션 ID와 일관성 유지):
///   세션 ID   : SH_20240627_143052_1234
///   zip 파일명: verification_20240627_143052.zip
class PackingService {
  PackingService._();

  static Future<PackResult> pack({
    required String name,
    required double heightCm,
    required double weightKg,
    required String watch,
    required String memo,
    required DeviceSession session,
    required List<AttachedFile> fitFiles,
    required List<AttachedFile> colaFiles,
    required List<AttachedFile> captureFiles,
  }) async {
    // 세션 ID에서 날짜·시간 추출: "SH_20240627_143052_1234" → ["SH","20240627","143052","1234"]
    final idParts = session.sessionId.split('_');
    final zipName = 'verification_${idParts[1]}_${idParts[2]}.zip';
    final docsDir = await getApplicationDocumentsDirectory();
    final zipPath = '${docsDir.path}/$zipName';

    // ── meta.json (기계용) ──────────────────────────────────────
    final metaMap = <String, dynamic>{
      'session_id': session.sessionId,
      'created_at': session.createdAt,
      'user': {
        'name': name,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'watch': watch,
      },
      'device': {
        'model': session.deviceModel,
        'android': session.androidVersion,
        'app_version': session.appVersion,
      },
      'memo': memo,
      'files': [
        ...fitFiles.map(_fileMeta),
        ...colaFiles.map(_fileMeta),
        ...captureFiles.map(_fileMeta),
      ],
    };
    final metaBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(metaMap),
    );

    // ── info.txt (사람용) ──────────────────────────────────────
    final infoBytes = utf8.encode(
      _buildInfoText(
        name: name,
        heightCm: heightCm,
        weightKg: weightKg,
        watch: watch,
        memo: memo,
        session: session,
        fitFiles: fitFiles,
        colaFiles: colaFiles,
        captureFiles: captureFiles,
      ),
    );

    // ── zip 구성 ───────────────────────────────────────────────
    final archive = Archive();

    archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));
    archive.addFile(ArchiveFile('info.txt', infoBytes.length, infoBytes));

    // FIT + Cola: 루트 레벨
    for (final f in [...fitFiles, ...colaFiles]) {
      final bytes = await _readFile(f);
      archive.addFile(ArchiveFile(f.name, bytes.length, bytes));
    }

    // 캡처: captures/ 하위 폴더
    for (final f in captureFiles) {
      final bytes = await _readFile(f);
      archive.addFile(ArchiveFile('captures/${f.name}', bytes.length, bytes));
    }

    // 인코딩 & 저장
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw Exception('ZIP 인코딩 실패');

    await File(zipPath).writeAsBytes(zipBytes);

    return PackResult(
      zipPath: zipPath,
      zipName: zipName,
      sizeBytes: zipBytes.length,
    );
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────

  static Map<String, dynamic> _fileMeta(AttachedFile f) => {
        'type': f.type.name,
        'name': f.name,
        'size_bytes': f.sizeBytes,
      };

  /// tempPath 우선, 없으면 originalPath (두 경로 모두 로컬 파일 경로)
  static Future<List<int>> _readFile(AttachedFile f) async {
    final path = f.tempPath ?? f.originalPath;
    return File(path).readAsBytes();
  }

  static String _buildInfoText({
    required String name,
    required double heightCm,
    required double weightKg,
    required String watch,
    required String memo,
    required DeviceSession session,
    required List<AttachedFile> fitFiles,
    required List<AttachedFile> colaFiles,
    required List<AttachedFile> captureFiles,
  }) {
    final sb = StringBuffer();

    sb.writeln('===== Samsung Health 검증 수집 정보 =====');
    sb.writeln();

    sb.writeln('[ 세션 정보 ]');
    sb.writeln('세션 ID    : ${session.sessionId}');
    sb.writeln('수집 일시  : ${session.createdAt}');
    sb.writeln();

    sb.writeln('[ 사용자 정보 ]');
    sb.writeln('이름       : $name');
    sb.writeln('키         : $heightCm cm');
    sb.writeln('몸무게     : $weightKg kg');
    sb.writeln('착용 워치  : $watch');
    if (memo.isNotEmpty) sb.writeln('메모       : $memo');
    sb.writeln();

    sb.writeln('[ 기기 정보 ]');
    sb.writeln('기기 모델  : ${session.deviceModel}');
    sb.writeln('Android    : ${session.androidVersion}');
    sb.writeln('앱 버전    : ${session.appVersion}');
    sb.writeln();

    sb.writeln('[ 첨부 파일 ]');
    _appendFileList(sb, 'FIT 파일', fitFiles);
    _appendFileList(sb, 'Cola.zip', colaFiles);
    _appendFileList(sb, '운동 캡처', captureFiles);

    sb.writeln('=========================================');
    return sb.toString();
  }

  static void _appendFileList(
    StringBuffer sb,
    String label,
    List<AttachedFile> files,
  ) {
    sb.writeln('$label (${files.length}개):');
    if (files.isEmpty) {
      sb.writeln('  (없음)');
    } else {
      for (final f in files) {
        sb.writeln('  - ${f.name} (${f.sizeLabel})');
      }
    }
    sb.writeln();
  }
}
