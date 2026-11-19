/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly MODULE_ID: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

declare module "*.vue" {
  import type { DefineComponent } from "vue";
  const component: DefineComponent<Record<string, unknown>, Record<string, unknown>, unknown>;
  export default component;
}

declare module "miuix-vue";
declare module "miuix-vue/icons";
