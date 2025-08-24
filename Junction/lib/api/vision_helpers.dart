// lib/api/vision_helpers.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:vision_score/api/vision_score_api.dart';
export 'vision_score_api.dart' show DetectResponse;


String pickBaseUrlForWebAndDev() {
  if (kIsWeb) return 'http://localhost:8000';
  return 'http://localhost:8000';
}

Widget buildResultImage(String base64Str) {
  return Image.memory(base64Decode(base64Str));
}

Future<DetectResponse> uploadMediaAndScoreBytes(
  Uint8List bytes, {
  required String filename,
}) async {
  final api = VisionApi(baseUrl: pickBaseUrlForWebAndDev());
  return await api.detectFireAndScoreBytes(bytes, filename: filename);
}

