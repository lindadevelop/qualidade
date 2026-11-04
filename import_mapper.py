# -*- coding: utf-8 -*-
"""
Importação de Ações + NC/OM do Excel para o programa de Gestão da Qualidade.
Idempotente: numa 2ª execução não cria duplicados (atualiza por referência).
Decisões do utilizador:
  - Áreas do Excel criadas como novas em quality_areas.
  - Responsáveis do Excel mapeados por keyword para os utilizadores demo; sem
    correspondência -> pendente de revisão (responsável null).
  - Campos sem correspondência preservados em import_registry (raw_data).
Usa transactions com ROLLBACK em caso de erro técnico.
"""
import openpyxl, json, re, sys, uuid
from collections import defaultdict

NC_PATH = "C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_20e5c68a16de_NC_OM.xlsx"
AC_PATH = "C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_01e7008f325c_Livro7.xlsx"

# ---------- utilizadores demo (BD) ----------
USERS = {
    "ana":   "11111111-1111-1111-1111-111111111111",  # Ana Qualidade   (quality)
    "bruno": "22222222-2222-2222-2222-222222222222",  # Bruno Direção   (management)
    "carla": "33333333-3333-3333-3333-333333333333",  # Carla Sistemas  (action_owner)
    "diogo": "44444444-4444-4444-4444-444444444444",  # Diogo Dev       (action_owner)
    "eva":   "55555555-5555-5555-5555-555555555555",  # Eva Comercial   (action_owner)
    "fabio": "66666666-6666-6666-6666-666666666666",  # Fábio Financeiro(action_owner)
    "goncalo":"77777777-7777-7777-7777-777777777777", # Gonçalo PHC     (action_owner)
    "ines":  "99999999-9999-9999-9999-999999999999",  # Inês Logística  (action_owner)
    "geral": "5735e898-ac3c-4946-9ab8-2cc3e1c63079",  # Utilizador Geral (quality)
}

# Mapeamento de responsáveis do Excel -> utilizador demo (keyword).
# Proibido aproximar duvidoso: sem keyword conhecida -> None (pendente de revisão).
def map_responsible(raw):
    if not raw: return None
    s = str(raw).strip().lower()
    if s in ("não indicado", "nao indicado", "", "—", "-", "a definir / conforme plano de ações", "a definir / conforme plano de acoes"):
        return None
    # nomes que contêm 'qualidade' -> Ana Qualidade
    if "qualidade" in s: return USERS["ana"]
    if "gerência" in s or "gerencia" in s or "direç" in s or "direc" in s or "líderes" in s or "lideres" in s or "gerencia" in s:
        return USERS["bruno"]
    if "desenvolvimento" in s or "consultoria" in s or "técnica" in s or "tecnica" in s or "formação test" in s:
        return USERS["diogo"]
    if "sistemas" in s: return USERS["carla"]
    if "comercial" in s or "comunicaç" in s or "comunicac" in s: return USERS["eva"]
    if "financeiro" in s or "administrativo" in s or "rh" in s and "qualidade" not in s: return USERS["fabio"]
    if "phc" in s or "pré-venda" in s or "pre-venda" in s: return USERS["goncalo"]
    if "logística" in s or "logistica" in s or "fornecedor" in s or "compras" in s or "reclamaç" in s or "reclamac" in s:
        return USERS["ines"]
    # nomes próprios conhecidos do registo
    known = {
        "márcia costa": USERS["ana"], "jose alves": USERS["diogo"], "josé alves": USERS["diogo"],
        "vitor rodrigues": USERS["diogo"], "flávio pacheco": USERS["diogo"], "flavio pacheco": USERS["diogo"],
        "nuno barros": USERS["diogo"], "carlos bernardino": USERS["carla"],
        "humberto santos": USERS["ines"], "pedro barbosa": USERS["goncalo"],
        "joaquim duarte": USERS["eva"], "marco ribas": USERS["eva"],
    }
    if s in known: return known[s]
    return None  # pendente de revisão

# Área do Excel: gerar nome limpo (sem '/'); se já existir usa; senão cria.
def clean_area(raw):
    if not raw: return None
    return str(raw).strip()