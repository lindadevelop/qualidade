export const dateError = 'Introduza uma data válida no formato dd/mm/aaaa.'
export function validDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false
  const [y,m,d] = value.split('-').map(Number) as [number,number,number]
  if (y < 1 || m < 1 || m > 12 || d < 1) return false
  const leap = y % 4 === 0 && (y % 100 !== 0 || y % 400 === 0)
  return d <= [31,leap?29:28,31,30,31,30,31,31,30,31,30,31][m-1]!
}
export function datePT(value: unknown): string {
  const v = String(value || '').slice(0,10)
  return validDate(v) ? `${v.slice(8,10)}/${v.slice(5,7)}/${v.slice(0,4)}` : '—'
}
export function parsePT(value: string): string | null {
  if (!/^\d{2}\/\d{2}\/\d{4}$/.test(value)) return null
  const iso = `${value.slice(6)}-${value.slice(3,5)}-${value.slice(0,2)}`
  return validDate(iso) ? iso : null
}
