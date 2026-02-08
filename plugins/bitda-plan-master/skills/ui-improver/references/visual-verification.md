# Visual Verification Guide

> ⚠️ **IMPORTANT**: `agent-browser`는 **스킬(Skill)**입니다. 에이전트(Agent)가 아닙니다!
>
> **호출 방법:**
> ```typescript
> // ✅ 올바른 호출 (Skill 도구 사용)
> Skill({ skill: "agent-browser", args: "open http://localhost:3000/..." })
>
> // ❌ 잘못된 호출 (에이전트로 오인)
> // Task({ subagent_type: "agent-browser", ... })
> ```

## 검증 워크플로우

아래 명령들은 `/agent-browser` 스킬 내에서 실행되는 명령 형식입니다.

### 서버 확인 및 실행

```bash
# 1. 먼저 3000 포트 서버 상태 확인
lsof -i :3000

# 2-A. 서버가 이미 실행 중이면 → 바로 사용
# 2-B. 서버가 없으면 → 실행
pnpm dev:preview  # 루트에서 실행 (권장, 포트 3000 기본)
```

### 브라우저 검증

```bash
# 변경된 화면 열기 (preview 앱 URL 사용)
# Skill({ skill: "agent-browser", args: "open http://localhost:3000/[앱명]/[경로]" })
agent-browser open http://localhost:3000/[앱명]/[대상-페이지-경로]

# 3. 스냅샷으로 현재 상태 확인
agent-browser snapshot -i

# 4. 변경 전/후 비교용 스크린샷
agent-browser screenshot ./screenshots/[feature]-after.png --full

# 5. 개선 항목별 검증
agent-browser is visible @e1     # 요소 표시 확인
agent-browser get text @e2       # 텍스트 확인
agent-browser click @e3          # 인터랙션 테스트

# 6. 브라우저 종료
agent-browser close
```

---

## 개선 유형별 검증

### 스타일/레이아웃 개선 검증

```bash
# 간격/정렬 개선 확인
agent-browser open http://localhost:3000/target-page
agent-browser screenshot ./screenshots/layout-check.png --full
agent-browser get box @e1  # 요소 위치/크기 확인

# 반응형 디자인 검증
agent-browser set viewport 1920 1080
agent-browser screenshot ./screenshots/desktop.png
agent-browser set viewport 768 1024
agent-browser screenshot ./screenshots/tablet.png
agent-browser set viewport 375 667
agent-browser screenshot ./screenshots/mobile.png
```

### 인터랙션 개선 검증

```bash
# hover 상태 확인
agent-browser hover @button
agent-browser snapshot -i

# focus 상태 확인
agent-browser focus @input
agent-browser snapshot -i

# 클릭 반응 확인
agent-browser click @actionBtn
agent-browser wait 500
agent-browser snapshot -i
```

### 접근성 개선 검증

```bash
# aria 속성 확인
agent-browser get attr @e1 aria-label
agent-browser get attr @e2 role

# 키보드 네비게이션 확인
agent-browser press Tab
agent-browser snapshot -i
agent-browser press Tab
agent-browser snapshot -i
```

---

## 검증 체크리스트

| 개선 항목 | 검증 방법 | 확인 내용 |
|----------|----------|----------|
| 레이아웃 변경 | `screenshot --full` | 의도한 레이아웃 적용 |
| 간격 조정 | `get box` | 요소 간 간격 정확 |
| 색상 변경 | `screenshot` | 색상 대비 적절 |
| 호버 상태 | `hover` → `snapshot` | 호버 스타일 적용 |
| 클릭 반응 | `click` → `snapshot` | 상태 변화 정상 |
| 애니메이션 | `record start/stop` | 전환 효과 부드러움 |

---

## 자동 검증 명령

```typescript
const verifyImprovements = async (improvements: Improvement[]) => {
  for (const item of improvements) {
    switch (item.type) {
      case 'spacing':
        const box = await exec('agent-browser get box @' + item.ref);
        console.log(`${item.ref} position:`, box);
        break;
      case 'visibility':
        const visible = await exec('agent-browser is visible @' + item.ref);
        console.log(`${item.ref} visible:`, visible);
        break;
      case 'interaction':
        await exec('agent-browser click @' + item.ref);
        await exec('agent-browser wait 500');
        await exec('agent-browser snapshot -i');
        break;
    }
  }
};
```

---

## 검증 결과 보고 양식

```markdown
## Visual Verification Report

### 검증 대상
- 파일: [file path]
- URL: http://localhost:3000/[path]

### 개선 항목별 검증 결과

| 개선 항목 | 예상 결과 | 실제 결과 | 상태 |
|----------|----------|----------|------|
| 버튼 간격 조정 | 8px gap | 8px gap | ✅ |
| 테이블 헤더 정렬 | left-align | left-align | ✅ |
| 호버 색상 변경 | #3b82f6 | #3b82f6 | ✅ |

### 스크린샷
- Before: ./screenshots/before.png
- After: ./screenshots/after.png
- Mobile: ./screenshots/mobile.png

### 콘솔 에러
- (없음)

### 최종 결과
✅ 모든 개선 사항이 정상적으로 적용되었습니다.
```

---

## 오류 대응

| 오류 상황 | 대응 방법 |
|----------|----------|
| 스타일 미적용 | Tailwind 빌드 확인, 클래스명 오타 확인 |
| 레이아웃 깨짐 | flex/grid 속성 확인, overflow 설정 확인 |
| 인터랙션 미동작 | 이벤트 핸들러 바인딩 확인 |
| 반응형 문제 | breakpoint 설정 확인 |
