class BrandData {
  // 대표적인 패션/의류 브랜드 사전
  static const List<Map<String, String>> brands = [
    {'ko': '자라', 'en': 'ZARA'},
    {'ko': '마시모두띠', 'en': 'Massimo Dutti'},
    {'ko': '유니클로', 'en': 'UNIQLO'},
    {'ko': '나이키', 'en': 'Nike'},
    {'ko': '아디다스', 'en': 'Adidas'},
    {'ko': '뉴발란스', 'en': 'New Balance'},
    {'ko': '코스', 'en': 'COS'},
    {'ko': '에이치앤엠', 'en': 'H&M'},
    {'ko': '스파오', 'en': 'SPAO'},
    {'ko': '탑텐', 'en': 'TOPTEN10'},
    {'ko': '에잇세컨즈', 'en': '8 Seconds'},
    {'ko': '지오다노', 'en': 'GIORDANO'},
    {'ko': '폴로 랄프로렌', 'en': 'Polo Ralph Lauren'},
    {'ko': '타미 힐피거', 'en': 'Tommy Hilfiger'},
    {'ko': '라코스테', 'en': 'Lacoste'},
    {'ko': '파타고니아', 'en': 'Patagonia'},
    {'ko': '노스페이스', 'en': 'The North Face'},
    {'ko': '아크테릭스', 'en': 'Arc\'teryx'},
    {'ko': '메종 키츠네', 'en': 'Maison Kitsune'},
    {'ko': '아미', 'en': 'Ami'},
    {'ko': '메종 마르지엘라', 'en': 'Maison Margiela'},
    {'ko': '아페쎄', 'en': 'A.P.C.'},
    {'ko': '스투시', 'en': 'Stussy'},
    {'ko': '슈프림', 'en': 'Supreme'},
    {'ko': '반스', 'en': 'Vans'},
    {'ko': '컨버스', 'en': 'Converse'},
    {'ko': '아식스', 'en': 'Asics'},
    {'ko': '살로몬', 'en': 'Salomon'},
    {'ko': '닥터마틴', 'en': 'Dr. Martens'},
    {'ko': '버켄스탁', 'en': 'Birkenstock'},
    {'ko': '크록스', 'en': 'Crocs'},
    {'ko': '보테가 베네타', 'en': 'Bottega Veneta'},
    {'ko': '셀린느', 'en': 'Celine'},
    {'ko': '구찌', 'en': 'Gucci'},
    {'ko': '프라다', 'en': 'Prada'},
    {'ko': '디올', 'en': 'Dior'},
    {'ko': '샤넬', 'en': 'Chanel'},
    {'ko': '루이비통', 'en': 'Louis Vuitton'},
    {'ko': '생로랑', 'en': 'Saint Laurent'},
    {'ko': '발렌시아가', 'en': 'Balenciaga'},
    {'ko': '스톤아일랜드', 'en': 'Stone Island'},
    {'ko': '시피 컴퍼니', 'en': 'C.P. Company'},
    {'ko': '바버', 'en': 'Barbour'},
    {'ko': '우영미', 'en': 'Wooyoungmi'},
    {'ko': '준지', 'en': 'Juun.J'},
    {'ko': '솔리드옴므', 'en': 'Solid Homme'},
    {'ko': '시스템옴므', 'en': 'System Homme'},
    {'ko': '타임옴므', 'en': 'Time Homme'},
    {'ko': '무신사 스탠다드', 'en': 'Musinsa Standard'},
    {'ko': '커버낫', 'en': 'Covernat'},
    {'ko': '디스이즈네버댓', 'en': 'thisisneverthat'},
    {'ko': 'LMC', 'en': 'LMC'},
    {'ko': '마르디 메크르디', 'en': 'Mardi Mercredi'},
    {'ko': '젠틀몬스터', 'en': 'Gentle Monster'},
    {'ko': '아크네 스튜디오', 'en': 'Acne Studios'},
    {'ko': '질샌더', 'en': 'Jil Sander'},
    {'ko': '르메르', 'en': 'Lemaire'},
    {'ko': '가니', 'en': 'GANNI'},
    {'ko': '이자벨 마랑', 'en': 'Isabel Marant'},
    {'ko': '자크뮈스', 'en': 'Jacquemus'},
    {'ko': '미우미우', 'en': 'Miu Miu'},
    {'ko': '로에베', 'en': 'Loewe'},
    {'ko': '비비안 웨스트우드', 'en': 'Vivienne Westwood'},
    {'ko': '톰브라운', 'en': 'Thom Browne'},
    {'ko': '몽클레르', 'en': 'Moncler'},
    {'ko': '캐나다구스', 'en': 'Canada Goose'},
    {'ko': '챔피온', 'en': 'Champion'},
    {'ko': '푸마', 'en': 'Puma'},
    {'ko': '리복', 'en': 'Reebok'},
    {'ko': '언더아머', 'en': 'Under Armour'},
    {'ko': '컬럼비아', 'en': 'Columbia'},
    {'ko': '몽벨', 'en': 'Montbell'},
    {'ko': '호카 오네오네', 'en': 'Hoka One One'},
    {'ko': '킨', 'en': 'Keen'},
    {'ko': '테바', 'en': 'Teva'},
    {'ko': '차코', 'en': 'Chaco'},
    {'ko': '그레고리', 'en': 'Gregory'},
    {'ko': '포터리', 'en': 'Pottery'},
    {'ko': '어나더오피스', 'en': 'Another Office'},
    {'ko': '유니폼브릿지', 'en': 'Uniform Bridge'},
    {'ko': '에스피오나지', 'en': 'Espionage'},
    {'ko': '띠어리', 'en': 'Theory'},
    {'ko': '빈폴', 'en': 'Beanpole'},
    {'ko': '헤지스', 'en': 'Hazzys'},
    {'ko': '바나나 리퍼블릭', 'en': 'Banana Republic'},
    {'ko': '제이크루', 'en': 'J.Crew'},
    {'ko': '갭', 'en': 'GAP'},
    {'ko': '캘빈클라인', 'en': 'Calvin Klein'},
    {'ko': '게스', 'en': 'Guess'},
    {'ko': '리바이스', 'en': 'Levi\'s'},
    {'ko': '리', 'en': 'Lee'},
    {'ko': '꼼데가르송', 'en': 'Comme des Garcons'},
    {'ko': '이세이 미야케', 'en': 'Issey Miyake'},
    {'ko': '사카이', 'en': 'Sacai'},
    {'ko': '니들스', 'en': 'Needles'},
    {'ko': '엔지니어드 가먼츠', 'en': 'Engineered Garments'},
    {'ko': '파라부트', 'en': 'Paraboot'},
    {'ko': '버윅', 'en': 'Berwick'},
    {'ko': '락포트', 'en': 'Rockport'},
    {'ko': '콜한', 'en': 'Cole Haan'},
    {'ko': '에코', 'en': 'ECCO'},
    {'ko': '클락스', 'en': 'Clarks'},
    {'ko': '캠퍼', 'en': 'Camper'},
    {'ko': '우포스', 'en': 'OOFOS'},
    {'ko': '토앤토', 'en': 'Taw & Toe'},
  ];

  // 한글 문자열에서 초성을 추출하는 함수
  static String getChosung(String text) {
    const chosungList = [
      'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
      'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
    ];

    StringBuffer sb = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      // 한글 음절 범위 (가 ~ 힣)
      if (code >= 0xAC00 && code <= 0xD7A3) {
        int chosungIndex = ((code - 0xAC00) ~/ 28) ~/ 21;
        sb.write(chosungList[chosungIndex]);
      } else {
        // 한글 음절이 아니면 문자 그대로 유지
        sb.write(text[i]);
      }
    }
    return sb.toString();
  }

  // 사용자의 입력어에 따라 브랜드를 필터링하여 결과를 "한글(영어)" 포맷 리스트로 반환
  static List<String> filterBrands(String query) {
    if (query.isEmpty) return [];

    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final lowerQuery = cleanQuery.toLowerCase();

    // 입력어가 한글 자음(초성)으로만 이루어졌는지 체크
    final isChosungOnly = RegExp(r'^[ㄱ-ㅎ\s]+$').hasMatch(cleanQuery);

    List<Map<String, String>> matched = [];

    if (isChosungOnly) {
      // 1. 초성 검색 대응
      matched = brands.where((brand) {
        final koChosung = getChosung(brand['ko']!);
        return koChosung.contains(lowerQuery);
      }).toList();
    } else {
      // 2. 일반 검색 대응
      // 입력어가 영어(알파벳)로만 구성되어 있는지 체크
      final isEnglish = RegExp(r'^[a-zA-Z\s]+$').hasMatch(cleanQuery);

      if (isEnglish) {
        // 영어 검색: 시작 단어 매칭(startsWith) 적용
        matched = brands.where((brand) {
          final enName = brand['en']!.toLowerCase();
          return enName.startsWith(lowerQuery);
        }).toList();
      } else {
        // 한글 검색: 포함 매칭(contains) 적용
        matched = brands.where((brand) {
          final koName = brand['ko']!;
          return koName.contains(cleanQuery);
        }).toList();
      }
    }

    // "한글(영어)" 형식으로 변환하여 반환
    return matched.map((brand) => "${brand['ko']}(${brand['en']})").toList();
  }
}
