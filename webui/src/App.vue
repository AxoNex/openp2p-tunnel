<!-- SPDX-License-Identifier: Apache-2.0 -->
<script setup lang="ts">
import { ref } from "vue";
import MiuixLayout from "./ui/MiuixLayout.vue";
import StatusPage from "./ui/pages/status.vue";
import ConfigPage from "./ui/pages/config.vue";
import LogPage from "./ui/pages/log.vue";
import InfoPage from "./ui/pages/info.vue";

const pages = [StatusPage, ConfigPage, LogPage, InfoPage];
const titles = ["状态", "配置", "日志", "关于"];
const navindex = ref(0);
</script>

<template>
  <MiuixLayout v-model:navindex="navindex" :pages="pages" :titles="titles" />
</template>
