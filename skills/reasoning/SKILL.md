---
name: reasoning
description: 'Set or toggle Copilot Responses API reasoning effort. Use for "reasoning effort", "toggle reasoning", or "set effort" or "set reasoning".'
argument-hint: 'effort=[default|low|medium|high|xhigh](optional),scope=[workspace|profile|global](default:profile)'
---
## Scripts
- `./scripts/run.ps1`, -  Executes the main task.

## Workflow
1. Run the script with the appropriate scope and effort level arguments.
    ```
    ./scripts/run.ps1 -Scope <scope> -Effort <effort>
    ```
2. If `effort` is omitted, the script reads the current value and toggles between `default` and `high`.
3. The script directly updates only `github.copilot.chat.responsesApiReasoningEffort` in the resolved `settings.json` target.
