<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
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
import { showSnackbar } from "miuix-vue";
import StatusCard from "../components/StatusCard.vue";
import { api } from "../../lib/api";
import type { ServiceStatus, TunStatus } from "../../lib/types";

const status = ref<ServiceStatus | null>(null);
const tun = ref<TunStatus | null>(null);
const busy = ref(false);
const busyLabel = ref("");

const statusKind = computed<"checking" | "normal" | "abnormal">(() => {
  if (!status.value) return "checking";
  return status.value.running ? "normal" : "abnormal";
});

const statusTitle = computed(() => {
  if (!status.value) return "检测中…";
  return status.value.running ? "运行中" : "已停止";
});

const statusSummary = computed(() => {
  if (!status.value) return "正在获取服务状态";
  if (status.value.running) return `版本 ${status.value.version || "-"}`;
  if (!status.value.token_configured) return "尚未配置 Token，请到「配置」页填写";
  return "点击下方按钮启动服务";
});

const tokenLabel = computed(() =>
  status.value?.token_configured ? "已配置" : "未配置",
);

async function load(): Promise<void> {
  try {
    const [s, t] = await Promise.all([api.getStatus(), api.getTun()]);
    status.value = s;
    tun.value = t;
  } catch (e) {
    showSnackbar({ message: (e as Error).message });
  }
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

async function run(
  fn: () => Promise<unknown>,
  label: string,
  expectRunning: boolean,
): Promise<void> {
  busy.value = true;
  busyLabel.value = `${label}中…`;
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
    showSnackbar({ message: matched ? `${label}完成` : `${label}超时，请稍后刷新` });
  } catch (e) {
    showSnackbar({ message: (e as Error).message });
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

    <MiuixSmallTitle text="服务信息" />
    <MiuixCard class="card">
      <MiuixBasicComponent title="运行状态">
        <template #start>
          <MiuixIcon :icon="Settings" weight="medium" />
        </template>
        <template #end>
          <MiuixText>{{ status?.running ? "运行中" : "已停止" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="进程 PID">
        <template #end>
          <MiuixText>{{ status?.pid || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="Token">
        <template #end>
          <MiuixText>{{ tokenLabel }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="节点名称">
        <template #end>
          <MiuixText>{{ status?.node || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="版本">
        <template #end>
          <MiuixText>{{ status?.version || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
    </MiuixCard>

    <MiuixSmallTitle text="虚拟网卡" />
    <MiuixCard class="card">
      <MiuixBasicComponent title="optun 网卡">
        <template #start>
          <MiuixIcon :icon="Settings" weight="medium" />
        </template>
        <template #end>
          <MiuixText>{{ tun?.optun === "up" ? "已上线" : "未建立" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="虚拟 IP">
        <template #end>
          <MiuixText>{{ tun?.addr || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="IPv4 转发">
        <template #end>
          <MiuixText>{{ tun?.ip_forward === "1" ? "已开启" : "未开启" }}</MiuixText>
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
          aria-label="刷新"
          title="刷新"
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
          @click="run(api.start, '启动', true)"
        >
          启动
        </MiuixButton>
        <MiuixButton
          v-else
          class="grow"
          :disabled="busy"
          @click="run(api.stop, '停止', false)"
        >
          停止
        </MiuixButton>
        <MiuixButton
          v-if="status?.running"
          class="grow"
          :disabled="busy"
          @click="run(api.restart, '重启', true)"
        >
          重启
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
