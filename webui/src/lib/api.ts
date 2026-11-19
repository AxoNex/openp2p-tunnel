// SPDX-License-Identifier: Apache-2.0

import { PATHS } from "./constants";
import type {
  AppConfig,
  ServiceStatus,
  TunStatus,
  UpdateStatus,
} from "./types";

interface KsuExecResult {
  errno: number;
  stdout: string;
  stderr: string;
}

type KsuExec = (cmd: string) => Promise<KsuExecResult>;

let ksuExec: KsuExec | null = null;

try {
  const ksu = await import("kernelsu").catch(() => null);
  ksuExec = ksu ? (ksu.exec as KsuExec) : null;
} catch {
  ksuExec = null;
}

export const hasBridge = ksuExec !== null;
export const BRIDGE_UNAVAILABLE_MESSAGE = "KernelSU WebUI 桥接不可用 (ksu.exec)";

function toBase64(str: string): string {
  const bytes = new TextEncoder().encode(str);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function shellEscapeDoubleQuoted(value: string): string {
  return value.replace(/(["\\$`])/g, "\\$1");
}

async function run(subcommand: string, args: string[] = []): Promise<string> {
  if (!ksuExec) throw new Error(BRIDGE_UNAVAILABLE_MESSAGE);
  const cmd = `${PATHS.CONTROL} ${subcommand}${args.length ? " " + args.join(" ") : ""}`;
  const { errno, stdout, stderr } = await ksuExec(cmd);
  if (errno !== 0) throw new Error(stderr || `命令失败 (errno=${errno})`);
  return stdout;
}

export const api = {
  hasBridge,

  getStatus: async (): Promise<ServiceStatus> => JSON.parse(await run("status")),
  getTun: async (): Promise<TunStatus> => JSON.parse(await run("tun")),
  getConfig: async (): Promise<AppConfig> => JSON.parse(await run("config", ["get"])),
  getLog: async (lines = 100): Promise<string> => run("log", [String(lines)]),

  start: async () => run("start"),
  stop: async () => run("stop"),
  restart: async () => run("restart"),
  toggle: async () => run("toggle"),

  update: async (): Promise<{ started: boolean }> =>
    JSON.parse(await run("update")),
  getUpdateStatus: async (): Promise<UpdateStatus> =>
    JSON.parse(await run("update-status")),

  openLink: async (url: string): Promise<void> => {
    if (!ksuExec) throw new Error(BRIDGE_UNAVAILABLE_MESSAGE);
    await ksuExec(
      `am start -a android.intent.action.VIEW -d "${shellEscapeDoubleQuoted(url)}"`,
    );
  },

  saveConfig: async (config: AppConfig): Promise<void> => {
    const json = JSON.stringify(config, null, 2);
    await run("config", ["import", toBase64(json)]);
  },
};
