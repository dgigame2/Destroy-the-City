# Gera as pecas do HUD (medidas em px do mockup 1385x1136). Uso: python gerar.py
import math, os, struct, zlib
import numpy as np
OUT = os.path.dirname(os.path.abspath(__file__))

def rgb(h): return np.array([int(h[i:i+2], 16) for i in (1, 3, 5)], float)

class Canvas:
    def __init__(self, w, h, s=2):
        self.s = min(s, 1020 / w); s = self.s
        self.W, self.H = round(w * s), round(h * s)
        self.y, self.x = np.mgrid[0:self.H, 0:self.W]
        self.x = (self.x + .5) / s; self.y = (self.y + .5) / s
        self.c = np.zeros((self.H, self.W, 3)); self.a = np.zeros((self.H, self.W))
    def paint(self, mask, color, alpha=1.0):
        m = np.clip(mask, 0, 1) * alpha
        a = m + self.a * (1 - m)
        den = np.where(a > 0, a, 1)[..., None]
        self.c = (np.asarray(color) * m[..., None] + self.c * (self.a * (1 - m))[..., None]) / den
        self.a = a
    def cover(self, d): return np.clip(.5 - d * self.s, 0, 1)  # distancia -> cobertura suave
    def rr(self, x, y, w, h, r):
        r = min(r, w / 2, h / 2)
        qx = np.abs(self.x - x - w / 2) - w / 2 + r; qy = np.abs(self.y - y - h / 2) - h / 2 + r
        return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r
    def grad(self, y0, y1, top, bot):
        t = np.clip((self.y - y0) / (y1 - y0), 0, 1)[..., None]
        return rgb(top) * (1 - t) + rgb(bot) * t
    def box(self, x, y, w, h, r, layers):
        for t, color in layers:  # (espessura, cor) de fora para dentro
            self.paint(self.cover(self.rr(x, y, w, h, r)), rgb(color))
            x += t; y += t; w -= 2 * t; h -= 2 * t; r = max(r - t, 2)
        return x, y, w, h, r
    def face(self, x, y, w, h, r, top, bot, hi, lo, hit=2, lot=3, studs=None, power=1.0):
        m = self.cover(self.rr(x, y, w, h, r))
        self.paint(m, self.grad(y, y + h, top, bot))
        if studs:
            px, py, sw, sh, inset = studs
            nx = int((w - 2 * inset) // px); ny = max(1, int((h - 2 * inset + py - sh) // py))
            ox = x + (w - (nx - 1) * px - sw) / 2; oy = y + (h - (ny - 1) * py - sh) / 2
            for j in range(ny):
                for i in range(nx):
                    sx, sy = ox + i * px, oy + j * py
                    if inset >= 0 and math.hypot(max(abs(sx + sw / 2 - x - w / 2) - w / 2 + r, 0), max(abs(sy + sh / 2 - y - h / 2) - h / 2 + r, 0)) > r - sw:
                        continue  # nao corta stud na curva do canto
                    sm = self.cover(self.rr(sx, sy, sw, sh, 1.5)) * m
                    self.paint(self.cover(self.rr(sx + .6, sy + 1.4, sw, sh, 1.5)) * m, (0, 0, 0), .20 * power)
                    self.paint(sm, self.grad(y, y + h, top, bot))
                    self.paint(sm, (255, 255, 255), .10 * power)
                    self.paint(sm * self.cover(self.y - sy - 1.2), (255, 255, 255), .16 * power)
        # brilho em cima e ressalto embaixo acompanham a curva
        up = m * (1 - self.cover(self.rr(x, y + hit, w, h, r)))
        dn = m * (1 - self.cover(self.rr(x, y - lot, w, h, r)))
        self.paint(dn, rgb(lo)); self.paint(up, rgb(hi))
    def save(self, name):
        img = np.dstack([self.c, self.a * 255]).round().clip(0, 255).astype(np.uint8)
        raw = b"".join(b"\0" + row.tobytes() for row in img)
        ch = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
        with open(os.path.join(OUT, name + ".png"), "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", self.W, self.H, 8, 6, 0, 0, 0))
                    + ch(b"IDAT", zlib.compress(raw, 9)) + ch(b"IEND", b""))
        print(name, self.W, self.H)

INK = "#050D20"
c = Canvas(676, 174)  # painel azul
b = c.box(0, 0, 676, 174, 46, [(4, INK), (6, "#132D58"), (1.5, "#0A1C40")])
c.face(*b, "#1A4A90", "#0D3270", "#6D91C9", "#2A5592", 2, 2, (21, 20.5, 11, 10, -14), 1.4); c.save("Panel")

for name, dia, top, bot in (("RingLeft", 156, "#4AE0F7", "#1FBEE6"), ("RingRight", 190, "#B2CFE2", "#7C9DBA")):
    c = Canvas(dia, dia)
    b = c.box(0, 0, dia, dia, dia, [(4, INK), (5.5, "#122953"), (3, "#071735")])
    right = name == "RingRight"
    c.face(*b, top, bot, "#E4F6FF" if right else "#9CF2FF", "#4E708F" if right else "#129CC4", 2, 3)
    # fundo: borda escura (os raios e o brilho sao camadas animadas: RingSwirl e RingGlow)
    inside = c.cover(c.rr(b[0] + 2, b[1] + 2, b[2] - 4, b[3] - 5, dia))
    dx, dy = c.x - dia / 2, c.y - dia / 2
    rad = np.hypot(dx, dy) / (dia / 2 - 14)
    c.paint(inside * np.clip(rad, 0, 1) ** 2, rgb("#2F506E" if right else "#0573A6"), .75)
    d = np.abs(c.rr(5, 5, dia - 10, dia - 10, dia)) - 1  # filete de luz no aro, mais forte em cima
    c.paint(c.cover(d) * np.clip(1 - c.y / dia, 0, 1), rgb("#6E98D0"), .8); c.save(name)

c = Canvas(128, 128)  # raios que giram no circulo
dx, dy = c.x - 64, c.y - 64
rad = np.hypot(dx, dy) / 64
inside = c.cover(np.hypot(dx, dy) - 63)
rays = np.clip(np.sin((np.arctan2(dy, dx) + rad * 1.1) * 10) * 4 + .5, 0, 1)
c.paint(inside * rays * np.clip(rad * 1.5, 0, 1), rgb("#FFFFFF")); c.save("RingSwirl")
c = Canvas(128, 128)  # brilho do centro
c.paint(np.clip(np.exp(-(rad / .55) ** 2) - .037, 0, 1) * inside, rgb("#FFFFFF")); c.save("RingGlow")

c = Canvas(616, 62)  # trilho do XP
b = c.box(0, 0, 616, 62, 31, [(2.5, INK), (2.5, "#35BCE8"), (3, INK)])
c.face(*b, "#0A2550", "#123A74", "#06142F", "#1B4A86", 3, 1, (21, 20, 11, 10, 4), 1.2); c.save("XpTrack")
c = Canvas(600, 46)  # preenchimento do XP
c.face(0, 0, 600, 46, 23, "#16E7FC", "#04CFF6", "#A5FBFF", "#0796C4", 2, 4, (21, 20, 11, 10, 4), .75); c.save("XpFill")

c = Canvas(604, 62)  # trilho da vida
b = c.box(0, 0, 604, 62, 22, [(3, INK), (4, "#24528C"), (2.5, INK)])
c.face(*b, "#3A0A10", "#561018", "#24060A", "#6E1A22", 3, 1, (19.5, 20, 9.5, 9, 3), 1); c.save("HpTrack")
c = Canvas(585, 43)  # preenchimento da vida
c.face(0, 0, 585, 43, 13, "#FF3A3D", "#F00810", "#FF9A98", "#B00008", 2.5, 4, (19.5, 20, 9.5, 9, 3), .7); c.save("HpFill")

c = Canvas(412, 82)  # EVOLVE
b = c.box(0, 0, 412, 82, 27, [(4.5, "#0A0F20")])
c.face(*b, "#FFBB08", "#FF8B05", "#FFE796", "#D05E04", 2.5, 4, (20, 21.5, 10, 10, 9), .75); c.save("Evolve")
c = Canvas(54, 50)  # tecla R
b = c.box(0, 0, 54, 50, 10, [(3, "#070F20")])
c.face(*b, "#243C63", "#10223F", "#657C9D", "#0B1931", 2, 3); c.save("KeyR")

c = Canvas(226, 68)  # plaquinha SKILL / ATTACK
b = c.box(0, 0, 226, 68, 19, [(3.5, INK), (4.5, "#17386A"), (1.5, "#3F6699")])
c.face(*b, "#12305F", "#0C2850", "#0A2148", "#6E93C6", 1, 1.5); c.save("Plate")
c = Canvas(68, 58)  # tecla roxa
b = c.box(0, 0, 68, 58, 12, [(3, "#1A082E")])
c.face(*b, "#D040FF", "#9A08EC", "#F0A6FF", "#6909AC", 2.5, 4, (16, 16, 9, 8, 5), .8); c.save("Key")

c = Canvas(92, 84)  # coracao (formula de iq)
def heart(scale):
    px = np.abs(c.x - 46) / scale; py = (79 - c.y) / scale
    k = np.hypot(px - .25, py - .75) - math.sqrt(2) / 4
    m = .5 * np.maximum(px + py, 0)
    low = np.sqrt(np.minimum(px**2 + (py - 1)**2, (px - m)**2 + (py - m)**2)) * np.sign(px - py)
    return np.where(px + py > 1, k, low) * scale
d = heart(66)
c.paint(c.cover(d - 4), rgb("#080C17"))
m = c.cover(d); c.paint(m, c.grad(6, 76, "#FF3B3F", "#E3040C"))
c.paint(m * np.clip((d + 7) / 7, 0, 1) * np.clip((c.y - 40) / 30, 0, 1), rgb("#A00008"), .75)
hl = np.exp(-(((c.x - 27) / 10)**2 + ((c.y - 19) / 6)**2)) + .7 * np.exp(-(((c.x - 66) / 9)**2 + ((c.y - 17) / 5)**2))
c.paint(m * np.clip(hl, 0, 1), rgb("#FFB2A7"), .9); c.save("Heart")

c = Canvas(48, 48, .75)  # mira: o Roblox desenha no tamanho da imagem
d = np.abs(np.hypot(c.x - 24, c.y - 24) - 13) - 1.6
for cx, cy, w, h in ((24, 8, 3, 8), (24, 40, 3, 8), (8, 24, 8, 3), (40, 24, 8, 3), (24, 24, 3, 3)):
    d = np.minimum(d, c.rr(cx - w / 2, cy - h / 2, w, h, 1.5))
c.paint(c.cover(d - 1.8), rgb("#202838")); c.paint(c.cover(d), rgb("#FFFFFF")); c.save("Crosshair")

# ---- janela de rebirth (px da propria janela, UiConfig.RebirthMenu)
c = Canvas(440, 373)
b = c.box(0, 0, 440, 373, 26, [(4, INK), (5, "#132D58"), (1.5, "#0A1C40")])
c.face(*b, "#16417F", "#0B2C63", "#6D91C9", "#2A5592", 2, 2, (21, 20, 10, 9, 14), .55); c.save("Window")
for name, w, h, r, top, bot, hi, lo, ink in (
    ("WindowTitle", 362, 56, 16, "#FFBB08", "#FF8B05", "#FFE796", "#D05E04", "#0A0F20"),
    ("WindowClose", 56, 56, 16, "#FF4A4D", "#E3040C", "#FFA9A6", "#A00008", "#0A0F20"),
    ("RowPurple", 400, 46, 14, "#C840FF", "#9A08EC", "#F0A6FF", "#6909AC", INK),
    ("RowCyan", 400, 46, 14, "#16E7FC", "#04BFE8", "#A5FBFF", "#0796C4", INK),
    ("RowRed", 400, 46, 14, "#FF3A3D", "#F00810", "#FF9A98", "#B00008", INK),
    ("RowBlue", 400, 46, 14, "#3E9BFF", "#1566E0", "#A9D4FF", "#0C429C", INK),
):
    c = Canvas(w, h)
    b = c.box(0, 0, w, h, r, [(3.5, ink)])
    c.face(*b, top, bot, hi, lo, 2, 3.5, (20, 18, 9, 8, 6), .7); c.save(name)
