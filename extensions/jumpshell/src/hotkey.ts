/**
 * hotkey.ts — Assign keybindings for model-picker commands.
 *
 * Provides `jumpshell.assignModelHotkey`: the user picks a model + action,
 * presses the desired key combination in a webview panel, and the keybinding
 * is written directly to the user's keybindings.json.
 *
 * ┌────────────────────────────────────────────────────────────────────────┐
 * │ No public VS Code extension API exists to register keybindings at     │
 * │ runtime. We write directly to the user's keybindings.json (the same   │
 * │ file edited via File > Preferences > Keyboard Shortcuts).             │
 * └────────────────────────────────────────────────────────────────────────┘
 */
import { promises as fs } from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as vscode from 'vscode';

// ─── Public registration ──────────────────────────────────────────────────────

export function registerHotkeyCommands(
  context: vscode.ExtensionContext,
  outputChannel: vscode.OutputChannel
): void {
  context.subscriptions.push(
    vscode.commands.registerCommand(
      'jumpshell.assignModelHotkey',
      () => assignModelHotkeyFlow(context, outputChannel)
    )
  );
}

// ─── Flow ─────────────────────────────────────────────────────────────────────

async function assignModelHotkeyFlow(
  context: vscode.ExtensionContext,
  outputChannel: vscode.OutputChannel
): Promise<void> {
  // ── 1. Pick model ───────────────────────────────────────────────────
  const modelItems = await buildModelItems();
  const modelPick = await vscode.window.showQuickPick(modelItems, {
    title: 'Assign Model Hotkey (1/3) — Choose Model',
    placeHolder: 'Select the model to bind to a hotkey'
  });
  if (!modelPick) { return; }

  // ── 2. Pick action ──────────────────────────────────────────────────
  const actionItems: (vscode.QuickPickItem & { command: string })[] = [
    {
      label: '$(symbol-event)  Select Model',
      description: 'jumpshell.selectModel',
      detail: 'Switch the active chat model to the chosen model',
      command: 'jumpshell.selectModel'
    },
    {
      label: '$(comment-discussion)  Send Prompt To',
      description: 'jumpshell.sendPromptTo',
      detail: 'Open a new chat session with the chosen model and send the current selection (or a typed prompt)',
      command: 'jumpshell.sendPromptTo'
    }
  ];
  const actionPick = await vscode.window.showQuickPick(actionItems, {
    title: 'Assign Model Hotkey (2/3) — Choose Action',
    placeHolder: 'What should happen when the hotkey is pressed?'
  });
  if (!actionPick) { return; }

  // ── 3. Capture key combination in webview ───────────────────────────
  const combo = await captureKeyCombination(context);
  if (!combo) { return; }

  // ── 4. Build and write the keybinding entry ──────────────────────────
  const modelName = modelPick.label;
  // selectModel takes a plain string arg; sendPromptTo takes an object
  const args: unknown = actionPick.command === 'jumpshell.sendPromptTo'
    ? { model: modelName }
    : modelName;

  const entry: KeybindingEntry = { key: combo, command: actionPick.command, args };
  outputChannel.appendLine(`[hotkey] Writing keybinding: ${JSON.stringify(entry)}`);

  const kbPath = getUserKeybindingsPath();
  try {
    await writeKeybindingEntry(kbPath, entry);
    outputChannel.appendLine(`[hotkey] Written to ${kbPath}`);

    const choice = await vscode.window.showInformationMessage(
      `JumpShell: Bound ${combo} → ${actionPick.command} ("${modelName}")`,
      'Open Keybindings'
    );
    if (choice === 'Open Keybindings') {
      await vscode.commands.executeCommand('workbench.action.openGlobalKeybindingsFile');
    }
  } catch (err) {
    const msg = `Failed to write keybinding: ${err}`;
    outputChannel.appendLine(`[hotkey] ${msg}`);
    void vscode.window.showErrorMessage(`JumpShell: ${msg}`);
  }
}

// ─── Key capture webview ──────────────────────────────────────────────────────

function captureKeyCombination(context: vscode.ExtensionContext): Promise<string | undefined> {
  return new Promise<string | undefined>((resolve) => {
    const nonce = getNonce();
    const panel = vscode.window.createWebviewPanel(
      'jumpshellKeyCapturer',
      'JumpShell — Press Hotkey',
      vscode.ViewColumn.Active,
      { enableScripts: true, retainContextWhenHidden: false }
    );

    panel.webview.html = buildKeyCapturerHtml(nonce);

    let settled = false;
    const settle = (value: string | undefined) => {
      if (!settled) {
        settled = true;
        panel.dispose();
        resolve(value);
      }
    };

    panel.webview.onDidReceiveMessage((msg: { type: string; combo?: string }) => {
      if (msg.type === 'confirm' && msg.combo) { settle(msg.combo); }
      else if (msg.type === 'cancel') { settle(undefined); }
    });

    panel.onDidDispose(() => settle(undefined));
  });
}

function buildKeyCapturerHtml(nonce: string): string {
  return /* html */ `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; script-src 'nonce-${nonce}'; style-src 'unsafe-inline';" />
  <style>
    :root {
      --bg:       var(--vscode-editor-background,     #1e1e1e);
      --fg:       var(--vscode-editor-foreground,     #d4d4d4);
      --border:   var(--vscode-focusBorder,           #007acc);
      --desc:     var(--vscode-descriptionForeground, #888);
      --btn-bg:   var(--vscode-button-background,     #0e639c);
      --btn-fg:   var(--vscode-button-foreground,     #fff);
      --btn-hov:  var(--vscode-button-hoverBackground,#1177bb);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      color: var(--fg);
      font-family: var(--vscode-font-family, sans-serif);
      font-size: 13px;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      gap: 18px;
      padding: 24px;
    }
    h2 { font-size: 15px; font-weight: 600; }
    .hint { color: var(--desc); text-align: center; line-height: 1.5; }
    .combo-box {
      font-size: 26px;
      font-weight: bold;
      font-family: var(--vscode-editor-font-family, monospace);
      padding: 16px 36px;
      border: 2px solid var(--border);
      border-radius: 6px;
      min-width: 240px;
      text-align: center;
      letter-spacing: 2px;
      color: var(--desc);
      transition: border-color 0.15s, color 0.15s;
    }
    .combo-box.ready { border-color: #4caf50; color: #4caf50; }
    .actions { display: flex; gap: 10px; margin-top: 4px; }
    button {
      padding: 6px 22px;
      border-radius: 4px;
      border: 1px solid transparent;
      cursor: pointer;
      font-size: 13px;
      transition: background 0.12s;
    }
    button.primary {
      background: var(--btn-bg);
      color: var(--btn-fg);
      border-color: var(--btn-bg);
    }
    button.primary:hover:not(:disabled) { background: var(--btn-hov); }
    button.primary:disabled { opacity: 0.35; cursor: default; }
    button.ghost {
      background: transparent;
      color: var(--fg);
      border-color: var(--border);
    }
    button.ghost:hover { background: rgba(255,255,255,0.07); }
  </style>
</head>
<body>
  <h2>Step 3 of 3 — Press Your Hotkey</h2>
  <p class="hint">
    Press the key combination you want to assign.<br>
    Modifier-only combos are ignored; you need at least one non-modifier key.
  </p>
  <div class="combo-box" id="comboBox">waiting…</div>
  <div class="actions">
    <button class="primary" id="assignBtn" disabled onclick="doConfirm()">Assign</button>
    <button class="ghost" id="clearBtn" style="display:none" onclick="doClear()">Clear</button>
    <button class="ghost" onclick="doCancel()">Cancel</button>
  </div>

  <script nonce="${nonce}">
    const vscode = acquireVsCodeApi();

    const comboBox  = document.getElementById('comboBox');
    const assignBtn = document.getElementById('assignBtn');
    const clearBtn  = document.getElementById('clearBtn');

    const MODIFIERS = new Set(['Control','Shift','Alt','Meta']);

    // Normalise e.key to the VS Code keybinding token
    const KEY_MAP = {
      ' ':'space','ArrowUp':'up','ArrowDown':'down','ArrowLeft':'left','ArrowRight':'right',
      'Escape':'escape','Enter':'enter','Backspace':'backspace','Delete':'delete','Tab':'tab',
      'Home':'home','End':'end','PageUp':'pageup','PageDown':'pagedown','Insert':'insert',
      '/':'slash','\\\\':'backslash','.':'period',',':'comma',';':'semicolon',
      "'":"quote",'\`':'backquote','[':'bracketleft',']':'bracketright',
      '-':'minus','=':'equal',
    };
    for (let i = 1; i <= 19; i++) KEY_MAP['F' + i] = 'f' + i;

    let captured = '';

    document.addEventListener('keydown', e => {
      e.preventDefault();
      if (MODIFIERS.has(e.key)) { return; }

      const parts = [];
      if (e.ctrlKey)  parts.push('ctrl');
      if (e.shiftKey) parts.push('shift');
      if (e.altKey)   parts.push('alt');
      if (e.metaKey)  parts.push('meta');
      parts.push(KEY_MAP[e.key] ?? e.key.toLowerCase());

      captured = parts.join('+');
      comboBox.textContent = captured;
      comboBox.classList.add('ready');
      assignBtn.disabled = false;
      clearBtn.style.display = '';
    });

    function doClear() {
      captured = '';
      comboBox.textContent = 'waiting…';
      comboBox.classList.remove('ready');
      assignBtn.disabled = true;
      clearBtn.style.display = 'none';
    }

    function doConfirm() {
      if (captured) { vscode.postMessage({ type: 'confirm', combo: captured }); }
    }

    function doCancel() {
      vscode.postMessage({ type: 'cancel' });
    }
  </script>
</body>
</html>`;
}

// ─── keybindings.json helpers ─────────────────────────────────────────────────

interface KeybindingEntry {
  key: string;
  command: string;
  args: unknown;
}

/**
 * Return the path to the user's keybindings.json, resolved by platform and
 * VS Code variant (stable / insiders / Cursor).
 */
function getUserKeybindingsPath(): string {
  const appName = vscode.env.appName;
  let configDir: string;
  if (appName.toLowerCase().includes('cursor')) {
    configDir = 'Cursor';
  } else if (appName.toLowerCase().includes('insiders')) {
    configDir = 'Code - Insiders';
  } else {
    configDir = 'Code';
  }

  switch (process.platform) {
    case 'win32':
      return path.join(
        process.env['APPDATA'] ?? path.join(os.homedir(), 'AppData', 'Roaming'),
        configDir, 'User', 'keybindings.json'
      );
    case 'darwin':
      return path.join(
        os.homedir(), 'Library', 'Application Support', configDir, 'User', 'keybindings.json'
      );
    default:
      return path.join(
        process.env['XDG_CONFIG_HOME'] ?? path.join(os.homedir(), '.config'),
        configDir, 'User', 'keybindings.json'
      );
  }
}

/**
 * Append a keybinding entry to the user's keybindings.json.
 *
 * Handles the JSONC format (strips no comments, just inserts before the last `]`).
 * If the file doesn't exist, creates it.
 */
async function writeKeybindingEntry(kbPath: string, entry: KeybindingEntry): Promise<void> {
  await fs.mkdir(path.dirname(kbPath), { recursive: true });

  let existing: string;
  try {
    existing = await fs.readFile(kbPath, 'utf-8');
  } catch {
    existing = '// Place your key bindings in this file to override the defaults\n[\n]\n';
  }

  // Indent the entry uniformly at 2 spaces (matching VS Code's default formatting)
  const entryJson = JSON.stringify(entry, null, 2)
    .split('\n')
    .map(line => '  ' + line)
    .join('\n');

  const lastBracket = existing.lastIndexOf(']');
  if (lastBracket === -1) {
    await fs.writeFile(kbPath, `[\n${entryJson}\n]\n`, 'utf-8');
    return;
  }

  const before = existing.slice(0, lastBracket).trimEnd();
  // If trimmed text ends with '[' the array is empty (no existing entries)
  const isEmpty = before.endsWith('[');
  const separator = isEmpty ? '\n' : ',\n';
  const newContent = before + separator + entryJson + '\n' + existing.slice(lastBracket);
  await fs.writeFile(kbPath, newContent, 'utf-8');
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function buildModelItems(): Promise<vscode.QuickPickItem[]> {
  const items: vscode.QuickPickItem[] = [
    { label: 'Auto', description: 'Let Copilot choose', detail: 'id: auto' }
  ];
  try {
    const models = await vscode.lm.selectChatModels();
    for (const m of models) {
      items.push({ label: m.name, description: m.family, detail: `id: ${m.id}` });
    }
  } catch { /* LM API unavailable — return Auto only */ }
  return items;
}

function getNonce(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let nonce = '';
  for (let i = 0; i < 32; i++) {
    nonce += chars[Math.floor(Math.random() * chars.length)];
  }
  return nonce;
}
