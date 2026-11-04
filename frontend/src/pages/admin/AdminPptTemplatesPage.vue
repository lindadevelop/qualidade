<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import {ref} from 'vue'
import PlatformModule from '@/components/PlatformModule.vue'
const selected=ref('ppt_templates')
const tabs=[{"table": "ppt_templates", "label": "Templates PowerPoint"}]
</script>
<template><div><PageHeader><template #title>Templates PowerPoint</template><template #breadcrumb>Administração › Templates PowerPoint</template></PageHeader><div class="sq-card"><PlatformModule :key="selected" :table="selected"/></div></div></template>
