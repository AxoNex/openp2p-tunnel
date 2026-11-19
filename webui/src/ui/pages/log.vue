<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { onMounted, ref } from "vue";
import { MiuixCard, MiuixSmallTitle, MiuixButton } from "miuix-vue";
import { api } from "../../lib/api";

const log = ref("正在加载日志…");
const loading = ref(false);

async function load(): Promise<void> {
  loading.value = true;
  try {
    log.value = (await api.getLog(300)) || "(无日志)";
  } catch (e) {
    log.value = `加载失败: ${(e as Error).message}`;
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="page">
    <MiuixSmallTitle text="运行日志" />
    <MiuixCard class="card log-card">
      <pre class="log-view">{{ log }}</pre>
    </MiuixCard>

    <MiuixCard class="card action-card">
      <div class="action-bar">
        <MiuixButton
          type="primary"
          class="grow"
          :disabled="loading"
          @click="load"
        >
          刷新
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
