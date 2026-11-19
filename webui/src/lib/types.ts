// SPDX-License-Identifier: Apache-2.0

export interface NetworkConfig {
  Token: string;
  Node: string;
  User: string;
  ShareBandwidth: number;
  ServerHost: string;
  ServerIP: string;
  ServerPort: number;
  PublicIPPort: number;
}

export interface AppConfig {
  network: NetworkConfig;
  apps: unknown[] | null;
  LogLevel: number;
  MaxLogSize: number;
  TLSInsecureSkipVerify: boolean;
  Forcev6: boolean;
  MonitorInterval: string;
  Timezone: string;
}

export interface ServiceStatus {
  running: boolean;
  pid: number;
  token_configured: boolean;
  node: string;
  version: string;
  tun: "up" | "down";
  tun_addr: string;
}

export interface TunStatus {
  optun: string;
  addr: string;
  ip_forward: string;
}

export interface UpdateResult {
  ok: boolean;
  current: string;
  new: string;
  up_to_date: boolean;
  message: string;
}

export interface UpdateStatus {
  running: boolean;
  done?: boolean;
  stage?: "checking" | "downloading" | "restarting";
  current?: string;
  new?: string;
  ok?: boolean;
  up_to_date?: boolean;
  message?: string;
}
