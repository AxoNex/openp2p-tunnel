<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import {
  MiuixCard,
  MiuixSmallTitle,
  MiuixBasicComponent,
  MiuixText,
  MiuixArrowPreference,
} from "miuix-vue";
import { api } from "../../../lib/api";
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
    // 忽略：桥接不可用或服务未就绪时不阻塞页面渲染
  }
});
</script>

<template>
  <div class="page">
    <div class="about-hero">
      <h1>{{ MODULE_NAME }}</h1>
      <MiuixText color="var(--m-color-on-background)" type="subtitle">
        v{{ moduleVersion || "…" }}
      </MiuixText>
      <MiuixText color="var(--m-color-on-background)" type="body2">
        {{ MODULE_LICENSE }} · {{ MODULE_AUTHOR }}
      </MiuixText>
    </div>

    <MiuixCard class="card" style="padding-top: 12px">
      <MiuixArrowPreference
        :title="t('info.repository')"
        :summary="REPOSITORY_URL"
        clickable
        @click="api.openLink(REPOSITORY_URL)"
      />
    </MiuixCard>

    <MiuixSmallTitle :text="t('info.moduleInfo')" />
    <MiuixCard class="card">
      <MiuixBasicComponent :title="t('info.moduleId')">
        <template #end>
          <MiuixText>{{ MODULE_ID }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('info.moduleVersion')">
        <template #end>
          <MiuixText>{{ moduleVersion || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('info.coreVersion')">
        <template #end>
          <MiuixText>{{ coreVersion || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('info.nodeName')">
        <template #end>
          <MiuixText>{{ nodeName || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('info.author')">
        <template #end>
          <MiuixText>{{ MODULE_AUTHOR }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent :title="t('info.license')">
        <template #end>
          <MiuixText>{{ MODULE_LICENSE }}</MiuixText>
        </template>
      </MiuixBasicComponent>
    </MiuixCard>

    <MiuixSmallTitle :text="t('info.components')" />
    <MiuixCard class="card">
      <MiuixBasicComponent title="openp2p" :summary="t('info.openp2p')" />
      <MiuixBasicComponent title="miuix-vue" :summary="t('info.miuixVue')" />
      <MiuixBasicComponent title="@material/web" :summary="t('info.materialWeb')" />
    </MiuixCard>
  </div>
</template>

<style scoped>
.about-hero {
  padding: 24px 16px 8px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  text-align: center;
}

.about-hero h1 {
  margin: 0;
  font-size: 24px;
  font-weight: 600;
  color: var(--m-color-on-background);
}

.about-hero span {
  color: var(--m-color-on-surface-variant, rgba(0, 0, 0, 0.6));
  font-size: var(--m-text-body2-size, 14px);
}
</style>
