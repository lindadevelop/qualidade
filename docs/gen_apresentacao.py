#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Gera a apresentação de produto SAMSYS|Qualidade em PDF — estilo Gamma (claro, contraste alto)."""
import json, sys
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm, cm
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable)

def esc(s):
    return s.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')

def main(spec_path, out_path):
    with open(spec_path, encoding='utf-8') as f:
        spec = json.load(f)

    INDIGO = colors.HexColor('#2f2f6b')
    TEXT   = colors.HexColor('#26262c')
    MUTED  = colors.HexColor('#55556b')
    LIGHT  = colors.HexColor('#eef0fb')
    HEADBG = colors.HexColor('#2f2f6b')
    HEADTX = colors.white

    st_titulo  = ParagraphStyle('T', fontName='Helvetica-Bold', fontSize=26, leading=31, textColor=INDIGO, spaceAfter=6)
    st_h1      = ParagraphStyle('H1', fontName='Helvetica-Bold', fontSize=16, leading=20, textColor=INDIGO, spaceBefore=14, spaceAfter=6)
    st_body    = ParagraphStyle('B', fontName='Helvetica', fontSize=10.5, leading=15.5, textColor=TEXT, alignment=TA_LEFT, spaceAfter=5)
    st_cell    = ParagraphStyle('C', fontName='Helvetica', fontSize=9.5, leading=12.5, textColor=TEXT)
    st_cellb   = ParagraphStyle('CB', fontName='Helvetica-Bold', fontSize=9.5, leading=12.5, textColor=TEXT)
    st_head    = ParagraphStyle('TH', fontName='Helvetica-Bold', fontSize=9.8, leading=12.5, textColor=HEADTX)

    story = []
    for el in spec.get('elements', []):
        t = el.get('type')
        if t == 'heading':
            level = el.get('level', 1)
            if 'text' in el and el.get('size', 16) > 20:
                story.append(Paragraph(esc(el.get('text','')), st_titulo))
            else:
                story.append(Paragraph(esc(el.get('text','')), st_h1))
            story.append(HRFlowable(width='100%', thickness=1.2, color=INDIGO, spaceBefore=1, spaceAfter=8))
        elif t == 'paragraph':
            style = st_body
            if el.get('bold'):
                style = ParagraphStyle('Bb', parent=st_body, fontName='Helvetica-Bold')
            story.append(Paragraph(esc(el.get('text','')), style))
        elif t == 'table':
            rows = el.get('rows', [])
            header = el.get('header', True)
            data = []
            if header:
                data.append([Paragraph(esc(c), st_head) for c in el.get('header', [])])
            for r in rows:
                data.append([Paragraph(esc(c), st_cellb if c == r[0] else st_cell) for c in r])
            tw = A4[0] - 42*mm
            colw = [tw*0.34, tw*0.66]
            tbl = Table(data, colWidths=colw, repeatRows=1 if header else 0)
            style = [
                ('VALIGN', (0,0), (-1,-1), 'TOP'),
                ('GRID', (0,0), (-1,-1), 0.4, colors.HexColor('#d8d8e6')),
                ('LEFTPADDING', (0,0), (-1,-1), 7),
                ('RIGHTPADDING', (0,0), (-1,-1), 7),
                ('TOPPADDING', (0,0), (-1,-1), 5),
                ('BOTTOMPADDING', (0,0), (-1,-1), 5),
            ]
            if header:
                style += [
                    ('BACKGROUND', (0,0), (-1,0), HEADBG),
                    ('TEXTCOLOR', (0,0), (-1,0), HEADTX),
                ]
            for i in range(1, len(data)):
                if i % 2 == 0:
                    style.append(('BACKGROUND', (0,i), (-1,i), LIGHT))
            tbl.setStyle(TableStyle(style))
            story.append(tbl)
            story.append(Spacer(1, 9))
        elif t == 'pagebreak':
            from reportlab.platypus import PageBreak
            story.append(PageBreak())

    def footer(canv, doc):
        canv.saveState()
        canv.setFont('Helvetica', 8.5)
        canv.setFillColor(MUTED)
        canv.drawCentredString(A4[0]/2, 12*mm, f'SAMSYS|Qualidade · {doc.page}')
        canv.restoreState()

    doc = SimpleDocTemplate(
        out_path, pagesize=A4,
        title='SAMSYS|Qualidade — Apresentação do Produto',
        author='SAMSYS',
        leftMargin=21*mm, rightMargin=21*mm, topMargin=18*mm, bottomMargin=20*mm,
    )
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(json.dumps({'output': out_path, 'elements': len(spec.get('elements', []))}))
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))