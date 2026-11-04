<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import {ref} from 'vue'
import PlatformModule from '@/components/PlatformModule.vue'
const selected=ref('organizations')
const tabs=[{"table": "organizations", "label": "Organizações"}, {"table": "teams", "label": "Equipas"}, {"table": "organization_memberships", "label": "Membros"}]
</script>
<template><div><PageHeader><template #title>Organizações</template><template #breadcrumb>Administração › Organizações</template></PageHeader><nav class="sq-tabs" aria-label="Secções"><button v-for="tab in tabs" :key="tab.table" class="sq-tab" :class="{active:selected===tab.table}" :aria-pressed="selected===tab.table" @click="selected=tab.table">{{ tab.label }}</button></nav><div v-if="selected==='organization_memberships'" class="alert alert-info"><strong>Uma pessoa, uma conta, várias equipas.</strong> Não cries outro membro para associar uma segunda equipa. Abre a ficha do utilizador e adiciona as equipas e funções.<RouterLink class="btn btn-primary d-block mt-2" to="/administracao?tab=users">Gerir equipas e funções dos utilizadores</RouterLink></div><div class="sq-card"><PlatformModule :key="selected" :table="selected"/></div></div></template>
