#!/usr/bin/env bash
# agent-workflow-starter
# SessionStart 钩子：本地未推送的提交攒够了就提醒。
# SessionStart 的普通 stdout 会作为上下文进入 Claude，所以这里只输出一行纯文本。
#
# 阈值（环境变量可覆盖）：
#   STARTER_UNPUSHED_MAX_COMMITS  未推提交数超过它就提醒，默认 30
#   STARTER_UNPUSHED_MAX_DAYS     最早一个未推提交已满这么多天就提醒，默认 7
#
# 只读本地 git、不联网：与远端的比较以上次 fetch 的状态为准，不会为了提醒去连网络。
# 没有上游分支、不是 git 仓、stdin 不是合法 JSON 等任何异常，一律静默退出 0，绝不阻断会话。

MAX_COMMITS=${STARTER_UNPUSHED_MAX_COMMITS:-30}
MAX_DAYS=${STARTER_UNPUSHED_MAX_DAYS:-7}

# stdin 是 SessionStart 的 JSON（含 session_id、transcript_path、cwd、hook_event_name、source 等）
CWD=$(python3 -c 'import json, sys
try:
    print(json.load(sys.stdin).get("cwd", ""))
except Exception:
    print("")' 2>/dev/null)
[ -n "$CWD" ] || exit 0

TOP=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
N=$(git -C "$CWD" rev-list --count '@{u}..HEAD' 2>/dev/null) || exit 0
[ "${N:-0}" -gt 0 ] || exit 0

NOW=$(date +%s)
OLDEST=$(git -C "$CWD" log --format=%ct '@{u}..HEAD' 2>/dev/null | sort -n | head -1)
DAYS=$(( ( NOW - ${OLDEST:-$NOW} ) / 86400 ))

if [ "$N" -gt "$MAX_COMMITS" ] || [ "$DAYS" -ge "$MAX_DAYS" ]; then
  echo "[unpushed-reminder] 仓库 $(basename "$TOP") 有 $N 个提交没推送，最早一个是 $DAYS 天前。建议：在第一条回复里提醒使用者是否要推送；推送前先审查。"
fi
exit 0
