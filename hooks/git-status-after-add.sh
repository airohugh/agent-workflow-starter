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

# 触发判断、目录定位都在一段 python 里做，输出两行：定位到的目录、命令里 cd 是否出现多次(0/1)。
# 没输出 = 不触发或解析失败，静默退出。
#
# 触发：只在「命令段开头」匹配（行首，或 ; & | ( ` 之后，可带路径前缀如 /usr/bin/git）。
# 纯子串匹配会让 `grep -n "git add" x` 这类纯搜索、文档正文里提到 git commit 都白注入一次 status。
# git 与子命令之间允许全局选项：-C <路径>、-c <k=v>、--开头的长选项（--no-pager、--git-dir=… 等）。
# 已知残留：heredoc 正文里独立成行的 `git add ...` 仍会触发。宁可多报不可漏报——
# 漏报的代价是 pathspec 静默失败没人发现，误报的代价只是一段噪音。
#
# 定位：输入 JSON 顶层的 cwd 是 shell 的起始目录。命令内部 `cd /别的仓 && git commit` 或 `git -C 仓 add` 时
# git 在别处跑，照 cwd 报 status 会给出另一个仓的内容——核对工具给错核对结果比不给更糟。
# 所以按顺序叠加命令里的 cd 目标（相对路径逐级解析）、再叠加触发段里的 -C 路径（相对路径逐级相对解析）。
# 已知不准：`cd /a && git add x && cd /b` 会取到 /b；多个 cd 时会在输出里提示。仓库路径一并回显，取错看得出来。
loc=$(printf '%s' "$input" | python3 -c '
import json,os,re,sys
d = json.load(sys.stdin)
cmd = (d.get("tool_input") or {}).get("command") or ""
arg = r"(?:\"[^\"]*\"|\x27[^\x27]*\x27|[^\s;&|]+)"
trig = re.compile(
    r"(?:^|[;&|(`])[ \t]*(?:[^\s;&|]*/)?git((?:\s+(?:-C\s+" + arg + r"|-c\s+" + arg + r"|--[^\s;&|]+))*)\s+(?:add|commit)(?=\s|$)",
    re.M)
ms = list(trig.finditer(cmd))
if not ms:
    sys.exit(0)
def unq(x):
    x = x.strip()
    if len(x) >= 2 and x[0] == x[-1] and x[0] in (chr(34), chr(39)):
        x = x[1:-1]
    return os.path.expanduser(x)
cur = d.get("cwd") or os.getcwd()
cds = re.findall(r"(?:^|[;&|(])\s*cd\s+([^;&|]+)", cmd)
for c in cds:
    cur = os.path.join(cur, unq(c))
for c in re.findall(r"-C\s+(" + arg + ")", ms[-1].group(1)):
    cur = os.path.join(cur, unq(c))
print(cur)
print(1 if len(cds) >= 2 else 0)
' 2>/dev/null) || exit 0
[ -n "$loc" ] || exit 0
target=$(printf '%s\n' "$loc" | sed -n 1p)
multi_cd=$(printf '%s\n' "$loc" | sed -n 2p)
# 目录不存在就别在错的目录上报 status
cd "$target" 2>/dev/null || exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
repo=$(git rev-parse --show-toplevel 2>/dev/null)
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
status=$(git status --short | head -40)
staged=$(git diff --cached --name-only | wc -l | tr -d ' ')

note=""
if [ "$multi_cd" = "1" ]; then note="命令里有多个 cd，下面的仓库定位可能不准，请自行核对仓库路径。
"; fi

printf '%s%s\n%s' "$note" "[git-status-after-add] 仓库 ${repo}，分支 ${branch}，已 staged ${staged} 个文件。git status --short 前 40 行（核对真的 staged 了、没混入无关文件）：" "$status" \
  | python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": sys.stdin.read()}}, ensure_ascii=False))'
exit 0
