<script setup lang="ts">
import {computed,ref,watch} from 'vue'
import {datePT,parsePT,dateError,validDate} from '@/domain/dates'
defineOptions({inheritAttrs:false})
const props=defineProps<{modelValue?:string|null;type?:string;required?:boolean;disabled?:boolean;id?:string}>()
const emit=defineEmits(['update:modelValue','change'])
const input=ref<HTMLInputElement>(),raw=ref(''),time=ref('00:00'),show=ref(false)
const now=new Date(),month=ref(now.getMonth()),year=ref(now.getFullYear())
watch(()=>props.modelValue,v=>{if(v&&validDate(v.slice(0,10))){raw.value=datePT(v);time.value=v.slice(11,16)||'00:00';year.value=Number(v.slice(0,4));month.value=Number(v.slice(5,7))-1}else if(!v)raw.value=''}, {immediate:true})
const title=computed(()=>new Intl.DateTimeFormat('pt-PT',{month:'long',year:'numeric'}).format(new Date(year.value,month.value,1)))
const cells=computed(()=>{const first=new Date(year.value,month.value,1);const n=new Date(year.value,month.value+1,0).getDate();return [...Array((first.getDay()+6)%7).fill(0),...Array.from({length:n},(_,i)=>i+1)]})
function change(){const iso=parsePT(raw.value);input.value?.setCustomValidity(raw.value&&!iso?dateError:'');emit('update:modelValue',iso?iso+(props.type==='datetime-local'?'T'+time.value:''):raw.value?'INVALID_DATE':'');emit('change')}
function select(d:number){const v=`${String(year.value).padStart(4,'0')}-${String(month.value+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;raw.value=datePT(v);change();show.value=false;input.value?.focus()}
function move(n:number){const d=new Date(year.value,month.value+n,1);if(d.getFullYear()<100||d.getFullYear()>9999)return;year.value=d.getFullYear();month.value=d.getMonth()}
</script>
<template>
 <div class="pt-date"><div class="d-flex gap-1"><input :id="id" ref="input" v-model="raw" v-bind="$attrs" type="text" inputmode="numeric" placeholder="dd/mm/aaaa" pattern="[0-9]{2}/[0-9]{2}/[0-9]{4}" :required="required" :disabled="disabled" :title="dateError" @input="change"/><input v-if="type==='datetime-local'" v-model="time" type="time" class="form-control" aria-label="Hora" :disabled="disabled" @input="change"/><button type="button" class="btn btn-outline-secondary" aria-label="Abrir calendário" :disabled="disabled" :aria-expanded="show" @click="show=!show">▦</button></div>
 <div v-if="show" class="border rounded p-2 mt-1 bg-body" role="group" aria-label="Calendário em português" @keydown.esc="show=false"><div class="d-flex justify-content-between align-items-center"><button type="button" class="btn btn-sm" aria-label="Mês anterior" @click="move(-1)">‹</button><strong>{{title}}</strong><button type="button" class="btn btn-sm" aria-label="Mês seguinte" @click="move(1)">›</button></div><div class="calendar-grid"><span v-for="d in ['Seg','Ter','Qua','Qui','Sex','Sáb','Dom']" :key="d">{{d}}</span><template v-for="(d,i) in cells" :key="i"><button v-if="d" type="button" class="btn btn-sm" :aria-label="`${d} de ${title}`" @click="select(d)">{{d}}</button><span v-else/></template></div></div>
 </div>
</template>
<style scoped>.pt-date{min-width:0}.calendar-grid{display:grid;grid-template-columns:repeat(7,1fr);text-align:center;font-size:.85rem}.pt-date input[type=time]{max-width:8rem}</style>
