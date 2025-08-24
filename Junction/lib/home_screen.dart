import 'package:flutter/material.dart';

// utils 폴더에 있는 것
import 'utils/slide_page_route.dart';

// lib 바로 아래 있는 것
import 'esg_list_screen.dart';
import 'learn_more_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 커스텀 하단 패널 높이(px)
  double _panelPx = 0;
  late double _minPx;
  late double _maxPx;

  void _openEsgDb(BuildContext context) {
    Navigator.of(context).push(
      SlideFromRightPageRoute(builder: (_) => const EsgListScreen()),
    );
  }

  void _openLearnMore(BuildContext context) {
    Navigator.of(context).push(
      SlideFromRightPageRoute(builder: (_) => const LearnMoreScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // 패널 높이 경계(px)
    _minPx = h * 0.08; // 처음 얇게 보이게
    _maxPx = h * 0.42; // 최대 설명 높이
    _panelPx = (_panelPx == 0) ? _minPx : _panelPx;

    // 패널 진행도에 따른 본문 lift(최대 60px 위로)
    final t = ((_panelPx - _minPx) / (_maxPx - _minPx)).clamp(0.0, 1.0);
    final double lift = 60 * t;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const SizedBox.shrink(), // 로고/타이틀 없음
      ),
      body: SizedBox.expand(
        child: Stack(
          children: [
            // 배경
            Positioned.fill(
              child: Image.asset('assets/background1.png', fit: BoxFit.cover),
            ),
            Positioned.fill(child: Container(color: Colors.black26)),

            // 본문
            SafeArea(
              child: Transform.translate(
                offset: Offset(0, -lift),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: w * 0.08 + 40,
                    top: 140,
                    right: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vision Score',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: Colors.white,
                            fontSize: 64,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          ' CV-based Social Score Evaluation System',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextButton(
                          onPressed: () => _openEsgDb(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('  Go to ESG Score  >  '),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 하단 커스텀 드래그 패널
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _panelPx,
              child: _BottomSheetPanel(
                onDragUpdate: (dy) {
                  setState(() {
                    _panelPx = (_panelPx - dy).clamp(_minPx, _maxPx);
                  });
                },
                onDragEnd: () {
                  setState(() {
                    final mid = (_minPx + _maxPx) / 2;
                    _panelPx = (_panelPx < mid) ? _minPx : _maxPx;
                  });
                },
                onTapLearnMore: () => _openLearnMore(context),
                child: const _SheetContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 하단 패널
class _BottomSheetPanel extends StatelessWidget {
  const _BottomSheetPanel({
    required this.child,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTapLearnMore,
  });

  final Widget child;
  final void Function(double dy) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onTapLearnMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xF20E1116),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // 드래그 핸들
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
              onVerticalDragEnd: (_) => onDragEnd(),
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white.withOpacity(0.95),
                  size: 28,
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),

            // 내용
            Expanded(
              child: NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (n) {
                  n.disallowIndicator();
                  return false;
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                  child: child,
                ),
              ),
            ),

            // Learn more 버튼 (패널 하단)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton(
                  onPressed: onTapLearnMore,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  child: const Text('Learn more'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 패널 내부 텍스트
class _SheetContent extends StatelessWidget {
  const _SheetContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About Vision Score',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 10),
        Text(
          'As the importance of ESG management is increasingly emphasized worldwide,\n'
              'companies are being required to disclose ESG-related information in a more transparent manner.\n'
              'Accordingly, many countries are expanding mandatory ESG disclosures and establishing various guidelines to reinforce them.\n'
              'In Europe, the Corporate Sustainability Reporting Directive (CSRD) will make ESG disclosure mandatory starting in 2025 for large corporations,\n'
              'and will gradually extend its application to small and medium-sized enterprises that meet certain criteria.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        SizedBox(height: 12),
        Text(
          '• Key Metrics: Visual Data Processing for Construction Site Safety & Environment\n'
          '• Output: ESG Scores and Reports for Individual Projects and Companies',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
      ],
    );
  }
}
