# Invigo Marketplace

A curated collection of Claude Code plugins for enhanced development workflows.

## Installation

Add this marketplace to Claude Code:

```bash
/plugin marketplace add invigoworks/invigo-marketplace
```

## Available Plugins

### invigo-agents

A collection of 23 specialized AI agents for software development.

**Agents included:**
- Frontend: `frontend-developer`, `ui-ux-designer`, `mobile-developer`
- Backend: `backend-architect`, `api-documenter`, `database-architect`
- DevOps: `devops-engineer`, `deployment-engineer`
- Quality: `code-reviewer`, `test-engineer`, `debugger`, `error-detective`
- Languages: `typescript-pro`, `javascript-pro`, `python-pro`
- AI/ML: `ai-engineer`, `prompt-engineer`, `mcp-expert`
- Architecture: `architect-review`, `fullstack-developer`, `task-decomposition-expert`
- Utilities: `context-manager`, `search-specialist`

**Skills included:**
- `skill-creator`: Guide for creating effective skills

**Install:**
```bash
/plugin install invigoworks/invigo-marketplace invigo-agents
```

## Contributing

To add a new plugin:
1. Create a folder in `plugins/`
2. Add your agents, commands, or skills
3. Create `.claude-plugin/plugin.json`
4. Update the marketplace registry

## License

MIT
