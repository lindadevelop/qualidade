import {test} from 'node:test'
import assert from 'node:assert/strict'
import {parseKpiCsv} from '../src/domain/kpi-csv.ts'
import {modulePayload,platformModules} from '../src/domain/platform-modules.ts'
test('CSV supports BOM, decimal comma, quoted multiline and escaped quotes',()=>{
 const rows=parseKpiCsv('\uFEFFcodigo;periodo;valor;notas\r\nK1;2026-10;0;"Linha 1\nLinha ""2"""\r\nK2;2026-10;95,5;Ok')
 assert.equal(rows[0].valor,0);assert.equal(rows[0].notas,'Linha 1\nLinha "2"');assert.equal(rows[1].valor,95.5)
})
test('CSV rejects duplicates, empty values, malformed quotes and headers',()=>{
 for(const text of ['codigo;periodo;valor;notas\nK;2026-10;;x','codigo;periodo;valor;notas\nK;2026-10;1;x\nK;2026-10;2;y','codigo;periodo;valor;notas\nK;2026-10;1;"open','codigo;periodo;valor;notas\nK;2026-10;1;"x"y','a;b;c;d\nK;2026-10;1;x'])assert.throws(()=>parseKpiCsv(text))
})
test('module payload rejects invalid ranges and unsafe URLs and retains only editable keys',()=>{
 assert.throws(()=>modulePayload(platformModules.meetings,{title:'QA',scheduled_at:'2026-10-01T10:00',status:'scheduled',duration_min:1500}))
 assert.throws(()=>modulePayload(platformModules.organizations,{name:'QA',website:'javascript:alert(1)'}))
 const result=modulePayload(platformModules.organizations,{name:' QA ',active:true,created_by:'forged'});assert.equal(result.name,'QA');assert(!('created_by' in result))
})
