---
name: maintaining-weixinsi-homepage
description: Use when editing, personalizing, validating, committing, pushing, or deploying the WeixinSi/weixinsi.github.io Academic Pages/Jekyll repository, including profile, navigation, publications, talks, teaching, portfolio, CV, styling, layouts, Git identity, or GitHub Pages behavior.
---

# Maintaining Weixin Si Homepage

## Core contract

Work in `D:/Program/Code/LaTexProject/SWXCV/weixinsi.github.io`. Preserve user changes, verify success, and require explicit authorization for commit or push.

Communicate in Chinese outside code and commands.

## Start every task

1. Inspect `git status --short --branch`, `git remote -v`, and the relevant files.
2. Confirm the repository is `https://github.com/WeixinSi/weixinsi.github.io.git` on `master` before any commit or push.
3. Preserve unrelated changes. Do not reset, overwrite, or include them in a commit.
4. Before any Academic Pages content, structure, appearance, build, or deployment edit, read `references/academic-pages-architecture.md`. The checked-out repository is authoritative when it differs.

## Questions and planning

Collect consequential uncertainties and ask at most one consolidated confirmation message. Prefer stated assumptions when safe. Continue afterward unless a new safety-critical blocker appears.

Plan internally or in the task UI. Never create a plan Markdown file or pause for plan approval unless requested.

## Editing and validation

- Use `apply_patch` for text edits.
- Select the smallest correct layer. Prefer content/configuration over theme internals.
- Preserve YAML front matter, Liquid expressions, permalinks, and user content. Do not invent biography, employment, education, publication, or contact facts.
- Run `git diff --check`, inspect the diff, and run the narrowest relevant validation.
- Before Python commands, activate conda with `conda activate torch && <command>`. If PowerShell cannot parse `&&`, invoke it through `cmd.exe /d /c` while still activating `torch` first.
- Do not install dependencies or change deployment settings unless required by the request.

## Commit identity

Configure identity only in this repository:

```bash
git config user.name "NiuNiuAiXue"
git config user.email "2834913561@qq.com"
```

Verify both values before committing. The authenticated account may differ but needs repository write access.

## Commit and push authorization

- “修改”或“完成修改”仅授权编辑与验证。
- “提交”仅授权本地 Git commit。
- “提交并推送”“推送”或“上传到 GitHub”才授权 push。
- Never infer commit or push permission from requests to edit, fix, test, or preview. Never force-push.

When authorized, use Git Bash at `D:/Program Files/Git/bin/bash.exe` for staging, committing, pulling, and pushing. Run from `/d/Program/Code/LaTexProject/SWXCV/weixinsi.github.io`. Stage only reviewed files, inspect `git diff --cached`, and use a concise factual commit message. Before pushing, use `git pull --rebase origin master`; report conflicts instead of guessing.

## Handoff

Report modified files, validation evidence, commit hash if committed, push result if pushed, and Pages/Actions status if deployment was requested. State clearly when changes remain uncommitted.

## Common mistakes

- Do not use `git add .` when unrelated changes exist.
- Do not change global Git identity.
- Do not confuse commit, push, build, and deployment success.
- Do not edit generated `_site/` output.
- Do not create planning documents or repeat decisions across multiple confirmation rounds.
