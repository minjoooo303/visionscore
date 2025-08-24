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
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;
import 'package:vision_score/storage/company_storage.dart';


class EsgDetailScreen extends StatefulWidget {
  final EsgCompany company;
  const EsgDetailScreen({super.key, required this.company});

  @override
  State<EsgDetailScreen> createState() => _EsgDetailScreenState();
}

class _EsgDetailScreenState extends State<EsgDetailScreen> {
  EsgCompany? _company;
  Uint8List? _pickedBytes;
  String? _pickedName;
  bool _loading = false;
  DetectResponse? _result;
  String? _pickedVideoObjectUrl;        // blob://...

  // ★★★ 여기가 가장 중요합니다: 비디오 엘리먼트와 뷰 ID를 클래스 레벨로 옮겨 초기화합니다.
  final html.VideoElement _pickedVideoEl = html.VideoElement()
      ..controls = true
      ..autoplay = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

  late final String _pickedVideoViewId;

  @override
  void initState() {
    super.initState();
    _company = widget.company;  // 기본값

    _pickedVideoViewId = 'picked-video-${widget.company.id}';
    
    // ★★★ 여기가 핵심입니다: 플랫폼 뷰 팩토리를 앱 생명주기 동안 단 한 번만 등록합니다.
    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(_pickedVideoViewId, (int _) => _pickedVideoEl);
    }
    
    _restoreCompanyIfAny();
  }

  Future<void> _restoreCompanyIfAny() async {
    final saved = await loadCompanyForId(widget.company.id);
    if (!mounted) return;
    if (saved != null && saved.id == widget.company.id) {
      setState(() {
        _company = saved;
      });
    }
  }
  
  // ★★★ 이 함수를 수정합니다. 이제 이 함수는 단지 동영상 URL만 업데이트합니다.
  void _preparePickedVideoView() {
    if (!kIsWeb || _pickedBytes == null) return;
    
    _disposePickedVideoView(); // 기존 URL 정리

    final blob = html.Blob([_pickedBytes!]);
    _pickedVideoObjectUrl = html.Url.createObjectUrl(blob);
    _pickedVideoEl.src = _pickedVideoObjectUrl!;
  }
  
  // ★★★ 이 함수도 수정합니다. URL만 폐기하고 비디오 엘리먼트를 초기 상태로 되돌립니다.
  void _disposePickedVideoView() {
    if (!kIsWeb) return;
    if (_pickedVideoObjectUrl != null) {
      html.Url.revokeObjectUrl(_pickedVideoObjectUrl!);
      _pickedVideoObjectUrl = null;
    }
    _pickedVideoEl.src = ''; // 비디오 엘리먼트의 소스를 비워 초기화
    _pickedVideoEl.load(); 
  }

  @override
  void dispose() {
    _disposePickedVideoView();
    super.dispose();
  }

  void _deletePickedImageOrVideo() {
    final base = widget.company;
    final reset = base.copyWith(
      photoUrls: [],
      socialGradeLabel: base.socialGradeLabel,
      socialGradeLetter: base.socialGradeLetter,
      lastScore: null,
      lastExplain: null,
      lastMetrics: null,
      lastResultImageBase64: null,
    );

    setState(() {
      _company = reset;
      _pickedBytes = null;
      _pickedName = null;
      _result = null;
    });

    // await clearCompanyForId(base.id);
    _disposePickedVideoView();
    // setState(() {
    //   _pickedBytes = null;
    //   _pickedName = null;
    //   _result = null;
    // });
    // _disposePickedVideoView(); // 비디오 리소스도 확실하게 정리합니다.
  }


  Future<void> _pickImageOrVideo() async {
    // ★★★ 여기가 핵심입니다. 파일 선택 전에 이전 비디오 리소스를 무조건 정리합니다.
    
    _disposePickedVideoView();

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
      // _result = null; // 새 파일 선택 시 이전 결과 초기화
    });


    if (_isPickedVideo()) {
      _preparePickedVideoView();
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


  // lib/esg_detail_screen.dart 파일

  Future<void> _sendToBackend() async {
    if (_pickedBytes == null) return;

    setState(() => _loading = true);
    try {
      final r = await uploadMediaAndScoreBytes(
        _pickedBytes!,
        filename: _pickedName ?? 'upload.jpg',
      );
      setState(() => _result = r);
      final url = r.resultFile;
      if (_company != null) {
        final grade = _mapScoreToGrade(r.totalScore); // 점수로 등급 문자열 생성
        final parts = grade.split(' / ');
        final updated = _company!.copyWith(
          socialGradeLabel: parts[0],
          socialGradeLetter: parts[1],
          photoUrls: [..._company!.photoUrls, url],
          lastScore: r.totalScore, // ★ 점수 저장
          lastExplain: r.explain, // ★ 설명 저장
          lastMetrics: r.metrics, // ★ 메트릭 저장
          lastResultImageBase64: r.resultImageBase64, // 이미지도 저장
        );
        setState(() => _company = updated);
        await saveCompanyForId(updated); // 영구 저장
      }
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
  if (score >= 50) return '탁월 / S';
  if (score >= 48) return '우수 / A+';
  if (score >= 45) return '우수 / A';
  if (score >= 30) return '보통 / B';
  if (score >= 20) return '미흡 / C';
  return '매우 미흡 / D';
}


  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width;
    final company = _company ?? widget.company;

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
                                      final parts = gradeLetter.split(' / ');

                                      // 앞쪽 라벨 (탁월, 우수 등)
                                      final label = parts.isNotEmpty ? parts[0] : (company.socialGradeLabel ?? '');
                                      // 뒤쪽 등급 (S, A+ 등)
                                      final letter = parts.length > 1 ? parts[1] : (company.socialGradeLetter ?? '');

                                      // 2. 등급 문자열을 사용해 이미지 파일 경로를 완성합니다.
                                      // 예: 'assets/grades/A+.png'
                                      final String imagePath = 'assets/grades/$letter.png';

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
                                        label: const Text('Upload Image/Video'),
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
                                        label: const Text('Run Analysis'),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // ★★★ 추가된 버튼: 파일 삭제 ★★★
                                      if (_pickedBytes != null)
                                        IconButton(
                                          onPressed: _deletePickedImageOrVideo,
                                          icon: const Icon(Icons.delete),
                                          tooltip: '선택한 파일 삭제',
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
                                              // ★★★ 수정된 프리뷰 로직 (가장 중요) ★★★
                                              // 1. 저장된 분석 결과 영상이 있다면 이를 먼저 표시
                                              final lastPhotoUrl = company.photoUrls.isNotEmpty ? company.photoUrls.last : null;
                                              final isSavedVideo = lastPhotoUrl != null && (lastPhotoUrl.endsWith('.mp4') || lastPhotoUrl.endsWith('.mov'));
                                              late final String _savedVideoViewId = 'saved-video-${company.id}';

                                              if (isSavedVideo) {
                                                if (kIsWeb) {
                                                  ui_web.platformViewRegistry.registerViewFactory(_savedVideoViewId, (int viewId) {
                                                    return html.VideoElement()
                                                      ..src = lastPhotoUrl
                                                      ..controls = true
                                                      ..autoplay = false
                                                      ..style.width = '100%'
                                                      ..style.height = '100%'
                                                      ..style.objectFit = 'cover';
                                                  });
                                                  return HtmlElementView(viewType: _savedVideoViewId);
                                                }
                                              }

                                              // 2. 저장된 분석 결과 이미지가 있다면 이를 먼저 표시
                                              if (company.lastResultImageBase64 != null) {
                                                return buildResultImage(company.lastResultImageBase64!);
                                              }

                                              // 3. 비디오일 경우 웹 비디오 플레이어 우선
                                              if (_isPickedVideo() && kIsWeb) {
                                                return HtmlElementView(viewType: _pickedVideoViewId);
                                              }
                                              // 4. 백엔드가 이미지 결과를 줬으면: 결과 이미지
                                              if (_result?.resultImageBase64 != null) {
                                                return buildResultImage(_result!.resultImageBase64!);
                                              }
                                              // 5. 사용자가 '이미지'를 골랐으면: 이미지 미리보기
                                              if (_pickedBytes != null && _isPickedImage()) {
                                                return Image.memory(_pickedBytes!, fit: BoxFit.cover);
                                              }
                                              // 6. 아무 것도 없으면 Placeholder
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
                                                'Latest CCTV Image',
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

                                  if (company.lastScore != null) ...[
                                  
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
                                      label: const Text('open result file'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 18),

                company.lastScore != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          ' total score: ${company.lastScore!.toStringAsFixed(2)}점',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 25),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          ' total score:',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 25),
                        ),
                      ],
                    ),
               
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, c) {
                    final isNarrow = c.maxWidth < 900;
                    final explain = company.lastExplain; // ★ 이 부분 수정
                    final metrics = company.lastMetrics; // ★ 이 부분 수정

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
                                ? const Center(child: Text('This section will display the reasoning after the analysis."'))
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
                                ? const Center(child: Text('Detailed scores will be displayed here after the analysis.'))
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

    // // 거리 관련
    // if (dist != null) {
    //   final px = dist['min_person_machinery'] ??
    //       dist['min_person_machinery_min_overall'];
    //   items.addAll([
    //     const SizedBox(height: 8),
    //     _kvMini('사람-중장비 최소거리(px)', px),
    //     _kvMini('거리 임계값(px)', dist['threshold_px']),
    //   ]);
    // }

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