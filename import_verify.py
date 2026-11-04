import os
# -*- coding: utf-8 -*-
"""Verificação final pós-importação via API REST (mesmos endpoints da app)."""
import json, psycopg2
DB=dict(host="127.0.0.1",port=5432,user="postgres",password=os.environ["PGPASSWORD"],dbname="samsys_qualidade")
conn=psycopg2.connect(**DB); cur=conn.cursor()

def q(sql):
    cur.execute(sql); return cur.fetchall()

print("== Contagens ==")
for l,c in q("select 'ocorrencias',count(*) from quality_occurrences union all select 'nc',count(*) from quality_occurrences where type='NC' union all select 'om',count(*) from quality_occurrences where type='OM' union all select 'acoes',count(*) from quality_actions union all select 'areas',count(*) from quality_areas union all select 'origens',count(*) from quality_origins union all select 'relacoes',count(*) from quality_occurrence_relations union all select 'registo_import',count(*) from import_registry"):
    print("  ",l,c)

print("\n== Importadas (created/updated) por modulo/estado ==")
for l,c in q("select status,count(*) from import_registry group by status order by 1"):
    print("  ",l,c)

print("\n== Anomalias resumidas (top motivos) ==")
# anomalias ações
for l,c in q("""select a->>0 motivo, count(*) from 
   (select jsonb_array_elements(anomalies) a from import_registry) x group by 1 order by 2 desc"""):
    print("  ",l,c)

print("\n== Amostra ficha NC-2020-001 (com relacoes) ==")
for r in q("""select o.reference,o.type,o.year,o.status,o.effectiveness_status,o.occurrence_date,o.area_id,o.origin_id,
  (select string_agg(x.reference,',' order by x.reference) from quality_occurrence_relations rr join quality_occurrences x on x.id=rr.related_occurrence_id where rr.occurrence_id=o.id) rels,
  (select count(*) from quality_actions a where a.occurrence_id=o.id) n_acoes
  from quality_occurrences o where o.reference in ('NC-2020-001','NC-2022-002','NC-2025-003')"""):
    area = q(f"select name from quality_areas where id='{r[6]}'")[0][0]
    orig = q(f"select name from quality_origins where id='{r[7]}'")[0][0]
    print(f"  {r[0]} {r[1]} {r[2]} {r[3]} {r[4]} data={r[5]} area={area} orig={orig} rels={r[8] or '-'} n_acoes={r[9]}")

print("\n== Acoes com/se ocorrencia associada ===")
for l,c in q("select case when occurrence_id is null then 'sem_nc' else 'com_nc' end, count(*) from quality_actions group by 1"):
    print("  ",l,c)
conn.close()