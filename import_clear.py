import os
# -*- coding: utf-8 -*-
"""Apaga apenas os dados importados do Excel (deixa demo 2026 intacta)."""
import psycopg2
DB=dict(host="127.0.0.1",port=5432,user="postgres",password=os.environ["PGPASSWORD"],dbname="samsys_qualidade")
conn=psycopg2.connect(**DB); conn.autocommit=False
cur=conn.cursor()
# ações importadas são AC-*; ocorrências importadas não são 2026 (demo é 2026)
cur.execute("delete from public.import_registry")
ir=cur.rowcount
cur.execute("delete from public.quality_occurrence_relations")
rr=cur.rowcount
cur.execute("delete from public.quality_actions where reference like 'AC-%'")
ar=cur.rowcount
cur.execute("delete from public.quality_occurrences where reference not like '%-2026-%'")
orr=cur.rowcount
# apagar áreas/origens novas sem uso
cur.execute("""delete from public.quality_areas a where not exists
    (select 1 from quality_occurrences o where o.area_id=a.id) and a.name not in
    ('Administração','Comercial','Desenvolvimento','Financeiro','Logística','PHC','Sage','Sistemas')""")
area_d=cur.rowcount
cur.execute("""delete from public.quality_origins o where not exists
    (select 1 from quality_occurrences oc where oc.origin_id=o.id) and o.name not in
    ('Auditoria Externa','Auditoria Interna','Melhoria Interna','Outra','Processo Interno','Reclamação','Revisão pela Gestão')""")
orig_d=cur.rowcount
conn.commit()
print(f"removidos: import_registry={ir} relations={rr} actions={ar} occurrences={orr} areas={area_d} origins={orig_d}")
conn.close()