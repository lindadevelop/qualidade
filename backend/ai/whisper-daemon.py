#!/usr/bin/env python3
# whisper-daemon.py — Daemon de transcrição (faster-whisper local).
# Carrega o modelo UMA vez; lê caminhos de ficheiro, uma por linha, no stdin (JSON request)
# e escreve JSON no stdout: {"ok":true,"text":"...","duration_s":...} ou {"ok":false,"error":"..."}
# Comunicação stdio -> chamável de qualquer processo Node (voice-service.js).
import json, sys, os, time

MODEL = os.environ.get('STT_MODEL', 'small')
LANG = os.environ.get('STT_LANGUAGE', 'pt') or None
DEVICE = os.environ.get('STT_DEVICE', 'auto')
COMPUTE = os.environ.get('STT_COMPUTE_TYPE', 'int8')

_model = None
def get_model():
    global _model
    if _model is None:
        from faster_whisper import WhisperModel
        sys.stderr.write(f'[whisper] a carregar modelo {MODEL} ({DEVICE}/{COMPUTE})...\n')
        _model = WhisperModel(MODEL, device=DEVICE, compute_type=COMPUTE)
        sys.stderr.write('[whisper] modelo pronto\n')
        sys.stderr.flush()
    return _model

def transcribe(path):
    t0 = time.time()
    model = get_model()
    lang = LANG if LANG and LANG != 'auto' else None
    segments, info = model.transcribe(path, language=lang, vad_filter=True)
    text = ' '.join((s.text or '').strip() for s in segments).strip()
    return text, time.time() - t0

def main():
    sys.stderr.write(f'[whisper] daemon pronto (model={MODEL}, lang={LANG or "auto"})\n')
    sys.stderr.flush()
    # carrega o modelo no arranque (uma vez) para o 1º pedido ser rápido
    try: get_model()
    except Exception as e:
        sys.stderr.write(f'[whisper] erro a carregar: {e}\n')
    for line in sys.stdin:
        line = line.strip()
        if not line: continue
        try:
            req = json.loads(line)
            path = req.get('path') or line
        except Exception:
            path = line
        try:
            text, elapsed = transcribe(path)
            out = {"ok": True, "text": text, "elapsed_s": round(elapsed, 2)}
        except Exception as e:
            out = {"ok": False, "error": str(e)}
        sys.stdout.write(json.dumps(out, ensure_ascii=False) + '\n')
        sys.stdout.flush()

if __name__ == '__main__':
    main()