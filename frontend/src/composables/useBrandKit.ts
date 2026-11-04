// composables/useBrandKit.ts — aplica CSS variables do brand kit da organização ativa
import { fontStack } from '@/domain/google-fonts'
import { watch, ref, computed } from 'vue'
import { getBrandKit } from '@/services/strategy'
import type { BrandKit } from '@/types/strategy'
import { useOrganization } from './useOrganization'

export interface BrandColors {
  primary: string
  secondary: string
  background: string
  text: string
  accent: string
  danger: string
  warning: string
  info: string
  success: string
}

const DEFAULT_COLORS: BrandColors = {
  primary: '#7367f0',
  secondary: '#00cfe8',
  background: '#f5f5f9',
  text: '#5d596c',
  accent: '#28c76f',
  danger: '#ea5455',
  warning: '#ff9f43',
  info: '#00cfe8',
  success: '#28c76f',
}

const brandKit = ref<BrandKit | null>(null)
const loading = ref(false)
const brandError=ref('')
let loadSequence=0

export function useBrandKit() {
  const { activeOrganization } = useOrganization()
  const colors = computed<BrandColors>(() => {
    const b = brandKit.value
    if (!b) return DEFAULT_COLORS
    return {
      primary: b.primary_color || DEFAULT_COLORS.primary,
      secondary: b.secondary_color || DEFAULT_COLORS.secondary,
      background: b.background_color || DEFAULT_COLORS.background,
      text: b.text_color || DEFAULT_COLORS.text,
      accent: b.accent_color || DEFAULT_COLORS.accent,
      danger: b.danger_color || DEFAULT_COLORS.danger,
      warning: b.warning_color || DEFAULT_COLORS.warning,
      info: b.info_color || DEFAULT_COLORS.info,
      success: b.success_color || DEFAULT_COLORS.success,
    }
  })

  function applyBrandColors() {
    const c = colors.value
    const root = document.documentElement
    root.style.setProperty('--sq-primary', c.primary)
    root.style.setProperty('--sq-secondary', c.secondary)
    root.style.setProperty('--sq-bg', c.background)
    root.style.setProperty('--sq-text', c.text)
    root.style.setProperty('--sq-heading', c.text)
    const channels=c.primary.replace('#','').match(/.{2}/g)?.map(v=>{const x=parseInt(v,16)/255;return x<=.04045?x/12.92:((x+.055)/1.055)**2.4})||[0,0,0]
    const luminance=channels[0]!*.2126+channels[1]!*.7152+channels[2]!*.0722
    root.style.setProperty('--sq-on-primary',luminance>.179?'#161616':'#ffffff')
    root.style.setProperty('--sq-accent', c.accent)
    root.style.setProperty('--sq-danger', c.danger)
    root.style.setProperty('--sq-warning', c.warning)
    root.style.setProperty('--sq-info', c.info)
    root.style.setProperty('--sq-success', c.success)
    for(const name of ['primary','secondary','success','danger','warning','info'] as const){
      root.style.setProperty('--bs-'+name,c[name])
      const rgb=c[name].replace('#','').match(/.{2}/g)?.map(v=>parseInt(v,16)).join(',')
      if(rgb){root.style.setProperty('--bs-'+name+'-rgb',rgb);root.style.setProperty('--sq-'+name+'-rgb',rgb)}
    }
    root.style.setProperty('--sq-primary-soft', hexToRgba(c.primary, 0.12))

    const b = brandKit.value
    root.style.setProperty('--sq-font-body', fontStack(b?.font_body))
    root.style.setProperty('--sq-font-heading', fontStack(b?.font_heading))
    let favicon=document.querySelector<HTMLLinkElement>('link[rel="icon"]')
    if(!favicon){favicon=document.createElement('link');favicon.rel='icon';document.head.appendChild(favicon)}
    favicon.href=(b as any)?.favicon_data||'/favicon.svg'
  }

  async function loadBrandKit() {
    const org = activeOrganization.value
    const sequence=++loadSequence
    if (!org) {brandKit.value=null;applyBrandColors();return}
    brandError.value=''
    loading.value = true
    try {
      const kit = await getBrandKit(org.id)
      if(activeOrganization.value?.id !== org.id||sequence!==loadSequence) return
      brandError.value=(kit as any)?.asset_warning||''
      brandKit.value = kit
      applyBrandColors()
    } catch {
      if(activeOrganization.value?.id === org.id&&sequence===loadSequence) {brandError.value='Não foi possível carregar a identidade visual. Tenta novamente.';if(brandKit.value?.organization_id!==org.id){brandKit.value=null;applyBrandColors()}}
    } finally {
      loading.value = false
    }
  }

  watch(activeOrganization, loadBrandKit, { immediate: true })

  return {
    brandKit,
    brandError,
    logo:computed(()=>(brandKit.value as any)?.logo_data),
    icon:computed(()=>(brandKit.value as any)?.icon_data),
    colors,
    loading,
    applyBrandColors,
    loadBrandKit,
  }
}

function hexToRgba(hex: string, alpha: number): string {
  const clean = hex.replace('#', '')
  const bigint = parseInt(clean, 16)
  const r = (bigint >> 16) & 255
  const g = (bigint >> 8) & 255
  const b = bigint & 255
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}
