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

# 触发判断、目录定位都在一段 python 里做，输出三行：定位到的目录、开头以外是否还有 cd(0/1)、
# 定位是否可能不准(0/1：用了 --git-dir/--work-tree，或路径/选项解析失败)。
# 没输出 = 不触发或解析失败，静默退出。
#
# 触发：只在「命令段开头」匹配（行首，或 ; & | ( ` 之后，可带路径前缀如 /usr/bin/git）。
# 纯子串匹配会让 `grep -n "git add" x` 这类纯搜索、文档正文里提到 git commit 都白注入一次 status。
# git 与子命令之间允许全局选项：-C <路径>、-c <k=v>、--开头的长选项（--no-pager、--git-dir=… 等）。
# 已知残留：heredoc 正文里独立成行的 `git add ...` 仍会触发。宁可多报不可漏报——
# 漏报的代价是 pathspec 静默失败没人发现，误报的代价只是一段噪音。
#
# 不解析 --git-dir/--work-tree：出现就在输出开头提示定位可能不准。
#
# 定位：输入 JSON 顶层的 cwd 是 shell 的起始目录。命令内部 `cd /别的仓 && git commit` 或 `git -C 仓 add` 时
# git 在别处跑，照 cwd 报 status 会给出另一个仓的内容——核对工具给错核对结果比不给更糟。
# 只解析最常见、能确定的两种：命令开头的 `cd 路径 &&`（或 ; 、换行），以及触发段里的 -C 路径（相对路径逐级解析）。
# 别处再出现 cd（git 之后、括号/子 shell 里、换行分隔的多个 cd）不去猜作用域，只提示定位可能不准。
# 仓库路径一并回显，取错看得出来。
loc=$(printf '%s' "$input" | python3 -c '
import json,os,re,shlex,sys
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
loose = 0
rest = cmd
m0 = re.match(r"\s*cd\s+(.+?)\s*(?:&&|;|\n)", cmd)
if m0:
    try:
        t = shlex.split("cd " + m0.group(1))
    except ValueError:
        t = []
    if len(t) == 2:
        cur = os.path.join(cur, os.path.expanduser(t[1]))
        rest = cmd[m0.end():]
    else:
        loose = 1
other_cd = 1 if re.search(r"(?:^|[^\w./-])cd(?:\s|$)", rest) else 0
opts = ms[-1].group(1)
try:
    # 按参数边界解析：只有参数位置上的 -C <路径> 才是目录；-c <值> 与 --xxx[=值] 整个跳过，
    # 避免把 -c "core.sshCommand=ssh -C -i key" 里的 -C 当成目录。
    toks = shlex.split(opts)
    dirs = []
    i = 0
    while i < len(toks):
        t = toks[i]
        if t == "-C" and i + 1 < len(toks):
            dirs.append(toks[i + 1]); i += 2
        elif t == "-c":
            i += 2
        else:
            if t.startswith("--git-dir") or t.startswith("--work-tree"):
                loose = 1
            i += 1
except ValueError:
    loose = 1
    dirs = re.findall(r"-C\s+(" + arg + ")", opts)
if re.search(r"--(?:git-dir|work-tree)\b", opts):
    loose = 1
for c in dirs:
    cur = os.path.join(cur, unq(c))
if "\n" in cur:
    sys.exit(0)
print(cur)
print(other_cd)
print(loose)
' 2>/dev/null) || exit 0
[ -n "$loc" ] || exit 0
target=$(printf '%s\n' "$loc" | sed -n 1p)
other_cd=$(printf '%s\n' "$loc" | sed -n 2p)
loose=$(printf '%s\n' "$loc" | sed -n 3p)
# 目录不存在就别在错的目录上报 status
cd "$target" 2>/dev/null || exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
repo=$(git rev-parse --show-toplevel 2>/dev/null)
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
status=$(git status --short | head -40)
staged=$(git diff --cached --name-only | wc -l | tr -d ' ')

note=""
if [ "$other_cd" = "1" ]; then note="命令里除了开头的 cd 还有别的 cd（git 之后、括号里或多行），下面的仓库定位可能不准，请自行核对仓库路径。
"; fi
if [ "$loose" = "1" ]; then note="${note}命令用了 --git-dir/--work-tree，或路径与选项无法解析，下面的仓库定位可能不准，请自行核对。
"; fi

printf '%s%s\n%s' "$note" "[git-status-after-add] 仓库 ${repo}，分支 ${branch}，已 staged ${staged} 个文件。git status --short 前 40 行（核对真的 staged 了、没混入无关文件）：" "$status" \
  | python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": sys.stdin.read()}}, ensure_ascii=False))'
exit 0
