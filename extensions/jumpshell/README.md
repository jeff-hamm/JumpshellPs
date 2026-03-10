# Jumpshell

**Jumpshell** is a PowerShell module, MCP server, set of AI skills, and Python AI backend library — packaged together and delivered via a VS Code / Cursor extension.

📖 **[Full documentation →](https://jeff-hamm.github.io/jumpshell/)**

---

## Components

### AI Skills

A curated pack of **GitHub Copilot agent customization files** (`.instructions.md`, `.prompt.md`, `SKILL.md`) installed into `~/.agents/skills` where VS Code Copilot picks them up automatically.

| Skill | Description |
|---|---|
| `agent-script` | Create terminal-based AI scripts using the `ai_backends` module |
| `git-workflow` | Consistent branch/worktree discipline and commit message quality |
| `ocr-scan` | OCR images and scans to Markdown across 7 backends |
| `pdf-to-md` | Convert PDFs to clean Markdown |
| `reasoning` | Toggle Copilot Responses API reasoning effort |
| `setting` | Edit VS Code/Cursor settings with scope-aware targeting |
| `rule` | Create and manage instruction/rules files |
| `jumpdate` | Refresh instructions and skills from the remote repo |
| `smart-router` | Route agent tasks to the best model |

Skills are installed to `~/.agents/skills` (configurable via `jumpshell.skillsPath`).

📖 [Skills & Customization docs →](https://jeff-hamm.github.io/jumpshell/)

---

### MCP Server

A **Model Context Protocol server** (`jumpshellps`) backed by the Jumpshell PowerShell module. Once configured, Copilot agents can call shell utilities, file-system helpers, and module commands directly.

**Setup options:**

- **Extension command:** `Jumpshell: Install MCP Configuration`
- **Module command:** `Install-JumpshellMcp -Scope User`
- **Direct script:** `pwsh ./src/pwsh/mcp/Install-Mcp.ps1 -Scope User`

MCP config is written to your `mcp.json` (user or workspace scope, controlled by `jumpshell.mcpConfigScope`).

**Runtime commands:**

```powershell
Get-JumpshellMcp
Start-JumpshellMcpServer
Stop-JumpshellMcpServer -Force
```

📖 [MCP Server docs →](https://jeff-hamm.github.io/jumpshell/pwsh/MCP-Server)

---

### AI Backends (`ai-backends` / `ai-cli`)

A **Python multi-LLM backend library** with a unified `ai-cli` CLI supporting six providers:

| Backend | Type |
|---|---|
| `gemini` | API (free tier) |
| `openai` | API (paid) |
| `anthropic` | API (paid) |
| `github-api` | API (free tier) |
| `copilot-cli` | CLI (subscription) |
| `cursor` | CLI (subscription) |

**Install:**

```bash
pip install -e ./src/python/ai-backends
# or from GitHub
pip install git+https://github.com/jeff-hamm/jumpshell.git#subdirectory=src/python/ai-backends
```

**Quick usage:**

```python
import ai_backends

cache = ai_backends.ensure_registry()
backend, model = ai_backends.resolve_quality("normal", cache)
text = ai_backends.call_backend(backend, "Summarize this", model=model)
```

The extension installs/updates `ai-backends` automatically alongside skills when `jumpshell.installAiBackendsOnSkillsInstall` is `true`.

📖 [AI Backends docs →](https://jeff-hamm.github.io/jumpshell/ai/AI-Backends)

---

### PowerShell Module

The **JumpshellPs** PowerShell module provides shell utilities, directory helpers, Git integration, Kubernetes shortcuts, SSH helpers, and MCP server hosting.

**Import:**

```powershell
# From repo checkout
Import-Module .\Jumpshell.psd1 -Force

# Once installed
Import-Module Jumpshell -Force
```

The module installer adds `Import-Module Jumpshell -Force` to your `$PROFILE` and optionally installs skills, applications, and MCP configuration:

```powershell
pwsh ./src/pwsh/Install.ps1 -Skills -Modules -Applications -Mcps
```

📖 [PowerShell Module docs →](https://jeff-hamm.github.io/jumpshell/pwsh/PowerShell-Module)

---

## VS Code Extension

The extension is a delivery vehicle for the components above. On first install the **Setup / Configure Jumpshell** wizard opens automatically, pre-selecting anything not yet installed.

### Commands

| Command | Description |
|---|---|
| `Jumpshell: Setup / Configure Jumpshell` | Check all components; install or configure anything missing |
| `Jumpshell: Update Jumpshell` | Pull latest from git and refresh all installed components |
| `Jumpshell: Select Chat Model` | Pick the active Copilot chat model |
| `Jumpshell: Assign Model Hotkey` | Bind a keyboard shortcut to a specific model |

### Configuration

| Setting | Default | Description |
|---|---|---|
| `jumpshell.skillsPath` | `~/.agents/skills` | Target directory for managed skills |
| `jumpshell.installMcpOnSkillsInstall` | `false` | Also install MCP config when skills are installed |
| `jumpshell.installAiBackendsOnSkillsInstall` | `true` | Also install ai-backends when skills are installed |
| `jumpshell.mcpConfigScope` | `user` | Write MCP config to `user` or `workspace` |
| `jumpshell.moduleRootPath` | _(auto)_ | Explicit Jumpshell module root path or repo root |
| `jumpshell.extensionReleaseRepo` | `jeff-hamm/jumpshell` | GitHub repo slug for update checks |
| `jumpshell.includePreReleaseUpdates` | `false` | Include pre-release tags in update checks |

---

📖 **[Full documentation →](https://jeff-hamm.github.io/jumpshell/)**

