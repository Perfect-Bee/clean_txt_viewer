# Clean TXT Viewer

대용량 TXT 파일을 빠르게 읽기 위한 Flutter 기반 텍스트 뷰어 프로젝트

---

## 목차

1. [프로젝트 소개](#1-프로젝트-소개)
2. [개발 목적](#2-개발-목적)
3. [핵심 기능](#3-핵심-기능)
4. [핵심 실행 과정](#4-핵심-실행-과정)
5. [대용량 파일 처리 원리](#5-대용량-파일-처리-원리)
6. [실행 방법](#6-실행-방법)
7. [APK 빌드](#7-apk-빌드)
8. [현재 구현 상태](#8-현재-구현-상태)
9. [프로젝트 구조](#9-프로젝트-구조)
10. [아키텍처 설명](#10-아키텍처-설명)
11. [주요 클래스 설명](#11-주요-클래스-설명)
12. [향후 개발 계획](#12-향후-개발-계획)
13. [사용 패키지](#13-사용-패키지)
14. [GitHub 업로드 시 제외](#14-github-업로드-시-제외)
15. [최종 목표](#15-최종-목표)
16. [최근 수정 사항](#16-최근-수정-사항)

---

## 1. 프로젝트 소개

Clean TXT Viewer는 Flutter로 개발 중인 대용량 텍스트 뷰어입니다.

일반적인 텍스트 뷰어는 파일 전체를 메모리에 로드하기 때문에 수 MB 이상만 되어도 렉이 발생할 수 있습니다.

본 프로젝트는 TXT 파일 전체를 한 번에 읽지 않고, 필요한 부분만 페이지 단위로 읽어 화면에 표시하는 것을 목표로 합니다.

```text
- 대용량 TXT 파일 지원
- 페이지 단위 읽기
- 캐시 기반 페이지 이동
- 부드러운 탐색
- Android APK 배포
- 읽던 위치 저장
```

장기적으로는 EasyViewer 수준의 TXT 리더를 목표로 합니다.

---

## 2. 개발 목적

일반적인 방식은 TXT 파일 전체를 읽고 메모리에 적재한 뒤 UI에 렌더링합니다.

```text
TXT 파일
 ↓
전체 파일 읽기
 ↓
메모리 적재
 ↓
UI 렌더링
 ↓
렉 발생
```

Clean TXT Viewer는 현재 필요한 페이지 위치를 계산한 뒤, 필요한 부분만 읽고 캐시에 저장합니다.

```text
TXT 파일
 ↓
현재 페이지 위치 계산
 ↓
필요한 부분만 읽기
 ↓
화면 표시
 ↓
캐시 저장
```

따라서 수 MB 이상의 TXT 파일도 상대적으로 안정적으로 읽을 수 있습니다.

---

## 3. 핵심 기능

현재 구현 목표

```text
TXT 파일 선택
TXT 파일 읽기
페이지 단위 탐색
캐시 기반 로딩
글자 크기 변경
텍스트 선택
Android APK 지원
```

향후 목표

```text
최근 파일 목록
읽던 위치 저장
이어 읽기
검색
북마크
다크 모드
```

---

## 4. 핵심 실행 과정

Clean TXT Viewer의 핵심 실행 흐름은 다음과 같습니다.

```text
파일 선택
 ↓
파일 정보 생성
 ↓
현재 페이지 계산
 ↓
RandomAccessFile로 필요한 구간만 읽기
 ↓
UTF-8 안전 디코딩
 ↓
화면에 텍스트 출력
 ↓
이전/현재/다음 페이지 캐시 유지
```

최근에는 페이지를 직접 넘기는 방식에서 연속 스크롤 방식으로 확장되었습니다.

```text
64KB
 ↓
화면 출력
 ↓
스크롤 감지
 ↓
다음 페이지 자동 로딩
 ↓
기존 내용 뒤에 추가
```

결과적으로 사용자는 페이지를 넘긴다는 느낌보다 하나의 긴 문서를 읽는 느낌으로 사용할 수 있습니다.

---

## 5. 대용량 파일 처리 원리

기존 방식

```text
TXT
 ↓
전체 읽기
 ↓
메모리 적재
 ↓
화면 출력
```

문제

```text
파일 크기가 커질수록 렉 발생
```

현재 방식

```text
TXT
 ↓
현재 페이지 계산
 ↓
64KB 읽기
 ↓
텍스트 변환
 ↓
화면 출력
```

예시

```text
10MB TXT

1페이지
64KB

2페이지
64KB

3페이지
64KB
```

필요한 부분만 읽음

---

## 6. 실행 방법

패키지 설치

```bash
flutter pub get
```

실행

```bash
flutter run
```

---

## 7. APK 빌드

릴리즈 APK 생성

```bash
flutter build apk --release
```

생성 위치

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 8. 현재 구현 상태

<details>
<summary>현재 구현 상태 상세 보기</summary>

### 파일 선택

```dart
FilePicker.platform.pickFiles(...)
```

지원 형식

```text
txt
log
md
csv
json
xml
```

---

### 페이지 단위 읽기

```dart
RandomAccessFile
```

사용

```text
파일 전체를 읽지 않음
필요한 위치만 읽음
```

---

### 페이지 캐시

```text
이전 페이지
현재 페이지
다음 페이지
```

를 메모리에 유지

페이지 이동 시 체감 속도 향상

---

### UTF-8 안전 디코딩

```dart
Utf8Decoder(
  allowMalformed: true,
)
```

사용

UTF-8 문자 경계 문제 최소화

---

### 글자 크기 조절

```text
10 ~ 30px
```

범위 지원

---

### 텍스트 선택

```text
SelectableText
```

지원

</details>

---

## 9. 프로젝트 구조

<details>
<summary>프로젝트 구조 상세 보기</summary>

```text
lib/

├─ main.dart

├─ app/
│  ├─ clean_txt_viewer_app.dart
│  └─ app_theme.dart
│
├─ core/
│  └─ utils/
│      ├─ file_size_formatter.dart
│      └─ utf8_decoder.dart
│
└─ features/
   └─ reader/
      │
      ├─ data/
      │   ├─ txt_file_picker.dart
      │   └─ txt_page_reader.dart
      │
      ├─ domain/
      │   ├─ txt_file_info.dart
      │   └─ txt_reader_config.dart
      │
      └─ presentation/
          ├─ txt_reader_screen.dart
          │
          └─ widgets/
              ├─ reader_toolbar.dart
              └─ text_line_list.dart
```

</details>

---

## 10. 아키텍처 설명

<details>
<summary>아키텍처 설명 상세 보기</summary>

### main.dart

앱 시작점

```dart
void main() {
  runApp(
    const CleanTxtViewerApp(),
  );
}
```

역할

```text
앱 실행만 담당
```

---

### app

앱 전체 설정 담당

```text
MaterialApp
Theme
초기 화면
```

---

### core

공통 기능

```text
파일 크기 변환
UTF-8 디코딩
```

---

### features

실제 기능 구현

```text
파일 선택
파일 읽기
UI
```

</details>

---

## 11. 주요 클래스 설명

<details>
<summary>주요 클래스 설명 상세 보기</summary>

### TxtFilePicker

역할

```text
파일 선택 창 열기
파일 정보 생성
```

---

### TxtFileInfo

역할

```text
파일 경로
파일 이름
파일 크기
전체 페이지 수
```

보관

---

### TxtPageReader

역할

```text
페이지 읽기
캐시
UTF-8 처리
미리 읽기
```

---

### ReaderToolbar

역할

```text
이전 페이지
다음 페이지
슬라이더
글자 크기
```

UI 제공

---

### TextLineList

역할

```text
텍스트 렌더링
```

전담

---

### TxtReaderScreen

역할

```text
화면 상태 관리
페이지 전환
파일 열기
```

</details>

---

## 12. 향후 개발 계획

<details>
<summary>향후 개발 계획 상세 보기</summary>

### 1단계

```text
APK 빌드 안정화
```

---

### 2단계

```text
최근 파일 목록
```

---

### 3단계

```text
읽던 위치 저장
```

저장 정보

```text
파일 경로
현재 페이지
글자 크기
마지막 열람 시간
```

---

### 4단계

```text
이어 읽기
```

앱 실행

```text
최근 파일 복원
↓
마지막 페이지 이동
↓
계속 읽기
```

---

### 5단계

```text
검색 기능
```

---

### 6단계

```text
북마크
```

---

### 7단계

```text
다크 모드
```

</details>

---

## 13. 사용 패키지

<details>
<summary>사용 패키지 상세 보기</summary>

### file_picker

```yaml
file_picker: ^8.0.0
```

역할

```text
파일 선택
```

</details>

---

## 14. GitHub 업로드 시 제외

<details>
<summary>GitHub 업로드 제외 항목 보기</summary>

```text
build/
.dart_tool/
.idea/
.env
*.jks
*.keystore
개인 txt 파일
```

</details>

---

## 15. 최종 목표

<details>
<summary>최종 목표 상세 보기</summary>

```text
EasyViewer 수준의
대용량 TXT 뷰어
```

목표 기능

```text
빠른 파일 탐색
부드러운 페이지 이동
읽던 위치 저장
최근 파일 관리
검색
북마크
Android APK 배포
```

</details>

---

## 16. 최근 수정 사항

### 연속 스크롤 시스템 도입

초기 버전은 페이지 단위 탐색 방식으로 동작했습니다.

```text
페이지 1
 ↓
스크롤
 ↓
끝 도달
 ↓
다음 페이지 버튼 클릭
 ↓
페이지 2 로드
```

이 방식은 메모리 사용량은 적지만 긴 소설이나 로그 파일을 읽을 때 문서가 끊겨 보이는 문제가 있었습니다.

이를 개선하기 위해 연속 스크롤(Continuous Scrolling) 시스템을 도입했습니다.

<details>
<summary>최근 수정 사항 상세 보기</summary>

### 변경 목적

기존 방식

```text
64KB
 ↓
화면 출력
 ↓
사용자가 직접 다음 페이지 이동
```

개선 방식

```text
64KB
 ↓
화면 출력
 ↓
스크롤 감지
 ↓
다음 페이지 자동 로딩
 ↓
기존 내용 뒤에 추가
```

결과적으로 사용자는 페이지를 넘긴다는 느낌보다 하나의 긴 문서를 읽는 느낌으로 사용할 수 있습니다.

---

### ScrollController 추가

사용 코드

```dart
final ScrollController _scrollController =
    ScrollController();
```

역할

```text
현재 스크롤 위치 추적

스크롤 이벤트 감지

자동 페이지 로딩 트리거

스크롤바 직접 제어
```

---

### 스크롤바 직접 조작 지원

기존에는 마우스 휠로만 이동 가능했습니다.

추가 코드

```dart
Scrollbar(
  controller: scrollController,
  thumbVisibility: true,
  interactive: true,
)
```

변경 후

```text
스크롤바 드래그 가능

스크롤바 클릭 가능

보다 일반적인 문서 뷰어 사용 경험 제공
```

---

### 자동 다음 페이지 로딩

스크롤 위치를 감지하여 하단 근처에 도달하면 자동으로 다음 페이지를 읽습니다.

사용 코드

```dart
if (
  position.pixels >=
  position.maxScrollExtent - 800
) {
  _loadNextPage();
}
```

역할

```text
스크롤 끝 감지

다음 페이지 자동 로딩

사용자 조작 최소화
```

---

### 페이지 누적 방식 변경

기존 방식

```dart
_lines = lines;
```

특징

```text
새 페이지 이동 시
기존 데이터 제거
```

---

변경 방식

```dart
_lines = [
  ..._lines,
  ...newLines,
];
```

특징

```text
기존 데이터 유지

새 페이지 추가

연속 문서처럼 표시
```

---

### 자동 페이지 로딩 함수 추가

추가 함수

```dart
Future<void> _loadNextPage()
```

역할

```text
현재 페이지 확인

다음 페이지 존재 여부 확인

다음 페이지 읽기

기존 내용 뒤에 추가

주변 페이지 캐시 미리 생성
```

처리 흐름

```text
스크롤
 ↓
하단 근접
 ↓
_loadNextPage()
 ↓
다음 페이지 읽기
 ↓
화면 갱신
```

---

### 메모리 관리 현황

현재 방식

```text
읽은 페이지를 계속 유지
```

예시

```text
1페이지
2페이지
3페이지
...
100페이지
```

읽은 모든 페이지가 메모리에 남아 있습니다.

장점

```text
뒤로 이동 시 빠름
```

단점

```text
매우 큰 파일에서는
메모리 사용량 증가
```

---

### 향후 개선 예정

#### 페이지 윈도우 방식

현재 위치 기준

```text
현재 페이지

앞쪽 5페이지

뒤쪽 5페이지
```

만 유지

오래된 페이지는 자동 제거

---

#### 가상 스크롤(Virtual Scrolling)

목표

```text
100MB 이상 TXT

수천 페이지

수만 줄
```

에서도 안정적인 동작

구상

```text
화면에 보이는 영역만 렌더링

필요한 페이지만 메모리에 유지
```

---

### 변경된 클래스

#### TxtReaderScreen

추가 역할

```text
ScrollController 관리

스크롤 감지

자동 페이지 로딩

연속 스크롤 관리
```

---

#### TextLineList

추가 역할

```text
스크롤바 표시

스크롤바 직접 조작

ScrollController 연결
```

---

### 기대 효과

```text
페이지 이동 최소화

자연스러운 독서 경험

긴 TXT 파일 읽기 편의성 향상

EasyViewer와 유사한 사용 경험 제공
```

---

### 참고

이번 변경은 단순 UI 수정이 아니라

```text
페이지 전환형 뷰어
```

에서

```text
연속 스크롤 기반 뷰어
```

로 발전하기 위한 첫 단계입니다.

향후

```text
읽던 위치 저장

최근 파일 목록

검색

북마크

가상 스크롤
```

기능의 기반이 되는 구조입니다.

</details>
