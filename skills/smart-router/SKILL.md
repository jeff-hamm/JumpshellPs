---
name: smart-router
description: 'Create smart model-routing custom agents (.agent.md) that delegate to subagents with different models based on task complexity, prompt length, or custom criteria. Use for "model router", "smart auto", "custom auto mode", "routing agent", "model switching agent", "agent orchestrator", or any request to build agents that pick different models per task.'
argument-hint: 'scope=[workspace|directory|profile](default:profile) Describe the routing criteria (e.g., "use Opus for long prompts, Sonnet for short ones")'
---
# Smart Router — Build Model-Routing Custom Agents

Create `agent.md` orchestrator + worker agents that route requests to different models based on configurable criteria.

## When to Use

- User wants a "custom auto mode" that picks models based on prompt complexity, length, or topic
- User wants an orchestrator agent that delegates to subagents with different model tiers
- User needs to set up coordinator/worker patterns with model overrides
- User asks about routing requests to different models programmatically

## Prerequisites & References

- **`/agent-customization` skill** — Use this built-in skill for creating/editing `.agent.md` files, YAML frontmatter syntax, and troubleshooting agent detection issues. Invoke it when you need to validate frontmatter or debug why an agent isn't appearing.
- **VS Code custom agents docs** — https://code.visualstudio.com/docs/copilot/customization/custom-agents
- **VS Code subagents docs** — https://code.visualstudio.com/docs/copilot/agents/subagents

## Critical Constraints

### `model` frontmatter is `.agent.md` ONLY

The `model` property in YAML frontmatter is supported **only** in `.agent.md` custom agent files.

| File type | `model` frontmatter | `tools` frontmatter | Notes |
|-----------|---------------------|---------------------|-------|
| `.agent.md` | **Yes** | Yes | Full routing support |

**Cursor compatibility note:** Cursor uses `.cursorrules` and its own agent format. The `.agent.md` `model` frontmatter is a VS Code / GitHub Copilot feature. For cross-editor compatibility, the routing logic can live in a `.instructions.md` that *describes* the routing behavior in natural language (the LLM follows the instructions), but the actual model pinning requires `.agent.md` files. See the "Cursor-Compatible Fallback" section below.

### Required settings

Ensure these are enabled for subagent model routing to work:

```json
{
  "chat.customAgentInSubagent.enabled": true,
  "chat.agent.enabled": true
}
```

## Workflow

### 1. Gather routing criteria

Ask the user (or infer from the prompt) what criteria should determine model selection. Common patterns:

| Criteria | Example |
|----------|---------|
| Prompt length | < 100 chars → fast model, ≥ 100 chars → powerful model |
| Task type | Research/read-only → fast, editing/implementation → powerful |
| Keyword triggers | "quick", "simple" → fast; "thorough", "complex" → powerful |
| Explicit tier | User says `/high` or `/fast` in prompt |

### 2. Choose the agent file location

Use the `/agent-customization` skill's conventions for file placement:

| Scope | Path |
|-------|------|
| Workspace | For vscode, use `.agents/agents/<name>.agent.md`, for cursor use `.cursor/agents/<name>.md` (no model support) otherwise create/modify a root level `AGENTS.md` |
| Directory | Determine the most likely directory based on context and prompt and create an `AGENTS.md` file there |
| User profile | If `~/.copilot/agents/<name>.agent.md` |
| Cursor-compatible workspace |  |

### 3. Create the orchestrator agent

The orchestrator is the user-facing agent. It:
- Appears in the agents dropdown
- Reads the user's prompt
- Decides which worker subagent to delegate to
- Returns the subagent's result

**Template:**

```markdown
---
name: <router-name>
description: <one-line description of routing behavior>
tools: ['agent', 'read', 'search', 'edit', 'fetch']
agents: ['<worker-1>', '<worker-2>']
model: <default-model, e.g. Claude Sonnet 4.6 (copilot)>
---

You are a task router. Analyze each incoming request and delegate to the
appropriate worker agent:

<ROUTING RULES — filled from step 1>

**Rules:**
- Always delegate — never answer directly.
- Pass the full user prompt to the chosen worker.
- If the task is ambiguous, default to <worker-1>.
```

### 4. Create the worker agents

Each worker gets its own `.agent.md` with a pinned model and optionally restricted tools.

**Template:**

```markdown
---
name: <worker-name>
user-invocable: false
model: <pinned model name, e.g. Claude Opus 4.6 (copilot)>
tools: ['read', 'search', 'edit']
---

<Worker-specific instructions>
```

Key properties:
- `user-invocable: false` — hides the worker from the agents dropdown
- `model` — accepts a string or a prioritized array: `['Claude Opus 4.6 (copilot)', 'GPT-4o (copilot)']`
- `disable-model-invocation: true` — optional, prevents other agents from using this worker

### 5. Validate

After creating the files:

1. Reload VS Code (or let agent detection pick up the new files)
2. Check the agents dropdown — the orchestrator should appear, workers should NOT
3. Test routing by sending prompts of different complexities
4. Use the chat customization diagnostics view: right-click in Chat → Diagnostics

## Example: Complexity Router

### `.github/agents/smart-auto.agent.md`
```markdown
---
name: smart-auto
description: Routes to the best model based on task complexity
tools: ['agent', 'read', 'search', 'edit', 'fetch']
agents: ['deep-thinker', 'fast-responder']
model: Claude Sonnet 4.6 (copilot)
---

You are a smart task router. For every incoming request:

**Route to deep-thinker when:**
- The prompt is longer than 100 characters with substantial technical detail
- The task involves multi-file changes, architecture decisions, or debugging
- Keywords: "thorough", "analyze", "refactor", "debug", "architect", "complex"
- The user references multiple files or asks for a plan

**Route to fast-responder when:**
- The prompt is short and straightforward (< 100 characters)
- The task is a simple lookup, quick fix, or single-file change
- Keywords: "quick", "simple", "what is", "how do I", "list"

Always delegate. Never answer directly. Pass the full user prompt.
```

### `.github/agents/deep-thinker.agent.md`
```markdown
---
name: deep-thinker
user-invocable: false
model: ['Claude Opus 4.6 (copilot)', 'o4-mini (copilot)']
tools: ['read', 'search', 'edit', 'fetch', 'agent']
---

You handle complex, multi-step tasks that benefit from deep reasoning.
Take your time, plan thoroughly, and produce high-quality results.
```

### `.github/agents/fast-responder.agent.md`
```markdown
---
name: fast-responder
user-invocable: false
model: ['Claude Sonnet 4.6 (copilot)', 'GPT-4o (copilot)']
tools: ['read', 'search', 'edit']
---

You handle straightforward tasks quickly and efficiently.
Be concise and direct.
```

## Cursor-Compatible Fallback

For projects that need to work in both VS Code and Cursor, create a `.cursorrules` file that describes routing behavior in natural language. The LLM will follow the rules but **cannot** enforce model pinning — it's a best-effort approach:

```markdown
# Model Routing Guidance

When delegating to subagents, consider the following routing preferences:
- For complex tasks (multi-file edits, architecture, debugging): prefer using
  higher-capability models when available
- For simple tasks (lookups, single-file fixes, short answers): prefer using
  faster, more cost-effective models when available

Note: Actual model selection depends on the agent framework's capabilities.
In VS Code, use .agent.md files with the `model` frontmatter property for
enforceable model routing.
```

This is non-binding — the agent will read it as guidance but cannot programmatically switch models without `.agent.md` support.

## Advanced: Copilot CLI / ai-backends routing

For tasks delegated outside VS Code (terminal-based workflows), use the `ai_backends` Python package to enforce model routing:

```python
import ai_backends

cache = ai_backends.ensure_registry()

# Route based on prompt length
prompt = "..."
if len(prompt) > 200:
    backend, model = ai_backends.resolve_quality("high", cache)
else:
    backend, model = ai_backends.resolve_quality("fast", cache)

result = ai_backends.call_backend(backend, prompt, model=model)
```

See the `agent-script` skill for building complete terminal-based AI scripts with `ai_backends`.
