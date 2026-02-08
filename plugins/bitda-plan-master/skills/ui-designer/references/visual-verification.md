# Visual Verification with /agent-browser Skill (Phase 8)

> ⚠️ **IMPORTANT**: `agent-browser`는 **스킬(Skill)**입니다. 에이전트(Agent)가 아닙니다!
> 호출 시 `Skill` 도구를 사용해야 합니다.

코드 생성 완료 후, 실제 브라우저에서 UI가 의도한 대로 렌더링되는지 확인합니다.
이 단계는 **배포 전 필수 검증 단계**입니다.

## 검증 워크플로우

**⚠️ CRITICAL: 반드시 preview 앱에서 실행해야 합니다!**

이 프로젝트는 `apps/preview` 앱이 모든 앱(liquor, manufacturing, admin, tax-office)의 라우트를 통합 실행합니다.
개별 앱(apps/liquor 등)을 직접 실행하면 라우팅이 작동하지 않습니다.

### 서버 확인 및 실행

```bash
# 1. 먼저 3000 포트 서버 상태 확인
lsof -i :3000

# 2-A. 서버가 이미 실행 중이면 → 바로 사용
# 2-B. 서버가 없으면 → 실행
pnpm dev:preview  # 루트에서 실행 (권장, 포트 3000 기본)
# 또는
cd apps/preview && pnpm dev --port 3000

# 2. 브라우저 열기 - preview 앱 URL 사용
# ⚠️ 반드시 앱 prefix 포함! (예: /liquor, /manufacturing)
# liquor 앱: http://localhost:3000/liquor/[경로]
# manufacturing 앱: http://localhost:3000/manufacturing/[경로]
# admin 앱: http://localhost:3000/admin/[경로]
# tax-office 앱: http://localhost:3000/tax-office/[경로]
agent-browser open http://localhost:3000/[앱명]/[생성된-페이지-경로]

# 3. 페이지 스냅샷으로 UI 요소 확인
agent-browser snapshot -i

# 4. 주요 UI 요소 검증
agent-browser is visible @e1  # 주요 컴포넌트 표시 여부
agent-browser get text @e2    # 텍스트 내용 확인

# 5. 스크린샷 캡처 (검토용)
agent-browser screenshot ./screenshots/[feature-name].png --full

# 6. 인터랙션 테스트
agent-browser click @e3       # 버튼 클릭
agent-browser snapshot -i     # 상태 변화 확인

# 7. 브라우저 종료
agent-browser close
```

## 검증 체크리스트

| 검증 항목 | 명령어 | 확인 내용 |
|----------|--------|----------|
| 페이지 로드 | `agent-browser open` | 에러 없이 로드 |
| 레이아웃 | `screenshot --full` | 레이아웃 깨짐 없음 |
| 주요 컴포넌트 | `is visible @ref` | 모든 주요 컴포넌트 표시 |
| 버튼 동작 | `click @ref` | 클릭 시 올바른 반응 |
| 폼 동작 | `fill @ref "test"` | 입력 정상 동작 |
| Sheet/Dialog | `click @trigger` → `snapshot` | 열림/닫힘 정상 |
| 반응형 | `set viewport 375 667` | 모바일 레이아웃 정상 |

## 화면 유형별 검증

### 목록 화면 (S) 검증

```bash
# 테이블 렌더링 확인 (preview 앱에서 실행)
agent-browser open http://localhost:3000/manufacturing/production/order
agent-browser snapshot -i -s "table"
agent-browser get count "tr"  # 행 개수 확인

# 검색 기능 테스트
agent-browser fill @search "테스트"
agent-browser press Enter
agent-browser wait 1000
agent-browser snapshot -i

# 등록 버튼 → Sheet 열기
agent-browser click @createBtn
agent-browser wait @sheet
agent-browser is visible @sheet
```

### 폼 화면 (F) 검증

```bash
# Sheet/Form 열기
agent-browser click @openFormBtn
agent-browser wait @sheet

# 필수 필드 검증
agent-browser click @submitBtn  # 빈 상태로 제출
agent-browser snapshot -i       # 에러 메시지 확인

# 정상 입력 테스트
agent-browser fill @nameInput "테스트 데이터"
agent-browser select @statusSelect "active"
agent-browser click @submitBtn
agent-browser wait 1000
agent-browser snapshot -i       # 성공 상태 확인
```

### 팝업/Dialog (P) 검증

```bash
# Dialog 트리거
agent-browser click @deleteBtn
agent-browser wait @dialog
agent-browser is visible @dialog

# Dialog 내용 확인
agent-browser get text @dialogTitle     # "삭제 확인"

# 취소/확인 동작
agent-browser click @cancelBtn
agent-browser is visible @dialog        # false 예상
```

## 자동 검증 스크립트 예시

> ⚠️ `agent-browser`는 **스킬**입니다. `Task`가 아닌 `Skill` 도구로 호출하세요!

```typescript
// ✅ 올바른 호출 방법 (Skill 도구 사용)
Skill({
  skill: "agent-browser",
  args: `Verify generated UI for [기능명]:
    1. Open http://localhost:3000/[앱명]/[경로]
    2. Take full-page screenshot
    3. Verify these elements exist:
       - Page title: "[기능명]"
       - Create button
       - Data table with headers
    4. Test create flow:
       - Click create button
       - Verify sheet opens
       - Fill required fields
       - Submit and verify success
    5. Report any visual issues or errors`
});

// ❌ 잘못된 호출 (agent-browser는 에이전트가 아님!)
// Task({ subagent_type: "agent-browser", ... })
```

## 검증 결과 보고

```markdown
## Visual Verification Report

### 환경
- URL: http://localhost:3000/manufacturing/production/order  # preview 앱
- Viewport: 1920x1080

### 검증 결과

#### ✅ 통과 항목
- 페이지 로드 정상
- 테이블 렌더링 정상
- 검색 기능 동작 확인
- Sheet 열기/닫기 정상

#### ⚠️ 주의 항목
- 모바일 뷰에서 테이블 가로 스크롤 필요

#### ❌ 실패 항목
- (없음)

### 다음 단계
배포 준비 완료. `/github-deployer`로 PR 생성 가능.
```

## 오류 대응

| 오류 상황 | 대응 방법 |
|----------|----------|
| 페이지 로드 실패 | 개발 서버 상태, 라우트 설정 확인 |
| 컴포넌트 미표시 | Import 경로, export 확인 |
| 스타일 깨짐 | Tailwind 클래스, CSS 충돌 확인 |
| 인터랙션 미동작 | 이벤트 핸들러, 상태 관리 확인 |
| 콘솔 에러 | `agent-browser errors`로 에러 확인 |
