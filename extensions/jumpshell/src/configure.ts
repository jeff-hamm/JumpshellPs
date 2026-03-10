import { execFileAsync } from './utils';

export async function resolveAiCli(): Promise<string | undefined> {
  const candidates = process.platform === 'win32'
    ? ['ai-cli', 'ai-cli.exe', 'ai-backends', 'ai-backends.exe']
    : ['ai-cli', 'ai-backends'];

  for (const candidate of candidates) {
    try {
      await execFileAsync(candidate, ['--help'], { timeout: 5000, windowsHide: true });
      return candidate;
    }
    catch {
      continue;
    }
  }

  return undefined;
}
