# -*- coding: utf-8 -*-
import openpyxl, datetime

def load(path, sheet):
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb[sheet]
    hdr = [c.value for c in ws[1]]
    rows = []
    for r in ws.iter_rows(min_row=2, values_only=True):
        rows.append(dict(zip(hdr, r)))
    return rows

nco = load("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_20e5c68a16de_NC_OM.xlsx", "NC_OM")
acts = load("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_01e7008f325c_Livro7.xlsx", "query Tabela de Todas as Ações")

# filtrar linhas realmente com identificador
nco2 = [r for r in nco if r.get('ID NC')]
acts2 = [r for r in acts if r.get('Title')]
print("NC_OM: total cabeçalho-linhas=", len(nco)-1, "-> com ID:", len(nco2))
print("Livro7: total:", len(acts)-1, "-> com Title:", len(acts2))

# tipos NC vs OM
from collections import Counter
print("\nTipo NC/OM:", Counter(r.get('Tipo NC/OM') for r in nco2))
print("Prefixo ref NC_OM:", Counter(str(r.get('ID NC')).split('-')[0] for r in nco2))
print("Recorrente:", Counter(r.get('Recorrente?') for r in nco2))
print("Estado NC_OM:", Counter(r.get('Estado') for r in nco2))
print("Eficácia NC_OM:", Counter(r.get('Eficácia') for r in nco2))
print("NC relacionada não vazia:", sum(1 for r in nco2 if r.get('NC relacionada')))

# Ações
print("\nEstado Ações:", Counter(r.get('Estado') for r in acts2))
print("Encerrada?:", Counter(r.get('Encerrada?') for r in acts2))
print("Resultado/Eficácia:", Counter(r.get('Resultado / Eficácia') for r in acts2))
print("NC associada não vazia:", sum(1 for r in acts2 if r.get('NC associada')))
print("Origem Ações:", Counter(r.get('Origem') for r in acts2))

# datas
def is_bad_dt(v):
    return isinstance(v, datetime.datetime) and v.year < 2000
badK = sum(1 for r in acts2 if is_bad_dt(r.get('Data início')))
badL = sum(1 for r in acts2 if isinstance(r.get('Data fim prevista'), datetime.datetime) and (r.get('Data fim prevista').year<2000))
print("\nAções Data início <2000 (corrompida):", badK, "/", len(acts2))
print("Ações Data fim prevista <2000:", badL)

# Verificação é data ou texto?
verf = Counter(type(r.get('Verificação')).__name__ for r in acts2)
print("Verificação tipos:", verf)
# amostra verificação textual
textv = [r.get('Verificação') for r in acts2 if isinstance(r.get('Verificação'), str) and ('/' in str(r.get('Verificação')) or '-' not in str(r.get('Verificação')))]
print("Verificação texto amostra:", [str(v)[:20] for v in textv[:8]])