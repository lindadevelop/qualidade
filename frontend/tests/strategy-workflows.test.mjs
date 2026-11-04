import {test} from 'node:test'
import assert from 'node:assert/strict'
import {validatePeriod,kpiAssessment,normalizeCrossing,numberInRange,required} from '../src/domain/strategy-workflows.ts'
test('periods respect frequency, leap years and ISO weeks',()=>{
  for(const [p,f] of [['2026','yearly'],['2026-09','monthly'],['2026-Q3','quarterly'],['2026-W53','weekly'],['2024-02-29','daily']]) assert.equal(validatePeriod(p,f),p)
  for(const [p,f] of [['2026-00','monthly'],['2026-13','monthly'],['2026-Q5','quarterly'],['2025-W53','weekly'],['2026-02-29','daily'],['2026-09','yearly'],['2026-04-31','daily']]) assert.throws(()=>validatePeriod(p,f))
})
test('KPI comparison preserves zero, missing results and all directions',()=>{
  assert.equal(kpiAssessment(0,0,null),'Cumprido')
  assert.equal(kpiAssessment(null,5,3),'Sem resultado')
  assert.equal(kpiAssessment(5,null,null),'Sem meta')
  assert.equal(kpiAssessment(7,10,5),'Em alerta')
  assert.equal(kpiAssessment(2,10,5),'Desvio')
  assert.equal(kpiAssessment(12,10,15,'lower_is_better'),'Em alerta')
  assert.equal(kpiAssessment(9,10,null,'lower_is_better'),'Cumprido')
  assert.equal(kpiAssessment(11,10,2,'target'),'Em alerta')
  assert.equal(kpiAssessment(13,10,2,'target'),'Desvio')
})
test('TOWS enforces source quadrants and campaign and clears stale factors',()=>{
  const items=['strengths','weaknesses','opportunities','threats'].map((quadrant,id)=>({id:String(id),campaign_id:'a',quadrant,title:quadrant}))
  const crossing={campaign_id:'a',strategy_type:'so',name:'Expandir',s_item_id:'0',w_item_id:'1',o_item_id:'2',t_item_id:'3'}
  const normalized=normalizeCrossing(crossing,items)
  assert.equal(normalized.w_item_id,null);assert.equal(normalized.t_item_id,null)
  assert.throws(()=>normalizeCrossing({...crossing,s_item_id:'1'},items))
  assert.throws(()=>normalizeCrossing({...crossing,campaign_id:'b'},items))
  assert.throws(()=>normalizeCrossing({...crossing,o_item_id:null},items))
})
test('empty and nonfinite values are rejected but zero is valid',()=>{
  for(const n of ['',null,undefined,Infinity,NaN])assert.throws(()=>numberInRange(n,'Valor'))
  assert.equal(numberInRange(0,'Valor'),0)
  assert.throws(()=>numberInRange(101,'Progresso',0,100))
  assert.throws(()=>required('   ','Nome'))
})
