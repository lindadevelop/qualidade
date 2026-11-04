import os
# -*- coding: utf-8 -*-
"""
Segunda passagem: resolver relações entre ocorrências (NC relacionada) e
confirmar NC associada das ações pelos identificadores. Idempotente.
Não inventa relações; regista não resolvidas.
"""
import json, psycopg2
from collections import Counter
import openpyxl

NC_PATH = "C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_20e5c68a16de_NC_OM.xlsx"
AC_PATH = "C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_01e7008f325c_Livro7.xlsx"
DB = dict(host="127.0.0.1", port=5432, user="postgres", password=os.environ["PGPASSWORD"], dbname="samsys_qualidade")

def load(path, sheet, key):
    wb = openpyxl.load_workbook(path, data_only=True); ws = wb[sheet]
    hdr = [c.value for c in ws[1]]
    rows=[]
    for r in ws.iter_rows(min_row=2, values_only=True):
        d=dict(zip(hdr,r))
        if d.get(key): rows.append(d)
    return rows

nco=load(NC_PATH,"NC_OM","ID NC")
acts=load(AC_PATH,"query Tabela de Todas as Ações","Title")

conn=psycopg2.connect(**DB); conn.autocommit=False
cur=conn.cursor()
cur.execute("select reference,id from public.quality_occurrences")
id_by_ref={str(r[0]):r[1] for r in cur.fetchall()}

# --- NC relacionada (ocorrência <-> ocorrência). Table extra? qualidade_observations? Vamos
# ver se existe coluna/tabela de parent. Se não houver, regista em import_registry.anomalias.
# Verificar se há tabela de relações de ocorrências.
cur.execute("""select table_name from information_schema.tables where table_schema='public'
   and table_name like '%occurrence%' or table_name like '%relation%'""")
tabs=[r[0] for r in cur.fetchall()]
print("Tabelas ocorrência/relação:", tabs)

unresolved=[]
rel_count=Counter()
for r in nco:
    ref=str(r.get('ID NC')).strip()
    rel=r.get('NC relacionada')
    if rel:
        for part in str(rel).split(';'):
            pr=part.strip()
            if not pr: continue
            tid=id_by_ref.get(pr)
            if tid:
                rel_count["resolvida"]+=1
                cur.execute("""insert into public.quality_occurrence_relations
                    (occurrence_id, related_occurrence_id, relation_type)
                    values (%s,%s,'related') on conflict (occurrence_id, related_occurrence_id, relation_type) do nothing""",
                    (id_by_ref[ref], tid))
                cur.execute("""update public.import_registry
                    set anomalies = anomalies || %s::jsonb
                    where reference=%s and module='occurrence'""",
                    (json.dumps([f"relacionada:{pr}:resolvida"]), ref))
            else:
                rel_count["nao_resolvida"]+=1
                unresolved.append((ref,pr))
                cur.execute("""update public.import_registry
                    set anomalies = anomalies || %s::jsonb
                    where reference=%s and module='occurrence'""",
                    (json.dumps([f"relacionada:{pr}:NAO_RESOLVIDA"]), ref))

# --- NC associada das ações: confirmar que ficou ligada ---
act_unres=[]
for r in acts:
    ref=str(r.get('Title')).strip()
    assoc=str(r.get('NC associada') or "").strip()
    if not assoc: continue
    first=assoc.split(';')[0].strip()
    if first not in id_by_ref:
        act_unres.append((ref,first))
        cur.execute("""update public.import_registry set anomalies=anomalies || %s::jsonb
            where reference=%s and module='action'""",
            (json.dumps([f"nc_associada:{first}:NAO_RESOLVIDA"]), ref))
    else:
        cur.execute("""update public.import_registry set anomalies=anomalies || %s::jsonb
            where reference=%s and module='action'""",
            (json.dumps([f"nc_associada:{first}:resolvida"]), ref))

conn.commit()
print("Relações NC relacionada:", dict(rel_count))
print("Não resolvidas (NC relacionada):", len(unresolved))
for u in unresolved: print("  ", u)
print("Ações com NC associada não resolvida:", act_unres if act_unres else "nenhum")
conn.close()