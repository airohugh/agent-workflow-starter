#!/usr/bin/env bash
# agent-workflow-starter
# 逐项自检。只读，不写任何文件。兼容 bash 3.2。
# 输出格式：✅/❌/⚠️ [id] 说明；红黄项下一行起给「修法」。任一 ❌ 退出码 1。
set -u

MARK="agent-workflow-starter"
PASS=0
FAIL=0

# 外部命令防挂起：stdin 接 /dev/null；有 timeout/gtimeout 就限 15 秒
TO=""
if command -v timeout >/dev/null 2>&1; then TO="timeout 15"
elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout 15"; fi
run() {
  if [ -n "$TO" ]; then $TO "$@" < /dev/null; else "$@" < /dev/null; fi
}

ok()   { PASS=$((PASS+1)); echo "✅ [$1] $2"; }
bad()  { FAIL=$((FAIL+1)); echo "❌ [$1] $2"; shift 2; for l in "$@"; do echo "   修法：$l"; done; }
warn() { echo "⚠️ [$1] $2"; shift 2; for l in "$@"; do echo "   修法：$l"; done; }

has() { command -v "$1" >/dev/null 2>&1; }
EXT_ANTHROPIC="https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code"
EXT_OPENAI="https://marketplace.visualstudio.com/items?itemName=openai.chatgpt"

# --- VS Code ---
if [ -d "/Applications/Visual Studio Code.app" ] || has code; then
  ok vscode "VS Code 已安装"
else
  bad vscode "没找到 VS Code" "去 https://code.visualstudio.com 下载并拖进「应用程序」"
fi

if has code; then
  ok code-cli "code 命令在 PATH 里"
else
  warn code-cli "code 命令不在 PATH 里（不影响使用，但 install.sh 没法自动装扩展）" \
    "VS Code 命令面板运行 \"Shell Command: Install 'code' command in PATH\"，然后重开终端"
fi

ext_present() { # $1 = 扩展 id 前缀
  if ls -d "$HOME/.vscode/extensions/$1-"* >/dev/null 2>&1; then return 0; fi
  if has code && run code --list-extensions 2>/dev/null | grep -qi "^$1\$"; then return 0; fi
  return 1
}
if ext_present anthropic.claude-code; then
  ok ext-claude "Claude Code 扩展已安装"
else
  bad ext-claude "没装 Claude Code 扩展" "打开 $EXT_ANTHROPIC 点 Install，或 code --install-extension anthropic.claude-code"
fi
if ext_present openai.chatgpt; then
  ok ext-codex "Codex 扩展已安装"
else
  bad ext-codex "没装 Codex 扩展" "打开 $EXT_OPENAI 点 Install，或 code --install-extension openai.chatgpt"
fi

# --- 基础工具 ---
if run git --version >/dev/null 2>&1; then
  ok git "git 可用"
else
  bad git "git 不可用" "xcode-select --install"
fi
if has python3 && run python3 -c 'import json' >/dev/null 2>&1; then
  ok python3 "python3 可用（钩子要用）"
else
  bad python3 "python3 不可用（钩子要用）" "xcode-select --install"
fi

# --- Claude Code ---
CLAUDE_OK=0
if ! has claude; then
  if [ -e "$HOME/.local/bin/claude" ]; then
    bad claude-cli "claude 命令不在 PATH 里（~/.local/bin/claude 已存在，只是不在 PATH 里）" \
      "curl -fsSL https://claude.ai/install.sh | bash，然后新开终端" \
      "装过了还找不到：官方安装位置是 ~/.local/bin，把它加进 PATH 后新开终端"
  else
    bad claude-cli "claude 命令行不可用（PATH 里没有 claude）" \
      "curl -fsSL https://claude.ai/install.sh | bash，然后新开终端" \
      "装过了还找不到：官方安装位置是 ~/.local/bin，把它加进 PATH 后新开终端"
  fi
elif ! run claude --version >/dev/null 2>&1; then
  bad claude-cli "claude 命令存在，但 claude --version 运行失败" \
    "运行 claude doctor 看诊断"
else
  CLAUDE_OK=1
  ok claude-cli "claude 命令行可用"
fi
if [ "$CLAUDE_OK" = 1 ]; then
  if run claude auth status 2>&1 | grep -Eq '"loggedIn"[[:space:]]*:[[:space:]]*true'; then
    ok claude-login "Claude Code 已登录"
  else
    bad claude-login "Claude Code 未登录" \
      "运行 claude（或在 VS Code 的 Claude Code 面板点 Sign in），用 Pro/Max/Team/Enterprise 账号登录；免费账号不行"
  fi
else
  bad claude-login "无法检查登录状态：先修 claude-cli" "先修上一项 claude-cli"
fi

# --- Codex ---
CODEX_OK=0
if has codex && run codex --version >/dev/null 2>&1; then
  CODEX_OK=1
  ok codex-cli "codex 命令行可用"
else
  bad codex-cli "codex 命令行不可用" "curl -fsSL https://chatgpt.com/codex/install.sh | sh，然后新开终端"
fi
if [ "$CODEX_OK" = 1 ]; then
  if run codex login status >/dev/null 2>&1; then
    ok codex-login "Codex 已登录"
  else
    bad codex-login "Codex 未登录" \
      "运行 codex login，选 Sign in with ChatGPT；需要 Plus 及以上，Free/Go 用不了 CLI"
  fi
else
  bad codex-login "无法检查登录状态：先修 codex-cli" "先修上一项 codex-cli"
fi

# --- 本仓安装的东西 ---
marked() { [ -f "$1" ] && grep -q "$MARK" "$1"; }
if marked "$HOME/.claude/CLAUDE.md"; then
  ok rules-claude "~/.claude/CLAUDE.md 已安装"
else
  bad rules-claude "~/.claude/CLAUDE.md 不存在或不是本仓安装的" "在本目录跑 ./install.sh"
fi
if marked "$HOME/.codex/AGENTS.md"; then
  ok rules-codex "~/.codex/AGENTS.md 已安装"
else
  bad rules-codex "~/.codex/AGENTS.md 不存在或不是本仓安装的" "在本目录跑 ./install.sh"
fi
if [ -x "$HOME/bin/codex-review.sh" ]; then
  ok review-script "~/bin/codex-review.sh 存在且可执行"
else
  bad review-script "~/bin/codex-review.sh 不存在或不可执行" "在本目录跑 ./install.sh"
fi
if command -v codex-review.sh >/dev/null 2>&1; then
  ok path "codex-review.sh 在当前 PATH 里"
else
  bad path "当前终端的 PATH 里找不到 codex-review.sh（~/bin 没生效）" \
    "新开一个终端窗口；或运行 source ~/.zprofile"
fi
if [ -x "$HOME/.claude/hooks/unpushed-reminder.sh" ] && [ -x "$HOME/.claude/hooks/git-status-after-add.sh" ]; then
  ok hooks-files "两个钩子脚本存在且可执行"
else
  bad hooks-files "钩子脚本缺失或不可执行" "在本目录跑 ./install.sh"
fi
SETTINGS="$HOME/.claude/settings.json"
HOOK_FIX="打开 Claude Code 说「把 agent-workflow-starter 的 hooks/settings-snippet.json 合进 ~/.claude/settings.json」"
if ! has python3; then
  bad hooks-settings "无法检查 settings.json 的钩子配置：python3 不可用" "先修 python3"
elif [ ! -f "$SETTINGS" ]; then
  bad hooks-settings "~/.claude/settings.json 不存在" "$HOOK_FIX"
else
  hs=$(SETTINGS="$SETTINGS" python3 -c '
import json, os, sys
try:
    with open(os.environ["SETTINGS"]) as f:
        d = json.load(f)
except Exception:
    print("INVALID"); sys.exit(0)
def has_cmd(event, matcher_ok, needle):
    h = d.get("hooks") if isinstance(d, dict) else None
    groups = h.get(event) if isinstance(h, dict) else None
    if not isinstance(groups, list):
        return False
    for g in groups:
        if not isinstance(g, dict) or not matcher_ok(g.get("matcher", "")):
            continue
        for x in g.get("hooks") or []:
            if isinstance(x, dict) and needle in str(x.get("command", "")):
                return True
    return False
miss = []
if not has_cmd("SessionStart", lambda m: True, "unpushed-reminder.sh"):
    miss.append("unpushed-reminder.sh（SessionStart）")
if not has_cmd("PostToolUse", lambda m: "Bash" in str(m), "git-status-after-add.sh"):
    miss.append("git-status-after-add.sh（PostToolUse，matcher 为 Bash）")
print("MISSING " + "、".join(miss) if miss else "OK")
' 2>/dev/null) || hs="INVALID"
  case "$hs" in
    OK)
      ok hooks-settings "settings.json 里两个钩子的配置结构正确（是否真触发，开一个新会话看）" ;;
    MISSING*)
      bad hooks-settings "~/.claude/settings.json 里缺少钩子配置：${hs#MISSING }" "$HOOK_FIX" ;;
    *)
      bad hooks-settings "~/.claude/settings.json 不是合法 JSON，没法检查钩子配置" \
        "打开 Claude Code 说「~/.claude/settings.json 的 JSON 格式有问题，帮我修好（先备份）」，修好后再跑一次 ./check.sh" ;;
  esac
fi

# --- 可选 ---
if [ -n "$TO" ]; then
  ok timeout "timeout/gtimeout 可用"
else
  warn timeout "没有 timeout/gtimeout，复核卡住时不会超时自动停" \
    "brew install coreutils；不装也能用，只是复核不会超时自动停"
fi

echo
echo "$PASS 项通过，$FAIL 项未通过"
[ "$FAIL" -eq 0 ]
