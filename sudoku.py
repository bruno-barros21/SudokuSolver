import pygame
import random
import time
import sys

pygame.init()

# --- Cores ---
BG        = (245, 244, 240)
WHITE     = (255, 255, 255)
LINE_THIN = (200, 198, 190)
LINE_BOLD = (80,  78,  72)
BLUE      = (56, 138, 221)
BLUE_LITE = (214, 233, 251)
BLUE_MID  = (181, 212, 244)
RED       = (226,  75,  74)
TEXT_DARK = (44,  44,  42)
TEXT_GRAY = (140, 138, 128)
BTN_BG    = (255, 255, 255)
BTN_HVR   = (235, 233, 228)
BTN_ACT_B = (24,  95, 165)
BTN_ACT_T = (255, 255, 255)
GOLD      = (186, 117,  23)
GREEN     = (99, 153,  34)

CELL  = 60
BOARD = CELL * 9
PAD_L = 30
PAD_T = 100
W     = PAD_L * 2 + BOARD
H     = PAD_T + BOARD + 180

screen = pygame.display.set_mode((W, H))
pygame.display.set_caption("Sudoku")

font_lg  = pygame.font.SysFont("Arial", 30, bold=True)
font_md  = pygame.font.SysFont("Arial", 22)
font_sm  = pygame.font.SysFont("Arial", 14)
font_btn = pygame.font.SysFont("Arial", 14, bold=True)
font_note= pygame.font.SysFont("Arial", 11)
font_ttl = pygame.font.SysFont("Arial", 26, bold=True)

# --- Lógica do Sudoku ---
def solve(board):
    empty = next(((r,c) for r in range(9) for c in range(9) if board[r][c]==0), None)
    if not empty:
        return True
    r, c = empty
    nums = list(range(1,10)); random.shuffle(nums)
    for n in nums:
        if valid(board, r, c, n):
            board[r][c] = n
            if solve(board):
                return True
            board[r][c] = 0
    return False

def valid(board, r, c, n):
    if n in board[r]: return False
    if n in [board[i][c] for i in range(9)]: return False
    br, bc = (r//3)*3, (c//3)*3
    for i in range(3):
        for j in range(3):
            if board[br+i][bc+j] == n: return False
    return True

def generate(difficulty):
    board = [[0]*9 for _ in range(9)]
    solve(board)
    solution = [row[:] for row in board]
    remove = {'easy': 36, 'medium': 46, 'hard': 52}[difficulty]
    cells = list(range(81)); random.shuffle(cells)
    for idx in cells[:remove]:
        board[idx//9][idx%9] = 0
    return board, solution

# --- Estado ---
class Game:
    def __init__(self):
        self.difficulty = 'easy'
        self.new_game()

    def new_game(self):
        self.puzzle, self.solution = generate(self.difficulty)
        self.user   = [row[:] for row in self.puzzle]
        self.notes  = [[set() for _ in range(9)] for _ in range(9)]
        self.selected = None
        self.notes_mode = False
        self.errors = 0
        self.hints  = 3
        self.start  = time.time()
        self.done   = False
        self.msg    = ""

    def select(self, r, c):
        self.selected = (r, c)

    def input_num(self, n):
        if not self.selected or self.done: return
        r, c = self.selected
        if self.puzzle[r][c] != 0: return
        if self.notes_mode:
            if self.user[r][c] == 0:
                if n in self.notes[r][c]: self.notes[r][c].remove(n)
                else: self.notes[r][c].add(n)
        else:
            self.user[r][c] = n
            self.notes[r][c].clear()
            if n != self.solution[r][c]:
                self.errors += 1
            elif all(self.user[r2][c2] == self.solution[r2][c2]
                     for r2 in range(9) for c2 in range(9)):
                self.done = True
                elapsed = int(time.time() - self.start)
                m, s = divmod(elapsed, 60)
                self.msg = f"Parabéns! {m}:{s:02d} | Erros: {self.errors}"

    def erase(self):
        if not self.selected or self.done: return
        r, c = self.selected
        if self.puzzle[r][c] == 0:
            self.user[r][c] = 0
            self.notes[r][c].clear()

    def hint(self):
        if self.hints <= 0 or self.done:
            self.msg = "Sem dicas disponíveis."
            return
        empties = [(r,c) for r in range(9) for c in range(9)
                   if self.puzzle[r][c]==0 and self.user[r][c]!=self.solution[r][c]]
        if not empties: return
        r, c = random.choice(empties)
        self.user[r][c] = self.solution[r][c]
        self.notes[r][c].clear()
        self.selected = (r, c)
        self.hints -= 1
        self.msg = f"Dicas restantes: {self.hints}"

    def move(self, dr, dc):
        if not self.selected: self.selected = (0,0); return
        r, c = self.selected
        self.selected = (max(0,min(8,r+dr)), max(0,min(8,c+dc)))

game = Game()

# --- Botões ---
class Button:
    def __init__(self, x, y, w, h, label, action, toggle=False):
        self.rect   = pygame.Rect(x, y, w, h)
        self.label  = label
        self.action = action
        self.toggle = toggle
        self.active = False
        self.hover  = False

    def draw(self, surface):
        if self.active:
            bg, fg = BTN_ACT_B, BTN_ACT_T
        elif self.hover:
            bg, fg = BTN_HVR, TEXT_DARK
        else:
            bg, fg = BTN_BG, TEXT_DARK
        pygame.draw.rect(surface, bg, self.rect, border_radius=8)
        pygame.draw.rect(surface, LINE_THIN, self.rect, 1, border_radius=8)
        txt = font_btn.render(self.label, True, fg)
        surface.blit(txt, txt.get_rect(center=self.rect.center))

    def check_hover(self, pos):
        self.hover = self.rect.collidepoint(pos)

    def click(self, pos):
        if self.rect.collidepoint(pos):
            self.action()
            return True
        return False

def make_buttons():
    bw, bh = 90, 34
    gap = 10
    row1_y = PAD_T + BOARD + 20
    row2_y = row1_y + bh + 10

    def diff(d):
        def f():
            game.difficulty = d
            game.new_game()
            for b in diff_btns: b.active = (b.label.lower() == d[:len(b.label)])
        return f

    diffs  = [Button(PAD_L + i*(70+gap), row1_y-44, 70, 30,
                     ['Fácil','Médio','Difícil'][i], diff(['easy','medium','hard'][i]))
              for i in range(3)]
    diffs[0].active = True

    ctrl_labels = ['Apagar','Notas','Dica','Novo Jogo']
    ctrl_x = [PAD_L + i*(bw+gap) for i in range(4)]

    def erase_fn():  game.erase()
    def notes_fn():
        game.notes_mode = not game.notes_mode
        notes_btn.active = game.notes_mode
    def hint_fn():   game.hint()
    def new_fn():    game.new_game(); diffs[['easy','medium','hard'].index(game.difficulty)].active=True

    notes_btn = Button(ctrl_x[1], row2_y, bw, bh, 'Notas', notes_fn, toggle=True)

    ctrl = [
        Button(ctrl_x[0], row2_y, bw, bh, 'Apagar', erase_fn),
        notes_btn,
        Button(ctrl_x[2], row2_y, bw, bh, 'Dica', hint_fn),
        Button(ctrl_x[3], row2_y, bw+10, bh, 'Novo Jogo', new_fn),
    ]
    return diffs, ctrl

diff_btns, ctrl_btns = make_buttons()
all_btns = diff_btns + ctrl_btns

# --- Numpad ---
def numpad_rects():
    y = PAD_T + BOARD + 110
    size = 40
    gap  = 6
    total = 9*size + 8*gap
    x0 = (W - total) // 2
    return [pygame.Rect(x0 + i*(size+gap), y, size, size) for i in range(9)]

NUM_RECTS = numpad_rects()

# --- Desenho ---
def draw_board():
    # Fundo
    pygame.draw.rect(screen, WHITE, (PAD_L, PAD_T, BOARD, BOARD), border_radius=4)

    sel = game.selected
    # Highlight
    if sel:
        sr, sc = sel
        sv = game.user[sr][sc] or game.puzzle[sr][sc]
        for r in range(9):
            for c in range(9):
                rect = pygame.Rect(PAD_L + c*CELL, PAD_T + r*CELL, CELL, CELL)
                same_box = (r//3==sr//3 and c//3==sc//3)
                cv = game.user[r][c] or game.puzzle[r][c]
                if r==sr and c==sc:
                    pygame.draw.rect(screen, BLUE_LITE, rect)
                elif sv and sv==cv and not(r==sr and c==sc):
                    pygame.draw.rect(screen, BLUE_MID, rect)
                elif r==sr or c==sc or same_box:
                    pygame.draw.rect(screen, (232,231,226), rect)

    # Linhas finas
    for i in range(10):
        x = PAD_L + i*CELL
        y = PAD_T + i*CELL
        w = 1 if i%3!=0 else 2
        col = LINE_THIN if i%3!=0 else LINE_BOLD
        pygame.draw.line(screen, col, (x, PAD_T), (x, PAD_T+BOARD), w)
        pygame.draw.line(screen, col, (PAD_L, y), (PAD_L+BOARD, y), w)

    # Números
    for r in range(9):
        for c in range(9):
            v = game.user[r][c]
            given = game.puzzle[r][c] != 0
            cx = PAD_L + c*CELL + CELL//2
            cy = PAD_T + r*CELL + CELL//2
            if v != 0:
                if given:
                    color = TEXT_DARK
                    f = font_lg
                elif v != game.solution[r][c]:
                    color = RED
                    f = font_md
                else:
                    color = BLUE
                    f = font_md
                txt = f.render(str(v), True, color)
                screen.blit(txt, txt.get_rect(center=(cx,cy)))
            elif game.notes[r][c]:
                for n in range(1,10):
                    if n in game.notes[r][c]:
                        nr = (n-1)//3; nc = (n-1)%3
                        nx = PAD_L + c*CELL + 10 + nc*18
                        ny = PAD_T + r*CELL + 8  + nr*17
                        nt = font_note.render(str(n), True, TEXT_GRAY)
                        screen.blit(nt, (nx, ny))

def draw_numpad():
    for i, rect in enumerate(NUM_RECTS):
        n = i+1
        hover = rect.collidepoint(pygame.mouse.get_pos())
        bg = BTN_HVR if hover else BTN_BG
        pygame.draw.rect(screen, bg, rect, border_radius=6)
        pygame.draw.rect(screen, LINE_THIN, rect, 1, border_radius=6)
        txt = font_md.render(str(n), True, TEXT_DARK)
        screen.blit(txt, txt.get_rect(center=rect.center))

def draw_ui():
    screen.fill(BG)

    # Título
    title = font_ttl.render("Sudoku", True, TEXT_DARK)
    screen.blit(title, (PAD_L, 18))

    # Timer + erros
    elapsed = int(time.time() - game.start) if not game.done else 0
    m, s = divmod(elapsed, 60)
    timer_txt = font_sm.render(f"{m}:{s:02d}", True, TEXT_DARK)
    err_txt   = font_sm.render(f"Erros: {game.errors}", True, TEXT_GRAY)
    hints_txt = font_sm.render(f"Dicas: {game.hints}", True, TEXT_GRAY)
    screen.blit(timer_txt, (W-60, 24))
    screen.blit(err_txt,   (W-130, 46))
    screen.blit(hints_txt, (W-60, 46))

    # Dificuldade label
    dlbl = font_sm.render("Dificuldade:", True, TEXT_GRAY)
    screen.blit(dlbl, (PAD_L, PAD_T + BOARD + 20 - 44 - 20))

    draw_board()

    # Botões
    pos = pygame.mouse.get_pos()
    for b in all_btns:
        b.check_hover(pos)
        b.draw(screen)

    draw_numpad()

    # Mensagem
    if game.msg:
        col = GREEN if game.done else TEXT_GRAY
        msg = font_sm.render(game.msg, True, col)
        screen.blit(msg, msg.get_rect(centerx=W//2, y=H-28))

    if game.done:
        overlay = pygame.Surface((W, H), pygame.SRCALPHA)
        overlay.fill((245,244,240,180))
        screen.blit(overlay, (0,0))
        done_txt = font_ttl.render("Parabéns!", True, GREEN)
        screen.blit(done_txt, done_txt.get_rect(center=(W//2, H//2-20)))
        sub = font_md.render(game.msg, True, TEXT_DARK)
        screen.blit(sub, sub.get_rect(center=(W//2, H//2+20)))
        restart = font_sm.render("Prima N para novo jogo", True, TEXT_GRAY)
        screen.blit(restart, restart.get_rect(center=(W//2, H//2+50)))

# --- Loop principal ---
clock = pygame.time.Clock()

while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            pygame.quit(); sys.exit()

        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            pos = event.pos
            # Clique no tabuleiro
            bx = pos[0] - PAD_L; by = pos[1] - PAD_T
            if 0 <= bx < BOARD and 0 <= by < BOARD:
                game.select(by//CELL, bx//CELL)
            # Botões
            for b in all_btns:
                b.click(pos)
            # Numpad
            for i, rect in enumerate(NUM_RECTS):
                if rect.collidepoint(pos):
                    game.input_num(i+1)

        elif event.type == pygame.KEYDOWN:
            k = event.key
            if k in (pygame.K_1,pygame.K_2,pygame.K_3,pygame.K_4,pygame.K_5,
                     pygame.K_6,pygame.K_7,pygame.K_8,pygame.K_9):
                game.input_num(k - pygame.K_0)
            elif k in (pygame.K_KP1,pygame.K_KP2,pygame.K_KP3,pygame.K_KP4,pygame.K_KP5,
                       pygame.K_KP6,pygame.K_KP7,pygame.K_KP8,pygame.K_KP9):
                game.input_num(k - pygame.K_KP0)
            elif k in (pygame.K_BACKSPACE, pygame.K_DELETE, pygame.K_0):
                game.erase()
            elif k == pygame.K_UP:    game.move(-1, 0)
            elif k == pygame.K_DOWN:  game.move( 1, 0)
            elif k == pygame.K_LEFT:  game.move( 0,-1)
            elif k == pygame.K_RIGHT: game.move( 0, 1)
            elif k == pygame.K_n:     game.new_game(); diff_btns[['easy','medium','hard'].index(game.difficulty)].active=True
            elif k == pygame.K_h:     game.hint()

    draw_ui()
    pygame.display.flip()
    clock.tick(30)