<script setup lang="ts">
import { computed } from 'vue'
import { IconChevronLeft, IconChevronRight } from '@tabler/icons-vue'

const props = withDefaults(defineProps<{
  page: number
  perPage: number
  total: number
  perPageOptions?: number[]
}>(), {
  perPageOptions: () => [10, 20, 50, 100],
})

const emit = defineEmits<{
  (e: 'update:page', v: number): void
  (e: 'update:perPage', v: number): void
}>()

const totalPages = computed(() => Math.max(1, Math.ceil(props.total / props.perPage)))
const from = computed(() => (props.total === 0 ? 0 : (props.page - 1) * props.perPage + 1))
const to = computed(() => Math.min(props.page * props.perPage, props.total))

/** janela de páginas: 1 … p-1 p p+1 … N */
const pages = computed<(number | '…')[]>(() => {
  const tp = totalPages.value
  const p = props.page
  const wanted = new Set<number>([1, tp])
  for (let i = p - 1; i <= p + 1; i++) if (i >= 1 && i <= tp) wanted.add(i)
  const out: (number | '…')[] = []
  let prev = 0
  for (const n of [...wanted].sort((a, b) => a - b)) {
    if (n - prev > 1) out.push('…')
    out.push(n)
    prev = n
  }
  return out
})

function go(p: number) {
  if (p >= 1 && p <= totalPages.value && p !== props.page) emit('update:page', p)
}
function onPerPage(e: Event) {
  emit('update:perPage', Number((e.target as HTMLSelectElement).value))
}
</script>

<template>
  <div class="sq-pager">
    <div class="sq-pager-info">
      <span class="sq-pager-range">{{ from }}–{{ to }}</span>
      <span class="sq-pager-total">de {{ total }}</span>
      <span class="sq-pager-sep">·</span>
      <label class="sq-pager-perpage">
        <select class="sq-pager-select" :value="perPage" @change="onPerPage">
          <option v-for="n in perPageOptions" :key="n" :value="n">{{ n }}</option>
        </select>
        <span>por página</span>
      </label>
    </div>

    <nav class="sq-pager-nav" aria-label="Paginação">
      <button class="sq-pager-btn" :disabled="page <= 1" @click="go(page - 1)" aria-label="Página anterior">
        <IconChevronLeft :size="16" />
      </button>
      <template v-for="(p, i) in pages" :key="i">
        <span v-if="p === '…'" class="sq-pager-gap">…</span>
        <button v-else class="sq-pager-btn" :class="{ 'is-active': p === page }" @click="go(p as number)">{{ p }}</button>
      </template>
      <button class="sq-pager-btn" :disabled="page >= totalPages" @click="go(page + 1)" aria-label="Página seguinte">
        <IconChevronRight :size="16" />
      </button>
    </nav>
  </div>
</template>