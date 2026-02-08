# Project Structure Analysis (Phase 0)

**반드시 코드 생성 전에 기존 프로젝트 구조를 분석하고 준수해야 합니다.**

---

## ⚠️ Preview 앱 구조 (CRITICAL - 필수 숙지)

이 프로젝트는 **`apps/preview` 앱을 통해 모든 앱을 통합 실행**합니다.

### 라우팅 아키텍처

```
apps/preview/src/router.tsx  ← 통합 라우터 (모든 앱 라우트 import)
  ├── "/" → LandingPage (앱 선택 화면)
  ├── "/manufacturing/*" → apps/manufacturing의 라우트
  ├── "/liquor/*" → apps/liquor의 라우트
  ├── "/admin/*" → apps/admin의 라우트
  └── "/tax-office/*" → apps/tax-office의 라우트
```

### 각 앱의 라우터 export 패턴

```typescript
// apps/liquor/src/router.tsx 예시
export const liquorRoutes: RouteObject[] = [
  { index: true, element: <Navigate to="dashboard" replace /> },
  { path: 'dashboard', element: <DashboardPage /> },
  { path: 'inventory/movement', element: <MovementPage /> },
  // ...
];

export const LiquorLayout = () => <MainLayout><Outlet /></MainLayout>;
```

### 개발 서버 실행

```bash
# ⚠️ 반드시 preview 앱에서 실행!
pnpm dev:preview  # 루트에서
# 또는
cd apps/preview && pnpm dev

# 개별 앱(apps/liquor 등)을 직접 실행하면 라우팅이 작동하지 않음!
```

### 접근 URL 패턴

```
http://localhost:5173/              → 앱 선택 화면
http://localhost:5173/liquor/       → liquor 앱 대시보드
http://localhost:5173/manufacturing/ → manufacturing 앱
http://localhost:5173/admin/        → admin 앱
http://localhost:5173/tax-office/   → tax-office 앱
```

---

## 프로젝트 구조 탐색

코드 생성 전 다음 정보를 수집:

```typescript
const projectAnalysis = {
  appsStructure: await exploreDirectory('apps/'),
  packagesStructure: await exploreDirectory('packages/'),
  existingPages: await exploreDirectory('apps/*/src/pages/'),
  sharedComponents: await exploreDirectory('packages/web-platform/src/components/'),
  existingPatterns: await analyzeCodePatterns()
};
```

## 에이전트 활용

### 기본 구조 탐색 (code-explorer):

```typescript
Task({
  subagent_type: "feature-dev:code-explorer",
  prompt: `Analyze the project structure for [앱명]:
    1. Check apps/[앱명]/src/ directory structure
    2. Identify existing pages/ patterns
    3. Find shared components in packages/web-platform/
    4. Document import conventions
    5. Check existing routing patterns in router.tsx

    Return a summary of:
    - Directory structure
    - Component naming conventions
    - Import path patterns
    - State management patterns`
});
```

### 아키텍처 설계 (code-architect):

```typescript
Task({
  subagent_type: "feature-dev:code-architect",
  prompt: `Design component architecture for [기능명]:

    Context:
    - Target app: apps/[앱명]
    - Domain: [도메인명]

    Requirements:
    1. Identify all required components (Page, Sheet, Dialog)
    2. Design props interface for each component
    3. Define data flow between components
    4. Recommend folder structure in pages/

    Output:
    - Component tree diagram
    - File structure proposal
    - Props/state definitions
    - Integration points`
});
```

### 병렬 에이전트 실행:

```typescript
const parallelAnalysis = [
  Task({
    subagent_type: "feature-dev:code-explorer",
    prompt: "Analyze existing code patterns in apps/manufacturing/src/pages/"
  }),
  Task({
    subagent_type: "feature-dev:code-explorer",
    prompt: "List available shared components in packages/web-platform/src/"
  }),
  Task({
    subagent_type: "invigo-agents:typescript-pro",
    prompt: "Analyze existing TypeScript types and interfaces in the project"
  })
];
```

## 구조 분석 체크리스트

| 확인 항목 | 위치 | 목적 |
|----------|------|------|
| 앱 폴더 존재 | `apps/[앱명]/` | 대상 앱 확인 |
| pages 폴더 | `apps/[앱명]/src/pages/` 또는 `apps/[앱명]/src/[도메인]/` | 코드 생성 위치 |
| router.tsx | `apps/[앱명]/src/router.tsx` | 라우트 추가 위치 |
| 도메인 폴더 | `apps/[앱명]/src/[도메인]/` | 도메인 구조 |
| 공유 컴포넌트 | `packages/web-platform/src/` | 재사용 컴포넌트 |
| 타입 정의 | `apps/[앱명]/src/types/` | 타입 위치 |
| preview 라우터 | `apps/preview/src/router.tsx` | 통합 라우트 확인 |

### ⚠️ 라우트 추가 시 주의사항

1. **각 앱의 router.tsx**에 라우트 추가
2. **preview 앱이 자동으로 import**하므로 preview/router.tsx는 수정 불필요
3. **라우트와 Layout을 반드시 export** (preview에서 import해야 함)

```typescript
// apps/[앱명]/src/router.tsx - export 필수!
export const [앱명]Routes: RouteObject[] = [...];
export const [앱명]Layout = () => <MainLayout><Outlet /></MainLayout>;
```

## 기존 패턴 준수 규칙

**기존 코드 분석 후 발견된 패턴을 반드시 준수:**

1. **Import 경로**: 기존 파일의 import 패턴 분석
   ```typescript
   import { PageLayout } from '@bitda/web-platform';
   import { Card, Button } from '@bitda/web-platform/shadcn';
   ```

2. **컴포넌트 명명**: 기존 컴포넌트 네이밍 컨벤션 준수
   ```typescript
   // OrderPage.tsx, PlanPage.tsx 패턴 발견 시
   // 새 파일도 동일 패턴: ResultPage.tsx
   ```

3. **폴더 구조**: 기존 도메인 폴더 구조 준수
   ```
   // production/ 폴더에 PlanPage, OrderPage 있으면
   // ResultPage도 같은 production/ 폴더에 생성
   ```

4. **Export 패턴**: 기존 index.ts 패턴 분석 및 준수
   ```typescript
   // 기존 index.ts
   export { PlanPage } from './PlanPage';
   export { OrderPage } from './OrderPage';
   // 새로 추가
   export { ResultPage } from './ResultPage';
   ```

---

## Project Initialization Check (Phase 0.5)

### 프로젝트 환경 확인

```bash
# 1. tsconfig.json 존재 여부 확인
ls tsconfig.json

# 2. components.json 존재 여부 확인
ls components.json

# 3. package.json에서 필수 의존성 확인
cat package.json | grep -E "react|tailwindcss|@radix-ui"
```

### 자동 초기화 로직

**tsconfig.json이 없는 경우:**
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src"]
}
```

**components.json이 없는 경우:**
```bash
echo 'y' | npx shadcn@latest init -d
```

### shadcn-studio 레지스트리 설정

components.json 생성 후 자동으로 레지스트리 추가:

```json
{
  "registries": {
    "@ss-blocks": {
      "url": "https://shadcnstudio.com/r"
    }
  }
}
```
