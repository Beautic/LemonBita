class WeatherHelper {
  /// 기온 레벨 정의
  /// - Level 4: 더운 날 (23°C 이상)
  /// - Level 3: 선선한 날 (17°C ~ 22°C)
  /// - Level 2: 쌀쌀한 날 / 간절기 (9°C ~ 16°C)
  /// - Level 1: 추운 날 / 겨울 (8°C 이하)

  /// 옷의 기본 카테고리, 소분류, 소재 명칭을 기반으로 입기 좋은 기온 레벨(들)을 유추합니다.
  static List<int> getSuitableLevels({
    required String category,
    required String subCategory,
    required String material,
  }) {
    final cat = category.trim();
    final sub = subCategory.trim();
    final mat = material.toLowerCase().trim();

    // 1. 겨울/추운 날 전용 (Level 1)
    bool isWinter = false;
    if (mat.contains('패딩') || mat.contains('다운') || mat.contains('구스') || mat.contains('기모') || mat.contains('무스탕') || mat.contains('캐시미어')) {
      isWinter = true;
    }
    if (sub.contains('패딩') || sub.contains('코트') || sub.contains('다운') || sub.contains('겨울아우터') || sub.contains('목도리') || sub.contains('부츠')) {
      isWinter = true;
    }

    if (isWinter) {
      return [1, 2]; // 겨울 및 쌀쌀한 간절기 초입
    }

    // 2. 더운 날 전용 (Level 4)
    bool isSummer = false;
    if (mat.contains('린넨') || mat.contains('시어서커') || mat.contains('마 소재')) {
      isSummer = true;
    }
    if (sub.contains('반팔') || sub.contains('민소매') || sub.contains('나시') || sub.contains('반바지') || sub.contains('샌들') || sub.contains('슬리퍼')) {
      isSummer = true;
    }

    if (isSummer) {
      return [4]; // 더운 여름
    }

    // 3. 간절기 아우터 및 니트류 (Level 2, 3)
    if (sub.contains('자켓') || sub.contains('트렌치코트') || sub.contains('가죽자켓') || sub.contains('가디건') || sub.contains('니트') || sub.contains('스웨터')) {
      return [2, 3]; // 봄/가을 쌀쌀하거나 선선한 날
    }

    // 4. 일반 캐주얼 긴팔 및 봄/가을 팬츠 (Level 2, 3, 4)
    if (sub.contains('셔츠') || sub.contains('맨투맨') || sub.contains('후드') || sub.contains('긴팔') || sub.contains('청바지') || sub.contains('슬랙스')) {
      return [2, 3, 4]; // 한여름을 제외한 무난한 간절기용
    }

    // 5. 신발/액세서리 또는 매칭 키워드가 없는 경우 (전 기후 호환 폴백)
    if (cat.contains('신발') || cat.contains('가방') || cat.contains('액세서리')) {
      return [1, 2, 3, 4]; // 신발이나 가방은 사계절 공용으로 간주
    }

    // 기본값: 사계절 모두 입을 수 있는 무난한 청바지/소품 등으로 취급
    return [1, 2, 3, 4];
  }

  /// 기온 수치를 기준으로 기온 레벨을 판단합니다.
  static int getLevelFromCelsius(double celsius) {
    if (celsius >= 23.0) return 4;
    if (celsius >= 17.0) return 3;
    if (celsius >= 9.0) return 2;
    return 1;
  }

  /// 기온 레벨에 매칭되는 한글 라벨을 반환합니다.
  static String getLevelLabel(int level) {
    switch (level) {
      case 4:
        return '더운 날 (23°C↑)';
      case 3:
        return '선선한 날 (17~22°C)';
      case 2:
        return '쌀쌀한 날 (9~16°C)';
      case 1:
        return '추운 날 (8°C↓)';
      default:
        return '선선한 날 (17~22°C)';
    }
  }
}
