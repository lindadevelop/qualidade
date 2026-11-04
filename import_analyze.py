# -*- coding: utf-8 -*-
import openpyxl, datetime
from openpyxl.utils.datetime import from_excel

def sheet_info(path, sheet=None):
    wb = openpyxl.load_workbook(path, data_only=True)
    print("FICHEIRO:", path.split('/')[-1])
    print("  Folhas:", wb.sheetnames)
    ws = wb[sheet] if sheet else wb[wb.sheetnames[0]]
    print("  Folha usada:", ws.title, "| dims:", ws.dimensions, "| max_row:", ws.max_row, "| max_col:", ws.max_column)
    # cabeçalho
    hdr = [c.value for c in ws[1]]
    print("  Cabeçalho:", hdr)
    return wb, ws, hdr

def show_dates(path, sheet, ncols_range):
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb[sheet]
    print("\n===== Datas em", path.split('/')[-1], "/", sheet, "=====")
    for row in ws.iter_rows(min_row=1, max_row=6):
        vals = []
        for c in row:
            if c.column_letter in ncols_range or True:
                v = c.value
                dt = None
                try:
                    if isinstance(v,(int,float)) and v>1000:
                        dt = from_excel(v)
                        if isinstance(dt, datetime.datetime) and dt.year<1950:
                            dt = None
                except Exception:
                    dt=None
                s = repr(v)[:28]
                if dt: s += f"  -> {dt.date()}"
                vals.append(f"{c.column_letter}={s}")
        print(" | ".join(vals))

# NC_OM - colunas de data: Data deteção(B), Data limite(L), Data encerramento(P)
show_dates("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_20e5c68a16de_NC_OM.xlsx", "NC_OM", ["B","L","P"])
# Livro7 - colunas: Data início(K), Data fim prevista(L), Verificação(M... ) vejamos cabeçalho
wb,ws,hdr = sheet_info("C:/Users/carlo/AppData/Local/hermes/cache/documents/doc_01e7008f325c_Livro7.xlsx")
print("\nÍndices Livro7:")
for i,h in enumerate(hdr):
    print(f"  col {i}: {h}")