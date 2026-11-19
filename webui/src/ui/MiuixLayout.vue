<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import "miuix-vue/style.css";
import "./theme.css";
import type { Component } from "vue";
import {
  MiuixSnackbarHost,
  MiuixScrollArea,
  MiuixIcon,
  MiuixNavigationBar,
  MiuixTopAppBar,
} from "miuix-vue";
import { ScreenMirroring, Settings, Folder, Info } from "miuix-vue/icons";

const props = defineProps<{
  navindex: number;
  pages: Component[];
  titles: string[];
}>();

const emit = defineEmits<{
  (e: "update:navindex", value: number): void;
}>();

const navIcons = [ScreenMirroring, Settings, Folder, Info];

function selectTab(index: number): void {
  if (index === props.navindex) return;
  emit("update:navindex", index);
}
</script>

<template>
  <div class="app">
    <MiuixTopAppBar :large="false" title="OpenP2P Tunnel" class="app__top-app-bar" />

    <main class="app__body">
      <div
        v-for="(page, index) in pages"
        :key="index"
        v-show="navindex === index"
        class="app__page"
      >
        <MiuixScrollArea class="app__page-scroller">
          <component :is="page" />
        </MiuixScrollArea>
      </div>
    </main>

    <div class="app__bottom">
      <MiuixNavigationBar
        :model-value="navindex"
        :items="titles.map((label) => ({ label }))"
        @update:model-value="selectTab"
      >
        <template #icon="{ index }">
          <MiuixIcon :icon="navIcons[index]" :size="26" />
        </template>
      </MiuixNavigationBar>
    </div>
  </div>

  <MiuixSnackbarHost />
</template>

<style>
:root {
  --top-inset: var(--window-inset-top, 0px);
  --bottom-inset: var(--window-inset-bottom, 0px);
}

.app {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: var(--m-color-surface);
}

.app__body {
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

.app__page {
  height: 100%;
}

.app__top-app-bar {
  flex: none;
  padding-top: var(--top-inset);
}

.app__page-scroller {
  width: 100%;
  height: 100%;
}

.app__bottom {
  flex: none;
  z-index: 10;
  padding-bottom: var(--bottom-inset);
}
</style>
