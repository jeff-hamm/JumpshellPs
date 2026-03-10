import { createHash } from 'node:crypto';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ignoredNames = new Set(['__pycache__', '.DS_Store', 'Thumbs.db']);
const ignoredExtensions = new Set(['.bak', '.pyc', '.pyo', '.egg-info']);

const scriptPath = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(scriptPath);
const extensionRoot = path.resolve(scriptDir, '..');
const repoRoot = path.resolve(extensionRoot, '..', '..');
const sourceRoot = path.join(repoRoot, 'skills');
const sourceMcpRoot = path.join(repoRoot, 'mcps');
const sourceAiBackendsRoot = path.join(repoRoot, 'src', 'python', 'ai-backends');
const assetsRoot = path.join(extensionRoot, 'assets');
const targetRoot = path.join(assetsRoot, 'skills');
const targetMcpRoot = path.join(assetsRoot, 'mcps');
const targetAiBackendsRoot = path.join(assetsRoot, 'src', 'python', 'ai-backends');
const manifestPath = path.join(assetsRoot, 'skills-manifest.json');

async function main() {
  const sourceExists = await pathExists(sourceRoot);
  if (!sourceExists) {
    throw new Error(`Skill source directory not found: ${sourceRoot}`);
  }

  await fs.mkdir(assetsRoot, { recursive: true });
  await fs.rm(targetRoot, { recursive: true, force: true });
  await fs.mkdir(targetRoot, { recursive: true });

  const manifest = [];
  const skillEntries = await fs.readdir(sourceRoot, { withFileTypes: true });
  for (const entry of skillEntries.filter((candidate) => candidate.isDirectory()).sort((left, right) => left.name.localeCompare(right.name))) {
    if (shouldIgnoreName(entry.name)) {
      continue;
    }

    const sourceSkillDir = path.join(sourceRoot, entry.name);
    const targetSkillDir = path.join(targetRoot, entry.name);
    await copyDirectory(sourceSkillDir, targetSkillDir);

    const files = await collectFiles(targetSkillDir, targetSkillDir);
    manifest.push({
      name: entry.name,
      relativePath: entry.name,
      hash: await hashFiles(targetSkillDir, files),
      fileCount: files.length
    });
  }

  const payload = {
    generatedAt: new Date().toISOString(),
    sourceRoot,
    skills: manifest
  };

  await fs.rm(targetMcpRoot, { recursive: true, force: true });
  if (await pathExists(sourceMcpRoot)) {
    await copyDirectory(sourceMcpRoot, targetMcpRoot);
  }

  await fs.rm(targetAiBackendsRoot, { recursive: true, force: true });
  if (await pathExists(sourceAiBackendsRoot)) {
    await copyDirectory(sourceAiBackendsRoot, targetAiBackendsRoot);
  }

  await fs.writeFile(manifestPath, JSON.stringify(payload, null, 2) + '\n', 'utf8');
  console.log(`Synced ${manifest.length} skill(s) into ${targetRoot}`);
}

function shouldIgnoreName(name) {
  return ignoredNames.has(name) || ignoredExtensions.has(path.extname(name).toLowerCase());
}

async function copyDirectory(sourceDir, targetDir) {
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

async function collectFiles(directoryPath, baseDir) {
  const files = [];
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

async function hashFiles(baseDir, files) {
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

async function pathExists(targetPath) {
  try {
    await fs.access(targetPath);
    return true;
  }
  catch {
    return false;
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});