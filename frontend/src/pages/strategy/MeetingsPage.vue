<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import {ref} from 'vue'
import PlatformModule from '@/components/PlatformModule.vue'
const selected=ref('meetings')
const tabs=[{"table": "meetings", "label": "Reuniões"}, {"table": "meeting_presenters", "label": "Participantes"}]
</script>
<template><div><PageHeader><template #title>Reuniões</template><template #breadcrumb>Estratégia › Reuniões</template></PageHeader><nav class="sq-tabs" aria-label="Secções"><button v-for="tab in tabs" :key="tab.table" class="sq-tab" :class="{active:selected===tab.table}" :aria-pressed="selected===tab.table" @click="selected=tab.table">{{ tab.label }}</button></nav><div class="sq-card"><PlatformModule :key="selected" :table="selected"/></div></div></template>
