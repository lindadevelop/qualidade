# -*- coding: utf-8 -*-
import openpyxl
from collections import Counter

def load(path, sheet):
    wb = openpyxl.load_workbook(path, data_only=True); ws = wb[sheet]
    hdr=[c.value for c in ws[1]]
    return [dict(zip(hdr,r)) for r in ws.iter_rows(min_row=2,values_only=True)]

nco=[r for r in load("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_20e5c68a16de_NC_OM.xlsx","NC_OM") if r.get('ID NC')]
acts=[r for r in load("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_01e7008f325c_Livro7.xlsx","query Tabela de Todas as Ações") if r.get('Title')]

allresp=Counter()
for r in nco:
    v=r.get('Responsável')
    if v: allresp[("NC_OM",v)]+=1
for r in acts:
    v=r.get('Responsável')
    if v: allresp[("AC",v)]+=1

print("=== TODOS os responsáveis (não-vazio) ===")
for (src,name),n in allresp.most_common():
    print(f"  [{src}] {name!r} x{n}")