<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import {
  MiuixCard,
  MiuixSmallTitle,
  MiuixBasicComponent,
  MiuixText,
  MiuixButton,
  MiuixIconButton,
  MiuixIcon,
  MiuixProgressIndicator,
} from "miuix-vue";
import { Refresh, Settings } from "miuix-vue/icons";
import StatusCard from "../components/StatusCard.vue";
import { api } from "../../../lib/api";
import { uiStore } from "../../../lib/stores/uiStore";
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

const tokenLabel = computed(() =>
  status.value?.token_configured ? t("status.configured") : t("status.notConfigured"),
);

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
    // 命令已异步返回, 轮询状态直到到位 (转圈 + 实时更新卡片, 不阻塞 UI)
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
  <div class="page">
    <StatusCard
      class="status-banner"
      :status="statusKind"
      :label="statusTitle"
      :summary="statusSummary"
    />

    <MiuixSmallTitle :text="t('status.serviceInfo')" />
    <MiuixCard class="card">
      <MiuixBasicComponent :title="t('status.runState')">
        <template #start>
          <MiuixIcon :icon="Settings" weight="medium" />
        </template>
        <template #end>
          <MiuixText>{{ status?.running ? t("status.running") : t("status.stopped") }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('status.processPid')">
        <template #end>
          <MiuixText>{{ status?.pid || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('status.token')">
        <template #end>
          <MiuixText>{{ tokenLabel }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('status.nodeName')">
        <template #end>
          <MiuixText>{{ status?.node || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('info.coreVersion')">
        <template #end>
          <MiuixText>{{ status?.version || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
    </MiuixCard>

    <MiuixSmallTitle :text="t('status.virtualNic')" />
    <MiuixCard class="card">
      <MiuixBasicComponent :title="t('status.optun')">
        <template #start>
          <MiuixIcon :icon="Settings" weight="medium" />
        </template>
        <template #end>
          <MiuixText>{{ tun?.optun === "up" ? t("status.up") : t("status.down") }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('status.virtualIp')">
        <template #end>
          <MiuixText>{{ tun?.addr || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('status.ipForward')">
        <template #end>
          <MiuixText>{{ tun?.ip_forward === "1" ? t("status.on") : t("status.off") }}</MiuixText>
        </template>
      </MiuixBasicComponent>
    </MiuixCard>

    <MiuixCard class="card action-card">
      <div v-if="busy" class="busy-row">
        <MiuixProgressIndicator type="infinite" :size="20" />
        <MiuixText>{{ busyLabel }}</MiuixText>
      </div>
      <div class="action-bar">
        <MiuixIconButton
          :aria-label="t('common.refresh')"
          :title="t('common.refresh')"
          :disabled="busy"
          @click="load"
        >
          <MiuixIcon :icon="Refresh" :size="22" />
        </MiuixIconButton>
        <MiuixButton
          v-if="!status?.running"
          type="primary"
          class="grow"
          :disabled="busy"
          @click="run('start', api.start, true)"
        >
          {{ t("status.start") }}
        </MiuixButton>
        <MiuixButton
          v-else
          class="grow"
          :disabled="busy"
          @click="run('stop', api.stop, false)"
        >
          {{ t("status.stop") }}
        </MiuixButton>
        <MiuixButton
          v-if="status?.running"
          class="grow"
          :disabled="busy"
          @click="run('restart', api.restart, true)"
        >
          {{ t("status.restart") }}
        </MiuixButton>
      </div>
    </MiuixCard>
  </div>
</template>

<style scoped>
.status-banner {
  margin: 0 12px 12px;
}

.action-card {
  overflow: visible;
}

.action-bar {
  min-height: 56px;
  padding: 8px;
  display: flex;
  align-items: center;
  gap: 10px;
}

.action-bar .grow {
  flex: 1;
}

.busy-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 16px;
}
</style>
