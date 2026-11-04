# -*- coding: utf-8 -*-
import openpyxl
from collections import Counter

def load(path, sheet):
    wb = openpyxl.load_workbook(path, data_only=True); ws = wb[sheet]
    hdr=[c.value for c in ws[1]]
    return [dict(zip(hdr,r)) for r in ws.iter_rows(min_row=2,values_only=True)]

nco=[r for r in load("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_20e5c68a16de_NC_OM.xlsx","NC_OM") if r.get('ID NC')]
acts=[r for r in load("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_01e7008f325c_Livro7.xlsx","query Tabela de Todas as Ações") if r.get('Title')]

areas=set()
for r in nco:
    if r.get('Processo / Equipa'): areas.add(str(r.get('Processo / Equipa')).strip())
for r in acts:
    if r.get('Processo / Equipa'): areas.add(str(r.get('Processo / Equipa')).strip())
print("=== ÁREAS do Excel (Processo/Equipa) únicas ===")
for a in sorted(areas): print(" ", a)

origens=set()
for r in nco:
    if r.get('Origem'): origens.add(str(r.get('Origem')).strip())
print("\n=== ORIGENS NC_OM ===")
for o in sorted(origens): print(" ", o)

# NC associada nas ações - valores referenciados
assoc=set()
for r in acts:
    v=r.get('NC associada')
    if v: assoc.add(str(v).split(';')[0].strip())
print("\n=== NC associada (ações) que precisam existir como ocorrências ===")
nco_ids=set(str(r.get('ID NC')).strip() for r in nco)
missing=sorted(a for a in assoc if a not in nco_ids)
print("  referenciadas:", sorted(assoc))
print("  MISSING na NC_OM:", missing if missing else "nenhum")