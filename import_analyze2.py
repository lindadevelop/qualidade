# -*- coding: utf-8 -*-
import openpyxl
from openpyxl.utils.datetime import from_excel
import datetime

wb = openpyxl.load_workbook("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_01e7008f325c_Livro7.xlsx", data_only=True)
ws = wb["query Tabela de Todas as Ações"]
print("=== colunas de data Livro7 (sem data_only): mostro valor cru + células formatadas")
# carregar sem data_only para ver formatos e valores numéricos crus
wb2 = openpyxl.load_workbook("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_01e7008f325c_Livro7.xlsx")
ws2 = wb2["query Tabela de Todas as Ações"]
print("que células têm formato de data: coluna K (Data início) e L (Data fim prevista), M (verificação)")
for r in range(2,8):
    for col in ["K","L","M","N"]:  # K=Data início, L=fim, M=Verificação, N=... 
        cell = ws2[f"{col}{r}"]
        v = ws[f"{col}{r}"].value if ws[f"{col}{r}"] and ws[f"{col}{r}"].value is not None else None
        vraw = cell.value
        vfmt = cell.number_format
        interp = ""
        try:
            if isinstance(vraw,(int,float)) and vraw>1000:
                dt = from_excel(vraw)
                interp = f"-> {dt.date()}"
        except Exception: pass
        print(f"  {col}{r}: formato='{vfmt}' cru={vraw!r} data_only={v!r} {interp}")
    print("  ---")
# estatística: valores das colunas K,L como números (datas serial)
import statistics
from collections import Counter
for col,name in [("K","Data início"),("L","Data fim prevista"),("M","Verificação")]:
    nums=[]
    for r in range(2,ws2.max_row+1):
        v = ws2[f"{col}{r}"].value
        if isinstance(v,(int,float)) and 1000<v<60000: nums.append(v)
        elif isinstance(v, datetime.datetime): pass
    if nums:
        print(f"{name} (col {col}): {len(nums)} numéricas, min={min(nums):.3f} max={max(nums):.3f}")
        # mostrar amostra das primeiras e formatos
        for r in range(2,6):
            cv=ws2[f"{col}{r}"]; print(f"   {col}{r} fmt='{cv.number_format}' val={cv.value!r}")
    else:
        print(f"{name} (col {col}): sem datas numéricas; amostra: {[ws2[f'{col}{r}'].value for r in range(2,5)]}")