#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gera um mapa mental em PDF do fluxo de NC/OM e Ações do SAMSYS|Qualidade."""

import os
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

OUTPUT = r'C:\a\samsys-qualidade\docs\mapa-mental-nc-om-acoes.pdf'

# Cores do tema Samsys
PRIMARY = colors.HexColor('#7367f0')
SECONDARY = colors.HexColor('#00cfe8')
DANGER = colors.HexColor('#ea5455')
WARNING = colors.HexColor('#ff9f43')
SUCCESS = colors.HexColor('#28c76f')
INFO = colors.HexColor('#00cfe8')
DARK = colors.HexColor('#3b3b4f')
LIGHT_BG = colors.HexColor('#f5f5f9')
WHITE = colors.white

def draw_rounded_rect(c, x, y, w, h, r, fill, stroke=1):
    c.setFillColor(fill)
    c.setStrokeColor(DARK if stroke else fill)
    c.roundRect(x, y, w, h, r, fill=1, stroke=stroke)

def draw_text(c, x, y, text, size=10, color=DARK, bold=False, align='left'):
    c.setFont('Helvetica-Bold' if bold else 'Helvetica', size)
    c.setFillColor(color)
    if align == 'center':
        tw = c.stringWidth(text, 'Helvetica-Bold' if bold else 'Helvetica', size)
        x = x - tw / 2
    elif align == 'right':
        tw = c.stringWidth(text, 'Helvetica-Bold' if bold else 'Helvetica', size)
        x = x - tw
    c.drawString(x, y, text)

def draw_arrow(c, x1, y1, x2, y2, color=DARK):
    c.setStrokeColor(color)
    c.setLineWidth(1.2)
    c.line(x1, y1, x2, y2)
    # seta simples
    angle = 0
    if abs(x2 - x1) > 0.01:
        angle = (y2 - y1) / (x2 - x1)
    # desenha pequena ponta
    c.setFillColor(color)
    c.circle(x2, y2, 1.5, fill=1, stroke=0)

def box(c, x, y, w, h, title, lines, color, title_color=WHITE):
    draw_rounded_rect(c, x, y, w, h, 6, color)
    # faixa do título
    c.setFillColor(colors.Color(color.red * 0.85, color.green * 0.85, color.blue * 0.85))
    c.roundRect(x, y + h - 18, w, 18, 6, fill=1, stroke=0)
    # cobrir parte inferior para ficar retângulo
    c.rect(x, y + h - 18, w, 12, fill=1, stroke=0)
    draw_text(c, x + 6, y + h - 12, title, size=10, color=title_color, bold=True)
    ly = y + h - 32
    for line in lines:
        draw_text(c, x + 8, ly, line, size=8, color=DARK)
        ly -= 12

def main():
    c = canvas.Canvas(OUTPUT, pagesize=landscape(A4))
    w, h = landscape(A4)
    c.setTitle('SAMSYS|Qualidade - Fluxo NC/OM e Ações')
    c.setAuthor('SAMSYS|Qualidade')

    # Fundo
    c.setFillColor(LIGHT_BG)
    c.rect(0, 0, w, h, fill=1, stroke=0)

    # Título
    draw_text(c, w / 2, h - 1.2 * cm, 'SAMSYS|Qualidade — Mapa Mental: Não Conformidades / OM e Ações', size=18, color=DARK, bold=True, align='center')
    draw_text(c, w / 2, h - 1.9 * cm, 'Fluxo completo de funcionamento', size=11, color=colors.HexColor('#5d596c'), align='center')

    # ----- Coluna 1: Ocorrência -----
    box(c, 1.2 * cm, h - 5.5 * cm, 6 * cm, 3.2 * cm, '1. Ocorrência (NC / OM)', [
        '• Tipo: NC (Não Conformidade)',
        '• Tipo: OM (Oportunidade Melhoria)',
        '• Referência auto: NC-AAAA-0001',
        '• Origem, Área, Data, Descrição',
        '• Responsável e Análise de Causa',
    ], PRIMARY)

    # ----- Estados da Ocorrência (linha central) -----
    states = [
        ('ABERTA', 'OPEN', DANGER),
        ('EM CURSO', 'IN_PROGRESS', WARNING),
        ('AGUARDA EFICÁCIA', 'AWAITING_EFFECTIVENESS', INFO),
        ('ENCERRADA', 'CLOSED', SUCCESS),
    ]
    sx = 9 * cm
    sy = h - 4.5 * cm
    sw = 3.4 * cm
    sh = 1.4 * cm
    for i, (label, code, color) in enumerate(states):
        x = sx + i * (sw + 1.2 * cm)
        draw_rounded_rect(c, x, sy, sw, sh, 8, color)
        draw_text(c, x + sw / 2, sy + sh - 20, label, size=10, color=WHITE, bold=True, align='center')
        draw_text(c, x + sw / 2, sy + 10, code, size=8, color=colors.HexColor('#f0f0f0'), align='center')
        if i < len(states) - 1:
            draw_arrow(c, x + sw, sy + sh / 2, x + sw + 1.2 * cm, sy + sh / 2, DARK)

    # Seta da ocorrência para o primeiro estado
    draw_arrow(c, 7.2 * cm, h - 4.0 * cm, 9 * cm, h - 4.0 * cm, DARK)
    draw_text(c, 7.6 * cm, h - 3.7 * cm, 'cria', size=8, color=DARK)

    # ----- Transições automáticas -----
    trans_y = h - 6.8 * cm
    draw_text(c, sx, trans_y, 'Transições automáticas:', size=10, color=DARK, bold=True)
    draw_text(c, sx, trans_y - 0.5 * cm, '• Ação criada → OPEN passa a IN_PROGRESS', size=9, color=DARK)
    draw_text(c, sx, trans_y - 0.9 * cm, '• Todas as ações concluídas → AWAITING_EFFECTIVENESS', size=9, color=DARK)
    draw_text(c, sx, trans_y - 1.3 * cm, '• Eficácia validada como EFICAZ → CLOSED', size=9, color=DARK)
    draw_text(c, sx, trans_y - 1.7 * cm, '• Eficácia NÃO EFICAZ → volta a IN_PROGRESS', size=9, color=DARK)

    # ----- Coluna 2: Ações -----
    box(c, 1.2 * cm, h - 10.5 * cm, 6 * cm, 3.6 * cm, '2. Plano de Ações', [
        '• Ações vinculadas à ocorrência',
        '• Referência auto: ACT-00001',
        '• Responsável, Prazo, Estado',
        '• Estados: TODO / IN_PROGRESS / COMPLETED',
        '• Registo de trabalho (work logs)',
        '• Progresso % e horas realizadas',
    ], SECONDARY)

    draw_arrow(c, 7.2 * cm, h - 8.7 * cm, 9 * cm, h - 6.8 * cm, DARK)

    # ----- Plano de Conformidade -----
    box(c, sx, h - 10.5 * cm, 7 * cm, 3.6 * cm, '3. Plano de Conformidade (opcional)', [
        '• Rascunho / Proposto / Ativo / Concluído',
        '• Pode requerer aprovação designada',
        '• Aprovador designado vs Administrador',
        '• Histórico de aprovação imutável',
        '• Ações podem ser ligadas ao plano',
    ], colors.HexColor('#9b8cff'))

    draw_arrow(c, 9 * cm + 3.4 * cm, h - 8.7 * cm, 9 * cm + 3.5 * cm, h - 6.8 * cm, DARK)

    # ----- Copiloto IA -----
    box(c, sx + 8 * cm, h - 10.5 * cm, 5.5 * cm, 3.0 * cm, '4. Copiloto IA (assistivo)', [
        '• Analisa estado da ocorrência',
        '• Propõe Plano de Conformidade',
        '• NÃO persiste sem confirmação',
        '• Humano decide e valida',
    ], colors.HexColor('#6f42c1'))

    # ----- Eficácia -----
    box(c, sx + 14.5 * cm, h - 10.5 * cm, 5.5 * cm, 3.0 * cm, '5. Validação de Eficácia', [
        '• Disponível em AWAITING_EFFECTIVENESS',
        '• Resultado: Eficaz / Não Eficaz',
        '• Notas e evidências',
        '• Apenas Quality/Admin valida',
    ], SUCCESS)

    # ----- Permissões -----
    box(c, 1.2 * cm, h - 15.0 * cm, 6 * cm, 3.4 * cm, 'Permissões', [
        '• Quality / Admin: tudo',
        '• Management: leitura',
        '• Responsável: leitura da ocorrência',
        '• Action owner: atualiza própria ação',
        '• RLS no PostgreSQL',
    ], WARNING)

    # ----- Entidades / Tabelas -----
    box(c, sx, h - 15.0 * cm, 6.5 * cm, 3.4 * cm, 'Entidades Principais', [
        '• quality_occurrences',
        '• quality_actions',
        '• quality_compliance_plans',
        '• quality_work_logs',
        '• quality_attachments / comments',
        '• audit_log (histórico imutável)',
    ], INFO)

    # ----- Regras de Negócio -----
    box(c, sx + 7.5 * cm, h - 15.0 * cm, 7.5 * cm, 3.4 * cm, 'Regras de Negócio', [
        '• Ação concluída NÃO encerra ocorrência automaticamente',
        '• Ocorrência só encerra após eficácia validada',
        '• Reabertura limpa eficácia e data de encerramento',
        '• Eliminação bloqueada se houver dependências',
        '• Referências geradas atomicamente (sem duplicados)',
    ], DANGER)

    # ----- Rodapé -----
    draw_text(c, w / 2, 0.8 * cm, 'SAMSYS|Qualidade — documento gerado automaticamente a partir do código e migrations', size=8, color=colors.HexColor('#a5a3ae'), align='center')

    c.showPage()

    # ===== Página 2: Fluxograma detalhado =====
    c.setFillColor(LIGHT_BG)
    c.rect(0, 0, w, h, fill=1, stroke=0)
    draw_text(c, w / 2, h - 1.2 * cm, 'Fluxograma Detalhado — Ciclo de Vida de uma Ocorrência', size=16, color=DARK, bold=True, align='center')

    # Caixas de fluxo
    flow = [
        (1.5 * cm, h - 3.5 * cm, 'Criação', ['Utilizador com permissão preenche', 'tipo, origem, área, descrição...'], PRIMARY),
        (6.5 * cm, h - 3.5 * cm, 'Registo', ['BD gera referência única', 'status = OPEN'], colors.HexColor('#9b8cff')),
        (11.5 * cm, h - 3.5 * cm, 'Plano de Ações', ['Adicionam-se ações com', 'responsável e prazo'], SECONDARY),
        (16.5 * cm, h - 3.5 * cm, 'Execução', ['Responsável executa e regista', 'progresso / work logs'], WARNING),
        (21.5 * cm, h - 3.5 * cm, 'Conclusão Ações', ['Todas COMPLETED?', '→ AWAITING_EFFECTIVENESS'], INFO),
        (21.5 * cm, h - 7.0 * cm, 'Validação Eficácia', ['Quality/Admin decide', 'EFICAZ ou NÃO EFICAZ'], SUCCESS),
        (16.5 * cm, h - 7.0 * cm, 'Encerramento', ['Se EFICAZ → CLOSED', 'com data e validador'], colors.HexColor('#6f42c1')),
        (11.5 * cm, h - 7.0 * cm, 'Não Eficaz', ['Volta a IN_PROGRESS', 'novas ações podem ser criadas'], DANGER),
        (6.5 * cm, h - 7.0 * cm, 'Reabertura', ['A qualquer momento', 'se necessário'], colors.HexColor('#82828f')),
    ]

    for x, y, title, lines, color in flow:
        box(c, x, y, 4.2 * cm, 2.4 * cm, title, lines, color)

    # Setas entre caixas do fluxograma
    arrows = [
        (5.7 * cm, h - 2.3 * cm, 6.5 * cm, h - 2.3 * cm),
        (10.7 * cm, h - 2.3 * cm, 11.5 * cm, h - 2.3 * cm),
        (15.7 * cm, h - 2.3 * cm, 16.5 * cm, h - 2.3 * cm),
        (20.7 * cm, h - 2.3 * cm, 21.5 * cm, h - 2.3 * cm),
        (23.6 * cm, h - 3.5 * cm, 23.6 * cm, h - 4.6 * cm),
        (21.5 * cm, h - 5.8 * cm, 20.7 * cm, h - 5.8 * cm),
        (16.5 * cm, h - 5.8 * cm, 15.7 * cm, h - 5.8 * cm),
        (11.5 * cm, h - 5.8 * cm, 10.7 * cm, h - 5.8 * cm),
        (6.5 * cm, h - 5.8 * cm, 5.7 * cm, h - 5.8 * cm),
        (3.6 * cm, h - 4.6 * cm, 3.6 * cm, h - 3.5 * cm),
    ]
    for x1, y1, x2, y2 in arrows:
        draw_arrow(c, x1, y1, x2, y2, DARK)

    # Notas adicionais
    notes_y = h - 10.5 * cm
    draw_text(c, 1.5 * cm, notes_y, 'Notas importantes:', size=11, color=DARK, bold=True)
    notes = [
        '• Ocorrências podem ter anexos (evidências) e comentários em qualquer estado.',
        '• O audit_log regista todas as alterações em ocorrências e ações (create / update / delete).',
        '• O Plano de Conformidade é opcional e pode ser gerado manualmente ou proposto pelo Copiloto IA.',
        '• O fluxo de aprovação do plano distingue o APROVADOR DESIGNADO do ADMINISTRADOR/Sistema.',
        '• A IA é sempre assistiva: propõe, mas só persiste após confirmação humana.',
    ]
    for i, note in enumerate(notes):
        draw_text(c, 1.5 * cm, notes_y - 0.6 * cm - i * 0.5 * cm, note, size=9, color=DARK)

    draw_text(c, w / 2, 0.8 * cm, 'SAMSYS|Qualidade — fluxo baseado nas migrations 0002, 0003, 0030, 0048, 0049 e no frontend Vue 3', size=8, color=colors.HexColor('#a5a3ae'), align='center')

    c.save()
    print(f'PDF gerado: {OUTPUT}')

if __name__ == '__main__':
    main()
