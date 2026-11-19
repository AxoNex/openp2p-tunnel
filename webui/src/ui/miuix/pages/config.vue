<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
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
import { api } from "../../../lib/api";
import { uiStore } from "../../../lib/stores/uiStore";
import type { AppConfig, UpdateResult, UiStyle } from "../../../lib/types";

const { t } = useI18n();

const config = ref<AppConfig | null>(null);
const saving = ref(false);
const currentVersion = ref("");
const updateResult = ref<UpdateResult | null>(null);
const updating = ref(false);
const updateStage = ref("");
const showErrorDialog = ref(false);
const errorMessage = ref("");

// UI 偏好 (设置段)
const langCode = ref(uiStore.lang);
const styleCode = ref<UiStyle>(uiStore.uiStyle);
const monet = ref(uiStore.monetEnabled);

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
const autoClearLog = computed({
  get: () => config.value?.AutoClearLog ?? false,
  set: (v: boolean) => {
    if (config.value) config.value.AutoClearLog = v;
  },
});

async function load(): Promise<void> {
  try {
    config.value = await api.getConfig();
  } catch (e) {
    uiStore.notify((e as Error).message);
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

function stageLabel(stage: string): string {
  switch (stage) {
    case "checking":
      return t("config.checking");
    case "downloading":
      return t("config.downloading");
    case "restarting":
      return t("config.restarting");
    default:
      return stage;
  }
}

async function updateCore(): Promise<void> {
  updating.value = true;
  updateStage.value = t("config.checking");
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
          uiStore.notify(`${t("config.upToDateSnack")} (${result.current})`);
        } else if (result.ok) {
          uiStore.notify(t("config.updatedSnack", { version: result.new || "?" }));
        } else {
          showError(result.message || t("config.updateFailed"));
        }
        break;
      }
      if (st.running && st.stage) {
        updateStage.value = stageLabel(st.stage);
      }
    }
    if (!done) {
      showError(t("config.updateTimeout"));
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
  uiStore.notify(ok ? t("config.copied") : t("config.copyFailed"));
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
    uiStore.notify(t("config.saved"));
  } catch (e) {
    uiStore.notify((e as Error).message);
  } finally {
    saving.value = false;
  }
}

function onLangChange(): void {
  uiStore.setLang(langCode.value);
}

function onStyleChange(): void {
  uiStore.setUiStyle(styleCode.value);
}

function onMonetChange(): void {
  uiStore.setMonetEnabled(monet.value);
}

onMounted(() => {
  load();
  loadVersion();
});
</script>

<template>
  <div class="page">
    <MiuixSmallTitle :text="t('config.network')" />
    <MiuixCard class="card">
      <MiuixBasicComponent
        :title="t('config.tokenLabel')"
        :summary="t('config.tokenSummary')"
      >
        <template #start>
          <MiuixIcon :icon="Settings" weight="medium" />
        </template>
        <template #bottom>
          <MiuixInput
            v-model="token"
            :aria-label="t('config.tokenLabel')"
            :placeholder="t('config.tokenPlaceholder')"
          />
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent
        :title="t('config.nodeName')"
        :summary="t('config.nodeNameSummary')"
      >
        <template #bottom>
          <MiuixInput v-model="node" :aria-label="t('config.nodeName')" />
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('config.serverHost')">
        <template #bottom>
          <MiuixInput v-model="serverHost" :aria-label="t('config.serverHost')" />
        </template>
      </MiuixBasicComponent>
    </MiuixCard>

    <MiuixSmallTitle :text="t('config.options')" />
    <MiuixCard class="card">
      <MiuixBasicComponent :title="t('config.shareBandwidth')">
        <template #bottom>
          <MiuixInput
            v-model="shareBandwidth"
            :aria-label="t('config.shareBandwidth')"
            inputmode="numeric"
          />
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('config.skipTls')">
        <template #end>
          <MiuixSwitch v-model="insecure" />
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('config.autoClearLog')">
        <template #end>
          <MiuixSwitch v-model="autoClearLog" />
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('config.timezone')">
        <template #bottom>
          <MiuixInput v-model="timezone" :aria-label="t('config.timezone')" />
        </template>
      </MiuixBasicComponent>
    </MiuixCard>

    <MiuixSmallTitle :text="t('config.coreUpdate')" />
    <MiuixCard class="card">
      <MiuixBasicComponent
        :title="t('config.currentVersion')"
        :summary="t('config.coreUpdateSummary')"
      >
        <template #end>
          <MiuixText>{{ currentVersion || t("common.detecting") }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent
        v-if="updating"
        :title="t('config.updateProgress')"
        :summary="t('config.pleaseWait')"
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
        :title="updateResult.ok ? t('config.updateResult') : t('config.updateFailed')"
        :summary="updateResult.up_to_date ? t('config.upToDate') : updateResult.message"
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
          {{ updating ? t("config.updating") : t("config.updateToLatest") }}
        </MiuixButton>
      </div>
    </MiuixCard>

    <MiuixSmallTitle :text="t('config.settings')" />
    <MiuixCard class="card">
      <MiuixBasicComponent :title="t('common.language')">
        <template #bottom>
          <select v-model="langCode" class="native-select" @change="onLangChange">
            <option
              v-for="l in uiStore.availableLanguages"
              :key="l.code"
              :value="l.code"
            >
              {{ l.display }}
            </option>
          </select>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('common.uiStyle')">
        <template #bottom>
          <select v-model="styleCode" class="native-select" @change="onStyleChange">
            <option value="miuix">{{ t("common.miuixStyle") }}</option>
            <option value="md3">{{ t("common.md3Style") }}</option>
          </select>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('config.monetTheme')">
        <template #end>
          <MiuixSwitch v-model="monet" @update:model-value="onMonetChange" />
        </template>
      </MiuixBasicComponent>
    </MiuixCard>

    <!-- 更新失败弹窗 (不自动关闭, 可复制错误信息) -->
    <MiuixDialog
      v-model="showErrorDialog"
      :title="t('config.updateFailed')"
      :summary="errorMessage"
    >
      <template #default="{ close }">
        <div class="dialog-actions">
          <MiuixButton @click="copyError">{{ t("config.copyError") }}</MiuixButton>
          <MiuixButton type="primary" @click="close">{{ t("common.close") }}</MiuixButton>
        </div>
      </template>
    </MiuixDialog>

    <MiuixCard class="card action-card">
      <div class="action-bar">
        <MiuixIconButton
          :aria-label="t('common.reset')"
          :title="t('common.reset')"
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
          {{ t("common.save") }}
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

.native-select {
  width: 100%;
  padding: 10px 12px;
  border-radius: 12px;
  border: 1px solid var(--m-color-outline-variant, rgba(0, 0, 0, 0.2));
  background: var(--m-color-surface-container, transparent);
  color: var(--m-color-on-surface);
  font-size: 14px;
}
</style>
