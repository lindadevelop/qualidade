<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import {ref} from 'vue'
import PlatformModule from '@/components/PlatformModule.vue'
const selected=ref('brand_kits')
const tabs=[{"table": "brand_kits", "label": "Identidade visual"}]
</script>
<template><div><PageHeader><template #title>Identidade visual</template><template #breadcrumb>Administração › Identidade visual</template></PageHeader><div class="sq-card"><PlatformModule :key="selected" :table="selected"/></div></div></template>
