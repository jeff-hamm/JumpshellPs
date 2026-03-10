import { createHash } from 'node:crypto';
import { execFile } from 'node:child_process';
import { promises as fs } from 'node:fs';
import * as https from 'node:https';
import * as os from 'node:os';
import * as path from 'node:path';
import { promisify } from 'node:util';
import * as vscode from 'vscode';

const ignoredNames = new Set(['__pycache__', '.DS_Store', 'Thumbs.db']);
const ignoredExtensions = new Set(['.bak', '.pyc', '.pyo']);
const maxHttpRedirects = 5;

export const execFileAsync = promisify(execFile);

export function expandHome(inputPath: string): string {
  if (inputPath === '~') {
    return os.homedir();
  }

  if (inputPath.startsWith('~/') || inputPath.startsWith('~\\')) {
    return path.join(os.homedir(), inputPath.slice(2));
  }

  return inputPath;
}

export function uniqueStrings(values: string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim()).filter((value) => value.length > 0)));
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await fs.access(targetPath);
    return true;
  }
  catch {
    return false;
  }
}

export function shouldIgnoreName(name: string): boolean {
  return ignoredNames.has(name) || ignoredExtensions.has(path.extname(name).toLowerCase());
}

export async function collectFiles(directoryPath: string, baseDir: string): Promise<string[]> {
  const files = [] as string[];
  const entries = await fs.readdir(directoryPath, { withFileTypes: true });

  for (const entry of entries) {
    if (shouldIgnoreName(entry.name)) {
      continue;
    }

    const fullPath = path.join(directoryPath, entry.name);
    if (entry.isDirectory()) {
      files.push(...await collectFiles(fullPath, baseDir));
      continue;
    }

    if (!entry.isFile()) {
      continue;
    }

    files.push(path.relative(baseDir, fullPath).split(path.sep).join('/'));
  }

  return files.sort((left, right) => left.localeCompare(right));
}

export async function hashFiles(baseDir: string, files: string[]): Promise<string> {
  const hash = createHash('sha256');
  for (const relativeFile of files) {
    const bytes = await fs.readFile(path.join(baseDir, relativeFile));
    hash.update(relativeFile);
    hash.update('\0');
    hash.update(bytes);
    hash.update('\0');
  }

  return hash.digest('hex');
}

export async function copyDirectory(sourceDir: string, targetDir: string): Promise<void> {
  await fs.mkdir(targetDir, { recursive: true });
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    if (shouldIgnoreName(entry.name)) {
      continue;
    }

    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      await copyDirectory(sourcePath, targetPath);
      continue;
    }

    if (!entry.isFile()) {
      continue;
    }

    await fs.mkdir(path.dirname(targetPath), { recursive: true });
    await fs.copyFile(sourcePath, targetPath);
  }
}

export async function revealInFileExplorer(targetPath: string): Promise<void> {
  await vscode.commands.executeCommand('revealFileInOS', vscode.Uri.file(targetPath));
}

export async function fetchJson(url: string): Promise<unknown> {
  const response = await fetchBuffer(url, 0);
  const text = response.toString('utf8');
  try {
    return JSON.parse(text) as unknown;
  }
  catch {
    throw new Error(`Failed to parse JSON from ${url}.`);
  }
}

export async function downloadFile(url: string, targetPath: string): Promise<void> {
  const content = await fetchBuffer(url, 0);
  await fs.writeFile(targetPath, content);
}

async function fetchBuffer(url: string, redirectCount: number): Promise<Buffer> {
  return new Promise<Buffer>((resolve, reject) => {
    const request = https.get(
      url,
      {
        headers: {
          'User-Agent': 'jumpshell-extension-updater',
          Accept: 'application/vnd.github+json'
        }
      },
      (response) => {
        const statusCode = response.statusCode ?? 0;

        if (statusCode >= 300 && statusCode < 400 && response.headers.location) {
          response.resume();
          if (redirectCount >= maxHttpRedirects) {
            reject(new Error(`Too many redirects while requesting ${url}.`));
            return;
          }

          const redirectUrl = new URL(response.headers.location, url).toString();
          void fetchBuffer(redirectUrl, redirectCount + 1).then(resolve, reject);
          return;
        }

        if (statusCode < 200 || statusCode >= 300) {
          const chunks = [] as Buffer[];
          response.on('data', (chunk) => chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));
          response.on('end', () => {
            const body = Buffer.concat(chunks).toString('utf8').slice(0, 500);
            reject(new Error(`HTTP ${statusCode} while requesting ${url}: ${body}`));
          });
          return;
        }

        const chunks = [] as Buffer[];
        response.on('data', (chunk) => chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));
        response.on('end', () => resolve(Buffer.concat(chunks)));
      }
    );

    request.on('error', (error) => reject(error));
  });
}
