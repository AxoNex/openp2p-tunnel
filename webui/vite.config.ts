// SPDX-License-Identifier: Apache-2.0

import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

const moduleId = process.env.MODULE_ID || "openp2p-tunnel";

export default defineConfig({
  base: "./",
  build: {
    // 产物输出到模块根目录的 webroot/, 供 KernelSU WebUI 自动加载
    outDir: "../webroot",
    // 不自动清空 webroot, 保留 icon.svg (module.prop 的 webuiIcon 依赖它)
    emptyOutDir: false,
    target: "esnext",
    chunkSizeWarningLimit: 1000,
  },
  define: {
    "import.meta.env.MODULE_ID": JSON.stringify(moduleId),
  },
  plugins: [
    vue({
      template: {
        compilerOptions: {
          isCustomElement: (tag) => tag.startsWith("md-"),
        },
      },
    }),
  ],
});
