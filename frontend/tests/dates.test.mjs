import {test} from 'node:test'
import assert from 'node:assert/strict'
import {validDate,datePT,parsePT} from '../src/domain/dates.ts'
test('PT calendar dates are strict and independent of timezone',()=>{
 assert.equal(parsePT('22/09/2026'),'2026-09-22')
 assert.equal(datePT('2026-09-22'),'22/09/2026')
 for(const v of ['31/02/2026','29/02/2025','01/13/2026','1/1/2026','01/01/20260','texto'])assert.equal(parsePT(v),null)
 assert(validDate('2024-02-29'));assert(!validDate('1900-02-29'));assert(validDate('2000-02-29'))
 assert(!validDate('0000-01-01'));assert(!validDate('20260-01-01'))
})
