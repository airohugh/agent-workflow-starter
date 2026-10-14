#!/usr/bin/env bash
# agent-workflow-starter
# 卸载：按 manifest 还原。备份文件本身保留。兼容 bash 3.2。
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARK="agent-workflow-starter"
TS="$(date +%Y%m%d-%H%M%S)"
STATE_DIR="$HOME/.agent-workflow-starter"
MANIFEST="$STATE_DIR/manifest.tsv"
ZP="$HOME/.zprofile"

if [ ! -f "$MANIFEST" ]; then
  echo "没有找到 ${MANIFEST}，看起来没装过（或已卸载），什么也没做。"
  exit 0
fi

# 目标路径 -> 仓库里的源文件
src_for() {
  case "$1" in
    "$HOME/.claude/CLAUDE.md")                     echo "$SRC/rules/CLAUDE.md" ;;
    "$HOME/.codex/AGENTS.md")                      echo "$SRC/rules/AGENTS.md" ;;
    "$HOME/bin/codex-review.sh")                   echo "$SRC/scripts/codex-review.sh" ;;
    "$HOME/.claude/hooks/unpushed-reminder.sh")    echo "$SRC/hooks/unpushed-reminder.sh" ;;
    "$HOME/.claude/hooks/git-status-after-add.sh") echo "$SRC/hooks/git-status-after-add.sh" ;;
    *) echo "" ;;
  esac
}

KEPT=""      # 保留下来的备份路径，最后打印
DONE=""      # 已处理过的目标（同一目标可能在 manifest 里出现多次）
FAILED=0     # 未能还原的项数

while IFS="$(printf '\t')" read -r target backup || [ -n "${target:-}" ]; do
  [ -n "$target" ] || continue
  if printf '%s\n' "$DONE" | grep -Fxq -- "$target"; then continue; fi
  DONE="$DONE
$target"
  # 同一目标取 manifest 里最早的一行：它记录的是「装之前的原貌」
  # （若是 "-" 说明装之前不存在，后面几行的备份只是我们自己的旧版本或你的修改，不应拿来还原）
  if [ "$target" = "$ZP" ]; then
    # .zprofile 只删带标记的那一行，其余内容不动
    if [ -f "$ZP" ] && grep -q "# $MARK" "$ZP"; then
      tmp="$(mktemp "$ZP.tmp.XXXXXX")"
      grep -v "# $MARK" "$ZP" > "$tmp" || true
      if [ "$backup" = "-" ] && [ ! -s "$tmp" ]; then
        if [ -L "$ZP" ]; then
          : > "$ZP"
          rm -f "$tmp"
          echo "✅ $ZP 是符号链接，只剩我们那一行：保留链接，已清空它指向的文件"
        else
          rm -f "$tmp" "$ZP"
          echo "✅ $ZP 只剩我们那一行，已删除整个文件（原本就是我们创建的）"
        fi
      else
        # 写到目标而不是 mv 替换：.zprofile 若是符号链接，链接要保留
        cat "$tmp" > "$ZP" && rm -f "$tmp"
        echo "✅ 已从 $ZP 删除带标记的 PATH 行"
      fi
    else
      echo "· $ZP 里没有标记行，不动"
    fi
    if [ "$backup" != "-" ]; then KEPT="$KEPT
$backup"; fi
    continue
  fi

  if [ ! -f "$target" ]; then
    echo "· $target 已不存在，跳过"
    continue
  fi
  if ! grep -q "$MARK" "$target"; then
    if [ "$backup" != "-" ] && [ -f "$backup" ] && cmp -s "$backup" "$target"; then
      echo "· $target 已还原过，跳过"
      KEPT="$KEPT
$backup"
    else
      echo "⚠️ $target 里没有 $MARK 标记，不是我们装的（或你已替换），不动"
      FAILED=$((FAILED+1))
    fi
    continue
  fi

  src="$(src_for "$target")"
  if [ -z "$src" ] || [ ! -f "$src" ] || ! cmp -s "$src" "$target"; then
    saved="$target.before-uninstall-$TS"
    cp -p "$target" "$saved"
    KEPT="$KEPT
$saved"
    echo "· $target 与仓库版本不同（你改过），已另存 $saved"
  fi

  if [ "$backup" != "-" ]; then
    if [ -f "$backup" ]; then
      cp -p "$backup" "$target"
      KEPT="$KEPT
$backup"
      echo "✅ 已还原 ${target}（来自 ${backup}）"
    else
      echo "⚠️ 备份 $backup 不见了，$target 保持现状没动"
      FAILED=$((FAILED+1))
    fi
  else
    rm -f "$target"
    echo "✅ 已删除 ${target}（装之前不存在）"
  fi
done < "$MANIFEST"

if [ "$FAILED" -gt 0 ]; then
  echo
  echo "有 ${FAILED} 项未能还原，安装记录已保留在 ${STATE_DIR}，处理后可再跑一次 ./uninstall.sh"
else
  rm -rf "$STATE_DIR"
  echo "✅ 已删除 $STATE_DIR"
fi

KEPT="$(printf '%s\n' "$KEPT" | grep -v '^$' | sort -u || true)"
if [ -n "$KEPT" ]; then
  echo
  echo "以下备份/另存文件已保留，不再需要时请自行删除："
  printf '%s\n' "$KEPT" | sed 's/^/   /'
fi

echo
echo "未处理的事项："
echo "1. VS Code 扩展没有卸载。手动卸载：code --uninstall-extension anthropic.claude-code 与 code --uninstall-extension openai.chatgpt（或在扩展面板里点卸载）。"
echo "2. 之前让 Claude Code 合并进 ~/.claude/settings.json 的 hooks 段需要手动删，或打开 Claude Code 说：把 settings.json 里 unpushed-reminder.sh 和 git-status-after-add.sh 的 hooks 删掉。"

[ "$FAILED" -eq 0 ] || exit 1
