import re
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable, KeepTogether
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748b"))
        
        # Header (Pages > 1)
        if self._pageNumber > 1:
            self.drawString(42, 802, "Oracle 19c RAC (2 Nós) no Oracle Linux 9 — Diário de Engenharia")
            self.setStrokeColor(colors.HexColor("#cbd5e1"))
            self.setLineWidth(0.5)
            self.line(42, 796, 553, 796)

        # Footer (All pages)
        self.setStrokeColor(colors.HexColor("#cbd5e1"))
        self.setLineWidth(0.5)
        self.line(42, 45, 553, 45)
        
        self.drawString(42, 32, "Autor: Arley Ribeiro  |  Oracle Database 19c RAC & ASM")
        page_str = f"Página {self._pageNumber} de {page_count}"
        self.drawRightString(553, 32, page_str)
        self.restoreState()


def format_inline(text):
    # Escape XML chars first
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    
    # Protect inline code blocks first using placeholders
    code_tokens = []
    def code_repl(m):
        code_tokens.append(m.group(1))
        return f"___CODE_TOKEN_{len(code_tokens)-1}___"
    
    text = re.sub(r'`(.*?)`', code_repl, text)
    
    # Bold + Italic: ***text***
    text = re.sub(r'\*\*\*(.*?)\*\*\*', r'<b><i>\1</i></b>', text)
    # Bold: **text**
    text = re.sub(r'\*\*(.*?)\*\*', r'<b>\1</b>', text)
    # Italic: *text*
    text = re.sub(r'(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)', r'<i>\1</i>', text)
    
    # Links
    def repl_link(m):
        label, url = m.group(1), m.group(2)
        if url.startswith(('http://', 'https://', 'mailto:')):
            return f'<a href="{url}" color="#0284c7"><u>{label}</u></a>'
        return f'<font color="#0f2d59"><b>{label}</b></font>'
    
    text = re.sub(r'\[(.*?)\]\((.*?)\)', repl_link, text)
    
    # Restore code tokens
    for idx, code_val in enumerate(code_tokens):
        formatted_code = f'<font name="Courier" color="#b31d28" size="8"><b>{code_val}</b></font>'
        text = text.replace(f"___CODE_TOKEN_{idx}___", formatted_code)
    
    return text


def build_pdf(md_path, pdf_path):
    with open(md_path, 'r', encoding='utf-8') as f:
        md_content = f.read()

    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=A4,
        leftMargin=42,
        rightMargin=42,
        topMargin=54,
        bottomMargin=54,
        title="Diário de Engenharia: Oracle Database 19c RAC em Oracle Linux 9",
        author="Arley Ribeiro",
        subject="Provisionamento, Troubleshooting e Validação do Oracle 19c RAC, Grid Infrastructure e ASM com UDEV no Oracle Linux 9",
        creator="Arley Ribeiro da Silva Xavier",
        keywords="Oracle RAC, Oracle 19c, ASM, Grid Infrastructure, Oracle Linux 9, VirtualBox, Vagrant, DBA"
    )

    styles = getSampleStyleSheet()
    
    # Custom palette
    primary_color = colors.HexColor("#0f2d59")
    secondary_color = colors.HexColor("#1e40af")
    text_color = colors.HexColor("#1e293b")
    
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=16,
        leading=20,
        textColor=primary_color,
        spaceAfter=10
    )

    h2_style = ParagraphStyle(
        'Heading2_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11.5,
        leading=15,
        textColor=primary_color,
        spaceBefore=12,
        spaceAfter=5,
        keepWithNext=True
    )

    h3_style = ParagraphStyle(
        'Heading3_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=9.5,
        leading=13,
        textColor=secondary_color,
        spaceBefore=8,
        spaceAfter=3,
        keepWithNext=True
    )

    body_style = ParagraphStyle(
        'Body_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=12,
        textColor=text_color,
        spaceAfter=4
    )

    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=12,
        textColor=text_color,
        leftIndent=15,
        firstLineIndent=-10,
        spaceAfter=2
    )

    subbullet_style = ParagraphStyle(
        'SubBullet_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.2,
        leading=11.5,
        textColor=text_color,
        leftIndent=28,
        firstLineIndent=-10,
        spaceAfter=1.5
    )

    table_cell_style = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.8,
        leading=10.5,
        textColor=text_color
    )

    table_header_style = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.2,
        leading=11,
        textColor=colors.white
    )

    story = []
    lines = md_content.split('\n')
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]

        # Empty line
        if not line.strip():
            i += 1
            continue

        # Code block
        if line.strip().startswith('```'):
            code_lines = []
            lang = line.strip()[3:].strip()
            i += 1
            while i < n and not lines[i].strip().startswith('```'):
                code_lines.append(lines[i])
                i += 1
            if i < n:
                i += 1 # skip closing ```
            
            code_text = '\n'.join(code_lines)
            
            code_style = ParagraphStyle(
                'CodeText',
                fontName='Courier',
                fontSize=7.2,
                leading=9.8,
                textColor=colors.HexColor("#0f172a")
            )
            escaped_code = code_text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace(" ", "&nbsp;").replace("\n", "<br/>")
            code_para = Paragraph(escaped_code, code_style)
            
            code_table = Table([[code_para]], colWidths=[511])
            code_table.setStyle(TableStyle([
                ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#f8fafc")),
                ('BOX', (0,0), (-1,-1), 0.75, colors.HexColor("#cbd5e1")),
                ('TOPPADDING', (0,0), (-1,-1), 4),
                ('BOTTOMPADDING', (0,0), (-1,-1), 4),
                ('LEFTPADDING', (0,0), (-1,-1), 6),
                ('RIGHTPADDING', (0,0), (-1,-1), 6),
            ]))
            story.append(Spacer(1, 3))
            story.append(code_table)
            story.append(Spacer(1, 4))
            continue

        # Horizontal Rule
        if line.strip() in ['---', '***', '___']:
            story.append(Spacer(1, 3))
            story.append(HRFlowable(width="100%", thickness=0.6, color=colors.HexColor("#cbd5e1"), spaceBefore=3, spaceAfter=5))
            i += 1
            continue

        # H1
        if line.startswith('# '):
            text = format_inline(line[2:].strip())
            story.append(Paragraph(text, title_style))
            i += 1
            continue

        # H2
        if line.startswith('## '):
            text = format_inline(line[3:].strip())
            story.append(Paragraph(text, h2_style))
            i += 1
            continue

        # H3
        if line.startswith('### '):
            text = format_inline(line[4:].strip())
            story.append(Paragraph(text, h3_style))
            i += 1
            continue

        # Table
        if line.strip().startswith('|') and '|' in line[1:]:
            table_rows = []
            while i < n and lines[i].strip().startswith('|'):
                tline = lines[i].strip()
                if re.match(r'^\|(\s*:?-+:?\s*\|)+$', tline):
                    i += 1
                    continue
                cells = [c.strip() for c in tline.split('|')[1:-1]]
                table_rows.append(cells)
                i += 1
            
            if table_rows:
                formatted_data = []
                num_cols = max(len(row) for row in table_rows)
                for r_idx, row in enumerate(table_rows):
                    row_data = []
                    for c_idx in range(num_cols):
                        val = row[c_idx] if c_idx < len(row) else ""
                        c_style = table_header_style if r_idx == 0 else table_cell_style
                        row_data.append(Paragraph(format_inline(val), c_style))
                    formatted_data.append(row_data)

                if num_cols == 2:
                    col_widths = [130, 381]
                elif num_cols == 4:
                    col_widths = [95, 70, 160, 186]
                else:
                    col_widths = [511 / num_cols] * num_cols

                t = Table(formatted_data, colWidths=col_widths)
                t.setStyle(TableStyle([
                    ('BACKGROUND', (0,0), (-1,0), primary_color),
                    ('ALIGN', (0,0), (-1,-1), 'LEFT'),
                    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                    ('TOPPADDING', (0,0), (-1,-1), 3),
                    ('BOTTOMPADDING', (0,0), (-1,-1), 3),
                    ('LEFTPADDING', (0,0), (-1,-1), 5),
                    ('RIGHTPADDING', (0,0), (-1,-1), 5),
                    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.HexColor("#ffffff"), colors.HexColor("#f8fafc")]),
                    ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#cbd5e1")),
                ]))
                story.append(Spacer(1, 3))
                story.append(t)
                story.append(Spacer(1, 5))
            continue

        # Bullet List & Numbered List
        if re.match(r'^(\s*)[-\*]\s+', line) or re.match(r'^(\s*)\d+\.\s+', line):
            indent_spaces = len(re.match(r'^(\s*)', line).group(1))
            cleaned_text = re.sub(r'^\s*([-\*]|\d+\.)\s+', '', line)
            
            m_num = re.match(r'^\s*(\d+\.)\s+', line)
            prefix = f"{m_num.group(1)} " if m_num else "&bull; "
            
            p_style = subbullet_style if indent_spaces >= 3 else bullet_style
            story.append(Paragraph(f"{prefix}{format_inline(cleaned_text)}", p_style))
            i += 1
            continue

        # Regular Paragraph
        para_lines = [line]
        i += 1
        while i < n and lines[i].strip() and not lines[i].strip().startswith(('#', '|', '```', '---', '***', '- ', '* ')) and not re.match(r'^\s*\d+\.\s+', lines[i]):
            para_lines.append(lines[i])
            i += 1
        
        full_p_text = " ".join([l.strip() for l in para_lines])
        story.append(Paragraph(format_inline(full_p_text), body_style))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF successfully generated: {pdf_path}")

if __name__ == '__main__':
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    md_file = os.path.join(base_dir, "docs", "livro_sessao_oracle_rac.md")
    pdf_file = os.path.join(base_dir, "docs", "livro_sessao_oracle_rac.pdf")
    build_pdf(md_file, pdf_file)
