# Peek 개발 노트

빌드: `./build.sh` → `build/Peek.app` (유니버설: arm64 + x86_64). 배포: `./release.sh` → `dist/Peek-<버전>.dmg` + SHA-256.
Xcode 프로젝트 없이 `swiftc`로 직접 빌드한다. 애드혹 서명이라 배포본은 처음 열 때 Gatekeeper 확인을 거친다.
DMG는 `create-dmg`(brew)로 만들고 배경은 `dmg/background.tiff`(1x·2x 묶음)다.

## 구조

```
Sources/
  main.swift          진입점
  AppDelegate.swift   메뉴막대 상주 + 단축키 메뉴
  PlayerWindow.swift  플로팅 패널(NSPanel) + WKWebView + 호버 툴바 + 주소 입력·사이트 추가 화면
  Sheets.swift        주소 입력·사이트 추가 화면의 작은 뷰들(줄·입력 칸·버튼)
  Shim.swift          Fullscreen API 후킹 (창 안 전체화면)
  Services.swift      서비스 목록·내 사이트·최근 주소 + 환경설정 + 한/영 문구(L)
```

### 광고 차단

크롬 확장(uBlock Origin 등)은 WKWebView에서 실행되지 않는다. 대신 Safari 콘텐츠 차단기와
같은 형식(`WKContentRuleList`)으로 같은 일을 한다 — `Sources/AdBlock.swift`.

**유튜브 광고의 본체는 네트워크가 아니라 player 응답 안의 `adPlacements`/`playerAds` 다.**
요청을 막으면 차단 감지에 걸리므로, 막지 않고 응답에서 광고 항목만 지운다.

- `JSON.parse`·`Response.prototype.json`·`ytInitialPlayerResponse` 후크로 광고 필드 제거 (documentStart)
- 서드파티 광고 호스트 11종 네트워크 차단 (doubleclick·googlesyndication·imasdk 등)
- CSS 숨김(유튜브 배너·피드 광고, 트위치 광고 라벨)
- 빠져나온 인스트림 광고는 MutationObserver로 즉시 스킵 버튼 클릭 + 광고 트랙 끝으로 보내기
- youtube.com 경로(`/pagead`·`/ptracking`·`api/stats/ads`)는 **일부러 차단하지 않는다.** 차단 감지의 대표 신호다

메뉴막대 → 「광고 차단 (YouTube·Twitch)」로 끄고 켠다. 기본 켜짐.

⚠️ **WebKit 콘텐츠 차단기의 정규식은 `(a|b|c)` 그룹을 지원하지 않는다.** 대안을 묶어 쓰면
목록 전체가 조용히 컴파일 실패하고 차단이 하나도 안 걸린다. 규칙은 반드시 하나씩 분리한다.

### 아이콘

`icon/main.swift`가 Paper 시안(「Peek 툴바」 파일 · 아이콘 가-3)을 CoreGraphics로 직접 그려 PNG 7종을 뽑고, `iconutil`로 `AppIcon.icns`를 만든다.
`./icon/gen icon/out` 후 iconset 구성 → `iconutil -c icns`. 비트맵 원본이 없어도 크기별로 선명하다.

### 왜 Fullscreen API를 후킹하나

사이트의 전체화면 버튼을 그대로 두면 macOS 네이티브 전체화면이 발동해 별도 스페이스로 튄다.
플로팅 창의 목적과 정반대다. 그래서 `requestFullscreen`을 가로채 **창 안에서만** 전체화면을 만든다.

사이트마다 전체화면을 요청하는 대상이 다르다. 넷플릭스·티빙은 자기 플레이어 컨테이너를 넘기지만
**유튜브는 `<html>` 자체를 넘긴다.** 그대로 두면 플레이어가 커지지 않으므로, `html`·`body`가 오면
가장 큰 video의 플레이어 루트(`#movie_player` 등)로 바꿔 채운다.

또 유튜브는 전체화면일 때 창이 아니라 `screen` 크기로 플레이어를 잡는다. 가짜 전체화면 동안에는
`screen.width/height`가 창 크기를 답하도록 위장한다.

구현은 오버레이(`position:fixed`)가 아니라 **조상 체인 펴기**다.
유튜브·넷플릭스처럼 조상에 `transform`이 걸린 사이트에서는 `position:fixed`가 그 조상 안에 갇혀
오버레이가 화면을 못 덮는다(검은 화면·흰 여백으로 나타난다). 대신 대상의 조상들을 100%로 펴고
형제 요소를 `display:none`으로 숨긴 뒤, 해제할 때 전부 원복한다.

## DRM 상태 (중요)

WKWebView에서 확인한 것:

| 키 시스템 | 결과 |
|---|---|
| `com.apple.fps` / `.1_0` / `.2_0` / `.3_0` (FairPlay) | **지원** |
| `org.w3.clearkey` | 지원 |
| `com.widevine.alpha` | 미지원 |
| `com.microsoft.playready` | 미지원 |

넷플릭스·티빙·웨이브는 Safari에서 FairPlay를 쓰므로 경로는 열려 있고, User-Agent도 Safari로 보낸다.
넷플릭스·티빙은 실제 계정으로 재생까지 확인됐다(2026-09-01). Widevine만 쓰는 서비스(크롬 전용)는 재생되지 않는다.

## 한계

- 화질은 Safari 정책을 따른다. 넷플릭스 4K는 Safari에서도 안 나온다
- 서비스가 앱 내 브라우저를 차단하면 우회하지 않는다
- 애드혹 서명이라 처음 열 때 「그래도 열기」가 필요하다. 없애려면 개발자 ID 서명·공증이 필요하다
- 빌드할 때마다 서명이 바뀌어, 키체인의 「Peek WebCrypto Master Key」 접근을 다시 묻는다(개발 중에만)

## 디자인 정본

Paper 파일 「Peek 툴바」가 정본이다. 툴바·서비스 메뉴·주소 입력·사이트 추가·앱 아이콘(가-3)·GitHub 히어로·DMG 배경.
히어로 속 장면은 Blender Foundation의 「Spring」(2019) 한 장면으로, Wikimedia Commons에서 CC0로 공개된 캡처다.
