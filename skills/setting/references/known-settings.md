# Known VS Code / Cursor Setting Keys

This file is maintained by the `setting` skill. When the slow-path discovery finds a new key
that is broadly useful, add a row here so future lookups are instant.

**Format:** `| natural-language description(s) | dot-notation key | allowed values / type |`

## Copilot

| Description | Setting key | Allowed values |
|---|---|---|
| reasoning effort / thinking effort | `github.copilot.chat.responsesApiReasoningEffort` | `default` `low` `medium` `high` `xhigh` |
| copilot chat model / default model | `github.copilot.chat.defaultModel` | model ID string |

## Editor

| Description | Setting key | Allowed values |
|---|---|---|
| editor font size | `editor.fontSize` | number |
| editor tab size / indent size | `editor.tabSize` | number |
| word wrap | `editor.wordWrap` | `off` `on` `wordWrapColumn` `bounded` |
| format on save | `editor.formatOnSave` | `true` / `false` |
| auto save | `files.autoSave` | `off` `afterDelay` `onFocusChange` `onWindowChange` |

## Terminal

| Description | Setting key | Allowed values |
|---|---|---|
| terminal font size | `terminal.integrated.fontSize` | number |
