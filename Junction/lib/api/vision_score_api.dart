// lib/vision_api.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class DetectResponse {
  final double totalScore;
  final Map<String, dynamic> details;
  final String? resultImageBase64;
  final String resultFile;
  final String? originalImageName;
  final String? originalVideoName;

  final String? explain;
  final Map<String, dynamic>? metrics;

  DetectResponse({
    required this.totalScore,
    required this.details,
    required this.resultFile,
    this.resultImageBase64,
    this.originalImageName,
    this.originalVideoName,

    this.explain,   // ★
    this.metrics,   // ★
  });

  factory DetectResponse.fromJson(Map<String, dynamic> j) => DetectResponse(
        totalScore: (j['total_score'] as num).toDouble(),
        details: (j['details'] as Map<String, dynamic>),
        resultFile: j['result_file'] as String,
        resultImageBase64: j['result_image_base64'] as String?,
        originalImageName: j['original_image_name'] as String?,
        originalVideoName: j['original_video_name'] as String?,

        explain: j['explain'] as String?,                       // ★
        metrics: j['metrics'] as Map<String, dynamic>?,         // ★
      );
}

class VisionApi {
  final String baseUrl;
  final http.Client _client;
  VisionApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// ★ 웹/모바일 공통: 바이트 배열 업로드
  Future<DetectResponse> detectFireAndScoreBytes(
    Uint8List bytes, {
    required String filename,
  }) async {
    final uri = Uri.parse('$baseUrl/detect-fire-and-score/');
    final req = http.MultipartRequest('POST', uri);

    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: _guessContentType(filename),
    ));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    return DetectResponse.fromJson(data);
  }

  /// (선택) 모바일에서만: 파일 경로 업로드 (웹에서는 사용 금지)
  /// - 사용 시 dart:io의 File 필요
  Future<DetectResponse> detectFireAndScoreFilePath(String filepath) async {
    final uri = Uri.parse('$baseUrl/detect-fire-and-score/');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filepath,
        filename: p.basename(filepath),
        contentType: _guessContentType(filepath),
      ),
    );
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    return DetectResponse.fromJson(data);
  }

  String buildResultDownloadUrl(String resultFilePath) {
    final filename = p.basename(resultFilePath);
    return '$baseUrl/get-result/$filename';
  }

  static MediaType? _guessContentType(String path) {
    final ext = p.extension(path).toLowerCase();
    if (['.jpg', '.jpeg'].contains(ext)) return MediaType('image', 'jpeg');
    if (ext == '.png') return MediaType('image', 'png');
    if (ext == '.mp4') return MediaType('video', 'mp4');
    if (ext == '.mov') return MediaType('video', 'quicktime');
    if (ext == '.avi') return MediaType('video', 'x-msvideo');
    if (ext == '.mkv') return MediaType('video', 'x-matroska');
    if (ext == '.webm') return MediaType('video', 'webm');
    if (ext == '.m4v') return MediaType('video', 'x-m4v');
    return null;
  }
}
