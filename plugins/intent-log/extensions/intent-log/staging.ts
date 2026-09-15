// Staging for the intent-log skill: raw human prompts, one JSONL file per
// local day, kept under ~/.intent-log/staging/ and never inside a repository.
// The skill reads these instead of hunting through session transcripts, then
// moves each written-up day into staging/logged/ so the reminder stops
// counting it. Nothing here depends on the host that captured the prompt.

import { execFile } from "node:child_process";
import { appendFileSync, mkdirSync, readdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export interface StagedPrompt {
  /** When the person sent it, as an ISO-8601 UTC timestamp. */
  ts: string;
  /** Which agent captured it, such as "pi". */
  host: string;
  /** Host session identifier, so a resumed session can be told apart. */
  session: string | null;
  /** Working directory at the time of the prompt. */
  cwd: string;
  /** "owner/name" from the git remote, or null outside a repository. */
  repo: string | null;
  /** Checked-out branch, or null outside a repository or on a detached head. */
  branch: string | null;
  /** The prompt exactly as typed, trimmed. */
  prompt: string;
}

export interface StagedSummary {
  prompts: number;
  days: number;
  /** Oldest staged day as YYYY-MM-DD, or null when nothing is staged. */
  oldest: string | null;
}

/** The log's home: $INTENT_LOG_HOME, else ~/.intent-log. */
export function intentLogHome(env: NodeJS.ProcessEnv = process.env): string {
  const configured = env.INTENT_LOG_HOME;
  return configured && configured.length > 0 ? configured : join(homedir(), ".intent-log");
}

export function stagingDir(env: NodeJS.ProcessEnv = process.env): string {
  return join(intentLogHome(env), "staging");
}

/** YYYY-MM-DD in the machine's local timezone: the day the person experienced. */
export function localDate(at: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${at.getFullYear()}-${pad(at.getMonth() + 1)}-${pad(at.getDate())}`;
}

/**
 * Whether typed input is a request to the agent rather than a host command.
 * Slash commands and shell escapes never reach the agent; a skill invocation
 * does, and its raw text is the clearest record of the ask.
 */
export function isHumanPrompt(text: string): boolean {
  const trimmed = text.trim();
  if (trimmed.length === 0) return false;
  if (trimmed.startsWith("!")) return false;
  if (trimmed.startsWith("/")) return trimmed.startsWith("/skill:");
  return true;
}

/** "owner/name" from any common git remote URL, or null. */
export function repositoryFromRemote(url: string): string | null {
  const cleaned = url.trim().replace(/\.git$/, "").replace(/\/+$/, "");
  const scp = cleaned.match(/^[^@/]+@[^:]+:(.+)$/);
  const path = scp ? scp[1] : cleaned.replace(/^[a-z+]+:\/\/[^/]+\//i, "");
  const parts = path.split("/").filter((part) => part.length > 0);
  if (parts.length < 2) return null;
  const [owner, name] = parts.slice(-2);
  return /^[A-Za-z0-9_.-]+$/.test(owner) && /^[A-Za-z0-9_.-]+$/.test(name) ? `${owner}/${name}` : null;
}

async function git(cwd: string, args: string[]): Promise<string | null> {
  try {
    const { stdout } = await execFileAsync("git", ["-C", cwd, ...args], { timeout: 5000 });
    const value = stdout.trim();
    return value.length > 0 ? value : null;
  } catch {
    return null;
  }
}

/** Repository and branch for a working directory; nulls outside a repository
 * or on a detached head. An unborn branch (no commits yet) still has a name. */
export async function gitContext(cwd: string): Promise<{ repo: string | null; branch: string | null }> {
  const [remote, head] = await Promise.all([
    git(cwd, ["remote", "get-url", "origin"]),
    git(cwd, ["symbolic-ref", "--short", "-q", "HEAD"]),
  ]);
  return {
    repo: remote ? repositoryFromRemote(remote) : null,
    branch: head,
  };
}

/** Append prompts to the JSONL file for each prompt's local day. */
export function appendStaged(dir: string, prompts: StagedPrompt[]): string[] {
  if (prompts.length === 0) return [];
  mkdirSync(dir, { recursive: true });
  const byDay = new Map<string, string[]>();
  for (const prompt of prompts) {
    const day = localDate(new Date(prompt.ts));
    const lines = byDay.get(day) ?? [];
    lines.push(JSON.stringify(prompt));
    byDay.set(day, lines);
  }
  const written: string[] = [];
  for (const [day, lines] of byDay) {
    const file = join(dir, `${day}.jsonl`);
    appendFileSync(file, lines.join("\n") + "\n");
    written.push(file);
  }
  return written;
}

/** Count prompts still waiting in staging (files moved to logged/ are done). */
export function summarizeStaged(dir: string): StagedSummary {
  let files: string[];
  try {
    files = readdirSync(dir, { withFileTypes: true })
      .filter((entry) => entry.isFile() && /^\d{4}-\d{2}-\d{2}\.jsonl$/.test(entry.name))
      .map((entry) => join(dir, entry.name))
      .sort();
  } catch {
    return { prompts: 0, days: 0, oldest: null };
  }
  let prompts = 0;
  let days = 0;
  let oldest: string | null = null;
  for (const file of files) {
    const count = readFileSync(file, "utf8").split("\n").filter((line) => line.trim().length > 0).length;
    if (count === 0) continue;
    prompts += count;
    days += 1;
    oldest ??= basename(file, ".jsonl");
  }
  return { prompts, days, oldest };
}

/** The reminder shown at startup, or null when nothing is waiting. */
export function reminder(summary: StagedSummary, dir: string): string | null {
  if (summary.prompts === 0 || summary.oldest === null) return null;
  const prompts = `${summary.prompts} prompt${summary.prompts === 1 ? "" : "s"}`;
  const days = `${summary.days} day${summary.days === 1 ? "" : "s"}`;
  return `intent-log: ${prompts} from ${days} staged in ${dir} (oldest ${summary.oldest}). Run /skill:intent-log to write them up.`;
}
