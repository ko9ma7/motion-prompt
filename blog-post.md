# GPT Image 2.5로 4×4 스프라이트 시트 만들기

요즘 SNS에서 캐릭터 한 장을 넣고 16개의 전투 동작, 걷기, 아이들 모션을 한 번에 뽑는 이미지가 자주 보입니다. 핵심은 ‘4×4라고 써주는 것’보다 **캐릭터 일관성, 동작의 시간 순서, 기준점을 얼마나 정확히 고정하느냐**에 있습니다.

> **핵심 요약**: 4×4 한 장을 완성본으로 생각하지 말고, 16개의 키프레임 후보를 한 번에 만드는 시각적 초안으로 생각하는 편이 좋습니다. 생성 후에는 반드시 프레임 단위로 잘라 실제 재생 검수를 해야 합니다.

## 왜 GPT Image 2.5에서 이 방식이 특히 잘 맞나

OpenAI는 2026년 9월 8일 ChatGPT Images 2.5를 발표하면서 참조 대상 보존, 여러 차례 편집에서의 일관성, 복잡한 레이아웃과 투명 배경 처리 개선을 주요 변화로 설명했습니다. 이 특성은 스프라이트 시트처럼 같은 대상을 유지하면서 포즈만 바꿔야 하는 작업과 직접 맞닿아 있습니다.

출시 직후 X와 Reddit에는 캐릭터를 4×4, 총 16프레임으로 배치한 전투 모션·아이들 애니메이션 사례가 빠르게 공유됐습니다. 다만 보기 좋은 스프라이트 시트와 실제 게임 엔진에서 자연스럽게 재생되는 애니메이션은 다른 문제입니다. 팔·다리 좌우가 바뀌거나, 발 위치가 흔들리거나, 프레임 사이 예비동작이 부족한 문제는 여전히 검수해야 합니다.

## 4×4를 먼저 적기보다 ‘시간축’을 설계해야 합니다

전투 동작은 다음처럼 분해해두는 편이 좋습니다.

| 구간 | 역할 | 프레임 예시 |
|---|---|---:|
| Ready | 시작 자세 | 1~2 |
| Anticipation | 힘 모으기 | 3~5 |
| Action | 공격 가속·실행 | 6~9 |
| Impact | 타격 피크 | 10 |
| Follow-through | 관성·후속동작 | 11~13 |
| Recovery | 처음 자세 복귀 | 14~16 |

걷기는 Contact → Down → Passing → Up의 반복, 점프는 압축 → 도약 → 상승 → 정점 → 하강 → 착지 → 회복으로 나눌 수 있습니다.

## 프롬프트에서 가장 중요한 것은 ‘바뀌지 않아야 할 것’

프레임마다 포즈는 바뀌지만 다음 네 가지는 최대한 고정해야 합니다.

1. **정체성** — 머리 모양, 의상, 색, 무기, 소품, 얼굴/오브젝트 형태
2. **스케일** — 프레임마다 키나 크기가 흔들리지 않도록 고정
3. **카메라** — 시점, 화각, 줌을 고정
4. **등록점(registration)** — 캐릭터는 발바닥, 오브젝트는 중심축처럼 정렬 기준을 고정

## 복사해서 쓸 수 있는 4×4 전투 스프라이트 프롬프트

```text
GOAL
Create a 4×4 sprite sheet containing exactly 16 sequential frames of one coherent combat animation, using the uploaded character image as the identity reference.

SUBJECT FIDELITY
- Preserve the character's hairstyle, face, outfit, colors, footwear, accessories, body proportions, and left/right-specific details across every frame.
- Keep the character at a consistent scale.
- If the character has no clearly visible weapon or ability, do not invent unrelated powers; use a plausible physical action.

MOTION DESIGN
Build one continuous sequence:
Ready stance → anticipation → acceleration → main attack → impact peak → follow-through → recovery → return to the opening stance.
Animate real changes in joints, balance, and body mechanics. Do not simulate motion by merely shifting or rotating a static drawing.

STYLE
Crisp 16-bit game-style pixel art, clear silhouette, restrained palette, consistent logical pixel size, sharp nearest-neighbor-like edges.

CAMERA & REGISTRATION
- Fixed side or three-quarter camera.
- Same zoom, scale, and viewing angle in all frames.
- Keep a stable ground baseline and a consistent foot-contact registration point.

SPRITE SHEET
- Exactly 4 columns × 4 rows.
- Read left to right, then top to bottom.
- Equal cell dimensions and padding.
- One character per cell.
- Full body, props, and effects must remain inside the cell.
- No grid lines, frame numbers, text, watermarks, or UI.

BACKGROUND
Use genuine RGBA transparency. Do not render a checkerboard pattern to imitate transparency.

LOOP
Make frame 16 transition naturally back into frame 1.

QUALITY CHECK
Before presenting the result, verify all 16 frames, character consistency, left/right limb consistency, scale, ground registration, transparent background, cell-boundary safety, and loop continuity. Correct obvious defects first.
```

## 생성한 뒤 바로 GIF로 만들면 안 되는 이유

확대해서 팔·다리 좌우, 의상/소품 일관성, 발 위치, 예비동작과 후속동작, 픽셀 크기, 실제 알파 투명도를 먼저 확인하는 편이 좋습니다. 한 장의 시트가 보기 좋더라도 실제 재생에서는 움직임이 튀어 보일 수 있습니다.

1024×1024의 4×4 시트라면 한 셀은 256×256입니다. 프레임을 자를 때는 보이는 캐릭터의 바운딩 박스가 아니라 **고정 셀 좌표**를 기준으로 잘라야 등록점이 유지됩니다.

```text
cellWidth  = imageWidth / 4
cellHeight = imageHeight / 4
x = column * cellWidth
y = row * cellHeight
```

## 전투 말고도 같은 구조를 확장할 수 있습니다

- 캐릭터: 걷기·달리기·점프·회피
- 이모티콘: 웃음·놀람·하트·인사
- 제품: 8방향 회전·개폐
- 로봇/기계: 변형·전개·수납
- 동물/크리처: 보행·비행·공격
- 장면: 8컷 스토리보드

이런 반복 작업을 쉽게 하기 위해 대상, 동작, 배경, 시점, 프레임 수를 고르면 프롬프트와 프레임 플랜을 자동으로 조립하는 **Motion Prompt Lab**을 같이 만들었습니다. 서버나 API 키 없이 GitHub Pages에서 동작합니다.

## 참고 자료

- OpenAI, Introducing ChatGPT Images 2.5 (2026-09-08): https://openai.com/index/introducing-chatgpt-images-2-5/
- Kiki (@Mayz1169), 4×4 pixel-art combat sprite sheet: https://x.com/mayz1169/status/2097539942985728162
- Reddit r/aigamedev, “GPT Image 2.5 nailed a 16 frame combat sprite sheet” (2026-09-09)
- MagicCreator, awesome-gpt-image-2-5-prompts
