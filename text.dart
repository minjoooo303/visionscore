import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:vision_score/api/vision_helpers.dart';
import 'models/esg_company.dart';

import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

// 웹 전용
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;


class EsgDetailScreen extends StatefulWidget {
  final EsgCompany company;
  const EsgDetailScreen({super.key, required this.company});

  @override
  State<EsgDetailScreen> createState() => _EsgDetailScreenState();
}

class _EsgDetailScreenState extends State<EsgDetailScreen> {
  Uint8List? _pickedBytes;
  String? _pickedName;
  bool _loading = false;
  DetectResponse? _result;
  String? _pickedVideoObjectUrl;        // blob://...

  html.VideoElement? _pickedVideoEl;
  late final String _pickedVideoViewId = 'picked-video-${UniqueKey()}';

  void _preparePickedVideoView() {
    if (!kIsWeb || _pickedBytes == null) return;

    // blob 생성 → object URL
    final blob = html.Blob([_pickedBytes!]);
    _pickedVideoObjectUrl = html.Url.createObjectUrl(blob);

    // <video> 구성
    _pickedVideoEl = html.VideoElement()
      ..src = _pickedVideoObjectUrl!
      ..controls = true
      ..autoplay = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

    // 플랫폼 뷰 등록 (한 번만 등록)
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_pickedVideoViewId, (int _) => _pickedVideoEl!);
  }

  void _disposePickedVideoView() {
    if (!kIsWeb) return;
    if (_pickedVideoObjectUrl != null) {
      html.Url.revokeObjectUrl(_pickedVideoObjectUrl!);
      _pickedVideoObjectUrl = null;
    }
    _pickedVideoEl = null;
  }

  @override
  void dispose() {
    _disposePickedVideoView();
    super.dispose();
  }


  Future<void> _pickImageOrVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'],
      withData: true, // 웹에서 bytes 필요
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.first;
    setState(() {
      _pickedBytes = f.bytes;
      _pickedName = f.name;
      _result = null; // 새 파일 선택 시 이전 결과 초기화
    });


    if (_isPickedVideo()) {
      _preparePickedVideoView();
    } else {
      // 이미지 선택 시 이전 비디오 리소스 정리(선택)
      _disposePickedVideoView();
    }
  }

  bool _isPickedImage() {
    final name = (_pickedName ?? '').toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  bool _isPickedVideo() {
    final name = (_pickedName ?? '').toLowerCase();
    return name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.avi') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm') ||
        name.endsWith('.m4v');
  }


  Future<void> _sendToBackend() async {
    if (_pickedBytes == null) return;

    setState(() => _loading = true);
    try {
      final r = await uploadMediaAndScoreBytes(
        _pickedBytes!,
        filename: _pickedName ?? 'upload.jpg',
      );
      setState(() => _result = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드/분석 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapScoreToGrade(double score) {
    if (score >= 50) return 'S';
    if (score >= 48) return 'A+';
    if (score >= 45) return 'A';
    if (score >= 30) return 'B';
    if (score >= 20) return 'C';
    return 'D';
  }


  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width;
    final company = widget.company;

    return Scaffold(
      appBar: AppBar(title: const Text('About this company...')),
      body: Center(
          child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW > 1160 ? 1160 : maxW * 0.95),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // 회사명
                Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6),
                child: Text(
                  company.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 상단 2열
              LayoutBuilder(
                builder: (context, c) {
                  final isNarrow = c.maxWidth < 900;
                  return Flex(
                    direction: isNarrow ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 왼쪽: Social 등급 카드
                      Expanded(
                        flex: isNarrow ? 0 : 4,
                        child: SizedBox(
                          height: 200,
                          child: _outlinedCard(
                            context,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Social grade',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 18),
                                Builder(
                                  builder: (context) {
                                    // 1. 표시할 등급 문자열(grade letter)을 결정합니다.
                                    final String gradeLetter = _result != null
                                        ? _mapScoreToGrade(_result!.totalScore)
                                        : company.socialGradeLetter;

                                    // 2. 등급 문자열을 사용해 이미지 파일 경로를 완성합니다.
                                    // 예: 'assets/grades/A+.png'
                                    final String imagePath = 'assets/grades/$gradeLetter.png';

                                    // 3. Image.asset 위젯으로 이미지를 표시합니다.
                                    return Center(
                                      child:Image.asset(
                                        imagePath,
                                        height: 120, // UI에 맞게 이미지 높이를 조절하세요.
                                        fit: BoxFit.contain,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isNarrow ? 0 : 16, height: isNarrow ? 16 : 0),

                      // 오른쪽: 업로드 + 프리뷰 + 결과
                      Expanded(
                        flex: 8,
                        child: SizedBox(
                          height: 360,
                          child: _outlinedCard(
                            context,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _loading ? null : _pickImageOrVideo,
                                      icon: const Icon(Icons.upload),
                                      label: const Text('사진/영상 업로드'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed:
                                      (_loading || _pickedBytes == null) ? null : _sendToBackend,
                                      icon: _loading
                                          ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                          : const Icon(Icons.analytics),
                                      label: const Text('분석하기'),
                                    ),
                                    const SizedBox(width: 12),
                                    if (_pickedName != null)
                                      Text(
                                        _pickedName!,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 프리뷰 + "최근 CCTV 사진" 라벨
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: () {
                                            // 1) 백엔드가 이미지 결과를 줬으면: 결과 이미지 우선
                                            if (_result?.resultImageBase64 != null) {
                                              return buildResultImage(_result!.resultImageBase64!);
                                            }

                                            // 2) 사용자가 '영상'을 골랐으면: <video> 미리보기 (웹)
                                            if (_pickedBytes != null && _isPickedVideo() && kIsWeb && _pickedVideoEl != null) {
                                              return HtmlElementView(viewType: _pickedVideoViewId);
                                            }

                                            // 3) 사용자가 '이미지'를 골랐으면: 이미지 미리보기
                                            if (_pickedBytes != null && _isPickedImage()) {
                                              return Image.memory(_pickedBytes!, fit: BoxFit.cover);
                                            }

                                            // 4) 아무 것도 없으면 Placeholder
                                            return const Center(child: Icon(Icons.photo, size: 64));
                                          }(),
                                        ),

                                        Positioned(
                                          left: 8,
                                          top: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              '최근 CCTV 사진',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: () async {
                                    final filename = p.basename(_result!.resultFile);
                                    final url = 'http://localhost:8000/get-result/$filename';
                                    final u = Uri.parse(url);
                                    if (await canLaunchUrl(u)) {
                                      await launchUrl(u, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('결과 파일 열기'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              if (_result != null) ...[
          const SizedBox(height: 8),
      Text(
        '총점: ${_result!.totalScore}',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),

      const SizedBox(height: 18),

      // 등급 기준 (비워둠)
      Text(
        '등급 기준',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 900;
          final explain = _result?.explain;
          final metrics = _result?.metrics as Map<String, dynamic>?;

          return Flex(
            direction: isNarrow ? Axis.vertical : Axis.horizontal,
            children: [
              // 왼쪽: 설명(explain)
              Expanded(
                child: _outlinedCard(
                  context,
                  height: 180,
                  padding: const EdgeInsets.all(14),
                  child: explain== null
                      ? const Center(child: Text('분석 후 근거 설명이 여기에 표시됩니다.'))
                      : SingleChildScrollView(
                    child: Text(
                      explain,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.85,),
                    ),
                  ),
                ),),
              SizedBox(width: isNarrow ? 0 : 16, height: isNarrow ? 16 : 0),

              // 오른쪽: 메트릭(metrics)
              Expanded(
                child: _outlinedCard(
                  context,
                  height: 180,
                  padding: const EdgeInsets.all(14),
                  child: metrics == null
                      ? const Center(child: Text('분석 후 근거 메트릭이 여기에 표시됩니다.'))
                      : _MetricsView(metrics: metrics),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      ],
    ),
    ),
    ),
    ),
    );
  }

  static Widget _outlinedCard(
      BuildContext context, {
        Widget? child,
        double? height,
        EdgeInsets padding = const EdgeInsets.all(16),
      }) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// metrics(백엔드에서 준 숫자 근거) 렌더러
class _MetricsView extends StatelessWidget {
  final Map<String, dynamic> metrics;
  const _MetricsView({required this.metrics});

  @override
  Widget build(BuildContext context) {
    // 이미지: counts / distance_px
    // 비디오: counts_avg_per_frame / distance_px
    final scores = (metrics['scores'] ?? metrics['counts_avg_per_frame'])
    as Map<String, dynamic>?;

    final dist = metrics['distance_px'] as Map<String, dynamic>?;

    final items = <Widget>[];

    // 카운트 관련
    if (scores != null) {
      items.addAll([
        _kvMini('안전모 미착용 (10점)', scores['hardhat']),
        _kvMini('안전조끼 미착용 (10점)', scores['safety_vest']),
        _kvMini('중장비와 사람 거리 (10점)', scores['machinery_distance']),
        _kvMini('차량 유무 (10점)', scores['vehicle']),
        _kvMini('사람 수 (10점)', scores['person_count']),
        // _kvMini('화재/연기',
        //     '${counts['fires'] ?? 0} / ${counts['smokes'] ?? 0}'),
      ]);
    }

    // 거리 관련
    if (dist != null) {
      final px = dist['min_person_machinery'] ??
          dist['min_person_machinery_min_overall'];
      items.addAll([
        const SizedBox(height: 8),
        _kvMini('사람-중장비 최소거리(px)', px),
        _kvMini('거리 임계값(px)', dist['threshold_px']),
      ]);
    }

    if (items.isEmpty) {
      return const Center(child: Text('표시할 메트릭이 없습니다.'));
    }

    // 리스트로 출력
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: items,
    );
  }

  /// key-value 한 줄씩 출력하는 헬퍼
  Widget _kvMini(String k, dynamic v) {
    final text = (v == null) ? '—' : v.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontSize: 13))),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}