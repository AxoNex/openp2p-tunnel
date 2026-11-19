// SPDX-License-Identifier: Apache-2.0

import { createApp } from "vue";
import App from "./App.vue";
import i18n from "./locales";
import { uiStore } from "./lib/stores/uiStore";
import "./style.css";

const MANAGER_COLORS_URL = "https://mui.kernelsu.org/internal/colors.css";

// 动态加载 KernelSU 管理器的 Monet 颜色令牌（--primary / --md-sys-color-*）。
// 加载失败时静默移除，不影响页面渲染。
function loadOptionalManagerColors(): void {
  try {
    const link = document.createElement("link");
    link.rel = "stylesheet";
    link.href = MANAGER_COLORS_URL;
    link.dataset.managerColors = "true";
    link.onerror = () => link.remove();
    document.head.appendChild(link);
  } catch {
    // 忽略
  }
}

const app = createApp(App).use(i18n);

async function init(): Promise<void> {
  await uiStore.init();
  loadOptionalManagerColors();
  app.mount("#app");
}

void init();
