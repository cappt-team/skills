# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

本仓库是 Claude Code 的技能包，通过 Cappt API 实现 AI 驱动的 PowerPoint 演示文稿生成。

## 目录结构

```
cappt-skills/
├── Makefile
├── skills/
│   └── cappt/
│       ├── SKILL.md
│       ├── scripts/
│       │   ├── install.sh      # Install cappt CLI (macOS/Linux)
│       │   ├── install.ps1     # Install cappt CLI (Windows)
│       │   ├── update.sh       # Update cappt CLI (macOS/Linux)
│       │   ├── update.ps1      # Update cappt CLI (Windows)
│       │   ├── uninstall.sh    # Uninstall cappt CLI (macOS/Linux)
│       │   └── uninstall.ps1   # Uninstall cappt CLI (Windows)
│       └── reference/
│           ├── outline-format.md
│           └── troubleshooting.md
├── tools/
│   └── cappt/
│       ├── main.go             # Subcommand routing (login/whoami/generate/version)
│       ├── client.go           # HTTP client (auth header, all API calls)
│       ├── api.go              # SSE stream parser + error types
│       ├── auth.go             # Token storage, login URL fetch
│       └── go.mod
└── references/
    └── archives/
```

## 常用命令

```bash
make build          # Build CLI for current platform → dist/cappt
make build-all      # Build CLI for all platforms   → dist/cappt-{os}-{arch}
make package        # Package skill as zip           → dist/cappt.zip
make checksums      # Generate SHA256 checksums      → dist/checksums.txt
```

**Test CLI:**
```bash
cappt version
CAPPT_BASE_URL=https://api.b.cappt.cc cappt whoami
cappt generate --outline "# Test\n> Subtitle\n\n## 1. Section\n> Desc\n\n### 1.1 Subsection\n> Desc\n\n#### 1.1.1 Point\n> Content here"
```

**Release via git tag:**
- `git tag vX.Y.Z` → builds CLI for all platforms + packages skill zip → single GitHub Release

## 架构概览

### 技能执行流程（两阶段）

1. **大纲生成阶段（Claude 负责）**：根据用户输入生成符合 `skills/cappt/reference/outline-format.md` 规范的 Markdown 大纲。格式：1 个标题 → 3-5 个章节 → 每章节 3-5 小节 → 每小节 3-8 个要点，各层级均需 `>` 副标题。
2. **CLI 调用阶段**：调用 `cappt generate --outline-file` 将大纲发送至 Cappt API，返回演示文稿元数据和链接。

### 关键文件

| File | Responsibility |
|------|----------------|
| `skills/cappt/SKILL.md` | Skill workflow definition, trigger conditions, pre-checks |
| `tools/cappt/main.go` | CLI entry point, subcommand routing |
| `tools/cappt/client.go` | `Client` struct, `Authorization: Bearer {token}`, all HTTP calls |
| `tools/cappt/api.go` | SSE stream parsing, API error types |
| `tools/cappt/auth.go` | Token storage (`~/.config/cappt/auth.json`), login URL fetch |
| `skills/cappt/reference/outline-format.md` | Outline format spec |
| `skills/cappt/reference/api.md` | Cappt API reference |

### CLI Interface

```bash
cappt login                         # Print login URL to stdout
cappt login --token <token>         # Save token locally
cappt whoami                        # Check login status
cappt logout                        # Revoke token and clear local cache
cappt generate --outline-file FILE  # Generate PPT from file
cappt generate --outline "markdown" # Generate PPT from string
  # Options: --include-gallery, --include-preview, --token
cappt version                       # Print version
```

Exit codes: `0` success, `1` API/network error, `2` invalid arguments.

### API Configuration

- **Base URL:** default `https://api.cappt.cc`, override with `CAPPT_BASE_URL` env var
- **Auth:** `Authorization: Bearer {token}`, token cached at `~/.config/cappt/auth.json`, also accepts `CAPPT_TOKEN` env var

## 新增技能规范

每个技能必须包含 `SKILL.md` 文件（带 `name`/`description` front matter），CI 会自动为所有包含 `SKILL.md` 的目录打包 zip 并发布 Release。
