<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { api } from "../../lib/api";
import { uiStore } from "../../lib/stores/uiStore";
import { ICONS } from "../icons";
import type { AppConfig, UpdateResult, UiStyle } from "../../lib/types";

const { t } = useI18n();

const config = ref<AppConfig | null>(null);
const saving = ref(false);
const currentVersion = ref("");
const updateResult = ref<UpdateResult | null>(null);
const updating = ref(false);
const updateStage = ref("");
const showErrorDialog = ref(false);
const errorMessage = ref("");

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

function eventValue(event: Event): string {
  return String((event.target as HTMLInputElement).value ?? "");
}

function eventSelected(event: Event): boolean {
  return Boolean((event.target as HTMLElement & { selected?: boolean }).selected);
}

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
    await api.update();
    const deadline = Date.now() + 120000;
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

function onMonetChange(event: Event): void {
  monet.value = eventSelected(event);
  uiStore.setMonetEnabled(monet.value);
}

onMounted(() => {
  load();
  loadVersion();
});
</script>

<template>
  <div>
    <p class="md3-section-title">{{ t("config.network") }}</p>
    <div class="md3-card">
      <md-outlined-text-field
        class="field"
        :label="t('config.tokenLabel')"
        :supporting-text="t('config.tokenSummary')"
        :value="token"
        @input="token = eventValue($event)"
      />
      <md-outlined-text-field
        class="field"
        :label="t('config.nodeName')"
        :supporting-text="t('config.nodeNameSummary')"
        :value="node"
        @input="node = eventValue($event)"
      />
      <md-outlined-text-field
        class="field"
        :label="t('config.serverHost')"
        :value="serverHost"
        @input="serverHost = eventValue($event)"
      />
    </div>

    <p class="md3-section-title">{{ t("config.options") }}</p>
    <div class="md3-card">
      <md-outlined-text-field
        class="field"
        type="number"
        :label="t('config.shareBandwidth')"
        :value="shareBandwidth"
        @input="shareBandwidth = eventValue($event)"
      />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("config.skipTls") }}</strong></div>
        <md-switch :selected="insecure" @change="insecure = eventSelected($event)" />
      </div>
      <hr class="md3-divider" />
      <md-outlined-text-field
        class="field"
        :label="t('config.timezone')"
        :value="timezone"
        @input="timezone = eventValue($event)"
      />
    </div>

    <p class="md3-section-title">{{ t("config.coreUpdate") }}</p>
    <div class="md3-card">
      <div class="md3-row">
        <div class="copy">
          <strong>{{ t("config.currentVersion") }}</strong>
          <span>{{ t("config.coreUpdateSummary") }}</span>
        </div>
        <span class="md3-value">{{ currentVersion || t("common.detecting") }}</span>
      </div>
      <template v-if="updating">
        <hr class="md3-divider" />
        <div class="md3-busy">
          <md-circular-progress indeterminate></md-circular-progress>
          <span>{{ updateStage }}</span>
        </div>
      </template>
      <template v-else-if="updateResult">
        <hr class="md3-divider" />
        <div class="md3-row">
          <div class="copy">
            <strong>{{
              updateResult.ok ? t("config.updateResult") : t("config.updateFailed")
            }}</strong>
            <span>{{ updateResult.up_to_date ? t("config.upToDate") : updateResult.message }}</span>
          </div>
          <span class="md3-value">{{ updateResult.new || "-" }}</span>
        </div>
      </template>
      <div class="md3-actions" style="margin-top: 12px">
        <md-filled-button class="grow" :disabled="updating" @click="updateCore">
          {{ updating ? t("config.updating") : t("config.updateToLatest") }}
        </md-filled-button>
      </div>
    </div>

    <p class="md3-section-title">{{ t("config.settings") }}</p>
    <div class="md3-card">
      <div class="md3-row">
        <div class="copy"><strong>{{ t("common.language") }}</strong></div>
        <select v-model="langCode" class="md3-select" @change="onLangChange">
          <option
            v-for="l in uiStore.availableLanguages"
            :key="l.code"
            :value="l.code"
          >
            {{ l.display }}
          </option>
        </select>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("common.uiStyle") }}</strong></div>
        <select v-model="styleCode" class="md3-select" @change="onStyleChange">
          <option value="miuix">{{ t("common.miuixStyle") }}</option>
          <option value="md3">{{ t("common.md3Style") }}</option>
        </select>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("config.monetTheme") }}</strong></div>
        <md-switch :selected="monet" @change="onMonetChange($event)" />
      </div>
    </div>

    <md-dialog :open="showErrorDialog" @closed="showErrorDialog = false">
      <div slot="headline">{{ t("config.updateFailed") }}</div>
      <div>{{ errorMessage }}</div>
      <div slot="actions">
        <md-text-button @click="copyError">{{ t("config.copyError") }}</md-text-button>
        <md-text-button @click="showErrorDialog = false">
          {{ t("common.close") }}
        </md-text-button>
      </div>
    </md-dialog>

    <div class="md3-card">
      <div class="md3-actions">
        <md-filled-tonal-icon-button
          :aria-label="t('common.reset')"
          :title="t('common.reset')"
          :disabled="saving"
          @click="load"
        >
          <md-icon><svg viewBox="0 0 24 24"><path :d="ICONS.reset" /></svg></md-icon>
        </md-filled-tonal-icon-button>
        <md-filled-button class="grow" :disabled="saving || !config" @click="save">
          {{ t("common.save") }}
        </md-filled-button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.field {
  width: 100%;
  display: block;
  margin-bottom: 12px;
}
</style>
