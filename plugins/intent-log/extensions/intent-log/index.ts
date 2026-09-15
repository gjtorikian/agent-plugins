// Pi extension for the intent-log skill.
//
// Captures what the person typed, and writes it to ~/.intent-log/staging/
// once the agent has finished the run it prompted. At startup it says how
// many prompts are waiting to be written up. It never calls a model and never
// edits the log itself: turning prompts into entries is the skill's job.

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  appendStaged,
  gitContext,
  isHumanPrompt,
  reminder,
  stagingDir,
  summarizeStaged,
  type StagedPrompt,
} from "./staging.ts";

interface Pending {
  ts: string;
  prompt: string;
}

export default function (pi: ExtensionAPI) {
  const dir = stagingDir();
  let pending: Pending[] = [];
  let warned = false;

  async function flush(ctx: ExtensionContext): Promise<void> {
    if (pending.length === 0) return;
    const batch = pending;
    pending = [];
    try {
      const { repo, branch } = await gitContext(ctx.cwd);
      const session = ctx.sessionManager.getSessionId?.() ?? null;
      const prompts: StagedPrompt[] = batch.map((item) => ({
        ts: item.ts,
        host: "pi",
        session,
        cwd: ctx.cwd,
        repo,
        branch,
        prompt: item.prompt,
      }));
      appendStaged(dir, prompts);
    } catch (error) {
      pending = batch.concat(pending);
      if (!warned && ctx.hasUI) {
        warned = true;
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`intent-log: could not stage prompts in ${dir}: ${message}`, "warning");
      }
    }
  }

  pi.on("input", (event) => {
    if (event.source !== "interactive" || !isHumanPrompt(event.text)) return;
    pending.push({ ts: new Date().toISOString(), prompt: event.text.trim() });
  });

  pi.on("agent_end", async (_event, ctx) => {
    await flush(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    await flush(ctx);
  });

  pi.on("session_start", (event, ctx) => {
    if (event.reason !== "startup" || !ctx.hasUI) return;
    const message = reminder(summarizeStaged(dir), dir);
    if (message) ctx.ui.notify(message, "info");
  });
}
