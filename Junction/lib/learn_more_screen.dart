import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';

class LearnMoreScreen extends StatefulWidget {
  const LearnMoreScreen({super.key});
  @override
  State<LearnMoreScreen> createState() => _LearnMoreScreenState();
}

class _LearnMoreScreenState extends State<LearnMoreScreen> {
  final ScrollController _sc = ScrollController();

  // 이 지점까지 세로 스크롤 허용(카드 섹션이 본격적으로 보이는 임계)
  static const double _introMaxOffset = 700;

  // 스크롤 물리
  ScrollPhysics _physics = const ClampingScrollPhysics();

  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _sc.addListener(_onScroll);
  }

  void _onScroll() {
    final o = _sc.offset;
    setState(() => _offset = o);

    // 임계 도달 시 위치 고정(세로 드래그 멈춤)
    if (o >= _introMaxOffset && _physics is! NeverScrollableScrollPhysics) {
      setState(() => _physics = const NeverScrollableScrollPhysics());
      _sc.jumpTo(_introMaxOffset);
    }
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  // 카드 섹션 노출 진행률(0~1) — 뒤로가기 버튼 표시용
  double get _cardProgress =>
      (_offset / _introMaxOffset).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final headline = w < 600 ? 38.0 : (w < 1024 ? 60.0 : 78.0);

    return Scaffold(
      // ✅ 최종 요구: 배경은 항상 흰색
      backgroundColor: Colors.white,
      body: ScrollConfiguration(
        behavior: const _DragEverywhere(),
        child: Stack(
          children: [
            // 메인 컨텐츠
            CustomScrollView(
              controller: _sc,
              physics: _physics,
              slivers: [
                // 섹션 1: 인트로(검은 글씨)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: h,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'HI! This is Vision score :)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: headline,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 섹션 2: 세로 포스터형 카드 가로 캐러셀
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    color: Colors.transparent,
                    child: _HorizontalCards(
                      items: const [
                        _CardItem('See Safety',  'assets/cards/1.png'),
                        _CardItem('Realtime CV','assets/cards/3.png'),
                        _CardItem('Analytics',   'assets/cards/2.png'),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),

            // ▶ 좌측 상단 뒤로가기(카드 섹션이 보일수록 서서히 나타남)
            Positioned(
              left: 8,
              top: 8,
              child: SafeArea(
                child: AnimatedOpacity(
                  opacity: Curves.easeOut.transform(_cardProgress),
                  duration: const Duration(milliseconds: 180),
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.black26,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.black87,
                    ),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────── 가로 카드 섹션 ─────────────────── */

class _HorizontalCards extends StatefulWidget {
  const _HorizontalCards({required this.items});
  final List<_CardItem> items;

  @override
  State<_HorizontalCards> createState() => _HorizontalCardsState();
}

class _HorizontalCardsState extends State<_HorizontalCards> {
  late final PageController _pc;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    // 세로 포스터 느낌: 한 화면에 3장 가까이 보이도록 0.30
    _pc = PageController(viewportFraction: 0.30);
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final cardH = h * 0.65; // 화면 높이의 65%

    return SizedBox(
      height: cardH,
      child: PageView.builder(
        controller: _pc,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.items.length,
        itemBuilder: (context, i) {
          final d = (_page - i).abs();
          final scale = 1.0 - (d * 0.06).clamp(0.0, 0.12);
          final it = widget.items[i];

          return AnimatedScale(
            duration: const Duration(milliseconds: 220),
            scale: scale,
            child: AspectRatio(
              aspectRatio: 9 / 16, // 세로 긴 카드
              child: _PosterCard(
                imageAsset: it.imageAsset,
                onTap: () {}, // 탭 시 행동 필요하면 연결
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ─────────────────── 카드 위젯 ─────────────────── */

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.imageAsset, this.onTap, this.radius = 28});
  final String imageAsset;
  final VoidCallback? onTap;
  final double radius;

  // @override
  // Widget build(BuildContext context) {
  //   return Padding(
  //     padding: const EdgeInsets.only(right: 18.0),
  //     child: Material(
  //       elevation: 10,
  //       color: Colors.transparent,
  //       borderRadius: BorderRadius.circular(radius),
  //       child: InkWell(
  //         onTap: onTap,
  //         borderRadius: BorderRadius.circular(radius),
  //         child: Ink(
  //           decoration: BoxDecoration(
  //             borderRadius: BorderRadius.circular(radius),
  //             border: Border.all(color: Colors.black12),
  //           ),
  //           child: ClipRRect(
  //             borderRadius: BorderRadius.circular(radius),
  //             child: Image.asset(
  //               imageAsset,
  //               fit: BoxFit.contain,
  //               alignment: Alignment.center,
  //             ),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // 필요하면 탭 이벤트 유지
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16), // 모서리 둥글게 (옵션)
        child: Image.asset(
          imageAsset,
          fit: BoxFit.contain,   // 원본 비율 그대로
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _CardItem {
  final String title;
  final String imageAsset;
  const _CardItem(this.title, this.imageAsset);
}

/* ────────────── 스크롤/드래그 인식 보정 ────────────── */

class _DragEverywhere extends MaterialScrollBehavior {
  const _DragEverywhere();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
  };
}
