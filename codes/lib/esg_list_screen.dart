import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'models/esg_company.dart';
import 'esg_detail_screen.dart';
import 'utils/slide_page_route.dart';
import 'storage/company_repo.dart';

class EsgListScreen extends StatefulWidget {
  const EsgListScreen({super.key});
  @override
  State<EsgListScreen> createState() => _EsgListScreenState();
}

class _EsgListScreenState extends State<EsgListScreen> {
  final TextEditingController _controller = TextEditingController();
  final PageController _pc = PageController(viewportFraction: 0.40);

  List<EsgCompany> _allCompanies = [];
  String _query = '';
  bool _loading = true;
  double _page = 0;

  final Map<String, String> _logoById = {
    'c0': 'assets/hyundai.png',
    'c1': 'assets/samsung_mulsan.png',
    'c2': 'assets/gs.png',
    'c3': 'assets/posco_enc.png',
    'c4': 'assets/daewoo.png',
    'c5': 'assets/dlenc.png',
    'c6': 'assets/sk_ecoplant.png',
    'c7': 'assets/hanhwa.png',
    'c8': 'assets/lotte.png',
    'c9': 'assets/ssangyong.png',
    'c10': 'assets/kolon.png',
    'c11': 'assets/hyosung.png',
    'c12': 'assets/hanshin.png',
    'c13': 'assets/hdc.png',
    'c14': 'assets/taeyoung.png',
    'c15': 'assets/hoban.png',
  };

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    final repo = CompanyRepo();
    final list = await repo.getCompanies();
    if (!mounted) return;
    setState(() {
      _allCompanies = list;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<EsgCompany> get _filtered {
    if (_query.trim().isEmpty) return _allCompanies;
    final q = _query.trim();
    return _allCompanies.where((c) => c.name.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final w = sz.width;

    final double heroTopOffset = (sz.height * 0.20).clamp(48.0, 260.0);
    final double cardH = w < 700 ? 260 : (w < 1100 ? 320 : 360);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0E13),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final items = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const SizedBox.shrink(),
      ),
      body: ScrollConfiguration(
        behavior: const _DragEverywhereBehavior(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), // top padding은 0
          children: [
            // ⬇ 화면을 아래로 미는 유동 스페이서
            SizedBox(height: heroTopOffset),

            // 🔹 대제목 Companies
            Center(
              child: Text(
                'Companies.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 72, // 더 크게 하고 싶으면 60~72까지 조절 가능
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 🔹 중앙 검색바
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _BigDarkSearchField(
                  controller: _controller,
                  hint: 'Please enter the company name.',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ⬇ 가로 스냅 카드(그대로)
            SizedBox(
              height: cardH,
              child: PageView.builder(
                controller: _pc,
                physics: const BouncingScrollPhysics(),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final distance = (_page - i).abs();
                  final scale = 1.0 - (distance * 0.06).clamp(0.0, 0.12);
                  final elev  = (8 - distance * 4).clamp(2, 10).toDouble();
                  final c     = _filtered[i];
                  final logo  = _logoById[c.id];
                  return AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    scale: scale,
                    child: _CompanyBigCard(
                      company: c,
                      logoAsset: logo,
                      elevation: elev,
                      color: _pickCardColor(i),
                      onTap: () async {
                        await Navigator.of(context).push(
                          SlideFromRightPageRoute(builder: (_) => EsgDetailScreen(company: c)),
                        );
                        if (mounted) _loadCompanies();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _pickCardColor(int i) {
    const palette = [
      Color(0xFF1C222B),
      Color(0xFF2B2F3A),
      Color(0xFF2E3A7A),
      Color(0xFF2D6C6F),
      Color(0xFF734D30),
      Color(0xFF3B2D52),
    ];
    return palette[i % palette.length];
  }
}

/* ===================== 위젯들 ===================== */

class _BigDarkSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const _BigDarkSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        cursorColor: Colors.white70,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 18),
          prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 26),
          filled: true,
          fillColor: const Color(0xFF141821),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2A2F3B)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF3D77F2)),
          ),
        ),
      ),
    );
  }
}

class _CompanyBigCard extends StatelessWidget {
  final EsgCompany company;
  final String? logoAsset;
  final double elevation;
  final Color color;
  final VoidCallback onTap;

  const _CompanyBigCard({
    required this.company,
    required this.onTap,
    required this.elevation,
    required this.color,
    this.logoAsset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 18.0),
      child: Material(
        color: Colors.transparent,
        elevation: elevation,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.98), color.withOpacity(0.88)],
              ),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ▶ 좌측 로고 컬럼 (상단 정렬, 크게)
                Container(
                  width: 120, // 로고 영역 폭 (원하는 느낌까지 100~140 사이 조절)
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: logoAsset != null
                        ? Image.asset(logoAsset!, fit: BoxFit.contain)
                        : const Icon(Icons.apartment, size: 72, color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 18),

                // ▶ 우측 내용 컬럼 (큰 타이포)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 회사명 – 큼직하게
                      Text(
                        company.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Social 라벨
                      Text(
                        'Social',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 등급 – 강조 크게
                      Text(
                        '${company.socialGradeLabel} / ${company.socialGradeLetter}',
                        style: const TextStyle(
                          color: Color(0xFF75A2FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 35, // 강조 사이즈
                          letterSpacing: -0.2,
                        ),
                      ),

                      const Spacer(),

                      // 하단 CTA
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.95)),
                          const SizedBox(width: 6),
                          Text(
                            '자세히 보기',
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// 웹/데스크탑에서 마우스 드래그로도 스크롤 가능하게
class _DragEverywhereBehavior extends MaterialScrollBehavior {
  const _DragEverywhereBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
  };
}
