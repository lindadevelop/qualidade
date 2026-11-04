# Editable strategic report. Every record is paginated; none is silently omitted.
import json
import sys
import re
import textwrap
import base64
from io import BytesIO
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor

def color(value, fallback):
    value = value or fallback
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        value = fallback
    return RGBColor.from_string(value[1:])

LABELS = {'high':'Alto','medium':'Médio','low':'Baixo','risk':'Risco','opportunity':'Oportunidade','identified':'Identificado','analyzing':'Em análise','mitigating':'Em tratamento','monitored':'Monitorizado','closed':'Fechado','draft':'Rascunho','approved':'Aprovado','active':'Ativo','achieved':'Alcançado','cancelled':'Cancelado','todo':'Por iniciar','in_progress':'Em curso','completed':'Concluído','proposed':'Proposta','rejected':'Rejeitado','implemented':'Implementado','daily':'Diária','weekly':'Semanal','monthly':'Mensal','quarterly':'Trimestral','yearly':'Anual','monitor':'Monitorizar','not_relevant':'Não relevante'}
def translate(value):
    return LABELS.get(value,value or '—')
def display_date(value):
    if not value: return 'Por definir'
    parts=str(value)[:10].split('-')
    return '/'.join(reversed(parts)) if len(parts)==3 else str(value)

def build(payload, output):
    prs = Presentation()
    prs.slide_width, prs.slide_height = Inches(13.333), Inches(7.5)
    org = payload.get('organization') or {}
    brand = payload.get('brandKit') or {}
    template = payload.get('template') or {}
    included = template.get('sections', ['meeting','swot','tows','risks','objectives','actions','kpis','decisions'])
    body_size = max(18, min(24, template.get('body_font_size',18)))
    line_count = max(6, min(10, template.get('lines_per_slide',10)))
    wrap_width = int(88 * 18 / body_size)
    primary = color(brand.get('primary_color') or org.get('primary_color'), '#7367f0')
    ink = color(brand.get('text_color'), '#2c2c2c')
    font = brand.get('font_body') or 'Aptos'
    heading_font = brand.get('font_heading') or font

    def textbox(slide, text, x, y, w, h, size, bold=False, rgb=None):
        box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
        tf = box.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_right = 0
        for i, line in enumerate(str(text).split('\n')):
            p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            p.text = line
            p.font.name = heading_font if bold else font
            p.font.size, p.font.bold = Pt(size), bold
            p.font.color.rgb = rgb or ink
            p.space_after = Pt(8)
        return box

    def page(title, lines, note=''):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        # Long titles remain complete in notes and are wrapped into a separate content page.
        short_title = title if len(title) <= 100 else title[:97] + '…'
        textbox(slide, short_title, .7, .4, 11.9, 1.2, 30, True, primary)
        textbox(slide, '\n'.join(lines), .8, 1.8, 11.7, 4.8, body_size)
        textbox(slide, f"{org.get('name','Organização')} · {len(prs.slides)}", .8, 7, 11.7, .3, 10)
        if brand.get('logo_base64'):
            from PIL import Image
            logo = BytesIO(base64.b64decode(brand['logo_base64']))
            w,h = Image.open(logo).size
            scale = min(1.6/w,.4/h)
            logo.seek(0)
            slide.shapes.add_picture(logo, Inches(11), Inches(6.85), width=Inches(w*scale), height=Inches(h*scale))
        slide.notes_slide.notes_text_frame.text = title + '\n' + note + '\nGerado em: ' + payload.get('generatedAt','')

    def section(title, entries):
        key = 'swot' if title.startswith('SWOT') else 'tows' if title.startswith('TOWS') else 'objectives' if title.startswith('Objetivo') else 'actions' if title.startswith('Ações') else 'kpis' if title.startswith('KPI') else 'risks' if title.startswith('Riscos') else 'decisions' if title.startswith('Decisões') else 'meeting' if title=='Reunião' else 'cover'
        if key=='cover' and not template.get('include_cover',True) or key!='cover' and key not in included: return
        lines=[]
        if len(title)>100:
            lines.extend(textwrap.wrap(title,wrap_width))
        for entry in entries or ['Sem registos']:
            # Wrap each record into bounded lines and retain complete content across pages.
            wrapped = textwrap.wrap(str(entry),wrap_width,break_long_words=True,replace_whitespace=True) or ['—']
            lines.extend(wrapped)
            lines.append('')
        for offset in range(0,len(lines),line_count):
            page(title + (' · continuação' if offset else ''),lines[offset:offset+line_count], '\n'.join(map(str,entries)))

    section('Plano Estratégico', [org.get('name','Organização'), 'Plataforma Estratégica v1.5', 'Fotografia dos dados registados; rascunhos e estados mantidos conforme a aplicação.'])
    meeting=payload.get('meeting')
    if meeting: section('Reunião',[meeting.get('title',''), meeting.get('description') or '', f"Data: {meeting.get('scheduled_at','')} | Estado: {meeting.get('status','')}"])
    labels={'strengths':'Forças','weaknesses':'Fraquezas','opportunities':'Oportunidades','threats':'Ameaças'}
    for campaign in payload.get('swotCampaigns',[]):
        for key,label in labels.items():
            section(f"SWOT · {campaign.get('name','')} · {label}",[f"{i.get('title','')} — {i.get('description') or ''} | Impacto: {translate(i.get('impact') or 'n/d')}" for i in campaign.get('items',[]) if i.get('quadrant')==key])
        section(f"TOWS · {campaign.get('name','')}",[f"{c.get('strategy_type','').upper()} | {c.get('name','')} — {c.get('description') or ''} | Destino: {translate(c.get('disposition','monitor'))}" for c in campaign.get('crossings',[])])
    section('Riscos e oportunidades',[f"{translate(r.get('type',''))} | {r.get('title','')} | P {r.get('probability','—')} × I {r.get('impact','—')} = {r.get('score','—')} | Estado: {translate(r.get('status',''))} | Tratamento: {r.get('mitigation') or 'Por definir'}" for r in payload.get('risks',[])])
    for obj in payload.get('objectives',[]):
        section(f"Objetivo {obj.get('code','')}",[obj.get('name',''),obj.get('description') or '',f"Estado: {translate(obj.get('status',''))} | Progresso: {obj.get('progress',0)}% | Prazo: {display_date(obj.get('due_date'))}"])
        section(f"Ações · {obj.get('code','')}",[f"{a.get('name','')} | {translate(a.get('status',''))} | {a.get('progress',0)}% | Prazo: {display_date(a.get('due_date'))} | {a.get('description') or ''}" for a in obj.get('actions',[])])
    for k in payload.get('kpis',[]):
        targets={t['period']:t for t in k.get('targets',[])}
        results={r['period']:r for r in k.get('results',[])}
        entries=[f"{k.get('name','')} | Unidade: {k.get('unit') or '—'} | Frequência: {translate(k.get('frequency',''))} | Fonte: {k.get('data_source') or 'Por definir'}"]
        for period in sorted(set(targets)|set(results)):
            t,r=targets.get(period,{}),results.get(period,{})
            entries.append(f"{period} | Meta: {t.get('target_value','—')} | Resultado: {r.get('value','—')} | Alerta/tolerância: {t.get('warning_value') if t.get('warning_value') is not None else '—'} | {r.get('notes') or ''}")
        section(f"KPI {k.get('code','')}",entries)
    section('Decisões registadas',[f"{d.get('title','')} | Estado: {translate(d.get('status',''))} | {d.get('rationale') or d.get('description') or ''}" for d in payload.get('decisions',[])])
    if not len(prs.slides): page('Sem registos', ['Não existem dados nas secções selecionadas.'])
    prs.save(output)

if __name__ == '__main__':
    build(json.load(sys.stdin),sys.argv[1])
    print(json.dumps({'ok':True}))
