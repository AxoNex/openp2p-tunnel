// SPDX-License-Identifier: Apache-2.0

import { createI18n } from "vue-i18n";
import { MODULE_ID } from "../lib/constants";

type LocaleMessage = { [key: string]: LocaleMessage | string };

const i18n = createI18n({
  legacy: false,
  locale: "en-US",
  fallbackLocale: "en-US",
  messages: {} as { [locale: string]: LocaleMessage },
});

const localeModules = import.meta.glob("./*.json", { eager: false });

export interface AvailableLanguage {
  code: string;
  display: string;
}

export async function fetchAvailableLanguages(): Promise<AvailableLanguage[]> {
  const out: AvailableLanguage[] = [];
  for (const [path, loader] of Object.entries(localeModules)) {
    const code = path.slice(2, -5); // "./zh-CN.json" -> "zh-CN"
    try {
      const mod = (await loader()) as {
        default?: { lang?: { display?: string } };
      };
      out.push({ code, display: mod.default?.lang?.display ?? code });
    } catch {
      out.push({ code, display: code });
    }
  }
  return out.sort((a, b) => a.code.localeCompare(b.code));
}

async function loadLocale(code: string): Promise<void> {
  const loader = localeModules[`./${code}.json`];
  if (!loader) return;
  const mod = (await loader()) as { default?: LocaleMessage };
  if (mod.default) {
    i18n.global.setLocaleMessage(code, mod.default as never);
  }
}

export async function switchLocale(locale: string): Promise<void> {
  await loadLocale("en-US");
  if (locale !== "en-US") await loadLocale(locale);
  i18n.global.locale.value = locale;
  localStorage.setItem(`${MODULE_ID}.locale`, locale);
  document.documentElement.lang = locale;
}

export default i18n;
