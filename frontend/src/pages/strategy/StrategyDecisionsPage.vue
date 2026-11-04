<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import {ref} from 'vue'
import PlatformModule from '@/components/PlatformModule.vue'
const selected=ref('decisions')
const tabs=[{"table": "decisions", "label": "Decisões"}]
</script>
<template><div><PageHeader><template #title>Decisões</template><template #breadcrumb>Estratégia › Decisões</template></PageHeader><div class="sq-card"><PlatformModule :key="selected" :table="selected"/></div></div></template>
