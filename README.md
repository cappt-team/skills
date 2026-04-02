# Cappt Skills

AI-powered presentation generation, powered by [Cappt](https://cappt.cc).

[中文文档](./README.zh-Hans.md)

## Available Skills

| Skill | Description |
|-------|-------------|
| [cappt](./skills/cappt/SKILL.md) | Generate PowerPoint presentations from a topic, title, or article using the Cappt API |

## Installation

```
/install-skill https://github.com/cappt-team/skills/releases/latest/download/cappt-skill.zip
```

## Usage

After installation, just describe the presentation you need:

> "Create a presentation on the history of artificial intelligence"

The skill will generate an outline and call the Cappt API to produce the slides.

## Login

First-time setup requires authenticating with your Cappt account:

```bash
cappt login                      # Get the login URL
cappt login --token <token>      # Paste the token shown in the browser
```

## Development

```bash
make build        # Build CLI for current platform → dist/cappt
make build-all    # Build CLI for all platforms   → dist/cappt-{os}-{arch}
make package      # Package skill as zip           → dist/cappt.zip
make checksums    # Generate SHA256 checksums      → dist/checksums.txt
```

## License

MIT
