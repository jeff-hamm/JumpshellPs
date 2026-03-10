/**
 * modelPicker.ts — Experimental model-picker automation for Jumpshell.
 *
 * Registers commands that attempt to switch the active Copilot Chat model
 * either via the Language Model API or via SendKeys-style UI automation.
 *
 * ┌──────────────────────────────────────────────────────────────────────┐
 * │ BRITTLENESS WARNING — parts of this file rely on internal commands  │
 * │ and UI timing that may break across VS Code releases.               │
 * │ Run `scripts/Rebuild-ModelPicker.ps1` to have an agent validate    │
 * │ and patch this file against the current VS Code version.            │
 * └──────────────────────────────────────────────────────────────────────┘
 *
 * API check note (2025-06):
 *   There is NO public VS Code extension API to set the active chat model
 *   or create/send to chat sessions programmatically. `vscode.lm.selectChatModels()`
 *   is read-only (enumerates models for extension use). `vscode.chat` only
 *   exposes `createChatParticipant()`. All model-switching and chat-session
 *   creation relies on internal workbench/Copilot commands below.
 */
import * as vscode from 'vscode';

// ─── Shared helpers ─────────────────────────────────────────────────────────

/**
 * BRITTLE — Delay in ms between opening the model picker and injecting
 * keystrokes. Too short = the quick-pick hasn't rendered yet and the
 * type command goes nowhere. Too long = user sees a flash of empty UI.
 * Tune this if model selection fails silently on slow machines.
 */
const MODEL_PICKER_OPEN_DELAY_MS = 350;

function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/** Resolve a model name/id/family string to the label the UI picker expects. */
async function resolveModelLabel(
  modelNameOrId: string,
  outputChannel: vscode.OutputChannel
): Promise<{ label: string; validated: boolean }> {
  try {
    const available = await vscode.lm.selectChatModels();
    const lower = modelNameOrId.toLowerCase();
    const match = available.find(
      m => m.id.toLowerCase() === lower
        || m.name.toLowerCase() === lower
        || m.family.toLowerCase() === lower
        || m.name.toLowerCase().includes(lower)
        || m.id.toLowerCase().includes(lower)
        || m.family.toLowerCase().includes(lower)
    );
    if (match) {
      outputChannel.appendLine(`[model-picker] Resolved "${modelNameOrId}" → ${match.name} (${match.id})`);
      return { label: match.name, validated: true };
    }
  } catch { /* LM API unavailable – fall through */ }

  if (modelNameOrId.toLowerCase() === 'auto') {
    return { label: 'Auto', validated: true };
  }
  outputChannel.appendLine(
    `[model-picker] Warning: "${modelNameOrId}" not found in LM API. ` +
    `Proceeding with UI automation using it as-is.`
  );
  return { label: modelNameOrId, validated: false };
}

/** Build QuickPick items from the Language Model API. */
async function buildModelQuickPickItems(): Promise<vscode.QuickPickItem[]> {
  const models = await vscode.lm.selectChatModels();
  const items: vscode.QuickPickItem[] = [
    { label: 'Auto', description: 'Let Copilot choose', detail: 'id: auto' }
  ];
  for (const m of models) {
    items.push({
      label: m.name,
      description: m.family,
      detail: `id: ${m.id} · max tokens: ${m.maxInputTokens}`
    });
  }
  return items;
}

// ─── Public activation entry point ──────────────────────────────────────────

/**
 * Call from the main extension `activate()` to register model-picker commands.
 */
export function registerModelPickerCommands(
  context: vscode.ExtensionContext,
  outputChannel: vscode.OutputChannel
): void {
  context.subscriptions.push(
    vscode.commands.registerCommand(
      'jumpshell.selectModel',
      (modelNameOrId?: string) => selectModelFlow(modelNameOrId, outputChannel)
    )
  );

  context.subscriptions.push(
    vscode.commands.registerCommand(
      'jumpshell.listModels',
      () => listCopilotModels(outputChannel)
    )
  );

  context.subscriptions.push(
    vscode.commands.registerCommand(
      'jumpshell.sendPromptTo',
      (args?: { model?: string; prompt?: string }) =>
        sendPromptToFlow(args?.model, args?.prompt, outputChannel)
    )
  );
}

// ─── selectModel ────────────────────────────────────────────────────────────

/**
 * Attempt to switch the active chat model.
 *
 * Accepts a model display name, model id, or model family string.
 * When called with no argument, shows a dropdown of available models.
 *
 * ╔═══════════════════════════════════════════════════════════════════════╗
 * ║ BRITTLE — UI automation depends on:                                 ║
 * ║  • 'github.copilot.chat.openModelPicker' (internal Copilot cmd)    ║
 * ║  • 'type' command (injects keystrokes into focused input)           ║
 * ║  • 'workbench.action.acceptSelectedQuickOpenItem' (confirms pick)   ║
 * ║  • Fixed delays for QuickPick rendering                             ║
 * ╚═══════════════════════════════════════════════════════════════════════╝
 */
async function selectModelFlow(
  modelNameOrId: string | undefined,
  outputChannel: vscode.OutputChannel
): Promise<void> {
  // If no arg, show a dropdown instead of a free-text box
  if (!modelNameOrId) {
    try {
      const items = await buildModelQuickPickItems();
      const picked = await vscode.window.showQuickPick(items, {
        title: 'Select a Chat Model',
        placeHolder: 'Choose a model to switch to'
      });
      if (!picked) { return; }
      modelNameOrId = picked.label;
    } catch (err) {
      outputChannel.appendLine(`[model-picker] Failed to build model list: ${err}`);
      return;
    }
  }

  outputChannel.appendLine(`[model-picker] Attempting to select model: ${modelNameOrId}`);

  // Resolve the input (could be id, family, or name) to the display label
  const { label } = await resolveModelLabel(modelNameOrId, outputChannel);

  await automateModelPicker(label, outputChannel);
}

// ─── sendPromptTo ───────────────────────────────────────────────────────────

/**
 * Open a new chat session, select a model, and send a prompt.
 *
 * Prompt sources (in priority order):
 *   1. Explicit `prompt` argument
 *   2. Active editor selection
 *   3. User input box
 *
 * ╔═══════════════════════════════════════════════════════════════════════╗
 * ║ BRITTLE — In addition to the model-picker automation, this uses:   ║
 * ║  • 'workbench.action.chat.newChat' — internal workbench command    ║
 * ║    that opens a fresh chat session. May be renamed or removed.      ║
 * ║  • 'workbench.action.chat.open' with { query } — sends a prompt   ║
 * ║    into the active chat input. Argument shape is undocumented.      ║
 * ╚═══════════════════════════════════════════════════════════════════════╝
 */
async function sendPromptToFlow(
  model: string | undefined,
  prompt: string | undefined,
  outputChannel: vscode.OutputChannel
): Promise<void> {
  // ── 1. Resolve the model ──────────────────────────────────────────
  if (!model) {
    try {
      const items = await buildModelQuickPickItems();
      const picked = await vscode.window.showQuickPick(items, {
        title: 'Send Prompt To — Select Model',
        placeHolder: 'Choose a model for the new chat session'
      });
      if (!picked) { return; }
      model = picked.label;
    } catch (err) {
      outputChannel.appendLine(`[sendPromptTo] Failed to build model list: ${err}`);
      return;
    }
  }

  // ── 2. Resolve the prompt text ────────────────────────────────────
  if (!prompt) {
    const editor = vscode.window.activeTextEditor;
    const selection = editor?.selection;
    if (editor && selection && !selection.isEmpty) {
      prompt = editor.document.getText(selection);
    }
  }
  if (!prompt) {
    prompt = await vscode.window.showInputBox({
      prompt: 'Enter the prompt to send',
      placeHolder: 'Ask something…'
    });
  }
  if (!prompt) { return; }

  outputChannel.appendLine(`[sendPromptTo] Model: ${model}, Prompt length: ${prompt.length}`);

  // ── 3. Open a new chat session ────────────────────────────────────
  // BRITTLE — 'workbench.action.chat.newChat' is an internal command
  try {
    await vscode.commands.executeCommand('workbench.action.chat.newChat');
  } catch (err) {
    const msg = `Failed to open new chat session: ${err}`;
    outputChannel.appendLine(`[sendPromptTo] ${msg}`);
    void vscode.window.showErrorMessage(`Jumpshell: ${msg}`);
    return;
  }

  // Small delay for the chat panel to initialize
  await delay(300);

  // ── 4. Select the model via picker automation ─────────────────────
  const { label } = await resolveModelLabel(model, outputChannel);
  await automateModelPicker(label, outputChannel);

  // Wait for model selection to settle
  await delay(400);

  // ── 5. Send the prompt into the chat input ────────────────────────
  // BRITTLE — 'workbench.action.chat.open' with a { query } arg sends
  // text into the chat input. The argument shape is undocumented.
  try {
    await vscode.commands.executeCommand('workbench.action.chat.open', {
      query: prompt,
      isPartialQuery: false
    });
    outputChannel.appendLine(`[sendPromptTo] Prompt submitted to "${label}"`);
  } catch (err) {
    outputChannel.appendLine(`[sendPromptTo] chat.open with query failed: ${err}. Falling back to type command.`);
    // Fallback: focus the chat input and type
    try {
      await vscode.commands.executeCommand('workbench.action.chat.open');
      await delay(300);
      await vscode.commands.executeCommand('type', { text: prompt });
      await delay(100);
      // BRITTLE — submit with Enter via the 'default:enter' keybinding
      await vscode.commands.executeCommand('workbench.action.chat.submit');
      outputChannel.appendLine(`[sendPromptTo] Prompt submitted via type fallback`);
    } catch (fallbackErr) {
      const msg = `Failed to send prompt: ${fallbackErr}`;
      outputChannel.appendLine(`[sendPromptTo] ${msg}`);
      void vscode.window.showErrorMessage(`Jumpshell: ${msg}`);
    }
  }
}

// ─── listModels ─────────────────────────────────────────────────────────────

/**
 * List all Copilot models available through the Language Model API.
 * Shows both the display name and the model id in a QuickPick.
 */
async function listCopilotModels(outputChannel: vscode.OutputChannel): Promise<void> {
  try {
    const models = await vscode.lm.selectChatModels();
    if (models.length === 0) {
      void vscode.window.showInformationMessage('Jumpshell: No Copilot LM models found.');
      return;
    }

    const items = models.map(m => ({
      label: m.name,
      description: m.family,
      detail: `id: ${m.id} · max tokens: ${m.maxInputTokens}`
    }));

    outputChannel.appendLine(`[model-picker] Found ${models.length} model(s):`);
    for (const m of models) {
      outputChannel.appendLine(`  • ${m.name} | family=${m.family} | id=${m.id} | maxInput=${m.maxInputTokens}`);
    }

    void vscode.window.showQuickPick(items, {
      title: 'Copilot Language Models',
      placeHolder: 'Name (family) — id shown in detail'
    });
  } catch (err) {
    const msg = `Failed to list models: ${err}`;
    outputChannel.appendLine(`[model-picker] ${msg}`);
    void vscode.window.showErrorMessage(`Jumpshell: ${msg}`);
  }
}

// ─── Shared UI automation ───────────────────────────────────────────────────

/**
 * Open the Copilot model picker and type + confirm a model label.
 *
 * ╔═══════════════════════════════════════════════════════════════╗
 * ║ BRITTLE — Everything here relies on internal VS Code and    ║
 * ║ Copilot Chat commands and UI timing.                         ║
 * ╚═══════════════════════════════════════════════════════════════╝
 */
async function automateModelPicker(
  modelLabel: string,
  outputChannel: vscode.OutputChannel
): Promise<void> {
  try {
    // BRITTLE — internal command contributed by the GitHub Copilot Chat extension.
    await vscode.commands.executeCommand('github.copilot.chat.openModelPicker');
  } catch (err) {
    const msg = `Failed to open model picker — the internal command ` +
      `'github.copilot.chat.openModelPicker' may have been removed or renamed. ` +
      `Error: ${err}`;
    outputChannel.appendLine(`[model-picker] ${msg}`);
    void vscode.window.showErrorMessage(`Jumpshell: ${msg}`);
    return;
  }

  // BRITTLE — wait for the QuickPick UI to render
  await delay(MODEL_PICKER_OPEN_DELAY_MS);

  try {
    // BRITTLE — 'type' injects text into the focused input
    await vscode.commands.executeCommand('type', { text: modelLabel });
    await delay(200);
    // BRITTLE — confirms the currently highlighted QuickPick item
    await vscode.commands.executeCommand('workbench.action.acceptSelectedQuickOpenItem');

    outputChannel.appendLine(`[model-picker] Selection submitted: "${modelLabel}"`);
    void vscode.window.showInformationMessage(`Jumpshell: Model selection submitted — "${modelLabel}"`);
  } catch (err) {
    const msg = `SendKeys automation failed: ${err}`;
    outputChannel.appendLine(`[model-picker] ${msg}`);
    void vscode.window.showErrorMessage(`Jumpshell: ${msg}`);
  }
}
