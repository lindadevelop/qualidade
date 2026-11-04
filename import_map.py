# -*- coding: utf-8 -*-
import openpyxl
from collections import Counter

def load(path, sheet):
    wb = openpyxl.load_workbook(path, data_only=True); ws = wb[sheet]
    hdr = [c.value for c in ws[1]]
    return [dict(zip(hdr, r)) for r in ws.iter_rows(min_row=2, values_only=True)]

nco = [r for r in load("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_20e5c68a16de_NC_OM.xlsx","NC_OM") if r.get('ID NC')]
acts = [r for r in load("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_01e7008f325c_Livro7.xlsx","query Tabela de Todas as Ações") if r.get('Title')]

print("=== Processo / Equipa (NC_OM) ===")
for k,v in Counter(r.get('Processo / Equipa') for r in nco).most_common(): print(f"  {k!r}: {v}")
print("\n=== Processo / Equipa (Ações) ===")
for k,v in Counter(r.get('Processo / Equipa') for r in acts).most_common(): print(f"  {k!r}: {v}")
print("\n=== Responsável (NC_OM) ===")
for k,v in Counter(r.get('Responsável') for r in nco).most_common(): print(f"  {k!r}: {v}")
print("\n=== Responsável (Ações) ===")
for k,v in Counter(r.get('Responsável') for r in acts).most_common(): print(f"  {k!r}: {v}")
print("\n=== Aprovador (Ações) ===")
for k,v in Counter(r.get('Aprovador') for r in acts).most_common(): print(f"  {k!r}: {v}")
print("\n=== Origem NC_OM ===")
for k,v in Counter(r.get('Origem') for r in nco).most_common(): print(f"  {k!r}: {v}")
print("\n=== IDs NC_OM duplicados? ===")
ids=[str(r.get('ID NC')) for r in nco]; dups=[i for i,c in Counter(ids).items() if c>1]
print("  dups:", dups if dups else "nenhum")
print("=== Titles Ações duplicados? ===")
tid=[str(r.get('Title')) for r in acts]; dups2=[i for i,c in Counter(tid).items() if c>1]
print("  dups:", dups2 if dups2 else "nenhum")
print("\n=== NC associada (Ações) valores que NÃO existem em NC_OM ===")
nc_om_ids=set(str(r.get('ID NC')).strip() for r in nco)
assoc=[str(r.get('NC associada')).strip() for r in acts if r.get('NC associada')]
missing=set(a for a in assoc if a and a not in nc_om_ids)
print("  assoc=", len(assoc), "missing na NC_OM:", sorted(missing)[:20] if missing else "nenhum")