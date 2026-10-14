# 第 0 节：VS Code 初始配置

按顺序做。每一步都有「怎么确认做好了」。卡住了就跑一遍 `./check.sh`，它会告诉你哪一项红、怎么修。

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

## 3. 装两个命令行工具

扩展自带一份给聊天面板用的程序，但**交叉复核脚本要在终端里调用 `codex`，钩子检查要用 `claude`**，所以两个命令行工具也要装。两条都是官方安装命令：

```bash
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

装完**新开一个终端**，确认：

```bash
claude --version
codex --version
```

都打印版本号即可。`claude` 找不到时，按官方说明运行 `claude doctor` 看诊断。

## 4. 登录

- **Claude**：终端运行 `claude`，按提示在浏览器里登录；或者在 VS Code 左侧打开 Claude Code 面板，点 **Sign in**。需要 Pro、Max、Team、Enterprise 或 Console 账号，**免费账号用不了 Claude Code**。
- **ChatGPT / Codex**：终端运行 `codex login`，选 **Sign in with ChatGPT**，在浏览器里完成授权。**命令行和 IDE 扩展需要 Plus 及以上**，Free 和 Go 只能用桌面 App。

确认：

```bash
claude auth status     # 输出里有 "loggedIn": true
codex login status     # 打印 Logged in using ChatGPT
```

## 5. 终端

macOS 默认的 shell 是 zsh。`install.sh` 会在 `~/.zprofile` 末尾加一行，把 `~/bin` 放进 PATH（`codex-review.sh` 装在那里）。**这一行要新开终端才生效。** 如果你用的是 bash 或别的 shell，请自己把 `~/bin` 加进对应的配置文件。

VS Code 里的集成终端（`` Ctrl+` ``）同样需要重开才会读到新的 PATH。

## 6. 解释器

钩子脚本要用 `python3` 解析 JSON，`git` 也必须可用。两者都来自 Xcode 命令行工具；如果 `check.sh` 报这两项红，运行：

```bash
xcode-select --install
```

## check.sh 红项长什么样

下面是在一台刚跑完 `install.sh`、还没登录、也还没重开终端的机器上，`check.sh` 的真实输出片段。

**未登录：**

```text
✅ [claude-cli] claude 命令行可用
❌ [claude-login] Claude Code 未登录
   修法：运行 claude（或在 VS Code 的 Claude Code 面板点 Sign in），用 Pro/Max/Team/Enterprise 账号登录；免费账号不行
```

**PATH 未生效**（装完没重开终端）：

```text
✅ [review-script] ~/bin/codex-review.sh 存在且可执行
❌ [path] 当前终端的 PATH 里找不到 codex-review.sh（~/bin 没生效）
   修法：新开一个终端窗口；或运行 source ~/.zprofile
```

**命令行没装**（依赖它的登录检查会一起红，先修上一项）：

```text
❌ [codex-cli] codex 命令行不可用
   修法：curl -fsSL https://chatgpt.com/codex/install.sh | sh，然后新开终端
❌ [codex-login] 无法检查登录状态：先修 codex-cli
   修法：先修上一项 codex-cli
```

**钩子还没合进设置：**

```text
❌ [hooks-settings] ~/.claude/settings.json 里没有配置这两个钩子
   修法：打开 Claude Code 说「把 agent-workflow-starter 的 hooks/settings-snippet.json 合进 ~/.claude/settings.json」
```

全部修好后，最后一行是 `N 项通过，0 项未通过`，退出码 0。`⚠️` 黄色项（`code` 不在 PATH、没有 `timeout`）不影响使用。
