<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
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
  <div>
    <p class="md3-section-title">{{ t("log.title") }}</p>
    <div class="md3-card">
      <pre class="md3-log">{{ log }}</pre>
    </div>

    <div class="md3-card">
      <div class="md3-actions">
        <md-outlined-button
          class="grow"
          :disabled="loading || clearing"
          @click="clear"
        >
          {{ t("log.clear") }}
        </md-outlined-button>
        <md-filled-button class="grow" :disabled="loading" @click="load">
          {{ t("common.refresh") }}
        </md-filled-button>
      </div>
    </div>
  </div>
</template>
