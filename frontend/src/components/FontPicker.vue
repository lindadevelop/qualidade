<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { googleFonts, fontStack } from '@/domain/google-fonts'
const props = defineProps<{ id: string; modelValue: string; disabled?: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()
const selected = computed(() => googleFonts.find(font => font.family === props.modelValue))
const failed = ref(false)
const loading=ref(false)
watch(() => props.modelValue, async family => {
  failed.value = false
  if (!selected.value) {failed.value=true;return}
  loading.value=true
  try { const loaded=await document.fonts.load(`16px ${JSON.stringify(family)}`);if(props.modelValue===family)failed.value=loaded.length===0 }
  catch { if (props.modelValue === family) failed.value = true }
  finally {if(props.modelValue===family)loading.value=false}
}, { immediate: true })
</script>
<template>
  <div>
    <select :id="id" :value="modelValue" :disabled="disabled" required class="form-select" @change="emit('update:modelValue', ($event.target as HTMLSelectElement).value)">
      <option v-if="modelValue && !selected" :value="modelValue">{{ modelValue }} — fonte atual, fora do catálogo</option>
      <optgroup label="Google Fonts · gratuitas">
        <option v-for="font in googleFonts" :key="font.id" :value="font.family">{{ font.family }}</option>
      </optgroup>
    </select>
    <p class="border rounded p-2 mt-2 mb-1 font-sample" :style="{ fontFamily: fontStack(modelValue), fontSize: '18px' }">Qualidade e estratégia · Ação, confiança e evolução · 0123456789</p>
    <small v-if="selected" class="d-block sq-muted">Disponível na aplicação, sem instalação manual.</small>
    <small v-else class="d-block sq-muted">Esta fonte depende de estar instalada no dispositivo. Escolhe uma Google Font para a disponibilizar na aplicação.</small>
    <small v-if="loading" role="status">A carregar a fonte…</small>
    <small v-else-if="failed" class="text-danger d-block" role="alert">A fonte não está disponível. Será usada Inter, com alternativa sans-serif. Seleciona uma fonte do catálogo para tentar novamente.</small>
    <small v-else class="text-success d-block" role="status">Fonte carregada e aplicada à pré-visualização. Guarda para confirmar.</small>
    <div v-if="selected" class="d-flex flex-wrap gap-3 mt-1 small">
      <a :href="`/fonts/${selected.id}/regular.ttf`" :download="`${selected.family}.ttf`">Descarregar para usar no computador</a>
      <a :href="`/fonts/${selected.id}/OFL.txt`" target="_blank" rel="noopener">Licença livre</a>
    </div>
  </div>
</template>
