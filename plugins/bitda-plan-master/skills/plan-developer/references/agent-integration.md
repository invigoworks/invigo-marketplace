# Specialized Agent Integration

This skill leverages invigo-agents for enhanced quality and specialized expertise.

## Recommended Agents by Phase

| Phase | Agent | Purpose |
|-------|-------|---------|
| Architecture Review | `invigo-agents:architect-reviewer` | SOLID principles, proper layering, architectural consistency |
| Database Design | `invigo-agents:database-architect` | Data modeling, schema design, relationships |
| UX/UI Review | `invigo-agents:ui-ux-designer` | User research insights, accessibility, design systems |
| Backend Planning | `invigo-agents:backend-architect` | API design, microservice boundaries, scalability |
| API Documentation | `invigo-agents:api-documenter` | OpenAPI specs, endpoint documentation |

## Agent Invocation Strategy

### During Phase 2 (Specification Development):

1. **Architecture Review** - Before finalizing data structure:
   ```
   Task(subagent_type="invigo-agents:architect-reviewer")
   Prompt: "Review the proposed feature architecture for [기능명].
   Check SOLID principles, proper layering, and maintainability."
   ```

2. **Database Design** - For data requirements:
   ```
   Task(subagent_type="invigo-agents:database-architect")
   Prompt: "Design database schema for [기능명].
   Consider relationships, indexes, and scalability."
   ```

3. **UX/UI Review** - For screen layout decisions:
   ```
   Task(subagent_type="invigo-agents:ui-ux-designer")
   Prompt: "Review user flow and screen layout for [기능명].
   Suggest accessibility improvements and UX patterns."
   ```

## Parallel Agent Execution

For complex features, invoke multiple agents in parallel:

```typescript
// Parallel architecture + database review
const parallelReview = [
  Task({
    subagent_type: "invigo-agents:architect-reviewer",
    prompt: "Review feature architecture for domain boundaries"
  }),
  Task({
    subagent_type: "invigo-agents:database-architect",
    prompt: "Validate data model and relationships"
  }),
  Task({
    subagent_type: "invigo-agents:ui-ux-designer",
    prompt: "Evaluate user experience and accessibility"
  })
];
```

## Quality Gate with Agents

Before proceeding to Phase 3 (Document Generation), ensure:

- [ ] `architect-reviewer` approved architecture patterns
- [ ] `database-architect` validated data model
- [ ] `ui-ux-designer` confirmed UX flow
