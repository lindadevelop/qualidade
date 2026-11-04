<script setup lang="ts">
// Botão de ação em forma de ícone (quadrado compacto) com popup/tooltip bonito
// que ativa automaticamente no hover — substitui botões "texto+ícone" e tooltips nativos.
import { computed, ref } from 'vue'
import { IconPencil, IconCheck, IconRefresh, IconTrash, IconX, IconInfoCircle, IconBan } from '@tabler/icons-vue'
import type { Component } from 'vue'

const props = withDefaults(defineProps<{
  /** nome do ícone: pencil | check | refresh | trash | x | info | ban */
  icon: string
  /** cor por variante de estado visual */
  variant?: 'primary' | 'success' | 'secondary' | 'danger' | 'warning'
  /** texto do popup (tooltip) */
  label?: string
  /** posição do popup */
  tip?: 'top' | 'bottom' | 'left' | 'right'
  disabled?: boolean
}>(), {
  variant: 'primary',
  tip: 'top',
  disabled: false,
})

const emit = defineEmits<{ (e: 'click', ev: MouseEvent): void }>()

const items: Record<string, Component> = {
  pencil: IconPencil,
  check: IconCheck,
  refresh: IconRefresh,
  trash: IconTrash,
  x: IconX,
  info: IconInfoCircle,
  ban: IconBan,
}
const Ico = computed(() => items[props.icon] || IconInfoCircle)

function onClick(ev: MouseEvent) {
  if (!props.disabled) emit('click', ev)
}
</script>

<template>
  <button
    class="iab"
    :class="['iab-' + variant, { 'iab-disabled': disabled }]"
    :disabled="disabled"
    type="button"
    @click="onClick"
  >
    <component :is="Ico" :size="15" stroke-width="2" />
    <span v-if="label" class="iab-tip" :class="'iab-tip-' + tip">{{ label }}</span>
  </button>
</template>

<style scoped>
.iab {
  position: relative;
  left: auto;
  top: auto;
  transform: none;
  display: inline-grid;
  place-items: center;
  width: 30px;
  height: 30px;
  padding: 0;
  margin: 0;
  border-radius: .5rem;
  border: 1px solid transparent;
  background: transparent;
  cursor: pointer;
  transition: all .15s ease;
  flex-shrink: 0;
}
.iab svg { transition: transform .12s ease; }
.iab:active svg { transform: scale(.88); }

/* variantes */
.iab-primary { color: var(--roxo, #7367f0); border-color: var(--roxo, #7367f0); background: #fff; }
.iab-primary:hover { background: var(--roxo, #7367f0); color: #fff; box-shadow: 0 3px 10px rgba(115,103,240,.35); }
.iab-success { color: #28c76f; border-color: #28c76f; background: #fff; }
.iab-success:hover { background: #28c76f; color: #fff; box-shadow: 0 3px 10px rgba(40,199,111,.35); }
.iab-secondary { color: #6b6b80; border-color: #cdcdd8; background: #fff; }
.iab-secondary:hover { background: #6b6b80; color: #fff; box-shadow: 0 3px 10px rgba(107,107,128,.3); }
.iab-danger { color: #ea5455; border-color: #ea5455; background: #fff; }
.iab-danger:hover { background: #ea5455; color: #fff; box-shadow: 0 3px 10px rgba(234,84,85,.35); }
.iab-warning { color: #ff9f43; border-color: #ff9f43; background: #fff; }
.iab-warning:hover { background: #ff9f43; color: #fff; box-shadow: 0 3px 10px rgba(255,159,67,.35); }
.iab-disabled { opacity: .45; cursor: not-allowed; }
.iab-disabled:hover { transform: none; box-shadow: none; }

/* popup/tooltip bonito */
.iab-tip {
  position: absolute;
  z-index: 2000;
  pointer-events: none;
  white-space: nowrap;
  font-size: .74rem;
  font-weight: 600;
  letter-spacing: .01em;
  color: #fff;
  background: #2a2a3c;
  border-radius: .45rem;
  padding: .34rem .6rem;
  opacity: 0;
  transition: opacity .16s ease, transform .16s ease;
  box-shadow: 0 4px 16px rgba(20,20,40,.28);
}
.iab:hover .iab-tip { opacity: 1; }

/* posições + seta (afastado do botão, nunca o cobre) */
.iab-tip-top { bottom: calc(100% + 14px); left: 50%; transform: translateX(-50%) translateY(6px); }
.iab:hover .iab-tip-top { transform: translateX(-50%) translateY(0); }
.iab-tip-top::after { content:''; position:absolute; top:100%; left:50%; transform:translateX(-50%); border:5px solid transparent; border-top-color:#2a2a3c; }

.iab-tip-bottom { top: calc(100% + 14px); left: 50%; transform: translateX(-50%) translateY(-6px); }
.iab:hover .iab-tip-bottom { transform: translateX(-50%) translateY(0); }
.iab-tip-bottom::after { content:''; position:absolute; bottom:100%; left:50%; transform:translateX(-50%); border:5px solid transparent; border-bottom-color:#2a2a3c; }

.iab-tip-left { right: calc(100% + 14px); top: 50%; transform: translateY(-50%) translateX(6px); }
.iab:hover .iab-tip-left { transform: translateY(-50%) translateX(0); }
.iab-tip-left::after { content:''; position:absolute; left:100%; top:50%; transform:translateY(-50%); border:5px solid transparent; border-left-color:#2a2a3c; }

.iab-tip-right { left: calc(100% + 14px); top: 50%; transform: translateY(-50%) translateX(-6px); }
.iab:hover .iab-tip-right { transform: translateY(-50%) translateX(0); }
.iab-tip-right::after { content:''; position:absolute; right:100%; top:50%; transform:translateY(-50%); border:5px solid transparent; border-right-color:#2a2a3c; }
.iab:hover .iab-tip { will-change: auto; }
</style>