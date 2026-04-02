# Troubleshooting

## Authentication

### Token invalid or expired (401)

CLI automatically clears the cached token. Re-login:
```bash
AUTH_URL=$(cappt login)
cappt login --token <token>
```

### No browser available (SSH / headless)

1. Copy the URL printed by `cappt login`
2. Open it in a local browser and complete login
3. Copy the token shown in the browser
4. Run `cappt login --token <token>`

---

## Installation

### command not found: cappt

Install directory is not in `PATH`. Add to your shell profile:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc   # or ~/.bashrc
source ~/.zshrc
```

### Wrong architecture (Exec format error)

Force reinstall to download the correct binary:
```bash
bash ${CLAUDE_SKILL_DIR}/scripts/install.sh --force
```

### SHA256 mismatch

File was corrupted during download. Delete the temp file and retry. If it persists, report at https://github.com/cappt-team/skills/issues

---

## PPT Generation

### Out of AI credits (code 5410)

Log in to Cappt and top up your account.

### Internal server error (code 500)

Wait a few minutes and retry.

### Stream ended without a result

Outline is too long (recommended: ≤ 30 slides) or network is unstable. Shorten the outline and retry.

### Generation failed

Check outline format against `outline-format.md`:
- One `#` title at the top
- 3–5 `##` sections
- 3–5 `###` subsections per section
- 3–8 `####` points per subsection
- Every heading must have a `>` subtitle immediately below it

---

## Network

### Cannot reach Cappt API

```bash
curl -I https://api.cappt.cc
```

Behind a proxy:
```bash
HTTPS_PROXY=http://proxy:port cappt generate --outline-file outline.md
```
