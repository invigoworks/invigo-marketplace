# UI Analysis Checklist

Comprehensive checklist for UI/UX, architecture, and code quality analysis.

## UI/UX Analysis

### Visual Hierarchy & Layout

- [ ] **Spacing Consistency**
  - Uniform margins/padding throughout component
  - Consistent gap between related elements
  - Proper visual grouping of related items

- [ ] **Alignment**
  - Text alignment matches content type (left for text, center for icons)
  - Vertical alignment of elements in rows
  - Column alignment in tables/grids

- [ ] **Typography**
  - Font sizes follow hierarchy (headings > body > captions)
  - Line heights appropriate for readability
  - Font weights used consistently for emphasis

- [ ] **Visual Weight Balance**
  - Key actions are visually prominent
  - Secondary actions are subdued
  - Empty states don't feel incomplete

### Color & Contrast

- [ ] **Color Consistency**
  - Status colors consistent (success=green, error=red, warning=yellow)
  - Brand colors applied correctly
  - Semantic color usage (primary, secondary, muted)

- [ ] **Contrast Ratios**
  - Text meets WCAG AA (4.5:1 for normal, 3:1 for large)
  - Interactive elements distinguishable
  - Focus states visible

- [ ] **Dark/Light Mode**
  - Colors adapt properly to theme
  - No hardcoded colors that break in dark mode

### Interactive States

- [ ] **Hover States**
  - All clickable elements have hover feedback
  - Hover effects are subtle but noticeable
  - Cursor changes appropriately

- [ ] **Focus States**
  - Keyboard navigation shows focus ring
  - Focus order is logical
  - Focus trap works correctly in modals

- [ ] **Loading States**
  - Loading indicators for async operations
  - Skeleton screens for content loading
  - Disabled states during processing

- [ ] **Empty States**
  - Clear messaging when no data
  - Call-to-action for empty states
  - Helpful guidance for users

### Responsive Design

- [ ] **Mobile Adaptation**
  - Content readable on mobile
  - Touch targets are 44px minimum
  - Horizontal scroll avoided

- [ ] **Container Sizing**
  - Max-width constraints for readability
  - Responsive breakpoints defined
  - Flex/Grid layouts used appropriately

## Component Architecture

### Composition Patterns

- [ ] **Single Responsibility**
  - Each component does one thing well
  - Business logic separated from presentation
  - Render logic is clean and readable

- [ ] **Prop Interface Design**
  - Props are minimal and focused
  - Optional props have sensible defaults
  - Complex objects broken into primitives when possible

- [ ] **Reusability**
  - Common patterns extracted to shared components
  - Components are configurable via props
  - No duplicate code across components

### State Management

- [ ] **State Location**
  - State lives as close to usage as possible
  - Global state only for truly global data
  - URL state used for shareable/bookmarkable state

- [ ] **State Updates**
  - Immutable updates for arrays/objects
  - Derived state computed, not stored
  - No redundant state

- [ ] **Side Effects**
  - Effects have proper dependencies
  - Cleanup functions provided
  - Loading/error states handled

### Data Flow

- [ ] **Prop Drilling**
  - Not more than 2-3 levels of prop passing
  - Context used for deeply nested data
  - Composition preferred over prop drilling

- [ ] **Event Handling**
  - Callbacks named consistently (onXxx)
  - Events bubble up appropriately
  - Form handling centralized

## Code Quality

### TypeScript

- [ ] **Type Safety**
  - No `any` types without justification
  - Props interfaces defined
  - Return types explicit for complex functions

- [ ] **Type Inference**
  - Leveraging inference where obvious
  - Generic types for reusable utilities
  - Discriminated unions for variants

### Performance

- [ ] **Render Optimization**
  - Memoization for expensive computations
  - React.memo for pure components
  - useCallback for stable callbacks

- [ ] **Bundle Size**
  - No unused imports
  - Dynamic imports for heavy components
  - Tree-shaking friendly exports

### Code Organization

- [ ] **File Structure**
  - Related files grouped together
  - Consistent naming conventions
  - Barrel exports where appropriate

- [ ] **Naming**
  - Descriptive variable/function names
  - Boolean variables start with is/has/should
  - Event handlers start with handle/on

- [ ] **Comments**
  - Complex logic explained
  - No obvious comments
  - TODO items tracked

## Priority Classification

### P0 - Critical

Issues that:
- Break functionality
- Cause accessibility failures
- Create security vulnerabilities
- Severely impact user experience

### P1 - Major

Issues that:
- Significantly affect usability
- Violate design system consistency
- Create maintainability problems
- Impact performance noticeably

### P2 - Minor

Issues that:
- Are cosmetic improvements
- Enhance code clarity
- Improve developer experience
- Polish the user experience

## Analysis Output Template

```markdown
## Analysis Results: [Component Name]

### Summary
[Brief 2-3 sentence summary of findings]

### Issues Found

#### P0 - Critical
| Issue | Impact | Recommended Fix |
|-------|--------|-----------------|

#### P1 - Major
| Issue | Impact | Recommended Fix |
|-------|--------|-----------------|

#### P2 - Minor
| Issue | Impact | Recommended Fix |
|-------|--------|-----------------|

### Recommended Implementation Order
1. [First fix - highest impact]
2. [Second fix]
3. [Third fix]

### Estimated Effort
- P0 fixes: [time estimate]
- P1 fixes: [time estimate]
- P2 fixes: [time estimate]
```
