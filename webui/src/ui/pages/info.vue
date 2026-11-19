<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { onMounted, ref } from "vue";
import {
  MiuixCard,
  MiuixSmallTitle,
  MiuixBasicComponent,
  MiuixText,
  MiuixArrowPreference,
} from "miuix-vue";
import { api } from "../../lib/api";
import {
  MODULE_NAME,
  MODULE_VERSION,
  MODULE_AUTHOR,
  MODULE_LICENSE,
  MODULE_ID,
  REPOSITORY_URL,
} from "../../lib/constants";

const coreVersion = ref("");
const nodeName = ref("");

onMounted(async () => {
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
        v{{ MODULE_VERSION }}
      </MiuixText>
      <MiuixText color="var(--m-color-on-background)" type="body2">
        {{ MODULE_LICENSE }} · {{ MODULE_AUTHOR }}
      </MiuixText>
    </div>

    <MiuixCard class="card" style="padding-top: 12px">
      <MiuixArrowPreference
        title="开源仓库"
        summary="github.com/AxoNex/openp2p-tunnel"
        clickable
        @click="api.openLink(REPOSITORY_URL)"
      />
    </MiuixCard>

    <MiuixSmallTitle text="模块信息" />
    <MiuixCard class="card">
      <MiuixBasicComponent title="模块 ID">
        <template #end>
          <MiuixText>{{ MODULE_ID }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="模块版本">
        <template #end>
          <MiuixText>{{ MODULE_VERSION }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="核心版本">
        <template #end>
          <MiuixText>{{ coreVersion || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="节点名称">
        <template #end>
          <MiuixText>{{ nodeName || "-" }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="作者">
        <template #end>
          <MiuixText>{{ MODULE_AUTHOR }}</MiuixText>
        </template>
      </MiuixBasicComponent>
      <MiuixBasicComponent title="许可证">
        <template #end>
          <MiuixText>{{ MODULE_LICENSE }}</MiuixText>
        </template>
      </MiuixBasicComponent>
    </MiuixCard>

    <MiuixSmallTitle text="开源组件" />
    <MiuixCard class="card">
      <MiuixBasicComponent
        title="openp2p"
        summary="OpenP2P 内网穿透内核，随模块打包 linux-arm64 构建"
      />
      <MiuixBasicComponent
        title="miuix-vue"
        summary="Miuix 风格 Vue 3 组件库，驱动本 WebUI 界面"
      />
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
