// lib/models/esg_company.dart 파일

class EsgCompany {
  final String id;
  final String name;
  final String socialGradeLabel;
  final String socialGradeLetter;
  final List<String> photoUrls;
  final double? lastScore; // ★ 새로운 필드 추가: 마지막 분석 점수
  final String? lastExplain; // ★ 새로운 필드 추가: 마지막 분석 설명
  final Map<String, dynamic>? lastMetrics; // ★ 새로운 필드 추가: 마지막 분석 메트릭
  final String? lastResultImageBase64;

  EsgCompany({
    required this.id,
    required this.name,
    required this.socialGradeLabel,
    required this.socialGradeLetter,
    required this.photoUrls,
    this.lastScore, // ★
    this.lastExplain, // ★
    this.lastMetrics, // ★
    this.lastResultImageBase64,
  });
  
  // ★ 새로운 copyWith 메서드
  EsgCompany copyWith({
    String? socialGradeLabel,
    String? socialGradeLetter,
    List<String>? photoUrls,
    double? lastScore,
    String? lastExplain,
    Map<String, dynamic>? lastMetrics,
    String? lastResultImageBase64,
  }) {
    return EsgCompany(
      id: id,
      name: name,
      socialGradeLabel: socialGradeLabel ?? this.socialGradeLabel,
      socialGradeLetter: socialGradeLetter ?? this.socialGradeLetter,
      photoUrls: photoUrls ?? this.photoUrls,
      lastScore: lastScore ?? this.lastScore,
      lastExplain: lastExplain ?? this.lastExplain,
      lastMetrics: lastMetrics ?? this.lastMetrics,
      lastResultImageBase64: lastResultImageBase64 ?? this.lastResultImageBase64,
    );
  }

  // ★ 기존 copyWithNewPhoto 메서드는 제거하거나, 아래와 같이 재활용
  EsgCompany copyWithNewPhoto(String url) {
    return copyWith(
      photoUrls: [...photoUrls, url],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'socialGradeLabel': socialGradeLabel,
    'socialGradeLetter': socialGradeLetter,
    'photoUrls': photoUrls,
    'lastScore': lastScore,
    'lastExplain': lastExplain,
    'lastMetrics': lastMetrics,
    'lastResultImageBase64': lastResultImageBase64,
  };

  factory EsgCompany.fromJson(Map<String, dynamic> json) {
    return EsgCompany(
      id: json['id'] as String,
      name: json['name'] as String,
      socialGradeLabel: json['socialGradeLabel'] as String,
      socialGradeLetter: json['socialGradeLetter'] as String,
      photoUrls: (json['photoUrls'] as List<dynamic>).map((e) => e.toString()).toList(),
      lastScore: (json['lastScore'] as num?)?.toDouble(),
      lastExplain: json['lastExplain'] as String?,
      lastMetrics: json['lastMetrics'] as Map<String, dynamic>?,
      lastResultImageBase64: json['lastResultImageBase64'] as String?,
    );
  }
}