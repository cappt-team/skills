# Cappt Skills

基于 [Cappt](https://cappt.cc) 的 AI 演示文稿生成 Skills。

## 可用 Skills

| Skill | 说明 |
|-------|------|
| [cappt](./skills/cappt/SKILL.md) | 根据主题、标题或文章，调用 Cappt API 生成 PowerPoint 演示文稿 |

## 安装

```
/install-skill https://github.com/cappt-team/skills/releases/latest/download/cappt-skill.zip
```

## 使用

安装后，直接描述你想要的 PPT：

> "帮我做一个关于人工智能发展历史的 PPT"

Skill 会自动生成大纲并调用 Cappt API 生成演示文稿。

## 登录

首次使用时需要登录 Cappt 账号：

```bash
cappt login                        # 获取登录链接
cappt login --token <token>        # 粘贴浏览器显示的 token
```

如需使用非默认 API 环境，通过环境变量指定：

```bash
export CAPPT_BASE_URL=https://api.b.cappt.cc
```

## 开发

```bash
make build        # 构建 CLI（当前平台）→ dist/cappt
make build-all    # 构建所有平台      → dist/cappt-{os}-{arch}
make package      # 打包 Skill        → dist/cappt.zip
make checksums    # 生成 SHA256 校验和 → dist/checksums.txt
```

## 许可证

MIT
