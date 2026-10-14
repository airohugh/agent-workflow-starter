#!/usr/bin/env bash
# agent-workflow-starter
# PostToolUse(Bash) 钩子：git add / git commit 之后，自动把 git status --short 注入 Claude 上下文。
#
# 为什么：多路径 add 时只要有一个 pathspec 匹配失败，整条命令 fatal、一个文件都不会被 add；
# 不带 pathspec 的 commit 会带上索引里全部已 staged 的内容。这两件事都不报错，只能靠看 status 发现。
#
# 注意：PostToolUse 的普通 stdout 只进用户 transcript、不进模型上下文（见官方 hooks 文档），
# 所以这里输出 hookSpecificOutput.additionalContext 的 JSON。任何异常都静默退出 0，不阻断。
set -u
input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || exit 0

# 只在「命令段开头」匹配（行首，或 ; & | ( ` 之后，可带路径前缀如 /usr/bin/git）。
# 纯子串匹配会让 `grep -n "git add" x` 这类纯搜索、文档正文里提到 git commit 都白注入一次 status。
# 已知残留：heredoc 正文里独立成行的 `git add ...` 仍会触发。宁可多报不可漏报——
# 漏报的代价是 pathspec 静默失败没人发现，误报的代价只是一段噪音。
printf '%s' "$cmd" \
  | grep -qE '(^|[;&|(`])[[:space:]]*([^[:space:];&|]*/)?git[[:space:]]+(add|commit)([[:space:]]|$)' \
  || exit 0

# 输入 JSON 顶层的 cwd 是 shell 的起始目录。命令内部 `cd /别的仓 && git commit` 时 git 在别处跑，
# 照 cwd 报 status 会给出另一个仓的内容——核对工具给错核对结果比不给更糟。
# 所以再取命令里最后一个 cd 目标做修正。
# 已知不准：`cd /a && git add x && cd /b` 会取到 /b。因此下面把仓库路径一并回显，取错看得出来。
dirs=$(printf '%s' "$input" | python3 -c '
import json,os,re,sys
d = json.load(sys.stdin)
print(d.get("cwd") or "")
cmd = (d.get("tool_input") or {}).get("command") or ""
m = re.findall(r"(?:^|[;&|(])\s*cd\s+([^;&|]+)", cmd)
print(os.path.expanduser(m[-1].strip().strip(chr(34) + chr(39))) if m else "")
' 2>/dev/null)
base_dir=$(printf '%s\n' "$dirs" | sed -n 1p)
cd_to=$(printf '%s\n' "$dirs" | sed -n 2p)
[ -n "$base_dir" ] && cd "$base_dir" 2>/dev/null
[ -n "$cd_to" ] && cd "$cd_to" 2>/dev/null

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
repo=$(git rev-parse --show-toplevel 2>/dev/null)
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
status=$(git status --short | head -40)
staged=$(git diff --cached --name-only | wc -l | tr -d ' ')

printf '%s\n%s' "[git-status-after-add] 仓库 ${repo}，分支 ${branch}，已 staged ${staged} 个文件。git status --short 前 40 行（核对真的 staged 了、没混入无关文件）：" "$status" \
  | python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": sys.stdin.read()}}, ensure_ascii=False))'
exit 0
