# clean_txt_viewer

대용량 `.txt`, `.log`, `.md`, `.csv`, `.json`, `.xml` 파일을 부드럽게 읽기 위한 Flutter 기반 텍스트 뷰어입니다.

작은 텍스트 파일은 `readAsString()`으로 한 번에 읽어도 문제가 거의 없지만, 파일 크기가 3MB 이상으로 커지면 문자열 디코딩, 줄바꿈 계산, 레이아웃 계산, 렌더링이 한 번에 발생하면서 화면이 멈출 수 있습니다.

`clean_txt_viewer`는 이 문제를 줄이기 위해 파일 전체를 한 번에 읽지 않고, 필요한 구간만 조금씩 읽어서 화면에 표시합니다.

---

## 목차

- [1. 프로젝트 목표](#goal)
- [2. 기존 방식이 느려지는 이유](#problem)
- [3. 해결 방식 요약](#solution-summary)
- [4. 전체 동작 흐름](#flow)
- [5. 프로젝트 구조](#project-structure)
- [6. 사용 패키지](#packages)
- [7. file_picker 버전 주의](#file-picker-version)
- [8. 실행 방법](#run)
- [9. 핵심 코드 한눈에 보기](#core-code)
- [10. 코드별 역할 설명](#code-explanation)
- [11. 성능상 장점](#performance)
- [12. 주의할 점](#cautions)
- [13. 개선 아이디어](#future)
- [14. 요약](#summary)

---

<a id="goal"></a>

## 1. 프로젝트 목표

이 프로젝트의 목표는 단순합니다.

큰 텍스트 파일을 열 때 앱이 멈추지 않게 만드는 것입니다.

주요 목표는 다음과 같습니다.

- 3MB 이상의 텍스트 파일도 부드럽게 열기
- 파일 전체를 한 번에 메모리에 올리지 않기
- 현재 보고 있는 부분만 읽고 표시하기
- UI 스레드가 멈추지 않도록 디코딩 작업 분리하기
- `ListView.builder`를 사용해 보이는 줄만 렌더링하기
- 앞뒤 페이지만 캐시해서 페이지 이동을 빠르게 만들기

---

<a id="problem"></a>

## 2. 기존 방식이 느려지는 이유

텍스트 파일을 읽는 가장 쉬운 코드는 보통 아래와 같습니다.

```text
final text = await File(path).readAsString();

return Text(text);
```

이 방식은 작은 파일에서는 간단하고 잘 동작합니다.

하지만 파일이 커지면 문제가 생깁니다.

```text
TXT 파일 전체 읽기
        ↓
큰 String 객체 생성
        ↓
UTF-8 디코딩
        ↓
전체 텍스트 줄바꿈 계산
        ↓
하나의 Text 위젯으로 전체 레이아웃 계산
        ↓
스크롤하기 전에 이미 많은 내용을 처리
        ↓
렉 발생
```

사용자는 첫 화면 일부만 보고 싶은데, 앱은 파일 전체를 한 번에 처리하려고 합니다.

예를 들어 30MB짜리 로그 파일을 열면 첫 줄 몇 개만 보여주면 되는데도, 기존 방식은 30MB 전체를 읽고 전체 문자열을 화면에 올리려고 합니다.

이 과정에서 메모리 사용량과 렌더링 부담이 커지고, 결과적으로 앱이 버벅이게 됩니다.

---

<a id="solution-summary"></a>

## 3. 해결 방식 요약

`clean_txt_viewer`는 파일을 페이지 단위로 나누어 읽습니다.

이 프로젝트에서 페이지는 실제 책의 페이지가 아니라, 파일을 일정한 바이트 크기로 나눈 구간입니다.

```text
TXT 파일
  ↓
64KB 단위로 부분 읽기
  ↓
UTF-8 디코딩
  ↓
줄 단위로 분리
  ↓
현재 페이지의 줄만 ListView.builder로 표시
  ↓
앞/뒤 페이지 일부만 캐시
```

핵심은 다음 다섯 가지입니다.

```text
1. 파일 전체를 한 번에 읽지 않는다.
2. RandomAccessFile로 필요한 위치만 읽는다.
3. UTF-8 디코딩은 compute를 사용해 분리한다.
4. 화면 표시는 ListView.builder로 처리한다.
5. 앞뒤 페이지를 캐시해서 이동을 빠르게 만든다.
```

---

<a id="flow"></a>

## 4. 전체 동작 흐름

앱의 전체 흐름은 다음과 같습니다.

```text
사용자가 파일 열기 버튼 클릭
        ↓
file_picker로 파일 선택 창 열기
        ↓
사용자가 txt, log, md 등의 파일 선택
        ↓
선택한 파일 경로 가져오기
        ↓
파일 크기 확인
        ↓
전체 페이지 수 계산
        ↓
0번 페이지 읽기
        ↓
UTF-8 디코딩
        ↓
줄 단위로 나누기
        ↓
ListView.builder로 표시
        ↓
사용자가 다음 페이지 또는 슬라이더 이동
        ↓
해당 위치의 페이지만 다시 읽기
        ↓
앞/뒤 페이지 미리 읽기
```

---

<a id="project-structure"></a>

## 5. 프로젝트 구조

처음에는 단일 파일 구조로 시작할 수 있습니다.

```text
clean_txt_viewer/
 ├─ lib/
 │   └─ main.dart
 ├─ pubspec.yaml
 ├─ README.md
 └─ windows/
```

프로젝트가 커지면 아래처럼 나누는 것도 좋습니다.

```text
lib/
 ├─ main.dart
 ├─ screens/
 │   └─ txt_reader_screen.dart
 ├─ services/
 │   └─ txt_page_reader.dart
 ├─ models/
 │   └─ txt_page.dart
 └─ widgets/
     ├─ reader_toolbar.dart
     └─ text_line_list.dart
```

현재 단계에서는 `main.dart` 하나에 전체 기능을 넣어도 충분합니다.

기능이 많아지면 화면, 파일 읽기 로직, 위젯을 나누면 관리하기 쉬워집니다.

---

<a id="packages"></a>

## 6. 사용 패키지

이 프로젝트에서 사용하는 외부 패키지는 `file_picker`입니다.

`file_picker`는 사용자가 직접 컴퓨터에서 파일을 고를 수 있게 해주는 패키지입니다.

설치 명령어는 다음과 같습니다.

```text
flutter pub add file_picker
flutter pub get
```

파일 선택 기능은 아래 코드에서 사용됩니다.

```text
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: [
    'txt',
    'log',
    'md',
    'csv',
    'json',
    'xml',
  ],
);
```

이 코드의 역할은 다음과 같습니다.

```text
FilePicker.platform.pickFiles()
  → 파일 선택 창을 연다.

type: FileType.custom
  → 특정 확장자만 선택할 수 있도록 한다.

allowedExtensions
  → txt, log, md, csv, json, xml 파일만 선택 대상으로 지정한다.

result.files.single.path
  → 사용자가 고른 파일의 실제 경로를 가져온다.
```

중요한 점은 `file_picker`가 렉을 줄여주는 핵심 기능은 아니라는 것입니다.

`file_picker`의 역할은 파일을 고르는 것입니다.

렉을 줄이는 핵심은 아래 기능들이 담당합니다.

```text
RandomAccessFile
  → 파일 전체가 아니라 필요한 구간만 읽는다.

compute
  → 디코딩 작업을 UI 작업과 분리한다.

ListView.builder
  → 화면에 보이는 줄만 렌더링한다.

페이지 캐시
  → 앞뒤 페이지를 미리 읽어서 이동을 부드럽게 한다.
```

---

<a id="file-picker-version"></a>

## 7. file_picker 버전 주의

이 프로젝트에서는 `file_picker` 8.x 버전을 사용합니다.

`pubspec.yaml`의 dependencies 부분은 아래처럼 설정합니다.

```text
dependencies:
  flutter:
    sdk: flutter

  file_picker: ^8.0.0
```

`file_picker` 11.x 버전에서 아래와 같은 오류가 발생할 수 있습니다.

```text
The getter 'platform' isn't defined for the type 'FilePicker'.
```

이 프로젝트에서는 `file_picker: ^8.0.0`으로 설정했을 때 문제가 해결되었습니다.

`^8.0.0`의 의미는 다음과 같습니다.

```text
8.0.0 이상
9.0.0 미만
```

즉, `file_picker`가 11.x 버전으로 자동 업그레이드되지 않습니다.

더 확실하게 버전을 고정하고 싶다면 아래처럼 작성할 수도 있습니다.

```text
dependencies:
  flutter:
    sdk: flutter

  file_picker: 8.0.0
```

두 방식의 차이는 다음과 같습니다.

```text
file_picker: ^8.0.0
  → 8.x 안에서 가능한 최신 버전을 사용한다.

file_picker: 8.0.0
  → 정확히 8.0.0 버전만 사용한다.
```

보통은 아래 설정을 권장합니다.

```text
file_picker: ^8.0.0
```

패키지 버전을 바꾼 뒤에는 아래 명령어를 실행합니다.

```text
flutter clean
flutter pub get
```

그래도 IntelliJ에서 빨간 줄이 남아 있으면 프로젝트를 다시 열거나 캐시를 초기화합니다.

```text
File > Invalidate Caches...
```

---

<a id="run"></a>

## 8. 실행 방법

프로젝트 폴더로 이동합니다.

```text
cd clean_txt_viewer
```

패키지를 설치합니다.

```text
flutter pub get
```

Windows 데스크톱 앱으로 실행하려면 먼저 Windows 데스크톱 지원을 켭니다.

```text
flutter config --enable-windows-desktop
flutter doctor
```

실행합니다.

```text
flutter run -d windows
```

릴리즈 빌드는 다음 명령어를 사용합니다.

```text
flutter build windows --release
```

빌드 결과물은 보통 아래 경로에 생성됩니다.

```text
build/windows/x64/runner/Release/
```

---

<a id="core-code"></a>

## 9. 핵심 코드 한눈에 보기

이 프로젝트에서 중요한 코드는 크게 여섯 부분입니다.

```text
1. 파일 선택
2. 파일 크기 확인
3. 페이지 수 계산
4. 특정 위치부터 부분 읽기
5. UTF-8 안전 디코딩
6. ListView.builder로 줄 단위 표시
```

---

### 9.1 파일 선택 코드

```text
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: [
    'txt',
    'log',
    'md',
    'csv',
    'json',
    'xml',
  ],
);

if (result == null || result.files.single.path == null) {
  setState(() {
    _loading = false;
  });
  return;
}

final path = result.files.single.path!;
```

역할:

```text
사용자가 직접 파일을 고를 수 있게 한다.

result == null
  → 사용자가 파일 선택을 취소했다는 뜻이다.

result.files.single.path
  → 사용자가 선택한 파일의 실제 경로다.
```

---

### 9.2 파일 크기 확인 코드

```text
final file = File(path);
final length = await file.length();
```

역할:

```text
선택한 파일의 전체 크기를 바이트 단위로 확인한다.

예:
3MB 파일이라면 약 3,145,728 bytes 정도가 된다.
```

파일 크기를 알아야 전체 페이지 수를 계산할 수 있습니다.

---

### 9.3 페이지 크기 설정 코드

```text
static const int _pageSizeBytes = 64 * 1024;
```

역할:

```text
한 번에 읽을 파일 크기를 64KB로 정한다.

64 * 1024 = 65,536 bytes
```

파일 전체를 한 번에 읽지 않고, 64KB 단위로 나누어 읽습니다.

예를 들어 10MB 파일이라면 내부적으로는 이런 식으로 나뉩니다.

```text
page 0  → 0KB ~ 64KB
page 1  → 64KB ~ 128KB
page 2  → 128KB ~ 192KB
page 3  → 192KB ~ 256KB
...
```

---

### 9.4 전체 페이지 수 계산 코드

```text
final pageCount = (length + _pageSizeBytes - 1) ~/ _pageSizeBytes;
```

역할:

```text
파일 크기를 페이지 크기로 나누어 전체 페이지 수를 계산한다.
```

`~/`는 Dart에서 정수 나눗셈을 의미합니다.

예를 들어 파일 크기가 200KB이고 페이지 크기가 64KB라면 다음처럼 계산됩니다.

```text
200KB / 64KB = 3.125

필요한 페이지 수는 4페이지
```

그래서 나머지가 있는 경우도 포함하기 위해 아래 공식을 사용합니다.

```text
(length + pageSize - 1) ~/ pageSize
```

---

### 9.5 특정 페이지 읽기 코드

```text
final start = index * _pageSizeBytes;

final desiredLength = math.min(
  _pageSizeBytes,
  _fileLength - start,
);

final readLength = math.min(
  _pageSizeBytes + 3,
  _fileLength - start,
);
```

역할:

```text
index
  → 읽으려는 페이지 번호

start
  → 파일에서 읽기 시작할 위치

desiredLength
  → 실제로 이번 페이지에 포함할 길이

readLength
  → UTF-8 문자 깨짐을 줄이기 위해 조금 더 읽는 길이
```

`_pageSizeBytes + 3`을 읽는 이유는 UTF-8 문자 경계 때문입니다.

한글이나 이모지는 여러 바이트로 구성됩니다.

페이지 끝에서 문자가 중간에 잘리면 깨진 문자가 생길 수 있기 때문에, 끝부분을 조금 더 읽어서 가능한 안전하게 디코딩합니다.

---

### 9.6 RandomAccessFile로 부분 읽기

```text
final raf = await File(path).open(mode: FileMode.read);

try {
  await raf.setPosition(start);
  final bytes = await raf.read(readLength);

  final text = await compute(_decodeUtf8Safely, {
    'bytes': bytes,
    'desiredLength': desiredLength,
  });

  final normalized = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  final lines = normalized.split('\n');

  return lines;
} finally {
  await raf.close();
}
```

역할:

```text
File(path).open()
  → 파일을 연다.

raf.setPosition(start)
  → 읽기 시작할 위치로 이동한다.

raf.read(readLength)
  → 필요한 크기만큼만 읽는다.

compute(...)
  → 디코딩 작업을 별도 isolate에서 처리한다.

replaceAll(...)
  → Windows, macOS, Linux 줄바꿈 차이를 정리한다.

split('\n')
  → 텍스트를 줄 단위로 나눈다.

finally
  → 성공하든 실패하든 파일을 닫는다.
```

이 부분이 렉을 줄이는 핵심입니다.

전체 파일이 아니라 현재 페이지에 해당하는 일부 바이트만 읽습니다.

---

### 9.7 UTF-8 안전 디코딩 코드

```text
String _decodeUtf8Safely(Map<String, Object> message) {
  final bytes = message['bytes'] as Uint8List;
  final desiredLength = message['desiredLength'] as int;

  if (bytes.isEmpty) return '';

  var start = 0;

  while (
    start < bytes.length &&
    start < desiredLength &&
    _isUtf8Continuation(bytes[start])
  ) {
    start++;
  }

  var end = math.min(desiredLength, bytes.length);

  while (end < bytes.length && _isUtf8Continuation(bytes[end])) {
    end++;
  }

  if (end < start) {
    end = start;
  }

  final safeBytes = bytes.sublist(start, end);

  return const Utf8Decoder(
    allowMalformed: true,
  ).convert(safeBytes);
}
```

역할:

```text
바이트 배열을 UTF-8 문자열로 변환한다.

페이지 단위로 파일을 자르면 한글이나 특수문자가 중간에서 잘릴 수 있다.

이 함수는 가능한 한 안전한 위치에서 문자열을 디코딩하도록 돕는다.
```

---

### 9.8 UTF-8 continuation byte 확인 코드

```text
bool _isUtf8Continuation(int byte) {
  return (byte & 0xC0) == 0x80;
}
```

역할:

```text
현재 바이트가 UTF-8 문자의 중간 바이트인지 확인한다.

UTF-8에서 continuation byte는 보통 10xxxxxx 형태다.

(byte & 0xC0) == 0x80
  → 이 바이트가 UTF-8 문자의 중간 부분인지 확인하는 조건이다.
```

파일을 64KB 단위로 자를 때 문자가 중간에서 끊기는 문제를 줄이기 위해 사용합니다.

---

### 9.9 페이지 캐시 코드

```text
static const int _maxCachedPages = 9;

final LinkedHashMap<int, List<String>> _pageCache = LinkedHashMap();
```

역할:

```text
최근에 읽은 페이지를 메모리에 잠시 보관한다.

현재 페이지 주변을 캐시하면 이전/다음 페이지로 이동할 때 다시 파일을 읽지 않아도 된다.
```

캐시 저장 코드는 다음과 같습니다.

```text
void _putCache(int index, List<String> lines) {
  _pageCache.remove(index);
  _pageCache[index] = lines;

  while (_pageCache.length > _maxCachedPages) {
    _pageCache.remove(_pageCache.keys.first);
  }
}
```

동작 방식:

```text
1. 이미 같은 페이지가 캐시에 있으면 제거한다.
2. 새로 읽은 페이지를 캐시에 넣는다.
3. 캐시 개수가 최대치를 넘으면 가장 오래된 페이지를 제거한다.
```

이 방식은 LRU Cache와 비슷합니다.

---

### 9.10 앞뒤 페이지 미리 읽기 코드

```text
void _prefetchAround(int index, int version) {
  for (final page in <int>[index + 1, index - 1]) {
    if (page < 0 || page >= _pageCount) continue;
    if (_pageCache.containsKey(page)) continue;

    unawaited(
      _readPageLines(page, version).catchError(
        (_) => const <String>[],
      ),
    );
  }
}
```

역할:

```text
현재 페이지를 읽은 뒤, 다음 페이지와 이전 페이지를 미리 읽는다.

사용자가 다음 페이지로 넘어갈 가능성이 높기 때문에 미리 준비해둔다.
```

`unawaited`를 사용하는 이유는 다음과 같습니다.

```text
미리 읽기는 꼭 기다릴 필요가 없다.

현재 화면 표시가 먼저이고,
앞뒤 페이지 읽기는 뒤에서 조용히 처리되면 된다.
```

---

### 9.11 ListView.builder 표시 코드

```text
ListView.builder(
  padding: const EdgeInsets.all(16),
  itemCount: _lines.length,
  itemBuilder: (context, index) {
    final line = _lines[index].isEmpty ? ' ' : _lines[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        line,
        style: style,
        softWrap: true,
      ),
    );
  },
)
```

역할:

```text
현재 페이지의 줄 목록을 화면에 표시한다.

ListView.builder는 화면에 필요한 항목 위주로 위젯을 만든다.

즉, 줄이 많아도 처음부터 모든 줄 위젯을 한 번에 만들지 않는다.
```

`Text(hugeText)`보다 `ListView.builder`가 유리한 이유는 다음과 같습니다.

```text
Text(hugeText)
  → 전체 텍스트를 하나의 위젯으로 처리한다.
  → 파일이 커질수록 레이아웃 계산이 무거워진다.

ListView.builder
  → 줄 단위로 나누어 필요한 부분만 만든다.
  → 화면에 보이는 부분 위주로 처리한다.
```

---

<a id="code-explanation"></a>

## 10. 코드별 역할 설명

이 프로젝트의 주요 변수와 함수 역할을 정리하면 다음과 같습니다.

---

### 10.1 페이지 관련 변수

```text
static const int _pageSizeBytes = 64 * 1024;
static const int _maxCachedPages = 9;
```

설명:

```text
_pageSizeBytes
  → 한 번에 읽을 파일 크기다.
  → 현재는 64KB로 설정되어 있다.

_maxCachedPages
  → 메모리에 보관할 최대 페이지 개수다.
  → 현재는 9개 페이지까지 캐시한다.
```

64KB는 너무 크지도 작지도 않은 시작값입니다.

더 빠르게 페이지 이동을 하고 싶다면 128KB로 늘릴 수 있고, 메모리를 더 아끼고 싶다면 32KB로 줄일 수 있습니다.

---

### 10.2 파일 상태 변수

```text
String? _filePath;
String _fileName = '';
int _fileLength = 0;
int _pageCount = 1;
int _pageIndex = 0;
```

설명:

```text
_filePath
  → 현재 열려 있는 파일의 경로

_fileName
  → 화면에 보여줄 파일 이름

_fileLength
  → 파일 전체 크기

_pageCount
  → 전체 페이지 수

_pageIndex
  → 현재 보고 있는 페이지 번호
```

---

### 10.3 화면 상태 변수

```text
List<String> _lines = const [];
bool _loading = false;
bool _selectable = false;
double _fontSize = 15;
String? _error;
```

설명:

```text
_lines
  → 현재 페이지에서 화면에 표시할 줄 목록

_loading
  → 파일을 읽는 중인지 표시

_selectable
  → 텍스트 선택 가능 여부

_fontSize
  → 글자 크기

_error
  → 오류 메시지
```

---

### 10.4 파일 선택 함수

```text
Future<void> _pickAndOpen() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'txt',
        'log',
        'md',
        'csv',
        'json',
        'xml',
      ],
    );

    if (!mounted) return;

    if (result == null || result.files.single.path == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final path = result.files.single.path!;
    final file = File(path);
    final length = await file.length();

    _fileVersion++;
    _pageCache.clear();

    final pageCount = (length + _pageSizeBytes - 1) ~/ _pageSizeBytes;

    setState(() {
      _filePath = path;
      _fileName = _basename(path);
      _fileLength = length;
      _pageCount = pageCount == 0 ? 1 : pageCount;
      _pageIndex = 0;
      _previewPageIndex = 0;
      _lines = const [];
    });

    await _showPage(0);
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = '파일을 열 수 없습니다.\n$e';
    });
  }
}
```

이 함수는 파일 열기 버튼을 눌렀을 때 실행됩니다.

흐름은 다음과 같습니다.

```text
1. 로딩 상태를 true로 바꾼다.
2. 파일 선택 창을 연다.
3. 사용자가 파일을 선택하지 않으면 종료한다.
4. 선택한 파일 경로를 가져온다.
5. 파일 크기를 확인한다.
6. 전체 페이지 수를 계산한다.
7. 기존 캐시를 비운다.
8. 첫 번째 페이지를 읽는다.
```

---

### 10.5 페이지 표시 함수

```text
Future<void> _showPage(int index) async {
  if (_filePath == null) return;

  final clamped = _clampPage(index);
  final version = _fileVersion;
  final ticket = ++_loadTicket;

  setState(() {
    _loading = true;
    _error = null;
    _previewPageIndex = clamped;
  });

  try {
    final lines = await _readPageLines(clamped, version);

    if (!mounted || ticket != _loadTicket || version != _fileVersion) {
      return;
    }

    setState(() {
      _pageIndex = clamped;
      _previewPageIndex = clamped;
      _lines = lines;
      _loading = false;
    });

    _prefetchAround(clamped, version);
  } catch (e) {
    if (!mounted || ticket != _loadTicket) return;

    setState(() {
      _loading = false;
      _error = '페이지를 읽을 수 없습니다.\n$e';
    });
  }
}
```

이 함수는 특정 페이지를 화면에 보여줍니다.

중요한 부분은 `ticket`과 `version`입니다.

```text
version
  → 현재 열려 있는 파일이 바뀌었는지 확인한다.

ticket
  → 여러 페이지 요청이 겹쳤을 때 오래된 요청을 무시하기 위해 사용한다.
```

예를 들어 사용자가 슬라이더를 빠르게 움직이면 여러 페이지 읽기 요청이 동시에 발생할 수 있습니다.

이때 늦게 끝난 오래된 요청이 화면을 덮어쓰면 안 됩니다.

그래서 `ticket`과 `version`으로 현재 요청이 아직 유효한지 확인합니다.

---

### 10.6 페이지 번호 보정 함수

```text
int _clampPage(int index) {
  if (index < 0) return 0;
  if (index >= _pageCount) return _pageCount - 1;
  return index;
}
```

역할:

```text
페이지 번호가 범위를 벗어나지 않게 보정한다.

-1 페이지 요청
  → 0 페이지로 보정

마지막 페이지보다 큰 번호 요청
  → 마지막 페이지로 보정
```

---

### 10.7 파일 이름 추출 함수

```text
String _basename(String path) {
  return path.split(Platform.pathSeparator).last;
}
```

역할:

```text
전체 파일 경로에서 파일 이름만 뽑아낸다.
```

예를 들어 아래 경로가 있다면:

```text
C:\Users\parva\Desktop\sample.txt
```

결과는 다음과 같습니다.

```text
sample.txt
```

---

### 10.8 파일 크기 표시 함수

```text
String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unit = 0;

  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }

  final fixed = size < 10 && unit > 0 ? 1 : 0;
  return '${size.toStringAsFixed(fixed)} ${units[unit]}';
}
```

역할:

```text
바이트 단위 파일 크기를 사람이 읽기 쉬운 형태로 바꾼다.
```

예시:

```text
512       → 512 B
2048      → 2 KB
3145728   → 3 MB
10485760  → 10 MB
```

---

<a id="performance"></a>

## 11. 성능상 장점

기존 방식은 파일 크기가 커질수록 부담이 크게 증가합니다.

```text
파일 크기 증가
  ↓
읽어야 할 문자열 증가
  ↓
메모리 사용량 증가
  ↓
Text 레이아웃 계산 증가
  ↓
앱 멈춤
```

`clean_txt_viewer` 방식은 파일 크기가 커져도 한 번에 처리하는 양을 제한합니다.

```text
파일 크기 증가
  ↓
현재 페이지 크기는 거의 동일
  ↓
메모리 사용량 안정적
  ↓
렌더링할 줄 수 제한
  ↓
렉 감소
```

비교하면 다음과 같습니다.

```text
기존 방식:
100MB 파일을 열면 100MB 전체를 읽으려고 한다.

clean_txt_viewer 방식:
100MB 파일을 열어도 현재 페이지의 약 64KB만 먼저 읽는다.
```

그래서 큰 파일에서도 첫 화면을 더 빠르게 보여줄 수 있습니다.

---

<a id="cautions"></a>

## 12. 주의할 점

### 12.1 아주 긴 한 줄은 여전히 느릴 수 있음

줄바꿈이 거의 없는 파일은 한 줄 자체가 너무 길어질 수 있습니다.

예를 들어 JSON이 한 줄로 20MB 들어 있는 경우입니다.

```text
{"items":[{"id":1,"name":"..."},{"id":2,"name":"..."} ... ]}
```

이 경우 줄 단위 렌더링만으로는 부족할 수 있습니다.

해결하려면 긴 줄을 일정 길이마다 다시 나누는 처리가 필요합니다.

```text
긴 한 줄
  ↓
문자 수 기준으로 분할
  ↓
짧은 여러 줄로 표시
```

---

### 12.2 UTF-8이 아닌 파일은 깨질 수 있음

한국어 TXT 파일 중에는 UTF-8이 아니라 CP949 또는 EUC-KR 인코딩을 사용하는 경우가 있습니다.

현재 구조는 UTF-8 기준입니다.

UTF-8이 아닌 파일을 열면 글자가 깨질 수 있습니다.

나중에 추가할 수 있는 방식은 다음과 같습니다.

```text
1. 인코딩 자동 감지
2. 사용자가 직접 인코딩 선택
3. CP949 / EUC-KR 디코더 추가
```

---

### 12.3 페이지는 문장 기준이 아님

이 프로젝트의 페이지는 파일을 바이트 크기로 나눈 단위입니다.

```text
1페이지 = 약 64KB
```

그래서 문장이나 문단이 페이지 경계에서 나뉠 수 있습니다.

예를 들어 page 1의 마지막 문장이 page 2에서 이어질 수 있습니다.

---

### 12.4 텍스트 선택 기능은 성능에 영향을 줄 수 있음

`SelectableText`는 일반 `Text`보다 무겁습니다.

그래서 이 프로젝트에서는 텍스트 선택 기능을 스위치로 켜고 끌 수 있게 합니다.

```text
텍스트 선택 OFF
  → 일반 Text 사용
  → 더 가볍다.

텍스트 선택 ON
  → SelectableText 사용
  → 복사할 수 있지만 더 무겁다.
```

대용량 파일을 빠르게 읽을 때는 텍스트 선택을 끄는 것이 좋습니다.

---

<a id="future"></a>

## 13. 개선 아이디어

앞으로 추가할 수 있는 기능은 다음과 같습니다.

```text
검색 기능
북마크 기능
최근 열었던 파일 목록
다크 모드 / 라이트 모드 전환
글꼴 변경
CP949, EUC-KR 인코딩 지원
긴 줄 자동 분할
현재 위치 저장
마우스 휠 감도 설정
탭으로 여러 파일 열기
파일 드래그 앤 드롭
```

특히 먼저 추가하면 좋은 기능은 다음 세 가지입니다.

```text
1. 검색 기능
2. 최근 파일 목록
3. 마지막 읽은 위치 저장
```

이 세 가지가 들어가면 단순 뷰어에서 실제로 자주 쓰는 도구에 가까워집니다.

---

<a id="summary"></a>

## 14. 요약

`clean_txt_viewer`는 대용량 텍스트 파일을 부드럽게 보기 위해 다음 전략을 사용합니다.

```text
전체 읽기 금지
부분 읽기 사용
UI 스레드 보호
보이는 줄만 렌더링
주변 페이지만 캐시
```

핵심 구조는 다음과 같습니다.

```text
파일 선택
  → file_picker

파일 일부 읽기
  → RandomAccessFile

디코딩 분리
  → compute

화면 표시
  → ListView.builder

페이지 이동 최적화
  → 캐시와 prefetch
```

이 구조 덕분에 파일 크기가 커져도 앱이 한 번에 처리해야 하는 데이터 양은 작게 유지됩니다.

결과적으로 3MB 이상의 텍스트 파일에서도 렉을 크게 줄일 수 있습니다.