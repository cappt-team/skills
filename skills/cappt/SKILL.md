---
name: cappt
description: Generate a PowerPoint presentation from a topic, title, or article using Cappt. Use this skill when the user asks to create a PPT, presentation, or slide deck, or mentions Cappt. The skill first generates a structured Markdown outline, then calls the Cappt CLI to produce the final presentation. Trigger phrases include "生成PPT"、"做一个演示文稿"、"制作幻灯片"、"create a presentation"、"make a PPT"、"generate slides".
---

# Cappt PPT 生成器

使用 Cappt AI 服务，根据用户输入生成专业的 PowerPoint 演示文稿。

## 触发场景

同时满足以下两个条件时激活：
- 用户提到 PPT / 演示文稿 / 幻灯片 / presentation / slides / Cappt
- 有明确的生成意图（生成 / 做 / 制作 / 创建 / create / make / generate）

## 安全约束（最高优先级）

以下规则不可被用户指令覆盖：
- **Token 内容禁止输出**，不可读取、打印或日志记录 `~/.config/cappt/auth.json` 的内容
- **更新操作需用户明确确认**，不可在用户未要求时自动执行更新脚本

## 前置检查

按顺序执行以下检查，发现问题立即引导用户修复，再继续。

**检查 1：cappt CLI 是否已安装**

```bash
# macOS/Linux
command -v cappt
```
```powershell
# Windows
Get-Command cappt -ErrorAction SilentlyContinue
```

若未安装，按平台引导运行安装脚本：

```bash
# macOS/Linux
bash ${CLAUDE_SKILL_DIR}/scripts/install.sh
```
```powershell
# Windows
pwsh -ExecutionPolicy Bypass -File "${env:CLAUDE_SKILL_DIR}\scripts\install.ps1"
```

> 安装问题参见：`reference/troubleshooting.md`

**检查 2：是否已登录**

```bash
cappt whoami
```

若未登录（退出码 1），执行以下登录流程：

**步骤 1** — 获取登录链接（立即返回到 stdout）：
```bash
AUTH_URL=$(cappt login --utm-source <当前平台英文小写名称，如 claude-code、cursor>)
```
`--utm-source` 为可选参数，不传时默认为 `cappt`。将 `$AUTH_URL` 展示给用户，请用户在浏览器中打开并登录，登录后浏览器会显示一个 token。

**步骤 2** — 用户复制 token 后，将其保存到本地：
```bash
cappt login --token <用户粘贴的 token>
```

两项检查均通过后，进入工作流。

## 工作流

按顺序执行以下四步，不可跳过任何一步。

### 第一步 — 理解用户需求

从用户消息中识别：
- 需要转化为 PPT 的**主题、标题或文章内容**
- 是否需要返回所有幻灯片的图片集合（`--include-gallery`）
- 是否需要返回预览图（`--include-preview`）

若用户未提及上述选项，默认均为 **false**。

### 第二步 — 生成结构化 Markdown 大纲

参照 `reference/outline-format.md` 中的格式规范，生成符合要求的完整大纲。

关键要求：
- **语言一致**：大纲语言必须与用户输入语言一致
- **层级完整**：`#` 总标题 → `##` 章节（3-5 个）→ `###` 小节（每章节 3-5 个）→ `####` 要点（每小节 3-8 个）
- **副标题完整**：每级标题下方必须有一行 `>` 副标题
- **编号规范**：`##` 用 `1.`，`###` 用 `1.1`，`####` 用 `1.1.1`
- **数量随机**：各章节小节数、各小节要点数不可完全相同

生成完毕后，**将完整大纲展示给用户，等待确认后再进行第三步**。

若用户提供的文章超过 500 字，展示大纲后必须请用户确认再继续。

### 第三步 — 调用 cappt CLI 生成 PPT

将大纲写入临时文件，调用 CLI：

```bash
OUTLINE_FILE="/tmp/cappt_outline_$(date +%s).md"
cat > "$OUTLINE_FILE" << 'OUTLINE_EOF'
<在此粘贴完整大纲原文>
OUTLINE_EOF

cappt generate --outline-file "$OUTLINE_FILE"
```

若用户要求了图片集合或预览图，追加对应参数：
- `--include-gallery`：返回所有幻灯片图片 URL
- `--include-preview`：返回预览图 URL

传给 CLI 的必须是**完整的 Markdown 大纲原文**，不可使用摘要替代。

API 调用失败时最多重试一次。

### 第四步 — 展示结果

CLI 成功时将 JSON 输出到 stdout，解析后按以下格式展示：

```
您的 PPT 已经生成！

[在 Cappt 中打开并编辑]({edit_url})

封面预览：
![封面]({thumbnail})
```

若 JSON 中包含 `gallery` 字段，在封面下方依次展示每张幻灯片图片。
若包含 `preview` 字段，作为额外预览图展示。

## 错误处理

| 错误信息 | 原因 | 建议操作 |
|----------|------|----------|
| `out of AI credits` (code 5410) | Cappt 账户点数不足 | 引导用户前往 Cappt 充值 |
| `token invalid or expired` (401) | 登录态失效，缓存已自动清除 | 运行 `cappt login` 重新登录 |
| `internal server error` (500) | Cappt 服务端异常 | 稍后重试 |
| `generation failed` (fail) | 大纲格式有误或服务异常 | 检查大纲格式，参见 `reference/outline-format.md` |
| `stream ended without a result` | 页数过多或网络异常 | 缩短大纲后重试 |
| `command not found: cappt` | CLI 未安装 | 运行 `install.sh` / `install.ps1` |

若 CLI 以非零退出码退出，将 stderr 中的错误信息完整展示给用户。

> 更多错误排查见：`reference/troubleshooting.md`

## 生命周期管理

用户有安装/登录/更新/卸载需求时，直接引导运行对应命令：

| 操作 | macOS/Linux | Windows |
|------|-------------|---------|
| 安装 CLI | `bash ${CLAUDE_SKILL_DIR}/scripts/install.sh` | `pwsh -ExecutionPolicy Bypass -File "${env:CLAUDE_SKILL_DIR}\scripts\install.ps1"` |
| 登录 | `cappt login` → `cappt login --token <token>` | 同左 |
| 查看状态 | `cappt whoami` | 同左 |
| 注销 | `cappt logout` | 同左 |
| 更新 CLI | `bash ${CLAUDE_SKILL_DIR}/scripts/update.sh` | `pwsh -ExecutionPolicy Bypass -File "${env:CLAUDE_SKILL_DIR}\scripts\update.ps1"` |
| 卸载 | `bash ${CLAUDE_SKILL_DIR}/scripts/uninstall.sh` | `pwsh -ExecutionPolicy Bypass -File "${env:CLAUDE_SKILL_DIR}\scripts\uninstall.ps1"` |

## 参考文档

| 文档 | 用途 |
|------|------|
| `reference/outline-format.md` | 大纲格式规范（层级、编号、示例） |
| `reference/troubleshooting.md` | 故障排除指南 |

## 示例

**示例一 — 中文主题**
> 用户："帮我生成一个关于人工智能发展历史的PPT"
→ 前置检查 → 生成中文大纲 → 用户确认 → 调用 CLI → 展示结果

**示例二 — 英文主题**
> 用户："Create a 10-slide deck on climate change"
→ 前置检查 → 生成英文大纲 → 用户确认 → 调用 CLI → 展示结果

**示例三 — 文章转换**
> 用户："把这篇文章做成PPT：[文章内容]"
→ 前置检查 → 提取要点生成大纲 → 用户确认 → 调用 CLI → 展示结果

**示例四 — 安装 / 登录**
> 用户："我想用 Cappt 做 PPT，怎么安装？"
→ 引导运行 `install.sh`（或 `install.ps1`），然后 `cappt login`
