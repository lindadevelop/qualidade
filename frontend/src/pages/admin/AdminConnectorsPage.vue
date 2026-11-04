<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import KpiCsvImport from '@/components/KpiCsvImport.vue'
import {ref} from 'vue'
import PlatformModule from '@/components/PlatformModule.vue'
const selected=ref('connectors')
const tabs=[{"table": "connectors", "label": "Conectores"}]
</script>
<template><div><PageHeader><template #title>Conectores</template><template #breadcrumb>Administração › Conectores</template></PageHeader><div class="sq-card"><PlatformModule :key="selected" :table="selected"/></div><KpiCsvImport/></div></template>
