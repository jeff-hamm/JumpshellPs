# JumpShell

A VS Code extension that delivers the full **JumpShell** toolchain directly into your editor — AI skills, an MCP server, multi-LLM Python backends, and the JumpShell PowerShell module.

📖 **[Full documentation →](https://jeff-hamm.github.io/jumpshell/)**

---

## Features

### AI Skills (`~/.agents/skills`)

JumpShell bundles a curated pack of **GitHub Copilot agent customization files** — `.instructions.md`, `.prompt.md`, and `SKILL.md` workflows — installed directly into `~/.agents/skills` where VS Code Copilot picks them up automatically.

- **Install Skills** — copies all bundled skills into `~/.agents/skills` (prompts on conflicts)
- **Update Skills** — syncs bundled skills, updating only files whose content has changed
- Skills are tracked by the extension; only extension-managed files are removed on uninstall

Included skills cover: `git-workflow`, `agent-script`, `ocr-scan`, `pdf-to-md`, `reasoning`, `setting`, `rule`, `jumpdate`, and more.

### MCP Server

JumpShell ships a **Model Context Protocol server** (`jumpshellps`) backed by the JumpShell PowerShell module, giving Copilot access to shell utilities, file system helpers, and module commands.

- **Install MCP Configuration** — writes the `jumpshellps` entry into your `mcp.json` (user or workspace scope)
- Auto-detects the JumpShell module path; falls back to explicit `jumpshell.moduleRootPath` setting

### AI Backends (`ai-backends` / `ai-cli`)

A **Python multi-LLM backend library** with a unified CLI (`ai-cli`) supporting OpenAI, Anthropic, Gemini, and more. The package is bundled inside the extension and installed automatically when you install skills.

- **Install AI Backends** — runs `pip install --user` from the bundled package
- **Configure AI Backends** — runs `ai-cli --configure` in a terminal to set API keys
- Optional extras: `pip install ai-backends[openai]`, `[anthropic]`, `[gemini]`
- Auto-installed on skills install when `jumpshell.installAiBackendsOnSkillsInstall` is enabled (default)

### PowerShell Module

The **JumpShellPs** PowerShell module provides shell utilities, directory helpers, Git integration, Kubernetes shortcuts, MCP server hosting, and more. The module source is bundled in the extension.

- **Install PowerShell Module** — adds `Import-Module Jumpshell -Force` to your `$PROFILE` and runs `Install.ps1`

---

## Commands

| Command | Description |
|---|---|
| `JumpShell: Setup / Configure JumpShell` | Check all components and install/configure what's needed |
| `JumpShell: Update JumpShell` | Pull latest from git repo and refresh all installed components |
| `JumpShell: Select Chat Model` | Pick the active Copilot chat model |
| `JumpShell: Assign Model Hotkey` | Bind a keyboard shortcut to a specific model |

---

## Configuration

| Setting | Default | Description |
|---|---|---|
| `jumpshell.skillsPath` | `~/.agents/skills` | Target directory for managed skills |
| `jumpshell.installMcpOnSkillsInstall` | `false` | Also install MCP config when skills are installed |
| `jumpshell.installAiBackendsOnSkillsInstall` | `true` | Also install ai-backends when skills are installed |
| `jumpshell.mcpConfigScope` | `user` | Write MCP config to `user` or `workspace` |
| `jumpshell.moduleRootPath` | _(auto)_ | Explicit JumpShell module root path |
| `jumpshell.extensionReleaseRepo` | `jeff-hamm/jumpshell` | GitHub repo slug for update checks |
| `jumpshell.includePreReleaseUpdates` | `false` | Include pre-release tags in update checks |

---

📖 **[Full documentation →](https://jeff-hamm.github.io/jumpshell/)**

## Development

```bash
npm install
npm run build
```

`npm run build` does two things:

1. Copies the repository's top-level `skills/` folder into `assets/skills/`.
2. Compiles the extension from `src/` to `dist/`.

For local extension-host development, the extension can install directly from the repo's `skills/` folder even before `assets/skills/` exists.

## Packaging

```bash
npm run package
```

`vsce` will run `npm run build` through `vscode:prepublish`, so the packaged VSIX includes the current skill bundle.

## GitHub VSIX Updates

If JumpShell is installed from a VSIX instead of the VS Code Marketplace, run `JumpShell: Check GitHub VSIX Updates`.

The command will:

1. Query the configured GitHub releases repository.
2. Compare the newest release tag with the currently installed extension version.
3. Download the newest `.vsix` asset and install it when a newer version is available.
