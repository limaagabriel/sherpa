import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const BOOTSTRAP_MARKER = "sherpa pi-harness bootstrap";

const extensionDir = dirname(fileURLToPath(import.meta.url));
const packageRoot = resolve(extensionDir, "../..");
const skillsDir = resolve(packageRoot, "skills");
const resolverPath = resolve(packageRoot, "scripts", "resolve-project-pack.sh");

process.env.SHERPA_PLUGIN_ROOT = packageRoot;

let packAdditionalContext: string | null = null;

export default function sherpaPiExtension(pi: ExtensionAPI) {
	let injectBootstrap = true;

	pi.on("resources_discover", async () => ({
		skillPaths: [skillsDir],
	}));

	pi.on("session_start", async (event) => {
		injectBootstrap = true;
		packAdditionalContext = resolvePackContext(event.cwd ?? process.cwd());
	});

	pi.on("session_compact", async () => {
		injectBootstrap = true;
	});

	pi.on("agent_end", async () => {
		injectBootstrap = false;
	});

	pi.on("context", async (event) => {
		if (!injectBootstrap) return;
		if (event.messages.some(messageContainsBootstrap)) return;

		const bootstrap = buildBootstrap();
		const bootstrapMessage = {
			role: "user" as const,
			content: [{ type: "text" as const, text: bootstrap }],
			timestamp: Date.now(),
		};

		const insertAt = firstNonCompactionSummaryIndex(event.messages);
		return {
			messages: [
				...event.messages.slice(0, insertAt),
				bootstrapMessage,
				...event.messages.slice(insertAt),
			],
		};
	});
}

function resolvePackContext(cwd: string): string | null {
	const result = spawnSync("bash", [resolverPath], {
		input: JSON.stringify({ cwd }),
		encoding: "utf8",
	});
	if (result.status !== 0 || !result.stdout) return null;

	try {
		const parsed = JSON.parse(result.stdout) as {
			hookSpecificOutput?: { additionalContext?: unknown };
		};
		const additional = parsed.hookSpecificOutput?.additionalContext;
		return typeof additional === "string" ? additional : null;
	} catch {
		return null;
	}
}

function buildBootstrap(): string {
	const sections = [packAdditionalContext, piHarnessBridge()].filter(
		(section): section is string => Boolean(section),
	);
	return sections.join("\n\n");
}

function piHarnessBridge(): string {
	return `<EXTREMELY_IMPORTANT>
${BOOTSTRAP_MARKER}

You are running sherpa under the pi harness. Read \`protocols/harness/pi.md\` (under \`$SHERPA_PLUGIN_ROOT\`) for the harness contract. Key mappings:
- \`ask_user_question\` (rpiv) is the AskUserQuestion equivalent.
- Subagent dispatch goes through pi-subagents: the \`subagent\` tool or \`/run <name>\`.
- \`$SHERPA_PLUGIN_ROOT\` locates the sherpa package (canonical \`agents/*.md\`, \`skills/\`, \`protocols/\`).
</EXTREMELY_IMPORTANT>`;
}

function messageContainsBootstrap(message: unknown): boolean {
	const content = (message as { content?: unknown }).content;
	if (typeof content === "string") return content.includes(BOOTSTRAP_MARKER);
	if (!Array.isArray(content)) return false;
	return content.some((part) => {
		return (
			part &&
			typeof part === "object" &&
			(part as { type?: unknown }).type === "text" &&
			typeof (part as { text?: unknown }).text === "string" &&
			(part as { text: string }).text.includes(BOOTSTRAP_MARKER)
		);
	});
}

function firstNonCompactionSummaryIndex(messages: unknown[]): number {
	let index = 0;
	while ((messages[index] as { role?: unknown } | undefined)?.role === "compactionSummary") {
		index += 1;
	}
	return index;
}
