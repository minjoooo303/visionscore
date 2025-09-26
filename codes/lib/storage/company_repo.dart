import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/esg_company.dart';
import 'company_storage.dart'; // saveCompanyForId / loadCompanyForId / loadAllCompanies

const _kCompanyIdsKey = 'company_ids_seeded_v1';

class CompanyRepo {
  Future<List<EsgCompany>> getCompanies() async {
    final prefs = await SharedPreferences.getInstance();
    final idsJson = prefs.getStringList(_kCompanyIdsKey);

    if (idsJson != null && idsJson.isNotEmpty) {
      // 이미 시드 완료 → 저장된 회사들 로드
      final list = <EsgCompany>[];
      for (final id in idsJson) {
        final c = await loadCompanyForId(id);
        if (c != null) list.add(c);
      }
      return list;
    }

    // 시드 없으면 16개 생성 후 저장
    final seeded = _mockCompanies();
    for (final c in seeded) {
      await saveCompanyForId(c);
    }
    await prefs.setStringList(
      _kCompanyIdsKey,
      seeded.map((e) => e.id).toList(),
    );
    return seeded;
  }

  List<EsgCompany> _mockCompanies() {
    final names = <String>[
      '(주) 현대건설','삼성물산','GS건설','포스코이앤씨',
      '대우건설','DL이앤씨','SK에코플랜트','한화건설',
      '롯데건설','쌍용건설','코오롱글로벌','효성중공업',
      '한신공영','HDC현대산업개발','태영건설','호반건설',
    ];
    return List.generate(16, (i) {
      return EsgCompany(
        id: 'c$i',
        name: names[i],
        socialGradeLabel: '평가 전',
        socialGradeLetter: 'TBD',
        photoUrls: ['https://picsum.photos/seed/esg$i/1200/800'],
      );
    });
  }
}
