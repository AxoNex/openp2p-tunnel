<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { api } from "../../../lib/api";
import { uiStore } from "../../../lib/stores/uiStore";
import { ICONS } from "../icons";
import type { ServiceStatus, TunStatus } from "../../../lib/types";

const { t } = useI18n();

const status = ref<ServiceStatus | null>(null);
const tun = ref<TunStatus | null>(null);
const busy = ref(false);
const busyLabel = ref("");

const ingLabel = {
  start: "status.starting",
  stop: "status.stopping",
  restart: "status.restarting",
} as const;

const statusKind = computed<"checking" | "normal" | "abnormal">(() => {
  if (!status.value) return "checking";
  return status.value.running ? "normal" : "abnormal";
});

const statusTitle = computed(() => {
  if (!status.value) return t("common.detecting");
  return status.value.running ? t("status.running") : t("status.stopped");
});

const statusSummary = computed(() => {
  if (!status.value) return t("status.gettingStatus");
  if (status.value.running)
    return t("status.versionOf", { version: status.value.version || "-" });
  if (!status.value.token_configured) return t("status.tokenNotConfigured");
  return t("status.clickToStart");
});

const statusColor = computed(() => {
  switch (statusKind.value) {
    case "normal":
      return "var(--md-sys-color-primary-container)";
    case "abnormal":
      return "var(--md-sys-color-error-container)";
    default:
      return "var(--md-sys-color-secondary-container)";
  }
});

const statusOnColor = computed(() => {
  switch (statusKind.value) {
    case "normal":
      return "var(--md-sys-color-on-primary-container)";
    case "abnormal":
      return "var(--md-sys-color-on-error-container)";
    default:
      return "var(--md-sys-color-on-secondary-container)";
  }
});

async function load(): Promise<void> {
  try {
    const [s, tu] = await Promise.all([api.getStatus(), api.getTun()]);
    status.value = s;
    tun.value = tu;
  } catch (e) {
    uiStore.notify((e as Error).message);
  }
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

async function run(
  action: "start" | "stop" | "restart",
  fn: () => Promise<unknown>,
  expectRunning: boolean,
): Promise<void> {
  busy.value = true;
  busyLabel.value = t(ingLabel[action]);
  try {
    await fn();
    const deadline = Date.now() + 15000;
    let matched = false;
    while (Date.now() < deadline) {
      await sleep(700);
      const s = await api.getStatus().catch(() => null);
      if (s) {
        status.value = s;
        if (s.running === expectRunning) {
          matched = true;
          break;
        }
      }
    }
    const label = t(`status.${action}`);
    uiStore.notify(
      matched ? t("status.done", { label }) : t("status.timeout", { label }),
    );
  } catch (e) {
    uiStore.notify((e as Error).message);
  } finally {
    busy.value = false;
    busyLabel.value = "";
    await load();
  }
}

onMounted(load);
</script>

<template>
  <div>
    <div
      class="md3-card banner"
      :style="{ background: statusColor, color: statusOnColor }"
    >
      <h2 class="md3-card-title">{{ statusTitle }}</h2>
      <p class="md3-card-desc">{{ statusSummary }}</p>
    </div>

    <p class="md3-section-title">{{ t("status.serviceInfo") }}</p>
    <div class="md3-card">
      <div class="md3-row">
        <div class="copy"><strong>{{ t("status.runState") }}</strong></div>
        <span class="md3-value">{{
          status?.running ? t("status.running") : t("status.stopped")
        }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("status.processPid") }}</strong></div>
        <span class="md3-value">{{ status?.pid || "-" }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("status.token") }}</strong></div>
        <span class="md3-value">{{
          status?.token_configured ? t("status.configured") : t("status.notConfigured")
        }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("status.nodeName") }}</strong></div>
        <span class="md3-value">{{ status?.node || "-" }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("info.coreVersion") }}</strong></div>
        <span class="md3-value">{{ status?.version || "-" }}</span>
      </div>
    </div>

    <p class="md3-section-title">{{ t("status.virtualNic") }}</p>
    <div class="md3-card">
      <div class="md3-row">
        <div class="copy"><strong>{{ t("status.optun") }}</strong></div>
        <span class="md3-value">{{ tun?.optun === "up" ? t("status.up") : t("status.down") }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("status.virtualIp") }}</strong></div>
        <span class="md3-value">{{ tun?.addr || "-" }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("status.ipForward") }}</strong></div>
        <span class="md3-value">{{
          tun?.ip_forward === "1" ? t("status.on") : t("status.off")
        }}</span>
      </div>
    </div>

    <div class="md3-card">
      <div v-if="busy" class="md3-busy">
        <md-circular-progress indeterminate></md-circular-progress>
        <span>{{ busyLabel }}</span>
      </div>
      <div class="md3-actions">
        <md-filled-tonal-icon-button
          :aria-label="t('common.refresh')"
          :title="t('common.refresh')"
          :disabled="busy"
          @click="load"
        >
          <md-icon><svg viewBox="0 0 24 24"><path :d="ICONS.refresh" /></svg></md-icon>
        </md-filled-tonal-icon-button>
        <md-filled-button
          v-if="!status?.running"
          class="grow"
          :disabled="busy"
          @click="run('start', api.start, true)"
        >
          {{ t("status.start") }}
        </md-filled-button>
        <md-filled-button
          v-else
          class="grow"
          :disabled="busy"
          @click="run('stop', api.stop, false)"
        >
          {{ t("status.stop") }}
        </md-filled-button>
        <md-filled-tonal-button
          v-if="status?.running"
          class="grow"
          :disabled="busy"
          @click="run('restart', api.restart, true)"
        >
          {{ t("status.restart") }}
        </md-filled-tonal-button>
      </div>
    </div>
  </div>
</template>
