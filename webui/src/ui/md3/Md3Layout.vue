<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import "./material";
import "./theme.css";
import { onBeforeUnmount, onMounted, ref, type Component } from "vue";
import { useI18n } from "vue-i18n";
import { uiStore } from "../../lib/stores/uiStore";
import { ICONS } from "./icons";

const { t } = useI18n();

const props = defineProps<{
  navindex: number;
  pages: Component[];
  titles: string[];
}>();

const emit = defineEmits<{
  (event: "update:navindex", value: number): void;
}>();

const toastText = ref("");
const navIconKeys = ["home", "settings", "description", "info"] as const;
let toastTimer = 0;

function showToast(text: string): void {
  toastText.value = text;
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => {
    toastText.value = "";
  }, 2600);
}

function selectTab(index: number): void {
  if (index === props.navindex) return;
  emit("update:navindex", index);
}

function iconPath(index: number): string {
  const key = navIconKeys[index];
  const filledKey = `${key}_filled` as keyof typeof ICONS;
  const filled = ICONS[filledKey];
  return props.navindex === index && filled ? filled : ICONS[key];
}

onMounted(() => {
  document.documentElement.classList.add("md3-active");
  uiStore.setToastHandler(showToast);
});

onBeforeUnmount(() => {
  document.documentElement.classList.remove("md3-active");
  uiStore.setToastHandler();
  window.clearTimeout(toastTimer);
});
</script>

<template>
  <div class="app-root">
    <header class="top-bar">
      <div class="top-bar-content">
        <h1 class="screen-title">{{ t("common.appName") }}</h1>
      </div>
    </header>

    <main class="main-content">
      <div
        v-for="(page, index) in pages"
        :key="index"
        v-show="navindex === index"
        class="page-scroller"
      >
        <component :is="page" />
      </div>
    </main>

    <nav class="bottom-nav" :aria-label="t('common.appName')">
      <button
        v-for="(title, index) in titles"
        :key="title"
        type="button"
        class="nav-tab"
        :class="{ active: navindex === index }"
        @click="selectTab(index)"
      >
        <span class="icon-container">
          <md-icon>
            <svg viewBox="0 0 24 24"><path :d="iconPath(index)" /></svg>
          </md-icon>
        </span>
        <span class="label">{{ title }}</span>
      </button>
    </nav>

    <Transition name="toast">
      <div v-if="toastText" class="md3-toast" role="status">{{ toastText }}</div>
    </Transition>
  </div>
</template>
