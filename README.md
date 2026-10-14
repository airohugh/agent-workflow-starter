# agent-workflow-starter

**前提：一个 Claude 付费账号（Pro / Max / Team / Enterprise）和一个 ChatGPT 付费账号（Plus 及以上），各一个。两边的免费账号都用不了本仓库依赖的命令行工具。**

> **English summary.** A starter kit for a two-vendor workflow inside VS Code: Claude Code does the work, OpenAI Codex does a read-only cross-review, so hallucinations get caught by a model that doesn't share the same blind spots. It ships a vendor-neutral rule file for each tool, a one-command review script with the three flags people always forget, two small Claude Code hooks, and templates. macOS only (verified); Windows is untested. Body text is in Chinese. Requires a paid Claude plan and a paid ChatGPT plan (Plus or above).

验证于 2026-10：macOS，Claude Code 2.1.292，Codex CLI 0.162。

## 这是什么

在 VS Code 里用一个壳、两家模型：

- **Claude Code** 主做：写分析、写方案、写代码。
- **Codex**（OpenAI）做**只读交叉复核**：它看不到你们的对话，只看成品和原始材料，专门挑错。

一家模型回头检查自己，会沿着同一条思路再走一遍，同源的错看不出来。换一家来审，错的地方不太会重合。原理与边界见 [docs/principles.md](docs/principles.md)。

## 装好之后你得到什么

| 东西 | 装到哪 | 干什么 |
|---|---|---|
| `rules/CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude Code 的全局行为准则：先想再写、精简、跑过才算验证、交叉复核怎么用、收尾怎么交 |
| `rules/AGENTS.md` | `~/.codex/AGENTS.md` | Codex 的全局约定：做复核时怎么报、凭据纪律、语言 |
| `scripts/codex-review.sh` | `~/bin/codex-review.sh` | 一条命令发起一轮只读复核 |
| `hooks/unpushed-reminder.sh` | `~/.claude/hooks/` | 开会话时，当前仓库未推送的提交攒多了就提醒 |
| `hooks/git-status-after-add.sh` | `~/.claude/hooks/` | Claude 每次 `git add` / `git commit` 后，自动把 `git status` 给它看，防止漏加、错加 |
| `templates/` | 留在仓库 | 五格决策卡、任务三件套、会话总结 |

已有的 `~/.claude/CLAUDE.md` 与 `~/.codex/AGENTS.md` 会先备份成带日期的副本再覆盖，安装输出会告诉你备份在哪。想把你原来的规则留着，装完后把备份里要的部分贴回去即可。

## 上手（约 40 分钟，其中手动约 15 分钟，都是点击和登录）

| 步 | 做什么 | 怎么做 |
|---|---|---|
| 1 | 装 VS Code | <https://code.visualstudio.com> 下载，拖进「应用程序」 |
| 2 | 装两个扩展：Claude Code、Codex | `install.sh` 会替你装（需要 `code` 命令在 PATH 里）；否则按 [docs/setup-vscode.md](docs/setup-vscode.md) 第 2 步点链接 |
| 3 | 装两个命令行工具 | `curl -fsSL https://claude.ai/install.sh \| bash` 和 `curl -fsSL https://chatgpt.com/codex/install.sh \| sh`，装完新开终端 |
| 4 | 登录 | 终端运行 `claude` 按提示登录；运行 `codex login` 选 Sign in with ChatGPT |
| 5 | 拿到本仓库 | `git clone <本仓库地址> ~/agent-workflow-starter && cd ~/agent-workflow-starter` |
| 6 | 安装 | `./install.sh` |
| 7 | 自检 | **新开一个终端**，`cd ~/agent-workflow-starter && ./check.sh`，看到全绿 |
| 8 | 合并钩子配置 | 在 VS Code 里打开 Claude Code，说一句：「把 ~/agent-workflow-starter/hooks/settings-snippet.json 合进 ~/.claude/settings.json」。合并后再跑一次 `./check.sh` |
| 9 | 第一次真用 | 见下一节 |

每一步卡住都可以先跑 `./check.sh`：每个红项下面都写了修法。各项的详细说明与红项截图见 [docs/setup-vscode.md](docs/setup-vscode.md)。

## 第一次真用：拿一份自己的分析跑一轮交叉复核

1. 在 Claude Code 里，让它基于你手上的一份材料（报表、研报、合同都行）写一份分析，存成 `analysis.md`。
2. 建一个只放送审文件的临时目录，把分析和原始材料复制进去：

   ```bash
   mkdir -p /tmp/review-1 && cp analysis.md 原始材料.pdf /tmp/review-1/
   ```

3. 写 `/tmp/review-1/prompt.md`，比如：

   ```text
   请复核 analysis.md。它基于 原始材料.pdf 写成。
   找出：与原文不符的数字或事实、没有出处的数字、推理跳跃、自相矛盾、遗漏的重要情况。
   按严重度从高到低列出，每条写：问题、证据位置（文件与页码或原文句子）、建议怎么改。
   能核实的请自己核对原文；核实不了的说明原因。
   ```

4. 跑：

   ```bash
   cd /tmp/review-1 && codex-review.sh prompt.md report.md
   ```

5. 把 `report.md` **完整**交给 Claude Code，让它逐条判断：哪些是真问题（照改）、哪些是复核方看不到证据（不删内容）、哪些是复核方自己错了（驳回并写理由）。改完再审一轮，直到新的发现不再来自上一轮的修改。

完整做法、三个必踩的坑、什么时候停，见 [docs/cross-review.md](docs/cross-review.md)。

## 卸载

```bash
cd ~/agent-workflow-starter && ./uninstall.sh
```

它会把装之前就存在的文件还原、删掉本仓库装上去的文件、从 `~/.zprofile` 删掉那一行 PATH。备份文件保留，路径会打印出来。合进 `settings.json` 的钩子段需要手动删（或让 Claude Code 删），VS Code 扩展需要手动卸载，卸载脚本最后会提示。

## 文档

- [docs/setup-vscode.md](docs/setup-vscode.md)：VS Code 初始配置，逐步确认，红项长什么样
- [docs/cross-review.md](docs/cross-review.md)：交叉复核怎么跑、三个坑、怎么判复核意见、什么时候停
- [docs/principles.md](docs/principles.md)：为什么多家互审能压幻觉，边界在哪
- [docs/dont-copy.md](docs/dont-copy.md)：原工作流里还有哪些东西没放进来，只讲思路
- [docs/windows.md](docs/windows.md)：Windows（未验证）

## 已知限制

- 只在 macOS 上验证过。Windows 见 [docs/windows.md](docs/windows.md)。
- `install.sh` 只往 `~/.zprofile`（zsh）加 PATH；用别的 shell 要自己加 `~/bin`。
- 每轮复核都会消耗 ChatGPT 账户的用量，撞到上限时要等几个小时恢复。

## 许可

MIT，见 [LICENSE](LICENSE)。
