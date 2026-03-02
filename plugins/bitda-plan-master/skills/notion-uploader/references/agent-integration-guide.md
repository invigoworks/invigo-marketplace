# Agent Integration Guide

> Extracted from SKILL.md for token optimization. Reference when delegating tasks to specialized agents.

## Recommended Agents by Task

| Task | Agent | Purpose |
|------|-------|---------|
| API Documentation | `invigo-agents:api-documenter` | OpenAPI specs, endpoint documentation |
| Context Management | `invigo-agents:context-manager` | Multi-agent workflows, session coordination |
| Backend Architecture | `invigo-agents:backend-architect` | API design review, business logic validation |
| Code Explorer | `feature-dev:code-explorer` | Analyze codebase features, trace execution paths |

## Invocation Strategy

### Phase 1 (Context Gathering)

- **Code Analysis**: `feature-dev:code-explorer` → "Analyze deployed code at [GitHub URL]. Extract component structure, data models, and business logic."
- **Context Coordination**: `invigo-agents:context-manager` → "Coordinate context from planning document and published code. Identify discrepancies."

### Phase 3 (Business Logic Documentation)

- **API Documentation**: `invigo-agents:api-documenter` → "Generate OpenAPI specification for [기능명] based on UI components."
- **Architecture Validation**: `invigo-agents:backend-architect` → "Review business logic documentation for [기능명]. Verify completeness."

## Parallel Processing

For multi-component features, launch multiple `invigo-agents:api-documenter` agents in parallel (one per component).

## Quality Gate

Before Notion registration, validate with `invigo-agents:backend-architect`:
- All CRUD operations documented
- Validation rules specified
- Error handling defined
- API endpoints proposed
