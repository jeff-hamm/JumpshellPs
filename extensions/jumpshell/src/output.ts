import * as vscode from 'vscode';

let channel: vscode.OutputChannel | undefined;

export function initOutputChannel(outputChannel: vscode.OutputChannel): void {
  channel = outputChannel;
}

export function getOutputChannel(): vscode.OutputChannel {
  if (!channel) {
    throw new Error('JumpShell output channel has not been initialized.');
  }

  return channel;
}
