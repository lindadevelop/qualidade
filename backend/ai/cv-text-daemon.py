# cv-text-daemon.py — extração de texto de PDFs via pymupdf (bridge para Node)
# Lê linhas JSON no stdin: {"path": "...", "ocr": false} -> {"ok": true, "text": "...", "pages": N, "ocr_used": false}
# Se o texto for insuficiente (digitalização), tenta OCR se TESSERACT_BIN estiver definido.
import sys, os, json, tempfile, subprocess, shutil

TESSERACT = os.environ.get('TESSERACT_BIN', '')
MIN_TEXT = 40  # caracteres mínimos para considerar "tem texto"

def pdf_to_images(pdf_path, out_prefix):
    """Renderiza páginas do PDF para PNG (via pymupdf)."""
    try:
        import pymupdf
        doc = pymupdf.open(pdf_path)
        paths = []
        for i, page in enumerate(doc):
            pix = page.get_pixmap(dpi=200)
            p = f"{out_prefix}_{i}.png"
            pix.save(p)
            paths.append(p)
        doc.close()
        return paths
    except Exception as e:
        return {"error": str(e)}

def extract_text(pdf_path):
    try:
        import pymupdf
        doc = pymupdf.open(pdf_path)
        parts, total = [], 0
        for page in doc:
            t = page.get_text("text")
            parts.append(t)
            total += len(t)
        n = doc.page_count
        doc.close()
        return "\n".join(parts), n
    except Exception as e:
        return None, str(e)

def ocr_images(imgs):
    parts = []
    for p in imgs:
        try:
            r = subprocess.run([TESSERACT, p, "stdout", "-l", "por+eng"], capture_output=True, text=True, timeout=120)
            parts.append(r.stdout or "")
        except Exception as e:
            parts.append(f"[erro OCR: {e}]")
    return "\n".join(parts)

def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception:
            continue
        pdf = req.get("path", "")
        try:
            text, meta = extract_text(pdf)
            if isinstance(text, str) is False and meta is not None:
                # erro
                sys.stdout.write(json.dumps({"ok": False, "error": f"extração falhou: {meta}"}) + "\n")
                sys.stdout.flush()
                continue
            pages = meta if isinstance(meta, int) else 0
            ocr_used = False
            if text is None or len(text.strip()) < MIN_TEXT:
                # pouco ou nenhum texto -> digitalização; tentar OCR se disponível
                if TESSERACT and os.path.exists(TESSERACT):
                    tmp = tempfile.mkdtemp(prefix="cvocr_")
                    imgs = pdf_to_images(pdf, os.path.join(tmp, "pg"))
                    if isinstance(imgs, dict) and imgs.get("error"):
                        text = ""
                    else:
                        text = ocr_images(imgs)
                        ocr_used = True
                    shutil.rmtree(tmp, ignore_errors=True)
                else:
                    text = ""
            sys.stdout.write(json.dumps({
                "ok": True,
                "text": text or "",
                "pages": pages,
                "ocr_used": ocr_used,
                "has_text": bool(text and len(text.strip()) >= MIN_TEXT),
            }) + "\n")
            sys.stdout.flush()
        except Exception as e:
            sys.stdout.write(json.dumps({"ok": False, "error": str(e)}) + "\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()