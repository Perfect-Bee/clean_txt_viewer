/// 기본 양식화 (Basic Formatting)
///
/// .txt 로 글을 옮기는 과정에서 줄바꿈과 띄어쓰기가 사라져
/// 서술과 대사가 한 줄에 붙어버리는 문제를 보정한다.
///
/// 규칙
///  - 따옴표로 묶인 대사를 하나의 문단으로 떼어내고,
///    앞뒤 서술과 빈 줄 1개로 분리한다.
///  - 곧은 큰따옴표("..."), 둥근 큰따옴표(“...”),
///    낫표(「...」), 겹낫표(『...』)를 대사 표시로 인식한다.
///
/// 예)
///   입력 : A가 B에게 잔을 집어 던지며 말했다. "백두산이" 그러자 B는 따라 불렀다."마르고 닳도록"
///   출력 :
///     A가 B에게 잔을 집어 던지며 말했다.
///
///     "백두산이"
///
///     그러자 B는 따라 불렀다.
///
///     "마르고 닳도록"
///
class BasicFormatter {
  const BasicFormatter._();

  /// 대사로 인식할 따옴표 쌍의 정규식.
  /// 새 따옴표 종류를 추가하려면 패턴을 한 줄 더 넣으면 된다.
  static final RegExp _dialogue = RegExp(
    r'"[^"]*"' // 곧은 큰따옴표 "..."
    r'|\u201C[^\u201D]*\u201D' // 둥근 큰따옴표 “...”
    r'|\u300C[^\u300D]*\u300D' // 낫표 「...」
    r'|\u300E[^\u300F]*\u300F', // 겹낫표 『...』
  );

  /// 줄바꿈 양옆에 붙은 공백(스페이스/탭) 제거용.
  static final RegExp _spacesAroundNewline = RegExp(r'[ \t]*\n[ \t]*');

  /// 빈 줄이 2개 이상 연속되면 1개로 줄이기.
  static final RegExp _extraBlankLines = RegExp(r'\n{3,}');

  /// 한 페이지(또는 청크) 분량의 원문 텍스트를 양식화한다.
  static String format(String raw) {
    if (raw.isEmpty) return raw;

    // 1) 대사 앞뒤에 빈 줄을 넣어 서술과 분리한다.
    var text = raw.replaceAllMapped(
      _dialogue,
      (m) => '\n\n${m[0]}\n\n',
    );

    // 2) 줄바꿈 주변의 잉여 공백을 정리한다.
    text = text.replaceAll(_spacesAroundNewline, '\n');

    // 3) 연속된 빈 줄은 1개로 통일한다.
    text = text.replaceAll(_extraBlankLines, '\n\n');

    // 4) 앞뒤 공백/빈 줄 제거.
    return text.trim();
  }
}