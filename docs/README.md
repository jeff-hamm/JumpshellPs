# Jumpshell Documentation

This folder is the primary documentation set for the refactored Jumpshell repository.

## Jekyll Site

Docs are now configured as a Jekyll site using a clean dark Just the Docs theme.
Navigation is generated automatically from Markdown pages with front matter.

Run locally from `docs`:

```powershell
bundle install
bundle exec jekyll serve
```

Then open `http://127.0.0.1:4000`.

## GitHub Pages Deployment

GitHub Actions workflow: `.github/workflows/docs-pages.yml`

Behavior:

- Builds Jekyll from `docs`
- Uses dark Just the Docs theme configuration from `docs/_config.yml`
- Deploys to GitHub Pages automatically on push to `main` or `master` when docs change

One-time repo setting:

1. Open repository Settings -> Pages.
2. Set Build and deployment Source to `GitHub Actions`.

## Start Here

1. Read [../README.md](../README.md) for repository-level onboarding.
2. Read [pwsh/Repository-Layout.md](pwsh/Repository-Layout.md) to understand where everything moved.
3. Read [pwsh/PowerShell-Module.md](pwsh/PowerShell-Module.md) for module entrypoints, load flow, and install/update behavior.
4. Read [extension/VSCode-Extension.md](extension/VSCode-Extension.md) for extension behavior, settings, packaging, and install workflows.
5. Read [pwsh/MCP-Server.md](pwsh/MCP-Server.md) for MCP architecture and operational commands.
6. Read [ai/AI-Backends.md](ai/AI-Backends.md) for Python backend architecture and integration.

## Subdirectories

- `docs/extension`: VS Code/Cursor extension and workspace/chat tooling docs
- `docs/pwsh`: PowerShell module and MCP architecture docs
- `docs/ai`: Python AI backend docs

## Documentation Map

| File | Focus |
|---|---|
| [pwsh/Repository-Layout.md](pwsh/Repository-Layout.md) | Canonical repository structure and old-to-new path mapping after refactor |
| [pwsh/PowerShell-Module.md](pwsh/PowerShell-Module.md) | Root shims, source module internals, dependency install/update flows |
| [pwsh/MCP-Server.md](pwsh/MCP-Server.md) | MCP server lifecycle, config template, logs, troubleshooting |
| [extension/VSCode-Extension.md](extension/VSCode-Extension.md) | VS Code/Cursor extension commands, settings, skill sync, MCP config install |
| [extension/VSCode-ChatSessions.md](extension/VSCode-ChatSessions.md) | Chat session and edit-session analysis functions |
| [extension/VSCode-WorkspaceManagement.md](extension/VSCode-WorkspaceManagement.md) | Profile detection, workspace storage, and layout export/apply |
| [extension/VSCode-QuickReference.md](extension/VSCode-QuickReference.md) | Copy/paste command reference |
| [ai/AI-Backends.md](ai/AI-Backends.md) | AI backend package architecture, install, and usage |

## Scope Notes

- Root-level `Jumpshell.psd1` and `Jumpshell.psm1` are compatibility shims.
- Canonical PowerShell implementation now lives in `src/pwsh`.
- Canonical MCP scripts now live in `src/pwsh/mcp`.
- Extension MCP template lives at `mcps/jumpshell.json` and is bundled into extension assets.
- Root-level `Install.ps1` is now extension-focused and delegates to `extensions/Install.ps1`.
