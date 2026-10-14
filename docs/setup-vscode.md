# 第 0 节：VS Code 初始配置

README「上手」表里 VS Code、扩展、命令行、登录几步的细节（本页编号与 README 不同）。每一步都有「怎么确认做好了」。卡住了就跑一遍 `./check.sh`，它会告诉你哪一项红、怎么修。

## 1. 装 VS Code

从 <https://code.visualstudio.com> 下载 macOS 版，解压后拖进「应用程序」文件夹。Claude Code 扩展要求 VS Code 1.94.0 或更新。

**把 `code` 命令放进 PATH**（可选，但能让 `install.sh` 自动装扩展）：打开 VS Code，按 `Cmd+Shift+P` 打开命令面板，输入并运行 `Shell Command: Install 'code' command in PATH`，然后关掉终端重开一个。

确认：新终端里运行 `code --version` 能打印版本号。

## 2. 装两个扩展

| 扩展 | 市场 ID | 链接 |
|---|---|---|
| Claude Code | `anthropic.claude-code` | <https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code> |
| Codex（OpenAI） | `openai.chatgpt` | <https://marketplace.visualstudio.com/items?itemName=openai.chatgpt> |

`code` 在 PATH 里时，`install.sh` 会替你装；否则点链接里的 Install，或在 VS Code 左侧扩展面板搜索名字安装。

## 3. 装 Codex 命令行（Claude 命令行可选）

两个扩展都自带一份程序给聊天面板用，但都**不会把命令放进终端的 PATH**。要不要另装命令行，两家情况不同：

- **Claude：可选。** 本仓库装的规则（`~/.claude/CLAUDE.md`）、钩子与 `~/.claude/settings.json` 由扩展和命令行共用，在扩展里照样生效。只有想在终端里直接运行 `claude` 时才需要装：

  ```bash
  curl -fsSL https://claude.ai/install.sh | bash
  ```

  装完新开终端，`claude --version` 能打印版本号即可。提示找不到命令，多半是安装位置 `~/.local/bin` 还不在 PATH 里；能找到但运行出错，运行 `claude doctor` 看诊断。

- **Codex：要装。** 交叉复核脚本 `codex-review.sh` 在终端里调用 `codex exec`，所以终端里必须能找到 `codex`。官方安装命令：

  ```bash
  curl -fsSL https://chatgpt.com/codex/install.sh | sh
  ```

  装完新开终端，`codex --version` 能打印版本号即可。

**不想另装 Codex 命令行的备选（非官方）：** Codex 扩展目录里自带一个完整的 `codex` 程序，可以在 `~/bin` 放一个转接脚本去调用它（`install.sh` 会把 `~/bin` 加进 PATH，所以这一步放在跑完 `install.sh` 之后）。这条路官方文档没写，扩展哪天改了目录结构就会失效，到时 `check.sh` 会报红：先 `rm ~/bin/codex`，再装上面的官方命令行（`~/bin` 排在 PATH 最前，不删会挡住官方那份）。

```bash
mkdir -p ~/bin && cat > ~/bin/codex <<'EOF'
#!/bin/bash
# 转接到 Codex VS Code 扩展自带的 codex（非官方做法：扩展改了目录结构就会失效，到时改装官方命令行）
BIN=$(ls -d "$HOME"/.vscode/extensions/openai.chatgpt-*/bin/macos-*/codex 2>/dev/null | sort -V | tail -1)
[ -x "$BIN" ] || { echo "找不到 Codex 扩展自带的 codex：扩展没装，或扩展改了目录结构。请改装官方命令行。" >&2; exit 1; }
exec "$BIN" "$@"
EOF
chmod +x ~/bin/codex
```

新开终端后 `codex --version` 能打印版本号即可。扩展升级后转接脚本自动用新版本；不用了 `rm ~/bin/codex` 即可（`uninstall.sh` 不管这个文件）。

## 4. 登录

两个扩展的登录都和各自的命令行共用，在面板里登录一次就行：

- **Claude**：在 VS Code 左侧打开 Claude Code 面板，点 **Sign in**，在浏览器里完成授权（装了命令行的，也可以在终端运行 `claude` 登录）。需要 Pro、Max、Team、Enterprise 或 Console 账号，**免费账号用不了 Claude Code**。
- **ChatGPT / Codex**：打开 Codex 面板，选 **Sign in with ChatGPT**，在浏览器里完成授权（也可以在终端运行 `codex login`）。**扩展和命令行都需要 Plus 及以上**，Free 和 Go 只能用桌面 App。

确认：

```bash
codex login status     # 打印 Logged in using ChatGPT
claude auth status     # 装了 claude 命令行才有：输出里有 "loggedIn": true
```

没装 `claude` 命令行时，终端里核实不了 Claude 的登录，`check.sh` 会给一个黄色提示；在面板里能正常对话就是已登录。

## 5. 终端

macOS 默认的 shell 是 zsh。`install.sh` 会在 `~/.zprofile` 末尾加一行，把 `~/bin` 放进 PATH（`codex-review.sh` 装在那里）。**这一行要新开终端才生效。** 如果你用的是 bash 或别的 shell，请自己把 `~/bin` 加进对应的配置文件。

VS Code 里的集成终端（`` Ctrl+` ``）同样需要重开才会读到新的 PATH。在 Claude Code 面板里让它跑复核时，如果报找不到 `codex-review.sh` 或 `codex`，彻底退出 VS Code（`Cmd+Q`）再打开；只是找不到 `codex-review.sh` 的话，也可以直接写全路径 `~/bin/codex-review.sh`。

## 6. 解释器

钩子脚本要用 `python3` 解析 JSON，`git` 也必须可用。两者都来自 Xcode 命令行工具；如果 `check.sh` 报这两项红，运行：

```bash
xcode-select --install
```

## check.sh 红项长什么样

下面是在一台刚跑完 `install.sh`、还没登录、也还没重开终端的机器上，`check.sh` 的真实输出片段。

**未登录：**

```text
✅ [codex-cli] codex 命令行可用
❌ [codex-login] Codex 未登录
   修法：在 VS Code 的 Codex 面板点 Sign in with ChatGPT（或终端运行 codex login），两边共用同一份登录；需要 Plus 及以上，Free/Go 用不了扩展和命令行
```

**PATH 未生效**（装完没重开终端）：

```text
✅ [review-script] ~/bin/codex-review.sh 存在且可执行
❌ [path] 当前终端的 PATH 里找不到 codex-review.sh（~/bin 没生效）
   修法：新开一个终端窗口；或运行 source ~/.zprofile
```

**命令行没装**（依赖它的登录检查会一起红，先修上一项）：

```text
❌ [codex-cli] codex 命令行不可用（交叉复核脚本要在终端里调用它）
   修法：curl -fsSL https://chatgpt.com/codex/install.sh | sh，然后新开终端
   修法：（备选，非官方）转接 Codex 扩展自带的那份，见 docs/setup-vscode.md 第 3 步
❌ [codex-login] 无法检查登录状态：先修 codex-cli
   修法：先修上一项 codex-cli
```

**钩子还没合进设置：**

```text
❌ [hooks-settings] ~/.claude/settings.json 不存在
   修法：打开 Claude Code 说「把 agent-workflow-starter 的 hooks/settings-snippet.json 合进 ~/.claude/settings.json」
```

全部修好后，最后一行是 `N 项通过，0 项未通过`，退出码 0。`⚠️` 黄色项（`code` 不在 PATH、没有 `timeout`、没装终端里的 `claude`）不影响使用。
