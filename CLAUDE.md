# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

Invigo Marketplace is a Claude Code plugin marketplace - a registry for discovering and distributing Claude Code plugins.

## Marketplace Structure

```
invigo-marketplace/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace metadata and plugin registry
├── plugins/
│   └── <plugin-name>/      # Individual plugin directories
│       ├── .claude-plugin/
│       │   └── plugin.json # Plugin metadata
│       ├── agents/         # Agent definitions (optional)
│       ├── commands/       # Command definitions (optional)
│       ├── skills/         # Skill definitions (optional)
│       └── README.md       # Plugin documentation
├── CLAUDE.md               # This file
└── README.md               # Marketplace documentation
```

## Managing the Marketplace

### Adding a New Plugin

1. Create a new directory under `plugins/`
2. Add `.claude-plugin/plugin.json` with plugin metadata
3. Add agents, commands, or skills as needed
4. Update `.claude-plugin/marketplace.json` to register the plugin

### marketplace.json Format

```json
{
  "name": "marketplace-name",
  "owner": {
    "name": "owner-name",
    "url": "https://github.com/owner"
  },
  "metadata": {
    "description": "Marketplace description",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "plugin-name",
      "description": "Plugin description",
      "version": "1.0.0",
      "author": { "name": "author", "url": "https://..." },
      "tags": ["tag1", "tag2"],
      "source": "./plugins/plugin-name"
    }
  ]
}
```

### plugin.json Format

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Plugin description",
  "author": { "name": "author", "url": "https://..." },
  "license": "MIT"
}
```

## Current Plugins

- **invigo-agents**: 23 specialized AI agents + skill-creator skill
