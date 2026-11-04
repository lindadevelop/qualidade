<script setup lang="ts">
defineProps<{ modelValue: boolean }>()
defineEmits<{ 'update:modelValue': [value: boolean] }>()
</script>
<template>
  <label class="alert alert-info d-flex gap-2 align-items-start mt-3 mb-0">
    <input type="checkbox" class="form-check-input flex-shrink-0" :checked="modelValue" @change="$emit('update:modelValue', ($event.target as HTMLInputElement).checked)" />
    <span>Revi os dados e confirmo esta alteração. Sugestões de IA só se tornam oficiais após esta validação.</span>
  </label>
</template>
