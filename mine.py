import pygame
import random
import time
import sys

pygame.init()

# --- Paleta ---
BG        = (245, 244, 240)
WHITE     = (255, 255, 255)
GRAY_LT   = (232, 231, 226)
GRAY_MD   = (180, 178, 170)
GRAY_DK   = (80,  78,  72)
TEXT_DARK = (44,  44,  42)
TEXT_GRAY = (140, 138, 128)
LINE      = (200, 198, 190)

CELL_UNREV = (210, 208, 200)
CELL_REV   = (245, 244, 240)
CELL_HOVER = (220, 218, 212)
CELL_MINE  = (226,  75,  74)
CELL_FLAG  = (186, 117,  23)
CELL_WRONG = (200,  50,  50)

NUM_COLORS = {
    1: (56, 138, 221),
    2: (99, 153,  34),
    3: (226,  75,  74),
    4: (24,  95, 165),
    5: (160,  50,  30),
    6: (30, 150, 140),
    7: (44,  44,  42),
    8: (140, 138, 128),
}

BTN_BG  = WHITE
BTN_HVR = GRAY_LT
BTN_ACT = (24, 95, 165)
BTN_ACT_T = WHITE

CELL = 36
PAD  = 24

CONFIGS = {
    'Fácil':   (9,  9,  10),
    'Médio':   (16, 16, 40),
    'Difícil': (16, 30, 99),
}

font_num  = pygame.font.SysFont("Arial", 18, bold=True)
font_sm   = pygame.font.SysFont("Arial", 13)
font_btn  = pygame.font.SysFont("Arial", 13, bold=True)
font_ttl  = pygame.font.SysFont("Arial", 22, bold=True)
font_emoji= pygame.font.SysFont("Segoe UI Emoji", 18)
font_big  = pygame.font.SysFont("Arial", 36, bold=True)
font_mid  = pygame.font.SysFont("Arial", 20)

# --- Estado do jogo ---
class Game:
    def __init__(self, difficulty='Fácil'):
        self.difficulty = difficulty
        self.new_game()

    def new_game(self):
        rows, cols, mines = CONFIGS[self.difficulty]
        self.rows  = rows
        self.cols  = cols
        self.total_mines = mines
        self.board = [[0]*cols for _ in range(rows)]   # contagem de vizinhos / -1=mina
        self.revealed  = [[False]*cols for _ in range(rows)]
        self.flagged   = [[False]*cols for _ in range(rows)]
        self.started   = False
        self.done      = False
        self.won       = False
        self.start_time= None
        self.elapsed   = 0
        self.flags_used= 0
        self.first_click = True

    def place_mines(self, safe_r, safe_c):
        safe = {(safe_r+dr, safe_c+dc) for dr in range(-1,2) for dc in range(-1,2)}
        cells = [(r,c) for r in range(self.rows) for c in range(self.cols)
                 if (r,c) not in safe]
        mines = random.sample(cells, min(self.total_mines, len(cells)))
        for r,c in mines:
            self.board[r][c] = -1
        for r in range(self.rows):
            for c in range(self.cols):
                if self.board[r][c] == -1: continue
                self.board[r][c] = sum(
                    1 for dr in range(-1,2) for dc in range(-1,2)
                    if 0<=r+dr<self.rows and 0<=c+dc<self.cols and self.board[r+dr][c+dc]==-1
                )

    def reveal(self, r, c):
        if not (0<=r<self.rows and 0<=c<self.cols): return
        if self.revealed[r][c] or self.flagged[r][c]: return
        if self.first_click:
            self.place_mines(r, c)
            self.first_click = False
            self.started = True
            self.start_time = time.time()
        self.revealed[r][c] = True
        if self.board[r][c] == -1:
            self.done = True; self.won = False
            self.elapsed = int(time.time() - self.start_time)
            self._reveal_all()
            return
        if self.board[r][c] == 0:
            for dr in range(-1,2):
                for dc in range(-1,2):
                    self.reveal(r+dr, c+dc)
        self._check_win()

    def _reveal_all(self):
        for r in range(self.rows):
            for c in range(self.cols):
                if self.board[r][c] == -1:
                    self.revealed[r][c] = True

    def _check_win(self):
        unrevealed = sum(1 for r in range(self.rows) for c in range(self.cols)
                         if not self.revealed[r][c])
        if unrevealed == self.total_mines:
            self.done = True; self.won = True
            self.elapsed = int(time.time() - self.start_time)

    def toggle_flag(self, r, c):
        if self.revealed[r][c] or self.done: return
        if self.flagged[r][c]:
            self.flagged[r][c] = False
            self.flags_used -= 1
        else:
            self.flagged[r][c] = True
            self.flags_used += 1

    def chord(self, r, c):
        if not self.revealed[r][c] or self.board[r][c] <= 0: return
        neighbors = [(r+dr,c+dc) for dr in range(-1,2) for dc in range(-1,2)
                     if (dr,dc)!=(0,0) and 0<=r+dr<self.rows and 0<=c+dc<self.cols]
        flags = sum(1 for nr,nc in neighbors if self.flagged[nr][nc])
        if flags == self.board[r][c]:
            for nr,nc in neighbors:
                if not self.flagged[nr][nc]:
                    self.reveal(nr,nc)

game = Game()

# --- Layout dinâmico ---
def window_size():
    rows, cols, _ = CONFIGS[game.difficulty]
    w = PAD*2 + cols*CELL
    h = PAD + 70 + rows*CELL + 80
    return max(w, 340), h

def board_origin():
    return PAD, 70

# --- Botões ---
class Button:
    def __init__(self, label, action, x=0, y=0, w=90, h=30):
        self.label  = label
        self.action = action
        self.rect   = pygame.Rect(x, y, w, h)
        self.active = False
        self.hover  = False

    def update_pos(self, x, y, w=None, h=None):
        self.rect = pygame.Rect(x, y, w or self.rect.w, h or self.rect.h)

    def draw(self, surface):
        bg = BTN_ACT if self.active else (BTN_HVR if self.hover else BTN_BG)
        fg = BTN_ACT_T if self.active else TEXT_DARK
        pygame.draw.rect(surface, bg, self.rect, border_radius=8)
        pygame.draw.rect(surface, LINE, self.rect, 1, border_radius=8)
        t = font_btn.render(self.label, True, fg)
        surface.blit(t, t.get_rect(center=self.rect.center))

    def check(self, pos): self.hover = self.rect.collidepoint(pos)
    def click(self, pos):
        if self.rect.collidepoint(pos): self.action(); return True
        return False

diff_btns = []
def set_diff(d):
    def f():
        game.difficulty = d
        game.new_game()
        resize_window()
        for b in diff_btns: b.active = (b.label == d)
    return f

for d in CONFIGS:
    b = Button(d, set_diff(d), w=76, h=28)
    b.active = (d == 'Fácil')
    diff_btns.append(b)

new_btn = Button("Novo Jogo", lambda: (game.new_game(),), w=90, h=28)

all_btns = diff_btns + [new_btn]

screen = None
W, H   = 0, 0

def resize_window():
    global screen, W, H
    W, H = window_size()
    screen = pygame.display.set_mode((W, H))
    pygame.display.set_caption("Minesweeper")
    layout_buttons()

def layout_buttons():
    gap = 8
    total_diff = sum(b.rect.w for b in diff_btns) + gap*(len(diff_btns)-1)
    x = PAD
    for b in diff_btns:
        b.update_pos(x, 28); x += b.rect.w + gap
    new_btn.update_pos(W - PAD - new_btn.rect.w, 28)

resize_window()

# --- Desenho ---
def draw_cell(surface, r, c, ox, oy, mx, my):
    x = ox + c*CELL
    y = oy + r*CELL
    rect = pygame.Rect(x, y, CELL, CELL)

    rev  = game.revealed[r][c]
    flag = game.flagged[r][c]
    val  = game.board[r][c]
    hover= rect.collidepoint(mx, my) and not rev and not flag and not game.done

    if rev:
        if val == -1:
            # Foi a mina clicada?
            bg = CELL_MINE if (game.done and not game.won) else CELL_REV
        else:
            bg = CELL_REV
    elif flag:
        bg = CELL_UNREV
    elif hover:
        bg = CELL_HOVER
    else:
        bg = CELL_UNREV

    pygame.draw.rect(surface, bg, rect)
    pygame.draw.rect(surface, LINE, rect, 1)

    cx, cy = x + CELL//2, y + CELL//2

    if flag:
        # Bandeira
        pygame.draw.polygon(surface, CELL_FLAG, [(cx-6,cy+7),(cx-6,cy-7),(cx+7,cy)])
        pygame.draw.line(surface, GRAY_DK, (cx-6,cy-7),(cx-6,cy+8), 2)
    elif rev and val == -1:
        # Mina
        pygame.draw.circle(surface, GRAY_DK, (cx,cy), 9)
        for angle in range(0,360,45):
            import math
            ax = cx + int(12*math.cos(math.radians(angle)))
            ay = cy + int(12*math.sin(math.radians(angle)))
            pygame.draw.line(surface, GRAY_DK, (cx,cy),(ax,ay), 2)
        pygame.draw.circle(surface, WHITE, (cx-3,cy-3), 3)
    elif rev and val > 0:
        col = NUM_COLORS.get(val, TEXT_DARK)
        t = font_num.render(str(val), True, col)
        surface.blit(t, t.get_rect(center=(cx,cy)))

def draw():
    screen.fill(BG)

    # Título
    title = font_ttl.render("Minesweeper", True, TEXT_DARK)
    screen.blit(title, (PAD, 6))

    # Botões
    mx, my = pygame.mouse.get_pos()
    for b in all_btns:
        b.check((mx,my))
        b.draw(screen)

    # HUD: minas restantes + timer
    remaining = game.total_mines - game.flags_used
    mine_t = font_sm.render(f"💣 {remaining}", True, TEXT_DARK if remaining>=0 else CELL_MINE)
    screen.blit(mine_t, (PAD, 62))

    if game.started:
        elapsed = game.elapsed if game.done else int(time.time() - game.start_time)
        m, s = divmod(elapsed, 60)
        timer_t = font_sm.render(f"⏱ {m}:{s:02d}", True, TEXT_DARK)
    else:
        timer_t = font_sm.render("⏱ 0:00", True, TEXT_GRAY)
    screen.blit(timer_t, (W//2 - timer_t.get_width()//2, 62))

    # Tabuleiro
    ox, oy = board_origin()
    for r in range(game.rows):
        for c in range(game.cols):
            draw_cell(screen, r, c, ox, oy, mx, my)

    # Overlay fim de jogo
    if game.done:
        bw, bh = game.cols*CELL, game.rows*CELL
        overlay = pygame.Surface((bw, bh), pygame.SRCALPHA)
        overlay.fill((245,244,240,200))
        screen.blit(overlay, (ox, oy))

        if game.won:
            msg  = font_big.render("Ganhou! 🎉", True, (99,153,34))
            m, s = divmod(game.elapsed, 60)
            sub  = font_mid.render(f"Tempo: {m}:{s:02d}", True, TEXT_DARK)
        else:
            msg = font_big.render("Boom! 💥", True, CELL_MINE)
            sub = font_mid.render("Clica em Novo Jogo", True, TEXT_DARK)

        cx = ox + bw//2
        cy = oy + bh//2
        screen.blit(msg, msg.get_rect(center=(cx, cy-22)))
        screen.blit(sub, sub.get_rect(center=(cx, cy+22)))

    pygame.display.flip()

# --- Loop ---
clock = pygame.time.Clock()

while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            pygame.quit(); sys.exit()

        elif event.type == pygame.MOUSEBUTTONDOWN:
            pos = event.pos
            ox, oy = board_origin()
            bx, by = pos[0]-ox, pos[1]-oy
            on_board = 0<=bx<game.cols*CELL and 0<=by<game.rows*CELL

            if event.button == 1:
                clicked_btn = any(b.click(pos) for b in all_btns)
                if not clicked_btn and on_board and not game.done:
                    r, c = by//CELL, bx//CELL
                    if not game.flagged[r][c]:
                        game.reveal(r, c)

            elif event.button == 3:
                if on_board and not game.done:
                    r, c = by//CELL, bx//CELL
                    game.toggle_flag(r, c)

            elif event.button == 2:
                if on_board and not game.done:
                    r, c = by//CELL, bx//CELL
                    game.chord(r, c)

        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_r or event.key == pygame.K_n:
                game.new_game()

    draw()
    clock.tick(30)