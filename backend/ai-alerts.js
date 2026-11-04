#!/usr/bin/env node
// ai-alerts.js — Alertas proativos da Qualidade (agendado via cron).
// Calcula as prioridades (consultor-service) e imprime o resumo JSON para o cronjob
// encaminhar por canal preferido do utilizador. Não envia automaticamente dados de
// terceiros por canais externos sem configuração explícita.
const { execFileSync } = require('child_process')
function main() {
  const out = execFileSync(process.execPath, [require.resolve('./ai/_alert-worker.js')], { encoding: 'utf8', timeout: 120000 })
  console.log(out.trim())
  process.exit(0)
}
main()