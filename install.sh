#!/usr/bin/env bash
# agent-workflow-starter
# 安装：把规则、复核脚本、钩子复制到 $HOME 下。幂等；已有且不同的文件先备份。
# 兼容 macOS 自带 bash 3.2（不用关联数组、mapfile 等）。
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARK="agent-workflow-starter"
TS="$(date +%Y%m%d-%H%M%S)"
STATE_DIR="$HOME/.agent-workflow-starter"
MANIFEST="$STATE_DIR/manifest.tsv"

mkdir -p "$STATE_DIR"
touch "$MANIFEST"

record() { printf '%s\t%s\n' "$1" "$2" >> "$MANIFEST"; }

# install_file <仓库内源文件> <目标路径> <exec|plain>
install_file() {
  local src="$SRC/$1" dst="$2" mode="$3" bak
  if [ ! -f "$src" ]; then
    echo "❌ 缺少源文件：$1（仓库不完整？）" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$dst")"
  if [ ! -e "$dst" ]; then
    cp "$src" "$dst"
    record "$dst" "-"
    echo "✅ 已安装：$dst"
  elif cmp -s "$src" "$dst"; then
    echo "· 已是最新：$dst"
  else
    bak="$dst.bak-$TS"
    cp -p "$dst" "$bak"
    cp "$src" "$dst"
    record "$dst" "$bak"
    echo "✅ 已更新：$dst"
    echo "   你原来的文件在 $bak"
  fi
  if [ "$mode" = "exec" ]; then chmod +x "$dst"; fi
}

echo "== 1/4 安装规则、脚本、钩子 =="
install_file "rules/CLAUDE.md"                  "$HOME/.claude/CLAUDE.md"                      plain
install_file "rules/AGENTS.md"                  "$HOME/.codex/AGENTS.md"                       plain
install_file "scripts/codex-review.sh"          "$HOME/bin/codex-review.sh"                    exec
install_file "hooks/unpushed-reminder.sh"       "$HOME/.claude/hooks/unpushed-reminder.sh"     exec
install_file "hooks/git-status-after-add.sh"    "$HOME/.claude/hooks/git-status-after-add.sh"  exec

echo
echo "== 2/4 PATH（~/bin） =="
ZP="$HOME/.zprofile"
if [ -f "$ZP" ] && grep -q "# $MARK" "$ZP"; then
  echo "· .zprofile 里已有 PATH 行，跳过"
else
  zbak="-"
  if [ -f "$ZP" ]; then
    zbak="$ZP.bak-$TS"
    cp -p "$ZP" "$zbak"
    # 末尾没换行就先补一个，避免新行接在旧行后面
    if [ -s "$ZP" ] && [ -n "$(tail -c1 "$ZP")" ]; then printf '\n' >> "$ZP"; fi
  fi
  printf '%s\n' 'export PATH="$HOME/bin:$PATH"  # agent-workflow-starter' >> "$ZP"
  record "$ZP" "$zbak"
  echo "✅ 已在 $ZP 追加 PATH 行"
  if [ "$zbak" != "-" ]; then echo "   你原来的文件在 $zbak"; fi
fi
echo "   新开一个终端窗口后生效"

echo
echo "== 3/4 VS Code 扩展 =="
if [ "${AWS_SKIP_EXTENSIONS:-}" = "1" ]; then
  echo "· 已设置 AWS_SKIP_EXTENSIONS=1，跳过"
elif command -v code >/dev/null 2>&1; then
  code --install-extension anthropic.claude-code || echo "⚠️ Claude Code 扩展安装失败，请手动装"
  code --install-extension openai.chatgpt || echo "⚠️ Codex 扩展安装失败，请手动装"
else
  echo "⚠️ 没找到 code 命令，请手动装两个扩展："
  echo "   https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code"
  echo "   https://marketplace.visualstudio.com/items?itemName=openai.chatgpt"
  echo "   把 code 放进 PATH：VS Code 命令面板运行 \"Shell Command: Install 'code' command in PATH\"，然后重开终端。"
fi

echo
echo "== 4/4 hooks 配置（需要你让 Claude Code 合并） =="
SNIPPET="$SRC/hooks/settings-snippet.json"
if [ -f "$SNIPPET" ]; then
  echo "打开 Claude Code 说一句：把下面这段 hooks 合进 ~/.claude/settings.json"
  echo "----------------------------------------"
  cat "$SNIPPET"
  echo "----------------------------------------"
else
  echo "⚠️ 找不到 hooks/settings-snippet.json"
fi

echo
echo "安装完成。Claude Code 与 Codex 的命令行请按 README 跑官方安装命令。"
echo "下一步：新开终端，进入本目录跑 ./check.sh"
