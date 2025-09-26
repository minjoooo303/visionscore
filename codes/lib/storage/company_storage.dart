import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/esg_company.dart';

/// 회사 하나 저장 (회사 ID를 키에 붙임)
Future<void> saveCompanyForId(EsgCompany company) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonStr = jsonEncode(company.toJson());
  await prefs.setString('saved_company_${company.id}', jsonStr);
}

/// 회사 하나 불러오기
Future<EsgCompany?> loadCompanyForId(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonStr = prefs.getString('saved_company_$id');
  if (jsonStr == null) return null;

  final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
  return EsgCompany.fromJson(jsonMap);
}

/// 전체 저장된 회사 목록 불러오기 (원하는 경우)
Future<List<EsgCompany>> loadAllCompanies() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where((k) => k.startsWith('saved_company_'));
  final companies = <EsgCompany>[];

  for (final k in keys) {
    final jsonStr = prefs.getString(k);
    if (jsonStr == null) continue;
    final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
    companies.add(EsgCompany.fromJson(jsonMap));
  }
  return companies;
}
