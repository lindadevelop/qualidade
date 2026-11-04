<script setup lang="ts">
import {useBrandKit} from '@/composables/useBrandKit'
const {colors}=useBrandKit()
import PageHeader from '@/components/PageHeader.vue'
import { onMounted, ref } from 'vue'
import VueApexCharts from 'vue3-apexcharts'
import { fetchEvolution, fetchByStatus, fetchByOrigin, fetchByArea } from '@/services/dashboard'
import { OCCURRENCE_STATUS_LABEL } from '@/utils/format'

const evolution = ref<any[]>([])
const byStatus = ref<any[]>([])
const byOrigin = ref<any[]>([])
const byArea = ref<any[]>([])
const loading = ref(true)

onMounted(async () => {
  ;[evolution.value, byStatus.value, byOrigin.value, byArea.value] = await Promise.all([
    fetchEvolution(12), fetchByStatus(), fetchByOrigin(), fetchByArea(),
  ])
  loading.value = false
})

const isDark = ref(document.documentElement.getAttribute('data-bs-theme') === 'dark')
const chartText = () => isDark.value ? '#b7b9d0' : '#5d596c'
const chartGrid = () => isDark.value ? '#3b3b53' : '#e7e7ef'

const donutSeries = () => byStatus.value.map(s => s.cnt)
const donutLabels = () => byStatus.value.map(s => OCCURRENCE_STATUS_LABEL[s.status] ?? s.status)
</script>

<template>
  <div>
    <PageHeader><template #title>Revisão pela Gestão</template><template #breadcrumb>Análise › Revisão pela Gestão</template></PageHeader>

    <div v-if="loading" class="sq-card"><div class="sq-skeleton" style="height:300px"></div></div>
    <template v-else>
      <div class="row g-3">
        <div class="col-xl-8"><div class="sq-card">
          <h6 class="sq-card-title">Evolução mensal (12 meses)</h6>
          <VueApexCharts type="area" height="280"
            :options="{chart:{toolbar:{show:false},foreColor:chartText()},stroke:{curve:'smooth',width:2},colors:[colors.danger,colors.primary,colors.success],fill:{type:'gradient'},grid:{borderColor:chartGrid()},xaxis:{categories:[...new Set(evolution.map(r=>r.period))].sort()},legend:{labels:{colors:chartText()}}}"
            :series="[{name:'NC',data:evolution.filter(r=>r.type==='NC').map(r=>r.cnt)},{name:'OM',data:evolution.filter(r=>r.type==='OM').map(r=>r.cnt)}]" />
        </div></div>
        <div class="col-xl-4"><div class="sq-card">
          <h6 class="sq-card-title">Estado</h6>
          <VueApexCharts type="donut" height="280"
            :options="{labels:donutLabels(),legend:{position:'bottom',labels:{colors:chartText()}},stroke:{width:0},colors:[colors.secondary,colors.warning,colors.info,colors.success]}"
            :series="donutSeries()" />
        </div></div>
        <div class="col-xl-6"><div class="sq-card">
          <h6 class="sq-card-title">Por origem</h6>
          <VueApexCharts type="bar" height="260" :options="{chart:{toolbar:{show:false},foreColor:chartText()},colors:[colors.primary],plotOptions:{bar:{borderRadius:4}},grid:{borderColor:chartGrid()},xaxis:{categories:byOrigin.map(o=>o.origin_name)}}" :series="[{name:'Ocorrências',data:byOrigin.map(o=>o.cnt)}]" />
        </div></div>
        <div class="col-xl-6"><div class="sq-card">
          <h6 class="sq-card-title">Por área</h6>
          <VueApexCharts type="bar" height="260" :options="{chart:{toolbar:{show:false},foreColor:chartText()},colors:[colors.secondary],plotOptions:{bar:{borderRadius:4,horizontal:true}},grid:{borderColor:chartGrid()},yaxis:{labels:{style:{colors:chartText()}}},...( { yaxis:{categories:byArea.map(a=>a.area_name)} } as any)}" :series="[{name:'Ocorrências',data:byArea.map(o=>o.cnt)}]" />
        </div></div>
      </div>
    </template>
  </div>
</template>
