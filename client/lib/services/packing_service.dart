import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
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
    required String strap,
    required String exercise,
    required String wearingPosition,
    required String wearingTightness,
    required String competitorWatch,
    required String trainingType,
    required String distance,
    required String location,
    required String memo,
    required String gpsStatus,
    required String gpsMemo,
    required String hrStatus,
    required String hrMemo,
    required String paceStatus,
    required String paceMemo,
    required String altitudeStatus,
    required String altitudeMemo,
    required DeviceSession session,
    required List<AttachedFile> fitFiles,
    required List<AttachedFile> colaFiles,
    required List<AttachedFile> logFiles,
    required List<AttachedFile> captureFiles,
  }) async {
    // 세션 ID에서 날짜·시간 추출: "SH_20240627_143052_1234" → ["SH","20240627","143052","1234"]
    final idParts = session.sessionId.split('_');
    final safeName = name.replaceAll(RegExp(r'[<>:"/\\|?*\s]'), '');
    final safeExercise = exercise.replaceAll(RegExp(r'[<>:"/\\|?*\s]'), '');
    final zipName = '${safeName}_${safeExercise}_${idParts[1]}_${idParts[2]}.zip';
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
        'strap': strap,
        'exercise': exercise,
        'wearing_position': wearingPosition,
        'wearing_tightness': wearingTightness,
        'competitor_watch': competitorWatch,
        'training_type': trainingType,
        'distance': distance,
        'location': location,
      },
      'verification': {
        'gps': {'status': gpsStatus, 'memo': gpsMemo},
        'hr': {'status': hrStatus, 'memo': hrMemo},
        'pace': {'status': paceStatus, 'memo': paceMemo},
        'altitude': {'status': altitudeStatus, 'memo': altitudeMemo},
      },
      'device': {
        'model': session.deviceModel,
        'android': session.androidVersion,
        'app_version': session.appVersion,
        'shealth_version': session.shealthVersion,
      },
      'memo': memo,
      'files': [
        ...fitFiles.map(_fileMeta),
        ...colaFiles.map(_fileMeta),
        ...logFiles.map(_fileMeta),
        ...captureFiles.map(_fileMeta),
      ],
    };
    final metaJson = const JsonEncoder.withIndent('  ').convert(metaMap);

    // ── info.txt (사람용) ──────────────────────────────────────
    final infoText = _buildInfoText(
      name: name,
      heightCm: heightCm,
      weightKg: weightKg,
      watch: watch,
      strap: strap,
      exercise: exercise,
      wearingPosition: wearingPosition,
      wearingTightness: wearingTightness,
      competitorWatch: competitorWatch,
      trainingType: trainingType,
      distance: distance,
      location: location,
      memo: memo,
      gpsStatus: gpsStatus,
      gpsMemo: gpsMemo,
      hrStatus: hrStatus,
      hrMemo: hrMemo,
      paceStatus: paceStatus,
      paceMemo: paceMemo,
      altitudeStatus: altitudeStatus,
      altitudeMemo: altitudeMemo,
      session: session,
      fitFiles: fitFiles,
      colaFiles: colaFiles,
      logFiles: logFiles,
      captureFiles: captureFiles,
    );

    final params = _PackIsolateParams(
      zipPath: zipPath,
      zipName: zipName,
      metaJson: metaJson,
      infoText: infoText,
      fitPaths: fitFiles.map((f) => f.tempPath ?? f.originalPath).toList(),
      colaPaths: colaFiles.map((f) => f.tempPath ?? f.originalPath).toList(),
      logPaths: logFiles.map((f) => f.tempPath ?? f.originalPath).toList(),
      capturePaths: captureFiles.map((f) => f.tempPath ?? f.originalPath).toList(),
    );

    // 무거운 Zip 인코딩 연산을 백그라운드 스레드(Isolate)에서 처리하여 메인 스레드 ANR 완전 예방
    return await compute(_packIsolateBody, params);
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────

  static Map<String, dynamic> _fileMeta(AttachedFile f) => {
        'type': f.type.name,
        'name': f.name,
        'size_bytes': f.sizeBytes,
      };


  static String _buildInfoText({
    required String name,
    required double heightCm,
    required double weightKg,
    required String watch,
    required String strap,
    required String exercise,
    required String wearingPosition,
    required String wearingTightness,
    required String competitorWatch,
    required String trainingType,
    required String distance,
    required String location,
    required String memo,
    required String gpsStatus,
    required String gpsMemo,
    required String hrStatus,
    required String hrMemo,
    required String paceStatus,
    required String paceMemo,
    required String altitudeStatus,
    required String altitudeMemo,
    required DeviceSession session,
    required List<AttachedFile> fitFiles,
    required List<AttachedFile> colaFiles,
    required List<AttachedFile> logFiles,
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
    sb.writeln('착용 스트랩: $strap');
    sb.writeln('선택 운동  : $exercise');
    sb.writeln();

    sb.writeln('[ 센서/데이터 이슈 결과 ]');
    sb.writeln('GPS        : $gpsStatus');
    if (gpsStatus == '확인 필요' && gpsMemo.isNotEmpty) {
      sb.writeln('  └ 메모  : $gpsMemo');
    }
    sb.writeln('심박수(HR)  : $hrStatus');
    if (hrStatus == '확인 필요' && hrMemo.isNotEmpty) {
      sb.writeln('  └ 메모  : $hrMemo');
    }
    sb.writeln('속도/페이스 : $paceStatus');
    if (paceStatus == '확인 필요' && paceMemo.isNotEmpty) {
      sb.writeln('  └ 메모  : $paceMemo');
    }
    sb.writeln('고도       : $altitudeStatus');
    if (altitudeStatus == '확인 필요' && altitudeMemo.isNotEmpty) {
      sb.writeln('  └ 메모  : $altitudeMemo');
    }
    sb.writeln();

    sb.writeln('[ 검증 디테일 ]');
    sb.writeln('착용 위치  : $wearingPosition');
    sb.writeln('착용 정도  : $wearingTightness');
    sb.writeln('동시착용 타사기기: $competitorWatch');
    sb.writeln('운동 종류  : $trainingType');
    sb.writeln('운동 거리  : $distance km');
    sb.writeln('장소       : $location');
    if (memo.isNotEmpty) sb.writeln('특이 사항  : $memo');
    sb.writeln();

    sb.writeln('[ 기기 정보 ]');
    sb.writeln('기기 모델  : ${session.deviceModel}');
    sb.writeln('Android    : ${session.androidVersion}');
    sb.writeln('앱 버전    : ${session.appVersion}');
    sb.writeln('삼성 헬스  : ${session.shealthVersion}');
    sb.writeln();

    sb.writeln('[ 첨부 파일 ]');
    _appendFileList(sb, 'FIT 파일', fitFiles);
    _appendFileList(sb, 'Cola.zip', colaFiles);
    _appendFileList(sb, '로그 파일', logFiles);
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

/// Isolate 압축 전달용 매개변수 클래스
class _PackIsolateParams {
  final String zipPath;
  final String zipName;
  final String metaJson;
  final String infoText;
  final List<String> fitPaths;
  final List<String> colaPaths;
  final List<String> logPaths;
  final List<String> capturePaths;

  _PackIsolateParams({
    required this.zipPath,
    required this.zipName,
    required this.metaJson,
    required this.infoText,
    required this.fitPaths,
    required this.colaPaths,
    required this.logPaths,
    required this.capturePaths,
  });
}

/// 백그라운드 워커 스레드에서 동작하는 압축 및 파일 저장 로직 (UI 멈춤/ANR 차단)
PackResult _packIsolateBody(_PackIsolateParams params) {
  final encoder = ZipFileEncoder();
  encoder.create(params.zipPath);

  // 1. 메타 데이터 및 텍스트 추가
  final metaBytes = utf8.encode(params.metaJson);
  final infoBytes = utf8.encode(params.infoText);

  final metaFile = ArchiveFile('meta.json', metaBytes.length, metaBytes);
  metaFile.compress = true;
  encoder.addArchiveFile(metaFile);

  final infoFile = ArchiveFile('info.txt', infoBytes.length, infoBytes);
  infoFile.compress = true;
  encoder.addArchiveFile(infoFile);

  // 로컬 파일 등록 헬퍼
  void addFile(String path, String archiveName, bool compress) {
    final file = File(path);
    if (!file.existsSync()) return;
    
    // 이미 압축된 파일(.zip, .png, .jpg 등)은 압축 레벨 0 (NO_COMPRESSION) 지정하여 속도 향상 및 메모리 보존
    encoder.addFile(file, archiveName, compress ? 9 : 0);
  }

  // 2. FIT 파일 추가 (FIT은 무압축 텍스트 데이터 계열이므로 압축률 적용 권장)
  for (final path in params.fitPaths) {
    final name = path.split('/').last.split('\\').last;
    addFile(path, name, true);
  }

  // 3. Cola 파일 추가 (이미 zip 압축되어 있으므로 Stored 방식 무압축 추가)
  for (final path in params.colaPaths) {
    final name = path.split('/').last.split('\\').last;
    addFile(path, name, false);
  }

  // 4. Log 파일 추가 (이미 zip 압축되어 있으므로 Stored 방식 무압축 추가)
  for (final path in params.logPaths) {
    final name = path.split('/').last.split('\\').last;
    addFile(path, name, false);
  }

  // 5. 캡처 이미지 추가 (PNG/JPG 등은 이미 압축된 이미지 포맷이므로 무압축 추가)
  for (final path in params.capturePaths) {
    final name = path.split('/').last.split('\\').last;
    addFile(path, 'captures/$name', false);
  }

  // 6. Zip 인코딩 종료 및 파일 쓰기 완료
  encoder.closeSync();

  final zipFile = File(params.zipPath);
  final size = zipFile.existsSync() ? zipFile.lengthSync() : 0;

  return PackResult(
    zipPath: params.zipPath,
    zipName: params.zipName,
    sizeBytes: size,
  );
}
