#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genere les sprites SVG pixel-perfect de DEPTH FIRST.

Chaque sprite est une grille ASCII : c'est la SOURCE editable. Le script
emet du SVG strictement entier (<rect> uniquement, aucune courbe, aucun
gradient) avec shape-rendering="crispEdges".

    python3 tools/gen_sprites.py

Retoucher un sprite : editer sa grille ici, relancer, et regarder le
resultat dans la galerie du jeu (bouton en-tete) plutot que dans un
explorateur de fichiers : le pixel art se juge a la bonne echelle.

Ajouter un sprite : une entree dans SPRITES, puis sa cle dans
SpriteSheet.keys (lib/ui/theme/art.dart).
"""

import math
import os

# ── Palette Dark Fantasy / PICO-8 Gothic ────────────────────────────
# ROLES STRICTEMENT SEPARES : une couleur = une signification. C'est ce
# qui permet de lire la grille d'un coup d'oeil sur un ecran de 6 pouces.
#   G  n'appartient QU'AU HEROS et a l'execution. Jamais a la sortie,
#      jamais a un bonus : sinon le curseur d'execution se confond avec
#      le decor, et le jeu devient illisible pendant un run.
PALETTE = {
    '0': '#11061A',  # contour, mortier, ombre profonde
    '1': '#1A0C27',  # pierre sombre (murs)
    '2': '#2A1B35',  # pierre moyenne (sol)
    '3': '#4A3B52',  # pierre claire, lichen
    '4': '#8B7D93',  # os
    '5': '#D0C8D6',  # os clair, reflet
    'G': '#39FF14',  # SPECTRE - heros, reperes, execution. Rien d'autre.
    'R': '#FF0055',  # SANG - danger mortel
    'F': '#FF5500',  # FEU - pointe de danger, flamme, accent chaud
    'A': '#FFB000',  # AMBRE - objet requis, serrure
    'C': '#00E5FF',  # CYAN - case bonus (temps)
    'f': '#181024',  # brouillard clair
    'v': '#0D0616',  # vide, abime, brouillard profond
}
TRANSPARENT = '.'

SPRITES = {}


def nested(rings, size=16):
    """Anneaux concentriques : lit comme un puits vu d'aplomb."""
    grid = []
    for y in range(size):
        row = ''
        for x in range(size):
            depth = min(y, size - 1 - y, x, size - 1 - x)
            row += rings[min(depth, len(rings) - 1)]
        grid.append(row)
    return grid


def poke(grid, pixels):
    """Pose des pixels sur une grille existante."""
    g = [list(r) for r in grid]
    for x, y, ch in pixels:
        g[y][x] = ch
    return [''.join(r) for r in g]


# ════════════════════════════════════════════════════════════════════
# SOL — doit rester le fond le plus neutre : c'est lui qui tuile
# partout. Le lisere bas/droite fait le joint entre dalles.
# ════════════════════════════════════════════════════════════════════
SPRITES['floor'] = [
    '2222222222222221',
    '2222222222222221',
    '2212222222222221',
    '2222222222222221',
    '2222222222322221',
    '2222222222222221',
    '2222222222222221',
    '2222232222222221',
    '2222222222222221',
    '2222222222212221',
    '2222222222222221',
    '2232222222222221',
    '2222222222222221',
    '2222222222222221',
    '2222222222222221',
    '1111111111111111',
]

# Variante gravee, a semer une dalle sur cinq pour casser la repetition.
SPRITES['floor_rune'] = [
    '2222222222222221',
    '2222222222222221',
    '2222222222222221',
    '2222333333222221',
    '2223222222322221',
    '2223200002322221',
    '2223202202322221',
    '2223202202322221',
    '2223200002322221',
    '2223222222322221',
    '2222333333222221',
    '2222222222222221',
    '2222222222222221',
    '2232222222222221',
    '2222222222222221',
    '1111111111111111',
]

# ════════════════════════════════════════════════════════════════════
# MURS — PLUS SOMBRES que le sol. Le mur se lit comme un plein, le sol
# comme un chemin : c'est la lecture de base de toute la grille.
# ════════════════════════════════════════════════════════════════════
SPRITES['wall'] = [
    '0000000000000000',
    '0111110111111110',
    '0111110111111110',
    '0111110111111110',
    '0000000000000000',
    '1110111111101111',
    '1110111111101111',
    '1110111111101111',
    '0000000000000000',
    '0111110111111110',
    '0111110111111110',
    '0111110111111110',
    '0000000000000000',
    '1110111111101111',
    '1110111111101111',
    '1110111111101111',
]

SPRITES['wall_lichen'] = [
    '0000000000000000',
    '0111110111111110',
    '0113110111111110',
    '0133110111111110',
    '0000000000000000',
    '1110111111101111',
    '1110111111101331',
    '1110111111101311',
    '0000000000000000',
    '0111110111111110',
    '0111110113111110',
    '0111110111111110',
    '0000000000000000',
    '1110111111101111',
    '1113111111101111',
    '1110111111101111',
]

# ════════════════════════════════════════════════════════════════════
# PICS — vue du dessus stricte : cinq pointes vues d'aplomb, coeur
# incandescent. Dalle plus sombre que le sol : le danger s'annonce.
# ════════════════════════════════════════════════════════════════════
SPRITES['spike'] = [
    '1111111111111111',
    '1111111111111111',
    '111R11111111R111',
    '11RFR111111RFR11',
    '111R11111111R111',
    '1111111111111111',
    '1111111111111111',
    '1111111R11111111',
    '111111RFR1111111',
    '1111111R11111111',
    '1111111111111111',
    '111R11111111R111',
    '11RFR111111RFR11',
    '111R11111111R111',
    '1111111111111111',
    '0000000000000000',
]

# ════════════════════════════════════════════════════════════════════
# VIDE — chute franche vers le noir. Doit se distinguer du mur AU
# PREMIER COUP D'OEIL : la ou le mur a une trame de briques, l'abime
# est lisse, ebreche sur les bords, et liesere de sang.
# ════════════════════════════════════════════════════════════════════
SPRITES['pit'] = poke(
    nested(['1', '0', 'v', 'v', 'v', 'v', 'v', 'v']),
    [(4, 1, 'R'), (11, 1, 'R'), (1, 5, 'R'), (14, 6, 'R'),
     (2, 10, 'R'), (13, 11, 'R'), (5, 14, 'R'), (10, 14, 'R'),
     (3, 2, '3'), (12, 2, '3'), (2, 4, '3'), (13, 9, '3'),
     (3, 13, '3'), (12, 12, '3')],
)

# ════════════════════════════════════════════════════════════════════
# SORTIE — escalier descendant, chaque anneau est une marche plus bas.
# N'utilise AUCUNE couleur d'accent : le vert spectre reste au heros.
# ════════════════════════════════════════════════════════════════════
SPRITES['exit'] = [
    '3333333333333333',
    '3000000000000003',
    '3055555555555503',
    '3055555555555503',
    '3000000000000003',
    '3044444444444403',
    '3044444444444403',
    '3000000000000003',
    '3033333333333303',
    '3033333333333303',
    '3000000000000003',
    '3022222222222203',
    '3022222222222203',
    '3000000000000003',
    '3011111111111103',
    '3333333333333333',
]

# ════════════════════════════════════════════════════════════════════
# DALLE CORROMPUE — le donjon a ecrit dans ton programme. Doit se lire
# comme une BLESSURE dans la pierre : la dalle est fendue en etoile et
# quelque chose de vif respire dessous.
# ════════════════════════════════════════════════════════════════════
def _fractured_slab():
    """Deux fractures traversantes, une lueur rouge dans la faille.
    L'asymétrie est volontaire : une blessure n'est pas un symbole."""
    g = [list(row) for row in SPRITES['floor']]
    cracks = []
    # fracture quasi verticale, décalée
    for y in range(15):
        cracks.append((7 + y * 3 // 15, y))
    # fracture quasi horizontale
    for x in range(15):
        cracks.append((x, 9 - x * 3 // 15))
    seen = set()
    for x, y in cracks:
        if (x, y) in seen:
            continue
        seen.add((x, y))
        g[y][x] = '0'
        # la lueur ne borde qu'UN côté : la faille a une profondeur
        if x + 1 < 15 and g[y][x + 1] == '2':
            g[y][x + 1] = 'R'
    return [''.join(r) for r in g]


SPRITES['corrupted'] = _fractured_slab()

# ════════════════════════════════════════════════════════════════════
# PORTE SCELLEE — deux battants, ferrures, serrure ambre centree.
# Les chemins caches ne s'ouvrent qu'avec une cle rapportee d'une run
# precedente, et emportee : la porte doit donner envie bien avant
# d'etre ouvrable.
# ════════════════════════════════════════════════════════════════════
SPRITES['door_locked'] = [
    '0000000000000000',
    '0333333333333330',
    '0311111001111130',
    '0344444004444430',
    '0311111001111130',
    '0311110AAA011130',
    '031111A000A11130',
    '031111A000A11130',
    '0311110A0A011130',
    '0311110A0A011130',
    '031111A000A11130',
    '0344444AAA444430',
    '0311111001111130',
    '0333333333333330',
    '0000000000000000',
    '0000000000000000',
]

# ════════════════════════════════════════════════════════════════════
# SUPERPOSITIONS — fond TRANSPARENT : elles se dessinent par-dessus la
# dalle et ne doivent jamais la masquer.
# ════════════════════════════════════════════════════════════════════

# Objet requis : eclat anguleux, pas une bille. Sans lui la sortie
# reste fermee, donc il doit crier « ramasse-moi ».
SPRITES['item'] = [
    '................',
    '................',
    '.......00.......',
    '......0A50......',
    '.....0AA5A0.....',
    '....0AAA5AA0....',
    '....0AAA5AA0....',
    '....0AAA5AA0....',
    '.....0AAFA0.....',
    '.....0AFFA0.....',
    '......0FF0......',
    '.......00.......',
    '................',
    '................',
    '................',
    '................',
]

# Case bonus : toujours hors du chemin direct. C'est un detour, donc un
# pari — visible avant de s'engager.
SPRITES['bonus'] = [
    '................',
    '................',
    '................',
    '.......00.......',
    '.....00CC00.....',
    '....0C5CCCC0....',
    '...0CC5CCCCC0...',
    '...0CCCCCCCC0...',
    '...0CCCCCCCC0...',
    '....0CCCCCC0....',
    '.....00CC00.....',
    '.......00.......',
    '................',
    '................',
    '................',
    '................',
]

# Repere pose par MARQUER. Discret : il ne doit jamais masquer la dalle.
SPRITES['mark'] = [
    '................',
    '................',
    '................',
    '................',
    '................',
    '.......GG.......',
    '......G..G......',
    '......G..G......',
    '.......GG.......',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
]

# ════════════════════════════════════════════════════════════════════
# BROUILLARD — trame serree. L'illisibilite EST le message : le joueur
# doit voir au premier regard qu'il n'a pas l'information.
# ════════════════════════════════════════════════════════════════════
SPRITES['fog'] = ['fvfvfvfvfvfvfvfv' if y % 2 == 0
                  else 'vfvfvfvfvfvfvfvf' for y in range(16)]

# Variante rare : des yeux dans l'ombre. PUREMENT DECORATIVE — aucune
# regle de jeu ne s'y attache. L'effet vient de la rarete : une dalle
# sur trente, pas davantage.
SPRITES['fog_eyes'] = poke(
    SPRITES['fog'],
    [(2, 5, '3'),
     (2, 9, '3'),
     (3, 5, '3'),
     (3, 9, '3'),
     (4, 5, '3'),
     (4, 9, '3'),
     (5, 5, '3'),
     (5, 9, '3'),
     (6, 5, '3'),
     (6, 9, '3'),
     (2, 6, '3'),
     (6, 6, '3'),
     (2, 7, '3'),
     (6, 7, '3'),
     (2, 8, '3'),
     (6, 8, '3'),
     (3, 6, 'G'),
     (3, 8, 'G'),
     (4, 6, 'G'),
     (4, 8, 'G'),
     (5, 6, 'G'),
     (5, 8, 'G'),
     (3, 7, 'G'),
     (4, 7, '5'),
     (5, 7, 'G'),
     (9, 5, '3'),
     (9, 9, '3'),
     (10, 5, '3'),
     (10, 9, '3'),
     (11, 5, '3'),
     (11, 9, '3'),
     (12, 5, '3'),
     (12, 9, '3'),
     (13, 5, '3'),
     (13, 9, '3'),
     (9, 6, '3'),
     (13, 6, '3'),
     (9, 7, '3'),
     (13, 7, '3'),
     (9, 8, '3'),
     (13, 8, '3'),
     (10, 6, 'G'),
     (10, 8, 'G'),
     (11, 6, 'G'),
     (11, 8, 'G'),
     (12, 6, 'G'),
     (12, 8, 'G'),
     (10, 7, 'G'),
     (11, 7, '5'),
     (12, 7, 'G')],
)


# ════════════════════════════════════════════════════════════════════
# FONDS ET ANIMATION DU MENU
# ════════════════════════════════════════════════════════════════════
# Le menu n'a pas besoin d'une scene : il a besoin d'etre VIVANT.
# Quatre couches suffisent, de la plus lente a la plus rapide :
#   1. bg_stone        mur tuile 32x32, immobile
#   2. bg_sigil_1..3   sceau qui pulse derriere le titre (~2 s le cycle)
#   3. bg_torch_1..3   torches qui vacillent (~0,15 s par image)
#   4. bg_wisp_1..4    volutes spectrales qui derivent (~0,2 s)
#   +  bg_ember        braise unique, animee par DEPLACEMENT vertical,
#                      pas par changement d'image
# Les cadences vivent cote Flutter, pas ici.


def _stone_wall():
    """Mur tuile 32x32, decale d'une demi-brique. Immobile : c'est le
    fond, il ne doit jamais attirer l'oeil."""
    g = []
    for y in range(32):
        row = ''
        band = y % 8
        offset = 0 if (y // 8) % 2 == 0 else 8
        for x in range(32):
            if band in (0, 7):
                row += '0'
            elif (x + offset) % 16 == 0:
                row += '0'
            else:
                row += '1'
        g.append(row)
    return poke(g, [(3, 2, '2'), (20, 3, '2'), (11, 10, '2'),
                    (27, 12, '3'), (5, 18, '3'), (18, 19, '2'),
                    (24, 26, '2'), (9, 27, '3')])


SPRITES['bg_stone'] = _stone_wall()


# Sceau grave, 32x32, en trois intensites : la pulsation se joue en
# alternant les trois images. Derriere le titre, tres basse opacite.
def _ring(g, r, ch, width=0.55, cx=15.5, cy=15.5):
    """Anneau d'un pixel d'epaisseur. Un cercle trace par distance est
    parfaitement regulier, la ou un cercle dessine a la main a toujours
    une bosse."""
    for y in range(len(g)):
        for x in range(len(g)):
            if abs(math.hypot(x - cx, y - cy) - r) <= width:
                g[y][x] = ch


def _line(g, x0, y0, x1, y1, ch):
    """Bresenham : les diagonales restent nettes, sans marche d'escalier
    irreguliere."""
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        if 0 <= x0 < len(g) and 0 <= y0 < len(g):
            g[y0][x0] = ch
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def _polar(r, deg, cx=15.5, cy=15.5):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def _sigil(rings_ink, star_ink, core_ink):
    """Sceau 32x32 : double anneau, couronne de graduations, hexagramme
    inscrit, coeur. La pulsation ne joue pas sur une luminosite globale
    mais sur QUELLES PARTIES s'allument — le sceau a l'air de se
    charger, au lieu de clignoter bloc.
    """
    g = [['.' for _ in range(32)] for _ in range(32)]

    _ring(g, 15.0, rings_ink)
    _ring(g, 12.0, rings_ink)

    # Graduations entre les deux anneaux, toutes les 30 degres.
    for k in range(12):
        x0, y0 = _polar(12.4, k * 30)
        x1, y1 = _polar(14.6, k * 30)
        _line(g, x0, y0, x1, y1, rings_ink)

    # Hexagramme inscrit : deux triangles opposes.
    for base in (90, 270):
        pts = [_polar(10.5, base + i * 120) for i in range(3)]
        for i in range(3):
            ax, ay = pts[i]
            bx, by = pts[(i + 1) % 3]
            _line(g, ax, ay, bx, by, star_ink)

    _ring(g, 4.0, core_ink)
    g[15][15] = core_ink
    g[15][16] = core_ink
    g[16][15] = core_ink
    g[16][16] = core_ink

    return [''.join(r) for r in g]


# Trois etats de charge, du sommeil a l'eveil.
SPRITES['bg_sigil_1'] = _sigil('3', '3', '3')
SPRITES['bg_sigil_2'] = _sigil('4', '3', 'G')
SPRITES['bg_sigil_3'] = _sigil('4', 'G', 'G')

# Torche murale. Trois images de flamme, meme support : le vacillement
# vient de la flamme, jamais du support, sinon la torche « saute ».
_TORCH_BASE = [
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
    '......3333......',
    '......3443......',
    '......3443......',
    '.......33.......',
    '.......33.......',
    '.......33.......',
    '................',
    '................',
]

SPRITES['bg_torch_1'] = poke(_TORCH_BASE, [
    (7, 3, 'F'), (8, 3, 'F'),
    (6, 4, 'F'), (7, 4, 'A'), (8, 4, 'A'), (9, 4, 'F'),
    (6, 5, 'F'), (7, 5, 'A'), (8, 5, 'A'), (9, 5, 'F'),
    (6, 6, 'R'), (7, 6, 'F'), (8, 6, 'F'), (9, 6, 'R'),
    (7, 7, 'R'), (8, 7, 'R'),
])

SPRITES['bg_torch_2'] = poke(_TORCH_BASE, [
    (7, 2, 'F'),
    (7, 3, 'A'), (8, 3, 'F'),
    (6, 4, 'F'), (7, 4, 'A'), (8, 4, 'A'), (9, 4, 'F'),
    (6, 5, 'R'), (7, 5, 'A'), (8, 5, 'F'), (9, 5, 'F'),
    (6, 6, 'R'), (7, 6, 'F'), (8, 6, 'R'), (9, 6, 'R'),
    (7, 7, 'R'), (8, 7, 'R'),
])

SPRITES['bg_torch_3'] = poke(_TORCH_BASE, [
    (8, 3, 'F'),
    (7, 4, 'F'), (8, 4, 'A'), (9, 4, 'F'),
    (6, 5, 'F'), (7, 5, 'A'), (8, 5, 'A'), (9, 5, 'R'),
    (6, 6, 'R'), (7, 6, 'F'), (8, 6, 'F'), (9, 6, 'R'),
    (7, 7, 'R'), (8, 7, 'R'),
])


# Volute spectrale : quatre images en boucle. Fond transparent, se
# superpose au mur. A faire deriver lentement en plus du cycle d'images.
def _wisp(pixels):
    g = [['.' for _ in range(16)] for _ in range(16)]
    for x, y, ch in pixels:
        g[y][x] = ch
    return [''.join(r) for r in g]


SPRITES['bg_wisp_1'] = _wisp([
    (7, 5, 'G'), (8, 5, 'G'), (6, 6, 'G'), (9, 6, 'G'),
    (7, 6, '5'), (8, 6, '5'), (6, 7, 'G'), (9, 7, 'G'),
    (7, 7, 'G'), (8, 7, 'G'), (7, 8, 'G'), (8, 8, 'G'),
    (8, 9, 'G'), (8, 10, 'G'),
])
SPRITES['bg_wisp_2'] = _wisp([
    (7, 4, 'G'), (8, 4, 'G'), (6, 5, 'G'), (9, 5, 'G'),
    (7, 5, '5'), (8, 5, '5'), (6, 6, 'G'), (9, 6, 'G'),
    (7, 6, 'G'), (8, 6, 'G'), (7, 7, 'G'), (8, 7, 'G'),
    (7, 8, 'G'), (7, 9, 'G'), (8, 10, 'G'),
])
SPRITES['bg_wisp_3'] = _wisp([
    (7, 3, 'G'), (8, 3, 'G'), (6, 4, 'G'), (9, 4, 'G'),
    (7, 4, '5'), (8, 4, '5'), (7, 5, 'G'), (8, 5, 'G'),
    (8, 6, 'G'), (7, 7, 'G'), (8, 8, 'G'), (7, 9, 'G'),
])
SPRITES['bg_wisp_4'] = _wisp([
    (7, 2, 'G'), (8, 2, 'G'), (7, 3, '5'), (8, 3, 'G'),
    (7, 4, 'G'), (8, 5, 'G'), (7, 6, 'G'), (8, 7, 'G'),
])

# Braise. UNE seule image : c'est son DEPLACEMENT vers le haut, avec un
# leger zigzag, qui donne la vie. Trois tailles melangees a l'ecran.
SPRITES['bg_ember'] = _wisp([
    (7, 7, 'F'), (8, 7, 'A'), (7, 8, 'A'), (8, 8, 'F'),
])


# ════════════════════════════════════════════════════════════════════
# LE HEROS — silhouette encapuchonnee, vue du dessus.
# ════════════════════════════════════════════════════════════════════
# L'ORIENTATION DOIT ETRE LISIBLE SANS ANIMATION : le joueur doit
# pouvoir predire ou AVANCER l'emmene, sans hesiter, a 20 px de cote.
# Le spectre est concentre sur le SEUL avant (le regard) — un cerne
# vert uniforme rendait la silhouette symetrique, donc illisible.
# Le liseré d'os detache la silhouette du sol sans dire de direction.
# Les trois autres orientations sont DERIVEES par rotation : il est
# impossible qu'elles divergent entre elles.
AGENT_NORTH = [
    '................',
    '.......00.......',
    '......0GG0......',
    '.....0G55G0.....',
    '.....0G55G0.....',
    '....0GG55GG0....',
    '...04G3333G40...',
    '..043333333340..',
    '..043311113340..',
    '.04333111133340.',
    '.04333111133340.',
    '..043311113340..',
    '..043333333340..',
    '...0433333340...',
    '....00000000....',
    '................',
]


def rotate_cw(grid):
    """Rotation horaire de 90 degres, pour deriver E / S / O du nord."""
    n = len(grid)
    return [''.join(grid[n - 1 - x][y] for x in range(n)) for y in range(n)]


def build_agents():
    north = AGENT_NORTH
    east = rotate_cw(north)
    south = rotate_cw(east)
    west = rotate_cw(south)
    SPRITES['agent_n'] = north
    SPRITES['agent_e'] = east
    SPRITES['agent_s'] = south
    SPRITES['agent_w'] = west


def to_svg(name, grid):
    """Encode la grille en <rect> fusionnes horizontalement."""
    size = len(grid)
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d"'
        ' shape-rendering="crispEdges">' % (size, size),
        '  <!-- %s - genere par tools/gen_sprites.py, ne pas editer a la main -->'
        % name,
    ]
    for y, row in enumerate(grid):
        x = 0
        while x < size:
            ch = row[x]
            run = 1
            while x + run < size and row[x + run] == ch:
                run += 1
            if ch != TRANSPARENT:
                parts.append(
                    '  <rect x="%d" y="%d" width="%d" height="1" fill="%s"/>'
                    % (x, y, run, PALETTE[ch])
                )
            x += run
    parts.append('</svg>')
    return '\n'.join(parts) + '\n'


def validate():
    problems = []
    for name, grid in SPRITES.items():
        size = len(grid)
        if size not in (16, 32):
            problems.append('%s : %d lignes (attendu 16 ou 32)' % (name, size))
            continue
        for i, row in enumerate(grid):
            if len(row) != size:
                problems.append('%s ligne %d : %d colonnes au lieu de %d -> %r'
                                % (name, i, len(row), size, row))
            for ch in row:
                if ch != TRANSPARENT and ch not in PALETTE:
                    problems.append('%s ligne %d : caractere inconnu %r'
                                    % (name, i, ch))
    return problems


def main():
    build_agents()
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
    out = os.path.join(root, 'assets', 'sprites')
    os.makedirs(out, exist_ok=True)

    problems = validate()
    if problems:
        for p in problems:
            print('ERREUR', p)
        raise SystemExit(1)

    for name, grid in sorted(SPRITES.items()):
        with open(os.path.join(out, name + '.svg'), 'w', encoding='utf-8') as f:
            f.write(to_svg(name, grid))

    print('%d sprites generes dans assets/sprites/' % len(SPRITES))


if __name__ == '__main__':
    main()
