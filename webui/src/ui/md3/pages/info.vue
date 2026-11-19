<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { api } from "../../../lib/api";
import { ICONS } from "../icons";
import {
  MODULE_NAME,
  MODULE_AUTHOR,
  MODULE_LICENSE,
  MODULE_ID,
  REPOSITORY_URL,
} from "../../../lib/constants";

const { t } = useI18n();

const moduleVersion = ref("");
const coreVersion = ref("");
const nodeName = ref("");

onMounted(async () => {
  try {
    moduleVersion.value = await api.getModuleVersion();
  } catch {
    // 忽略：桥接不可用或模块目录不可读时不阻塞页面渲染
  }
  try {
    const st = await api.getStatus();
    coreVersion.value = st.version;
    nodeName.value = st.node;
  } catch {
    // 忽略
  }
});
</script>

<template>
  <div>
    <div class="md3-hero">
      <h1>{{ MODULE_NAME }}</h1>
      <span class="sub">v{{ moduleVersion || "…" }}</span>
      <span class="meta">{{ MODULE_LICENSE }} · {{ MODULE_AUTHOR }}</span>
    </div>

    <div class="md3-card">
      <md-text-button @click="api.openLink(REPOSITORY_URL)">
        <md-icon slot="icon">
          <svg viewBox="0 0 24 24"><path :d="ICONS.github" /></svg>
        </md-icon>
        {{ t("info.repository") }}
      </md-text-button>
    </div>

    <p class="md3-section-title">{{ t("info.moduleInfo") }}</p>
    <div class="md3-card">
      <div class="md3-row">
        <div class="copy"><strong>{{ t("info.moduleId") }}</strong></div>
        <span class="md3-value">{{ MODULE_ID }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("info.moduleVersion") }}</strong></div>
        <span class="md3-value">{{ moduleVersion || "-" }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("info.coreVersion") }}</strong></div>
        <span class="md3-value">{{ coreVersion || "-" }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("info.nodeName") }}</strong></div>
        <span class="md3-value">{{ nodeName || "-" }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("info.author") }}</strong></div>
        <span class="md3-value">{{ MODULE_AUTHOR }}</span>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy"><strong>{{ t("info.license") }}</strong></div>
        <span class="md3-value">{{ MODULE_LICENSE }}</span>
      </div>
    </div>

    <p class="md3-section-title">{{ t("info.components") }}</p>
    <div class="md3-card">
      <div class="md3-row">
        <div class="copy">
          <strong>openp2p</strong>
          <span>{{ t("info.openp2p") }}</span>
        </div>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy">
          <strong>miuix-vue</strong>
          <span>{{ t("info.miuixVue") }}</span>
        </div>
      </div>
      <hr class="md3-divider" />
      <div class="md3-row">
        <div class="copy">
          <strong>@material/web</strong>
          <span>{{ t("info.materialWeb") }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
