import type { Plugin } from "@opencode-ai/plugin"
import { execFile } from "node:child_process"
import { resolve, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const SCRIPT = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../hooks/notify.sh",
)

function notify(
  event: string,
  opts?: { subagent?: boolean },
) {
  const args = [event]
  if (opts?.subagent) args.push("--subagent")
  execFile("bash", [SCRIPT, ...args], (err) => {
    if (err) console.error("[agent-alert]", err.message)
  })
}

export const AgentAlert: Plugin = async ({ client }) => {
  const pending = new Map<string, ReturnType<typeof setTimeout>>()

  return {
    "session.idle": async ({ event }) => {
      const sessionId = event.properties?.sessionID
      if (!sessionId) return
      if (pending.has(sessionId)) clearTimeout(pending.get(sessionId)!)

      pending.set(
        sessionId,
        setTimeout(async () => {
          pending.delete(sessionId)
          const isSubagent = !!event.properties?.parentID
          notify("stop", { subagent: isSubagent })
        }, 400),
      )
    },

    "permission.asked": async () => {
      notify("notification")
    },

    "session.error": async () => {
      notify("error")
    },
  }
}
