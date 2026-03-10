import * as vscode from 'vscode';
import { getOutputChannel } from './output';

type LocationMap = Record<string, boolean>;

const desiredSettings: {
  booleans: Array<{ section: string; key: string; value: boolean }>;
  locationMaps: Array<{ section: string; key: string; entries: LocationMap }>;
} = {
  booleans: [
    { section: 'github.copilot.chat.codeGeneration', key: 'useInstructionFiles', value: true }
  ],
  locationMaps: [
    {
      section: 'chat',
      key: 'promptFilesLocations',
      entries: {
        '.agents/prompts': true,
        '~/.agents/prompts': true,
        '.copilot/prompts': true,
        '~/.copilot/prompts': true,
        '.github/agents': true,
        '.claude': true,
        '~/.claude': true,
        '.cursor/rules': true,
        '~/.cursor/rules': true
      }
    },
    {
      section: 'chat',
      key: 'agentFilesLocations',
      entries: {
        '.agents/agents': true,
        '~/.agents/agents': true,
        '.copilot/agents': true,
        '~/.copilot/agents': true,
        '.github/agents': true,
        '.claude/agents': true,
        '~/.claude/agents': true,
        '.cursor/agents': true,
        '~/.cursor/agents': true
      }
    },
    {
      section: 'chat',
      key: 'instructionsFilesLocations',
      entries: {
        '.agents/rules': true,
        '~/.agents/rules': true,
        '.copilot/instructions': true,
        '~/.copilot/instructions': true,
        '.github/instructions': true,
        '.claude': true,
        '~/.claude': true,
        '.cursor/rules': true,
        '~/.cursor/rules': true
      }
    }
  ]
};

export async function ensureRecommendedSettings(options: { silent?: boolean } = {}): Promise<void> {
  const outputChannel = getOutputChannel();
  let changed = 0;

  for (const entry of desiredSettings.booleans) {
    const config = vscode.workspace.getConfiguration(entry.section);
    const current = config.get<boolean>(entry.key);
    if (current !== entry.value) {
      await config.update(entry.key, entry.value, vscode.ConfigurationTarget.Global);
      outputChannel.appendLine(`[settings] ${entry.section}.${entry.key} = ${entry.value}`);
      changed += 1;
    }
  }

  for (const entry of desiredSettings.locationMaps) {
    const config = vscode.workspace.getConfiguration(entry.section);
    const current = config.get<LocationMap>(entry.key) ?? {};
    const merged = { ...current };
    let dirty = false;

    for (const [locationKey, locationValue] of Object.entries(entry.entries)) {
      if (merged[locationKey] !== locationValue) {
        merged[locationKey] = locationValue;
        dirty = true;
      }
    }

    if (dirty) {
      await config.update(entry.key, merged, vscode.ConfigurationTarget.Global);
      outputChannel.appendLine(`[settings] ${entry.section}.${entry.key} updated`);
      changed += 1;
    }
  }

  if (!options.silent && changed > 0) {
    void vscode.window.showInformationMessage(`JumpShell updated ${changed} user setting(s).`);
  }

  if (changed > 0) {
    outputChannel.appendLine(`[settings] ${changed} setting(s) updated`);
  }
}
