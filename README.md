# Motion Prompt Lab

**Motion Prompt Lab**은 대상·자세·상황·동작·이동 경로·시점·스타일·프레임 수를 선택해 스프라이트 시트와 모션 시퀀스용 이미지 생성 프롬프트를 만드는 정적 웹 도구입니다.

- Repository: https://github.com/ko9ma7/motion-prompt
- GitHub Pages: https://ko9ma7.github.io/motion-prompt/
- 목표 버전: `v1.0.0`

## 주요 기능

- **35개 프리셋**: 전투, 아이들, 서기, 앉기, 눕기, 수면, 깨기, 앉기/일어서기/눕기 전환, 걷기, 조깅, 달리기, 살금살금 걷기, 기어가기, 점프, 낙하, 착지, 슬라이드, 구르기, 회피, 비행, 부유, 활공, 무중력, 수영, 제자리 헤엄, 등반, 춤, 감정 표현, 오브젝트 상호작용, 8방향 회전, 스토리보드 등
- **33개 상황/자세**: 서기, 벽 기대기, 의자/바닥 앉기, 쪼그리기, 무릎 꿇기, 네 발 자세, 바로/옆으로/엎드려 눕기, 웅크리기, 잠들기, 공중/비행/부유/무중력, 수면/수중, 등반/매달림/한 손 매달림/로프, 균형, 계단, 경사, 좁은 공간 등
- **83개 동작**: 호흡, 기지개, 하품, 앉기/일어서기/눕기/일어나기, 걷기/조깅/달리기/전력질주/살금살금 걷기, 점프/도약/슬라이드/구르기, 날기/활공/급강하, 수영/제자리 헤엄/부상, 펀치/킥/베기/찌르기/패링/회전공격, 춤/환호/박수/가리키기, 읽기/쓰기/타이핑/던지기/받기/들기 등
- 상황 선택은 **지상 / 공중·무중력 / 수면·수중 / 등반·매달림 / 지형·탑승 / 특수** 그룹으로 분류
- 동작 선택은 **기본 상태 / 지상 이동 / 공중·수중 / 전투 / 감정·사회적 동작 / 오브젝트 상호작용 / 방향·시선**으로 분류
- 동작 패밀리에 맞는 프레임 플랜 자동 생성
- 프레임 수 4 / 8 / 12 / 16 / 20 / 24 및 여러 배열 선택
- 대상 정체성, 스케일, 카메라, 등록점, 루프, 잘림, 셀 침범, 실제 알파 투명도 제약 설정
- LocalStorage로 마지막 설정과 테마 유지
- URL Hash로 현재 설정 공유
- Light / Dark theme
- API 키와 서버가 필요 없는 정적 GitHub Pages 프로젝트

## 12개 국가/지역 언어

**인터페이스 언어와 프롬프트 출력 언어를 서로 독립적으로 선택**할 수 있습니다.

| Locale | 언어 / 지역 |
|---|---|
| `ko-KR` | 한국어 · 대한민국 |
| `en-US` | English · United States |
| `ja-JP` | 日本語 · 日本 |
| `zh-CN` | 简体中文 · 中国 |
| `es-ES` | Español · España |
| `fr-FR` | Français · France |
| `de-DE` | Deutsch · Deutschland |
| `pt-BR` | Português · Brasil |
| `it-IT` | Italiano · Italia |
| `ru-RU` | Русский · Россия |
| `id-ID` | Bahasa Indonesia · Indonesia |
| `tr-TR` | Türkçe · Türkiye |

예를 들어 다음 조합이 가능합니다.

- UI: 한국어 / Prompt: 한국어
- UI: 한국어 / Prompt: English
- UI: 日本語 / Prompt: Español
- UI: Bahasa Indonesia / Prompt: Türkçe

자유 입력한 대상·상황·동작 설명은 외부 번역 API를 사용하지 않으므로 원문을 유지합니다. UI 언어와 프롬프트 언어가 다를 때는 생성 프롬프트 안에 **다른 언어로 작성된 자유 입력도 의미를 충실하게 해석하라는 지시**가 자동으로 추가됩니다.

## Windows 원클릭 GitHub Bootstrap

프로젝트 루트의 `github-bootstrap.cmd`를 Windows 10/11에서 실행하면 아래 작업을 순서대로 처리합니다.

1. Git 설치/버전 확인
2. Node.js/npm 확인 — 이 프로젝트에서는 선택 사항
3. GitHub CLI(`gh`) 설치 확인
4. `gh auth status` 확인 및 필요 시 `gh auth login` 시작
5. Git 사용자 이름/이메일 확인 및 로컬 설정
6. Git repository 초기화 및 `main` 브랜치 설정
7. JavaScript 문법 검사
8. `ko9ma7/motion-prompt` Repository 존재 여부 확인
9. Repository가 없을 때만 생성
10. `origin`을 `https://github.com/ko9ma7/motion-prompt.git`으로 연결
11. 파일 add / commit / push
12. Repository Description / Homepage / Topics 설정
13. GitHub Pages를 **GitHub Actions workflow 방식**으로 활성화
14. `deploy.yml` 실행
15. `gh run watch --exit-status`로 실제 배포 완료 확인
16. 배포 성공 후 `v1.0.0` 태그와 GitHub Release를 중복 없이 생성
17. 최종 Pages URL 출력 및 브라우저 열기

이미 Repository, remote, commit, Pages 설정, tag, release가 존재하면 가능한 부분은 그대로 사용하며 **중복 생성하지 않는 idempotent 방식**으로 처리합니다. 원격 브랜치와 로컬 브랜치가 충돌할 경우에는 강제 push를 하지 않고 복구 명령을 출력합니다.

### 실행

ZIP을 풀고 프로젝트 폴더에서 다음 파일을 더블클릭합니다.

```text
github-bootstrap.cmd
```

GitHub CLI가 없다면 스크립트가 다음 설치 명령을 안내합니다.

```bat
winget install --id GitHub.cli -e
```

Git이 없다면:

```bat
winget install --id Git.Git -e
```

> 토큰, 비밀번호, API Key를 `.cmd`나 Repository에 저장하지 않습니다. GitHub 인증은 `gh auth login`이 담당합니다.

## Repository 권장 설정

`github-bootstrap.cmd`에 다음 기본값이 이미 들어 있습니다.

- Repository: `ko9ma7/motion-prompt`
- Visibility: `public`
- Default branch: `main`
- Description: `Multilingual sprite-sheet and motion prompt builder for image generation`
- Homepage: `https://ko9ma7.github.io/motion-prompt/`
- Initial tag: `v1.0.0`
- Initial commit: `feat: launch multilingual Motion Prompt Lab`
- Topics: `prompt-engineering`, `sprite-sheet`, `pixel-art`, `animation`, `image-generation`, `github-pages`, `javascript`, `i18n`

다른 저장소에 재사용할 때는 `.cmd` 상단 변수만 변경하면 됩니다.

## 로컬 실행

빌드 단계가 없는 순수 HTML/CSS/JavaScript 프로젝트입니다.

```bash
python -m http.server 8080
```

브라우저에서 `http://localhost:8080/`을 엽니다.

### JavaScript 검증

Node.js가 설치되어 있다면:

```bash
node --check i18n.js
node --check prompt-engine.js
node --check app.js
```

## GitHub Pages 배포

수동으로 배포하는 경우에도 `main`에 push하면 `.github/workflows/deploy.yml`이 정적 사이트 전체를 GitHub Pages artifact로 업로드합니다.

```bash
git add -A
git commit -m "feat: launch multilingual Motion Prompt Lab"
git push -u origin main
```

Repository의 **Settings → Pages → Build and deployment → Source**는 `GitHub Actions`를 사용합니다.

## Project Structure

```text
/
├─ .github/
│  └─ workflows/
│     └─ deploy.yml
├─ assets/
│  ├─ favicon.svg
│  ├─ favicon-32.png
│  ├─ apple-touch-icon.png
│  ├─ icon-192.png
│  ├─ icon-512.png
│  └─ og-image.png
├─ .gitattributes
├─ .gitignore
├─ .nojekyll
├─ 404.html
├─ LICENSE
├─ README.md
├─ app.js
├─ blog-post.md
├─ favicon.ico
├─ github-bootstrap.cmd
├─ guide.html
├─ i18n.js
├─ index.html
├─ manifest.webmanifest
├─ prompt-engine.js
├─ robots.txt
├─ sitemap.xml
├─ site.webmanifest
└─ styles.css
```

## 주요 파일

- `i18n.js`: UI 언어, 옵션 라벨, 12개 locale 관리
- `prompt-engine.js`: 프리셋, 액션 패밀리, 프레임 플랜, 언어별 프롬프트 구조
- `app.js`: 상태 관리, UI 언어 적용, 프롬프트 렌더링, 복사/공유, LocalStorage
- `github-bootstrap.cmd`: Windows GitHub 초기화·Repository 연결·Pages 배포 자동화
- `.github/workflows/deploy.yml`: GitHub Pages Actions 배포
- `guide.html` / `blog-post.md`: 제작 원리와 활용 가이드

## Branding / Social Preview

- Canonical: `https://ko9ma7.github.io/motion-prompt/`
- Open Graph / X Card 이미지: `assets/og-image.png`
- `favicon.ico`, SVG favicon, 32px favicon, Apple Touch Icon, 192/512 PWA icon 포함
- `site.webmanifest` 포함
- `robots.txt` + `sitemap.xml` 포함

GitHub Repository의 **Settings → General → Social preview**에는 `assets/og-image.png`를 업로드해 사용할 수 있습니다.

## Security

GitHub Pages는 공개 프론트엔드이므로 OpenAI API Key, GitHub token, password, private key 등을 소스에 넣지 않습니다. 현재 서비스는 이미지 생성 API를 직접 호출하지 않고 프롬프트만 생성합니다.

실제 이미지 생성 버튼을 추가하려면 API Key를 보호할 별도의 Serverless/API Proxy가 필요합니다.

## License

MIT License. 자세한 내용은 `LICENSE`를 확인하세요.
