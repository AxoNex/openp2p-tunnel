<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { api } from "../../../lib/api";

const { t } = useI18n();

const log = ref(t("log.loading"));
const loading = ref(false);

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
        <md-filled-button class="grow" :disabled="loading" @click="load">
          {{ t("common.refresh") }}
        </md-filled-button>
      </div>
    </div>
  </div>
</template>
