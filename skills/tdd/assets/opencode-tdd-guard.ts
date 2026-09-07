import type { Plugin } from "@opencode-ai/plugin"

// Opencode plugin implementing the TDD phase guard.
// Reads the current phase from the .tdd/phase file (written by the
// orchestrator on each phase transition) and throws on out-of-phase writes.
//
// Phase file contents: one of "red" | "green" | "refactor".
// Missing file -> no enforcement (matches the no-guard degradation path).

const TEST_PATH_PATTERNS: RegExp[] = [
  /(^|\/)tests?\//,
  /(^|\/)__tests__\//,
  /(^|\/)spec\//,
  /_test\.[^/]+$/,
  /\.test\.[^/]+$/,
  /\.spec\.[^/]+$/,
  /_spec\.[^/]+$/,
  /(^|\/)test_[^/]+\.py$/,
  /(^|\/)conftest\.py$/,
]

const isTestPath = (p: string): boolean =>
  TEST_PATH_PATTERNS.some((rx) => rx.test(p))

const isTddDir = (p: string): boolean => /(^|\/)\.tdd(\/|$)/.test(p)

// Tools that write to the filesystem. Adjust if Opencode adds more.
const WRITE_TOOLS = new Set(["write", "edit", "patch"])

export const TddGuardPlugin: Plugin = async ({ directory, $ }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (!WRITE_TOOLS.has(input.tool)) return

      // Extract the target path from common tool arg shapes.
      const args = output.args ?? {}
      const path: string | undefined =
        args.filePath ?? args.path ?? args.file ?? args.target
      if (!path) return

      // Read phase from .tdd/phase; missing file = no enforcement.
      let phase = ""
      try {
        phase = (await $`cat ${directory}/.tdd/phase`.text()).trim()
      } catch {
        return
      }

      const inTest = isTestPath(path)
      const inTdd = isTddDir(path)

      if (phase === "red") {
        if (!inTest && !inTdd) {
          throw new Error(
            `tdd-guard: Red phase may only modify test files and .tdd/. Attempted: ${path}`,
          )
        }
      } else if (phase === "green" || phase === "refactor") {
        if (inTest || inTdd) {
          throw new Error(
            `tdd-guard: ${phase} phase may not modify test files or .tdd/. Attempted: ${path}. If the test is wrong, report it — do not fix it.`,
          )
        }
      }
    },
  }
}
