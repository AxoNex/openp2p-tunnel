<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import {
  MiuixCard,
  MiuixSmallTitle,
  MiuixBasicComponent,
  MiuixSwitch,
  MiuixInput,
  MiuixButton,
  MiuixIcon,
  MiuixIconButton,
  MiuixText,
  MiuixProgressIndicator,
  MiuixDialog,
} from "miuix-vue";
import { Refresh, Settings } from "miuix-vue/icons";
import { showSnackbar } from "miuix-vue";
import { api } from "../../lib/api";
import type { AppConfig, UpdateResult } from "../../lib/types";

const config = ref<AppConfig | null>(null);
const saving = ref(false);
const currentVersion = ref("");
const updateResult = ref<UpdateResult | null>(null);
const updating = ref(false);
const updateStage = ref("");
const showErrorDialog = ref(false);
const errorMessage = ref("");

const token = computed({
  get: () => config.value?.network.Token ?? "",
  set: (v: string) => {
    if (config.value) config.value.network.Token = v;
  },
});
const node = computed({
  get: () => config.value?.network.Node ?? "",
  set: (v: string) => {
    if (config.value) config.value.network.Node = v;
  },
});
const serverHost = computed({
  get: () => config.value?.network.ServerHost ?? "api.openp2p.cn",
  set: (v: string) => {
    if (config.value) config.value.network.ServerHost = v;
  },
});
const shareBandwidth = computed({
  get: () => String(config.value?.network.ShareBandwidth ?? 3),
  set: (v: string) => {
    if (config.value) config.value.network.ShareBandwidth = Number(v) || 0;
  },
});
const insecure = computed({
  get: () => config.value?.TLSInsecureSkipVerify ?? false,
  set: (v: boolean) => {
    if (config.value) config.value.TLSInsecureSkipVerify = v;
  },
});
const timezone = computed({
  get: () => config.value?.Timezone ?? "Asia/Shanghai",
  set: (v: string) => {
    if (config.value) config.value.Timezone = v;
  },
});

async function load(): Promise<void> {
  try {
    config.value = await api.getConfig();
  } catch (e) {
    showSnackbar({ message: (e as Error).message });
  }
}

async function loadVersion(): Promise<void> {
  try {
    currentVersion.value = (await api.getStatus()).version;
  } catch {
    currentVersion.value = "";
  }
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

const stageText: Record<string, string> = {
  checking: "正在下载并检查最新版本…",
  downloading: "已发现新版本，正在下载替换…",
  restarting: "替换完成，正在重启服务…",
};

async function updateCore(): Promise<void> {
  updating.value = true;
  updateStage.value = stageText.checking;
  updateResult.value = null;
  try {
    await api.update(); // 异步启动后台任务, 立即返回
    const deadline = Date.now() + 120000; // 更新最多约 2 分钟
    let done = false;
    while (Date.now() < deadline) {
      await sleep(800);
      const st = await api.getUpdateStatus().catch(() => null);
      if (!st) continue;
      if (st.done) {
        done = true;
        const result: UpdateResult = {
          ok: !!st.ok,
          current: st.current ?? "",
          new: st.new ?? "",
          up_to_date: !!st.up_to_date,
          message: st.message ?? "",
        };
        updateResult.value = result;
        if (result.up_to_date) {
          showSnackbar({ message: `已是最新版本 (${result.current})` });
        } else if (result.ok) {
          showSnackbar({ message: `核心已更新到 ${result.new || "最新版本"}` });
        } else {
          showError(result.message || "更新失败");
        }
        break;
      }
      if (st.running && st.stage) {
        updateStage.value = stageText[st.stage] ?? st.stage;
      }
    }
    if (!done) {
      showError("更新超时，请在终端运行 openp2pctl update --human 查看详情");
    }
    await loadVersion();
  } catch (e) {
    showError((e as Error).message);
  } finally {
    updating.value = false;
    updateStage.value = "";
  }
}

function showError(msg: string): void {
  errorMessage.value = msg;
  showErrorDialog.value = true;
}

async function copyError(): Promise<void> {
  const ok = await copyText(errorMessage.value);
  showSnackbar({ message: ok ? "已复制到剪贴板" : "复制失败" });
}

async function copyText(text: string): Promise<boolean> {
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    // 回退到 execCommand
  }
  try {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    const ok = document.execCommand("copy");
    document.body.removeChild(ta);
    return ok;
  } catch {
    return false;
  }
}

async function save(): Promise<void> {
  if (!config.value) return;
  saving.value = true;
  try {
    await api.saveConfig(config.value);
    showSnackbar({ message: "配置已保存（不会自动重启，需手动启动/重启后生效）" });
  } catch (e) {
    showSnackbar({ message: (e as Error).message });
  } finally {
    saving.value = false;
  }
}

onMounted(() => {
  load();
  loadVersion();
});
</script>

<template>
  <div class="page">
    <MiuixSmallTitle text="网络" />
    <MiuixCard class="card">
      <MiuixBasicComponent
        title="Token"
        summary="在 openp2p 控制台获取"
      >
        <template #start>
          <MiuixIcon :icon="Settings" weight="medium" />
        </template>
        <template #bottom>
          <MiuixInput v-model="token" aria-label="Token" placeholder="请输入 Token" />
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent
        title="节点名称"
        summary="留空则自动使用「品牌-型号」"
      >
        <template #bottom>
          <MiuixInput v-model="node" aria-label="节点名称" placeholder="自动" />
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="服务器地址">
        <template #bottom>
          <MiuixInput v-model="serverHost" aria-label="服务器地址" />
        </template>
      </MiuixBasicComponent>
    </MiuixCard>

    <MiuixSmallTitle text="选项" />
    <MiuixCard class="card">
      <MiuixBasicComponent title="共享带宽 (Mbps)">
        <template #bottom>
          <MiuixInput v-model="shareBandwidth" aria-label="共享带宽" inputmode="numeric" />
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="跳过 TLS 证书校验">
        <template #end>
          <MiuixSwitch v-model="insecure" />
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="时区">
        <template #bottom>
          <MiuixInput v-model="timezone" aria-label="时区" />
        </template>
      </MiuixBasicComponent>
    </MiuixCard>

    <MiuixSmallTitle text="核心更新" />
    <MiuixCard class="card">
      <MiuixBasicComponent
        title="当前版本"
        summary="从 openp2p 控制台下载最新 linux-arm64 核心"
      >
        <template #end>
          <MiuixText>{{ currentVersion || "检测中…" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent
        v-if="updating"
        title="更新进度"
        summary="请勿关闭页面"
      >
        <template #end>
          <MiuixProgressIndicator type="infinite" :size="20" />
        </template>
        <template #bottom>
          <MiuixText>{{ updateStage }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent
        v-else-if="updateResult"
        :title="updateResult.ok ? '更新结果' : '更新失败'"
        :summary="updateResult.up_to_date ? '已是最新版本，无需更新' : updateResult.message"
      >
        <template #end>
          <MiuixText>{{ updateResult.new || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
    </MiuixCard>
    <MiuixCard class="card action-card">
      <div class="action-bar">
        <MiuixButton
          type="primary"
          class="grow"
          :disabled="updating"
          @click="updateCore"
        >
          {{ updating ? "更新中…" : "更新到最新核心" }}
        </MiuixButton>
      </div>
    </MiuixCard>

    <!-- 更新失败弹窗 (不自动关闭, 可复制错误信息) -->
    <MiuixDialog
      v-model="showErrorDialog"
      title="更新失败"
      :summary="errorMessage"
    >
      <template #default="{ close }">
        <div class="dialog-actions">
          <MiuixButton @click="copyError">复制错误信息</MiuixButton>
          <MiuixButton type="primary" @click="close">关闭</MiuixButton>
        </div>
      </template>
    </MiuixDialog>

    <MiuixCard class="card action-card">
      <div class="action-bar">
        <MiuixIconButton
          aria-label="重置"
          title="重新加载"
          :disabled="saving"
          @click="load"
        >
          <MiuixIcon :icon="Refresh" :size="22" />
        </MiuixIconButton>
        <MiuixButton
          type="primary"
          class="grow"
          :disabled="saving || !config"
          @click="save"
        >
          保存
        </MiuixButton>
      </div>
    </MiuixCard>
  </div>
</template>

<style scoped>
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

.dialog-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 8px;
}
</style>
