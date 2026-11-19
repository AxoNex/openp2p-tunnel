// SPDX-License-Identifier: Apache-2.0

import { ref } from "vue";
import { toast } from "kernelsu";
import { fetchAvailableLanguages, switchLocale } from "../../locales";
import type { UiStyle } from "../types";

const lang = ref("en-US");
const isReady = ref(false);
const uiStyle = ref<UiStyle>("md3");
const monetEnabled = ref(false);
const navindex = ref(0);
const availableLanguages = ref<{ code: string; display: string }[]>([]);

let toastHandler: ((text: string) => void) | undefined = toast;

export function notify(text: string): void {
  toastHandler?.(text);
}

function setToastHandler(handler?: (text: string) => void): void {
  toastHandler = handler;
}

function applyMonetClass(): void {
  // miuix 风格通过 .miuix-monet 把 KernelSU 的 --primary 等映射为 --m-color-* 令牌；
  // MD3 风格通过 .md3-monet 映射为 --md-sys-color-* 令牌。
  document.documentElement.classList.toggle(
    "miuix-monet",
    uiStyle.value === "miuix" && monetEnabled.value,
  );
  document.documentElement.classList.toggle(
    "md3-monet",
    uiStyle.value === "md3" && monetEnabled.value,
  );
}

function setLang(code: string): void {
  lang.value = code;
  void switchLocale(code);
}

function setUiStyle(style: UiStyle): void {
  uiStyle.value = style;
  localStorage.setItem("uiStyle", style);
  applyMonetClass();
}

function setMonetEnabled(enabled: boolean): void {
  monetEnabled.value = enabled;
  localStorage.setItem("monetEnabled", enabled ? "1" : "0");
  applyMonetClass();
}

function setNavindex(value: number): void {
  navindex.value = value;
}

async function init(): Promise<void> {
  try {
    availableLanguages.value = await fetchAvailableLanguages();
  } catch {
    // 忽略：语言列表加载失败不阻塞启动
  }
  const savedLocale = localStorage.getItem("locale") || "en-US";
  await switchLocale(savedLocale);
  lang.value = savedLocale;

  const savedStyle = localStorage.getItem("uiStyle");
  if (savedStyle === "miuix" || savedStyle === "md3") {
    uiStyle.value = savedStyle;
  }
  monetEnabled.value = localStorage.getItem("monetEnabled") === "1";
  applyMonetClass();
  isReady.value = true;
}

export const uiStore = {
  get lang() {
    return lang.value;
  },
  get isReady() {
    return isReady.value;
  },
  get uiStyle() {
    return uiStyle.value;
  },
  get monetEnabled() {
    return monetEnabled.value;
  },
  get navindex() {
    return navindex.value;
  },
  get availableLanguages() {
    return availableLanguages.value;
  },
  setToastHandler,
  setLang,
  setUiStyle,
  setMonetEnabled,
  setNavindex,
  init,
  notify,
};
