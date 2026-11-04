<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import {ref} from 'vue'
import PlatformModule from '@/components/PlatformModule.vue'
const selected=ref('frameworks')
const tabs=[{"table": "frameworks", "label": "Frameworks"}, {"table": "cycles", "label": "Ciclos"}]
</script>
<template><div><PageHeader><template #title>Frameworks</template><template #breadcrumb>Administração › Frameworks</template></PageHeader><p>O framework define o modelo de gestão reutilizável. Cada ciclo representa um período: por exemplo, o mesmo framework pode ter os ciclos 2026 e 2027.</p><nav class="sq-tabs" aria-label="Secções"><button v-for="tab in tabs" :key="tab.table" class="sq-tab" :class="{active:selected===tab.table}" :aria-pressed="selected===tab.table" @click="selected=tab.table">{{ tab.label }}</button></nav><div class="sq-card"><PlatformModule :key="selected" :table="selected"/></div></div></template>
