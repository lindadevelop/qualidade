<script setup lang="ts">
import { IconChevronDown, IconChevronRight } from '@tabler/icons-vue'

defineProps<{
  label: string
  count: number
  collapsed?: boolean
  cols?: number
}>()
const emit = defineEmits<{ (e: 'toggle'): void }>()

function toggle() { emit('toggle') }
</script>

<template>
  <tr class="sq-group" :class="{ 'is-collapsed': collapsed }" @click="toggle">
    <td class="sq-group-cell" :colspan="cols || 10">
      <button type="button" class="sq-group-toggle" @click.stop="toggle" aria-label="Alternar grupo" :aria-expanded="!collapsed">
        <IconChevronRight v-if="collapsed" :size="16" />
        <IconChevronDown v-else :size="16" />
      </button>
      <span class="sq-group-name">{{ label }}</span>
      <span class="sq-group-count">{{ count }}</span>
    </td>
  </tr>
</template>