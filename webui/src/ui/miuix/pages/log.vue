<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { MiuixCard, MiuixSmallTitle, MiuixButton } from "miuix-vue";
import { api } from "../../../lib/api";
import { uiStore } from "../../../lib/stores/uiStore";

const { t } = useI18n();

const log = ref(t("log.loading"));
const loading = ref(false);
const clearing = ref(false);

async function load(): Promise<void> {
  loading.value = true;
  try {
    log.value = (await api.getLog(300)) || t("log.empty");
  } catch (e) {
    log.value = t("log.loadFailed", { message: (e as Error).message });
  } finally {
    loading.value = false;
  }
}

async function clear(): Promise<void> {
  clearing.value = true;
  try {
    await api.clearLog();
    log.value = t("log.empty");
    uiStore.notify(t("log.cleared"));
  } catch (e) {
    uiStore.notify((e as Error).message);
  } finally {
    clearing.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="page">
    <MiuixSmallTitle :text="t('log.title')" />
    <MiuixCard class="card log-card">
      <pre class="log-view">{{ log }}</pre>
    </MiuixCard>

    <MiuixCard class="card action-card">
      <div class="action-bar">
        <MiuixButton
          class="grow"
          :disabled="loading || clearing"
          @click="clear"
        >
          {{ t("log.clear") }}
        </MiuixButton>
        <MiuixButton
          type="primary"
          class="grow"
          :disabled="loading"
          @click="load"
        >
          {{ t("common.refresh") }}
        </MiuixButton>
      </div>
    </MiuixCard>
  </div>
</template>

<style scoped>
.log-card {
  overflow: hidden;
}

.log-view {
  margin: 0;
  padding: 12px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 12px;
  line-height: 1.5;
  white-space: pre-wrap;
  word-break: break-all;
  color: var(--m-color-on-surface);
  max-height: 50vh;
  overflow-y: auto;
}

.action-card {
  overflow: visible;
}

.action-bar {
  min-height: 56px;
  padding: 8px;
  display: flex;
  align-items: center;
}

.action-bar .grow {
  flex: 1;
}
</style>
