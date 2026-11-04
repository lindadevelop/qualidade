import os
# -*- coding: utf-8 -*-
"""
Importador completo e idempotente de Ações + NC/OM.
USO:
  python import_run.py --dry-run   (simulação; não grava)
  python import_run.py --commit    (executa em transação)
Liga ao PostgreSQL local (samsys_qualidade).
"""
import openpyxl, json, sys, datetime, unicodedata
import psycopg2
from collections import Counter

NC_PATH = "C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_20e5c68a16de_NC_OM.xlsx"
AC_PATH = "C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_01e7008f325c_Livro7.xlsx"
DB = dict(host="127.0.0.1", port=5432, user="postgres", password=os.environ["PGPASSWORD"], dbname="samsys_qualidade")

# utilizadores demo
U_ANA, U_BRUNO, U_DIOGO, U_CARLA, U_EVA, U_FABIO, U_GONCALO, U_INES, U_GERAL = (
 "11111111-1111-1111-1111-111111111111","22222222-2222-2222-2222-222222222222",
 "44444444-4444-4444-4444-444444444444","33333333-3333-3333-3333-333333333333",
 "55555555-5555-5555-5555-555555555555","66666666-6666-6666-6666-666666666666",
 "77777777-7777-7777-7777-777777777777","99999999-9999-9999-9999-999999999999",
 "5735e898-ac3c-4946-9ab8-2cc3e1c63079")

def norm(s):
    if not s: return ""
    s = unicodedata.normalize("NFD", str(s)); s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return s.lower().strip()

def map_responsible(raw):
    if not raw: return None
    s = norm(raw)
    if s in ("não indicado","nao indicado","a definir / conforme plano de ações","a definir / conforme plano de acoes","—","-",""): return None
    named_own = {"márcia costa":U_ANA,"marcia costa":U_ANA,"jose alves":U_DIOGO,"josé alves":U_DIOGO,
             "vitor rodrigues":U_DIOGO,"flávio pacheco":U_DIOGO,"flavio pacheco":U_DIOGO,
             "nuno barros":U_DIOGO,"carlos bernardino":U_CARLA,"humberto santos":U_INES,
             "pedro barbosa":U_GONCALO,"joaquim duarte":U_EVA,"marco ribas":U_EVA,
             "vitor dias":U_DIOGO,"wilson pereira":U_DIOGO,"tania campos":U_FABIO,
             # "Samuel Soares / Ruben Soares" -> gerência
             "samuel soares / ruben soares":U_BRUNO,
             "samuel soares / ruben soares / márcia costa":U_ANA,
             "márcia costa / josé alves":U_ANA,"marcia costa / jose alves":U_ANA,
             "márcia costa / led":U_ANA,"marcia costa / led":U_ANA,
             "márcia costa / líderes":U_ANA,"marcia costa / lideres":U_ANA,
             "equipa logística / pós-venda":U_INES,"equipa logistica / pos-venda":U_INES,
             "equipa logística / gestor conta fornecedor":U_INES,"equipa logistica / gestor conta fornecedor":U_INES,
             "líderes de equipa e diretores":U_BRUNO,"lideres de equipa e diretores":U_BRUNO,
             "líderes e diretores":U_BRUNO,"lideres e diretores":U_BRUNO}
    if s in named_own: return named_own[s]
    if "qualidade" in s: return U_ANA
    if "gerência" in s or "gerencia" in s or "direç" in s or "direc" in s or "líder" in s or "lider" in s: return U_BRUNO
    if "desenvolvimento" in s or "consultoria" in s or "técnic" in s or "tecnic" in s: return U_DIOGO
    if "sistema" in s: return U_CARLA
    if "comercial" in s or "comunicaç" in s or "comunicac" in s: return U_EVA
    if "financeir" in s or "administrativ" in s or "rh" in s: return U_FABIO
    if "phc" in s or "pré-venda" in s or "pre-venda" in s: return U_GONCALO
    if "logístic" in s or "logistic" in s or "fornecedor" in s or "compr" in s or "reclamaç" in s or "reclamac" in s or "jurídico" in s or "juridico" in s:
        return U_INES
    return None

# estado -> enum
OCC_STATUS = {"aberta":"OPEN","em análise":"OPEN","em analise":"OPEN","em implementação":"IN_PROGRESS",
              "em implementacao":"IN_PROGRESS","em verificação de eficácia":"AWAITING_EFFECTIVENESS",
              "em verificacao de eficacia":"AWAITING_EFFECTIVENESS","fechada":"CLOSED","concluída":"CLOSED","concluida":"CLOSED"}
ACT_STATUS = {"em curso":"IN_PROGRESS","em análise":"IN_PROGRESS","em analise":"IN_PROGRESS",
              "a aguardar avaliação de eficácia":"IN_PROGRESS","a aguardar avaliacao de eficacia":"IN_PROGRESS",
              "concluída":"COMPLETED","concluida":"COMPLETED","fechada":"COMPLETED"}
EFF_MAP = {"eficaz":"EFFECTIVE","parcialmente eficaz":"PARTIALLY_EFFECTIVE","ineficaz":"INEFFECTIVE",
           "não avaliada":"NOT_EVALUATED","nao avaliada":"NOT_EVALUATED","não aplicável":"NA","nao aplicavel":"NA"}

def load(path, sheet):
    wb = openpyxl.load_workbook(path, data_only=True); ws = wb[sheet]
    hdr = [c.value for c in ws[1]]
    rows=[]
    for r in ws.iter_rows(min_row=2, values_only=True):
        if any(v is not None for v in r): rows.append(dict(zip(hdr,r)))
    return rows

def load_all():
    nco = [r for r in load(NC_PATH,"NC_OM") if r.get('ID NC')]
    acts = [r for r in load(AC_PATH,"query Tabela de Todas as Ações") if r.get('Title')]
    return nco, acts

nco, acts = load_all()
DRY = "--dry-run" in sys.argv
MODE = "DRY-RUN (não grava)" if DRY else "EXECUÇÃO (grava)"

print(f"MODO: {MODE}")
print(f"NC/OM: {len(nco)}   Ações: {len(acts)}")

conn = psycopg2.connect(**DB); conn.autocommit = False
cur = conn.cursor()

# ---- áreas existentes na BD ----
cur.execute("select name from public.quality_areas")
db_areas = set(r[0] for r in cur.fetchall())
# ---- origens existentes ----
cur.execute("select name from public.quality_origins")
db_origins = set(r[0] for r in cur.fetchall())

# colheita de áreas/origens do Excel
area_pool = {}
for r in nco:
    v = r.get('Processo / Equipa')
    if v: area_pool.setdefault(str(v).strip(), set()).add(("nc", r.get('ID NC')))
for r in acts:
    v = r.get('Processo / Equipa')
    if v: area_pool.setdefault(str(v).strip(), set()).add(("ac", r.get('Title')))
origin_pool = set()
for r in nco:
    if r.get('Origem'): origin_pool.add(str(r.get('Origem')).strip())
for r in acts:
    if r.get('Origem'): origin_pool.add(str(r.get('Origem')).strip())

defined_area = None  # se criar áreas, usar created_by deste id
# obter 'Utilizador Geral' para created_by
cur.execute(f"select id from profiles where id='{U_GERAL}'")
defined_area = U_GERAL if cur.fetchone() else U_ANA

new_areas = sorted(a for a in area_pool if a not in db_areas)
new_origins = sorted(o for o in origin_pool if o not in db_origins)
print(f"\nNovas áreas a criar ({len(new_areas)}): {new_areas}")
print(f"Novas origens a criar ({len(new_origins)}): {new_origins}")

# ---- simulação: pré-registar mapeamento de responsáveis pendentes ----
VAGO = ("não indicado","nao indicado","a definir / conforme plano de ações","a definir / conforme plano de acoes","—","-")
pend_resp = set()
for r in nco + acts:
    src_r = r.get('ID NC') or r.get('Title')
    rp = r.get('Responsável')
    if rp and norm(rp) not in VAGO and not map_responsible(rp):
        pend_resp.add((src_r, str(rp)))
print(f"\nResponsáveis SEM correspondência (excluindo valores vazios): {len(pend_resp)}")
for src_r, nm in sorted(pend_resp, key=lambda x:x[0]):
    print(f"   {src_r}: '{nm}'")

if DRY:
    print("\n[DRY-RUN] Simulação terminada. Nada gravado.")
    conn.rollback(); conn.close(); sys.exit(0)

# ================= EXECUÇÃO =================
try:
    # criar origens novas
    id_orig = {}
    cur.execute("select name,id from public.quality_origins")
    id_orig = {r[0]: r[1] for r in cur.fetchall()}
    for o in new_origins:
        cur.execute("insert into public.quality_origins(name) values (%s) on conflict (name) do nothing returning id", (o,))
        row = cur.fetchone()
        id_orig[o] = row[0] if row else id_orig.get(o)
    # criar áreas novas
    id_area = {}
    cur.execute("select name,id from public.quality_areas")
    id_area = {r[0]: r[1] for r in cur.fetchall()}
    for a in new_areas:
        cur.execute("insert into public.quality_areas(name) values (%s) on conflict (name) do nothing returning id", (a,))
        row = cur.fetchone()
        id_area[a] = row[0] if row else id_area.get(a)

    # ---- pass 1: ocorrências (NC/OM) ----
    stats = Counter(); anomalies = []
    occ_id_by_ref = {}
    for i, r in enumerate(nco, start=2):
        ref = str(r.get('ID NC')).strip()
        anom = []
        # tipo
        tipo = r.get('Tipo NC/OM') or ""
        kind = "NC" if "conformidade" in norm(tipo) or ref.upper().startswith("NC") else "OM"
        # datas
        d_det = r.get('Data deteção'); d_lim = r.get('Data limite'); d_enc = r.get('Data encerramento')
        det = d_det.date() if isinstance(d_det, datetime.datetime) else None
        enc = d_enc.date() if isinstance(d_enc, datetime.datetime) else None
        if not det: anom.append(f"Data deteção inválida/vazia (linha {i})")
        estado = str(r.get('Estado') or "").strip()
        st = OCC_STATUS.get(norm(estado))
        if not st: st = "OPEN"; anom.append(f"Estado '{estado}' -> OPEN (linha {i})")
        eff = str(r.get('Eficácia') or "").strip()
        eff_db = EFF_MAP.get(norm(eff), eff or None)
        if eff and eff_db is None: anom.append(f"Eficácia '{eff}' sem mapa")
        # guard da app: só fecha com eficácia Eficaz validada; senão aguardar eficácia
        est_fecha = st == "CLOSED"
        if est_fecha and eff_db != "EFFECTIVE":
            st = "AWAITING_EFFECTIVENESS"
            anom.append(f"Excel 'Fechada' mas eficácia '{eff}' ≠ Eficaz -> aguardar eficácia (guard app)")
        eff_val_by = U_GERAL if (st == "CLOSED" and eff_db == "EFFECTIVE") else None
        eff_val_at = datetime.datetime.now() if eff_val_by else None
        area_nm = str(r.get('Processo / Equipa') or "").strip() or None
        area_id = id_area.get(area_nm) if area_nm else None
        if area_nm and not area_id: anom.append(f"Área '{area_nm}' não resolvida")
        origem_nm = str(r.get('Origem') or "").strip()
        origem_id = id_orig.get(origem_nm)
        if origem_nm and not origem_id: anom.append(f"Origem '{origem_nm}' não resolvida")
        resp = map_responsible(r.get('Responsável'))
        if r.get('Responsável') and not resp: anom.append(f"Responsável '{r.get('Responsável')}' pendente")
        ano = r.get('Ano')
        try: ano = int(ano)
        except: ano = (det.year if det else None); anom.append("Ano inválido -> data deteção")
        desc = r.get('Descrição da constatação') or r.get('Descrição') or ""
        causa = r.get('Causa identificada')
        if causa and norm(causa) == "—": causa = None
        # status CLOSED -> closed_at
        # upsert por reference
        cur.execute("select id from public.quality_occurrences where reference=%s", (ref,))
        ex = cur.fetchone()
        if ex:
            cur.execute("""update public.quality_occurrences set type=%s,year=%s,origin_id=%s,
                occurrence_date=%s,area_id=%s,description=%s,responsible_user_id=%s,
                cause_analysis=%s,status=%s,effectiveness_status=%s,closed_at=%s,
                effectiveness_validated_by=%s,effectiveness_validated_at=%s
                where reference=%s""",
                (kind,ano,origem_id,det or None,area_id,desc,resp,causa,st,eff_db,
                 (enc if st=="CLOSED" else None),eff_val_by,eff_val_at, ref))
            occ_id = ex[0]; sstat="updated"
        else:
            cur.execute("""insert into public.quality_occurrences
                (reference,type,year,origin_id,occurrence_date,area_id,description,responsible_user_id,
                 cause_analysis,status,effectiveness_status,closed_at,created_by,
                 effectiveness_validated_by,effectiveness_validated_at)
                values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) returning id""",
                (ref,kind,ano,origem_id,det or None,area_id,desc,resp,causa,st,eff_db,
                 (enc if st=="CLOSED" else None), U_GERAL,eff_val_by,eff_val_at))
            occ_id = cur.fetchone()[0]; sstat="created"
        occ_id_by_ref[ref]=occ_id
        stats[(kind, sstat)] += 1
        cur.execute("""insert into public.import_registry(src_file,sheet,row_num,reference,module,kind,status,target_id,raw_data,anomalies)
            values ('NC_OM.xlsx','NC_OM',%s,%s,'occurrence',%s,%s,%s,%s,%s) on conflict (src_file,row_num) do nothing""",
            (i,ref,kind,sstat,occ_id,json.dumps(r,default=str,ensure_ascii=False),json.dumps(anom,ensure_ascii=False)))
        if anom: anomalies.append((ref,"occurrence",i,anom))

    # ---- pass 1b: ações ----
    id_occ_by_ref = dict(occ_id_by_ref)
    # também ocorrências pré-existentes na BD (para NC associada não importadas do Excel)
    cur.execute("select reference,id from public.quality_occurrences")
    for ref,oid in cur.fetchall(): id_occ_by_ref.setdefault(str(ref), oid)

    act_stats = Counter(); act_anom=[]
    for i,r in enumerate(acts, start=2):
        ref = str(r.get('Title')).strip()
        anom=[]
        desc = r.get('Descrição da Ação') or ""
        estado = str(r.get('Estado') or "").strip()
        st = ACT_STATUS.get(norm(estado))
        if not st:
            encerrada = r.get('Encerrada?')
            st = "COMPLETED" if norm(str(encerrada))=="sim" else "IN_PROGRESS"
            anom.append(f"Estado '{estado}' -> {st} (linha {i})")
        resp = map_responsible(r.get('Responsável'))
        if r.get('Responsável') and not resp: anom.append(f"Responsável '{r.get('Responsável')}' pendente")
        # deadline: Data fim prevista = serial corrompido 1900 -> não confiável (anomalia), null
        d_fim = r.get('Data fim prevista')
        if isinstance(d_fim, datetime.datetime) and d_fim.year < 2000:
            anom.append(f"Data fim prevista corrompida (1900) linha {i} -> deadline não preenchida")
            d_fim = None
        elif isinstance(d_fim, datetime.datetime):
            d_fim = d_fim.date()
        else:
            d_fim = None
        # ocorrência associada
        nc_assoc = str(r.get('NC associada') or "").strip()
        occ_id = id_occ_by_ref.get(nc_assoc) if nc_assoc else None
        if nc_assoc and not occ_id: anom.append(f"NC associada '{nc_assoc}' não resolvida")
        # estado COMPLETED -> completed_at: usar Verificação (texto dd/mm/yyyy) se parseável
        verif = r.get('Verificação')
        comp_at = None
        if st=="COMPLETED" and verif:
            try:
                comp_at = datetime.datetime.strptime(str(verif).strip(), "%d/%m/%Y")
            except Exception:
                comp_at = None
        # upsert
        cur.execute("select id from public.quality_actions where reference=%s", (ref,))
        ex = cur.fetchone()
        if ex:
            cur.execute("""update public.quality_actions set occurrence_id=%s,description=%s,
                responsible_user_id=%s,deadline=%s,status=%s,completed_at=%s where reference=%s""",
                (occ_id,desc,resp,d_fim,st,comp_at,ref))
            aid=ex[0]; sstat="updated"
        else:
            cur.execute("""insert into public.quality_actions
                (reference,occurrence_id,description,responsible_user_id,deadline,status,completed_at,created_by)
                values (%s,%s,%s,%s,%s,%s,%s,%s) returning id""",
                (ref,occ_id,desc,resp,d_fim,st,comp_at,U_GERAL))
            aid=cur.fetchone()[0]; sstat="created"
        act_stats[(sstat)]+=1
        cur.execute("""insert into public.import_registry(src_file,sheet,row_num,reference,module,kind,status,target_id,raw_data,anomalies)
            values ('Livro7.xlsx','query Tabela de Todas as Ações',%s,%s,'action','-',%s,%s,%s,%s) on conflict (src_file,row_num) do nothing""",
            (i,ref,sstat,aid,json.dumps(r,default=str,ensure_ascii=False),json.dumps(anom,ensure_ascii=False)))
        if anom: act_anom.append((ref,"action",i,anom))

    conn.commit()
    print("\n=== RESULTADO ===")
    print("Ocorrências:", dict(stats))
    print("Ações:", dict(act_stats))
    print("Novas áreas:", len(new_areas), "| Novas origens:", len(new_origins))
    print("Anomalias ocorrências:", len(anomalies), "| anomalias ações:", len(act_anom))
    print("Responsáveis pendentes:", len(pend_resp))
    conn.close()
except Exception as e:
    conn.rollback()
    print("ERRO -> ROLLBACK:", e)
    import traceback; traceback.print_exc()
    conn.close(); sys.exit(1)