#!/usr/bin/env bash
# agent-workflow-starter
# 只读交叉复核的固定入口：把 codex exec 反复漏掉的参数写死，避免每次手敲出错。
#
# 用法：codex-review.sh <prompt 文件> <报告文件> [超时秒，默认 2400]
#
# 写死的参数及原因：
#   < /dev/null
#       codex exec 在 stdin 被接成管道且又给了 prompt 参数时，会把 stdin 当附加上下文读进来；
#       后台或非终端环境的 stdin 是一个永不关闭的管道，于是永远等下去。
#       症状：输出第一行停在 "Reading additional input from stdin..."，超时后报告 0 字节。
#   --skip-git-repo-check
#       codex 默认要求在 git 仓里运行；送审目录常常只是一个放送审文件的临时目录。
#   -c model_reasoning_effort=high
#       默认推理档位偏低，审计类任务差别明显。报告头会写出实际的 reasoning effort，可据此核对。
#   --sandbox read-only
#       复核方只读不写，不能改被审对象。
#
# 输出重定向必须是 > "$OUT" 2>&1：
#   别写成 2>&1 > file（那样 stderr 不进文件）；也别接 | tail（tail 会吞掉退出码，
#   且跑完之前看不到任何输出）。
#
# 建议用法：
#   1. 在一个只放送审文件的临时目录里跑（先 cd 进去再调用），避免复核方读到 .env 等凭据文件。
#   2. 外部事实（数据库里的值、线上状态）直接写进 prompt；只读沙箱里的复核方取不到外部数据，会卡住。

set -u

usage() {
  echo "用法：codex-review.sh <prompt 文件> <报告文件> [超时秒，默认 2400]"
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

if [ $# -lt 2 ]; then
  usage >&2
  exit 2
fi

PROMPT=$1
OUT=$2
LIMIT=${3:-2400}

[ -f "$PROMPT" ] || { echo "找不到 prompt 文件：$PROMPT" >&2; exit 2; }

if ! command -v codex >/dev/null 2>&1; then
  echo "PATH 里找不到 codex。官方安装命令：" >&2
  echo "  curl -fsSL https://chatgpt.com/codex/install.sh | sh" >&2
  exit 2
fi

TO=""
if command -v timeout >/dev/null 2>&1; then
  TO=timeout
elif command -v gtimeout >/dev/null 2>&1; then
  TO=gtimeout
else
  echo "没有 timeout，复核不会自动停；可 brew install coreutils" >&2
fi

PROMPT_TEXT=$(cat "$PROMPT")

if [ -n "$TO" ]; then
  "$TO" "$LIMIT" codex exec --sandbox read-only --skip-git-repo-check \
    -c model_reasoning_effort=high "$PROMPT_TEXT" < /dev/null > "$OUT" 2>&1
else
  codex exec --sandbox read-only --skip-git-repo-check \
    -c model_reasoning_effort=high "$PROMPT_TEXT" < /dev/null > "$OUT" 2>&1
fi
rc=$?

if grep -qi 'usage limit' "$OUT" 2>/dev/null; then
  echo "撞到用量上限：报告不完整，退出码可能仍是 0，别只看退出码" >&2
fi

echo "codex 退出码 ${rc}；报告 ${OUT}（完整读，别用 tail/head 截——报告按严重度降序，截尾会砍掉 blocker）" >&2
exit $rc
