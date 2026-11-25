"""Baixa as transcrições de 100 vídeos do YouTube para a pasta "transcricoes".

Como usar (Windows):
  1. Instale o Python: https://www.python.org/downloads/ (marque "Add python.exe to PATH").
  2. Abra o PowerShell nesta pasta e rode:
       python -m pip install youtube-transcript-api
       python baixar_transcricoes.py
  3. Quando terminar, zipe a pasta "transcricoes" e mande o zip.

Pode parar a qualquer hora (Ctrl+C) e rodar de novo: o que já baixou é pulado.
Os 10 primeiros são os mais importantes. Se o YouTube bloquear, o script para sozinho;
nesse caso, mande o que já baixou ou tente de novo outro dia.
"""
import re
import time
from pathlib import Path

import requests
from youtube_transcript_api import YouTubeTranscriptApi

PASTA = Path(__file__).parent / "transcricoes"
IDIOMAS = ["en", "en-US", "pt-BR", "pt", "es"]
PAUSA = 15  # segundos entre vídeos, para não ser bloqueado

VIDEOS = [
    ("monetizacao", "MJ-zYfL10Ew"),
    ("monetizacao", "hoMbv_R8AMU"),
    ("loops", "XTZxQvh1qkc"),
    ("loops", "bROouMt1b3g"),
    ("retencao", "LpAU6TheAZ4"),
    ("retencao", "hbzGO_Qonu0"),
    ("diversao", "216_5nu4aVQ"),
    ("ui", "Ezk3vEOvv8o"),
    ("monetizacao", "zoz3PSMqets"),
    ("retencao", "ZhQ_jKFnFSU"),
    ("retencao", "xIBc5He_sy4"),
    ("retencao", "zm1ypw2mLPI"),
    ("retencao", "zXzXOw5605E"),
    ("retencao", "ZpQbc7NtjXM"),
    ("retencao", "byM3x2HaAe4"),
    ("retencao", "fPT2GCkK1QM"),
    ("retencao", "dUmh6GAvJ-E"),
    ("retencao", "HxYGLLNczC8"),
    ("retencao", "7L8vAGGitr8"),
    ("retencao", "IwgTGFwk99M"),
    ("retencao", "uSzfYp2-Ubg"),
    ("retencao", "aErOwjZr33A"),
    ("retencao", "KTZm_lUMHuY"),
    ("retencao", "CRL8hBrf-Xo"),
    ("retencao", "dr1ziW-mamU"),
    ("retencao", "AbjI7ygMnao"),
    ("retencao", "Le4QhC3dDGk"),
    ("loops", "gkFKF9A-snY"),
    ("loops", "gc7K98RlOik"),
    ("loops", "aDE69s3pp7M"),
    ("loops", "wTbSrOexWZU"),
    ("loops", "6SYX17NzNqE"),
    ("loops", "PMj8Q4ViKzs"),
    ("loops", "Sk-nbAtIUko"),
    ("loops", "xznspQkSD6c"),
    ("loops", "yGhfUcPjXuE"),
    ("loops", "S5camMoNw-o"),
    ("loops", "Ae_zvm0-CQU"),
    ("loops", "gDQX3jk5xxc"),
    ("loops", "Zrf1cou_yVo"),
    ("loops", "Jqh7SVpMR1o"),
    ("loops", "fOhvepjtF9Q"),
    ("loops", "2FeMvQJloCE"),
    ("loops", "N2FND74tgGE"),
    ("loops", "MIMMJ4xHYR8"),
    ("ui", "F6AtQKo3uIY"),
    ("ui", "9kuWl_t1AOE"),
    ("ui", "RPqIm0I_gsw"),
    ("ui", "FK3kBKCn6s8"),
    ("ui", "zqNxVsTYCJ0"),
    ("ui", "YNCTZwIkpGg"),
    ("ui", "6ozhIpdyF-8"),
    ("ui", "pP5u9in-mh0"),
    ("ui", "y2Q9iF1LEfo"),
    ("ui", "AH_ugxmLeUM"),
    ("ui", "EOcY3hPMQkk"),
    ("ui", "wIuVvCuiJhU"),
    ("ui", "ONBqAZ9KuLk"),
    ("ui", "4Bv45aPMGyI"),
    ("ui", "dL152bMdK0k"),
    ("ui", "d640TphrQYQ"),
    ("ui", "5_3BUU9ZmNo"),
    ("ui", "bE_ZuNp1CTI"),
    ("ui", "73Pqsk74Jc0"),
    ("monetizacao", "-PoyiiGhoNo"),
    ("monetizacao", "a170E9klbP4"),
    ("monetizacao", "JG37MoDpOTw"),
    ("monetizacao", "k4j5DsbQnHM"),
    ("monetizacao", "5uXLixtTgJM"),
    ("monetizacao", "gXKoxaK6Ufg"),
    ("monetizacao", "x_SflcuSi1w"),
    ("monetizacao", "6rNer7ybunU"),
    ("monetizacao", "N-u2gI4DUyw"),
    ("monetizacao", "zgq6L4ZzCHs"),
    ("monetizacao", "66n0P2NtBoQ"),
    ("monetizacao", "ZAfE-Row9tU"),
    ("monetizacao", "yn4V-fBdUm8"),
    ("monetizacao", "JyDkSDHEBfQ"),
    ("monetizacao", "59AbBgxhfTA"),
    ("monetizacao", "uDw2h1vxeTs"),
    ("monetizacao", "uA2hcnFITR4"),
    ("diversao", "HUIjr39EsdE"),
    ("diversao", "lkatr_a1OMQ"),
    ("diversao", "56ENqlUST9U"),
    ("diversao", "RqmHvVabdL0"),
    ("diversao", "3EmDlsj27nA"),
    ("diversao", "6sZJYA06z7Y"),
    ("diversao", "U0a-IE5xawo"),
    ("diversao", "0m60QbT85Tc"),
    ("diversao", "iIOIT3dCy5w"),
    ("diversao", "Cm2_drGLGbc"),
    ("diversao", "78rPt0RsosQ"),
    ("diversao", "dWrun9VckWU"),
    ("diversao", "xnlaYLnCtFc"),
    ("diversao", "Fy0aCDmgnxg"),
    ("diversao", "qCj9CZoAvFY"),
    ("diversao", "JVZmxVDzkjk"),
    ("diversao", "G8AT01tuyrk"),
    ("diversao", "uuc6DRe4U4Q"),
    ("diversao", "5Fk7p-f2ymY"),
]


def titulo(vid):
    try:
        j = requests.get("https://www.youtube.com/oembed",
                         params={"url": f"https://www.youtube.com/watch?v={vid}", "format": "json"},
                         timeout=15).json()
        return f"{j['title']} — {j['author_name']}"
    except Exception:
        return vid


def main():
    api = YouTubeTranscriptApi()
    feitos = 0
    for n, (tema, vid) in enumerate(VIDEOS, 1):
        destino = PASTA / tema / f"{vid}.txt"
        if destino.exists():
            continue
        try:
            lista = api.list(vid)
            try:
                tr = lista.find_transcript(IDIOMAS)
            except Exception:
                tr = next(iter(lista))
            trechos = tr.fetch()
        except Exception as e:
            nome = type(e).__name__
            print(f"{n:3}/100 [ERRO] {vid}: {nome}")
            if nome in ("IpBlocked", "RequestBlocked"):
                print("O YouTube bloqueou esta internet. Mande o que já baixou ou tente outro dia.")
                break
            continue
        linhas = []
        for t in trechos:
            m, s = divmod(int(t.start), 60)
            linhas.append(f"[{m:02d}:{s:02d}] {t.text}")
        destino.parent.mkdir(parents=True, exist_ok=True)
        cab = (f"# {titulo(vid)}\nhttps://www.youtube.com/watch?v={vid}\n"
               f"Idioma: {tr.language} ({'automática' if tr.is_generated else 'manual'})\n\n")
        destino.write_text(cab + "\n".join(linhas), encoding="utf-8")
        feitos += 1
        print(f"{n:3}/100 [OK] {tema}/{vid}")
        time.sleep(PAUSA)
    print(f"\nPronto: {feitos} novos nesta rodada. Zipe a pasta 'transcricoes' e mande.")


if __name__ == "__main__":
    main()
