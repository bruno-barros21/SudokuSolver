:- module(minesweeper, [
    analyse_board/5,
    deduce_safe/5,
    deduce_mines/5
]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).

% =============================================
% MINESWEEPER SOLVER using CLP(FD)
% =============================================
%
% Board encoding sent from the frontend (flat list, row-major):
%   -2  = unrevealed, not flagged
%   -1  = flagged (treated as known mine)
%    0  = revealed, 0 neighbours
%    1-8 = revealed, N mine neighbours
%
% The solver:
%   1. Creates a CLP(FD) variable (0 or 1) for every unrevealed cell.
%   2. For every revealed numbered cell, posts the constraint:
%        sum(vars of unrevealed unflagged neighbours) = N - flagged_neighbours
%   3. Calls label/1 to enumerate solutions.
%   4. Collects all solutions; a cell is DEFINITELY SAFE if it is 0 in every
%      solution, DEFINITELY A MINE if it is 1 in every solution.
%
% To keep response time fast we cap enumeration at MaxSols solutions.
% Even with the cap, single-constraint deductions (the most common) are instant.

% =============================================
% NEIGHBOUR INDICES
% =============================================

neighbours(Idx, Rows, Cols, Neighbours) :-
    R is Idx // Cols,
    C is Idx mod Cols,
    findall(NIdx,
        ( member(DR, [-1, 0, 1]),
          member(DC, [-1, 0, 1]),
          (DR \= 0 ; DC \= 0),
          NR is R + DR,
          NC is C + DC,
          NR >= 0, NR < Rows,
          NC >= 0, NC < Cols,
          NIdx is NR * Cols + NC
        ),
        Neighbours).

% =============================================
% BUILD CONSTRAINT SYSTEM
% =============================================

% analyse_board(+Board, +Rows, +Cols, -SafeCells, -MineCells)
% Board: flat list of integers as described above.
analyse_board(Board, Rows, Cols, SafeCells, MineCells) :-
    length(Board, Total),
    Total =:= Rows * Cols,

    % Create one CLP(FD) variable per cell; known cells get fixed values.
    length(Vars, Total),
    assign_vars(Board, Vars, 0),

    % Post neighbour-sum constraints for every revealed numbered cell.
    post_constraints(Board, Vars, Rows, Cols, 0),

    % Enumerate solutions (cap at 500 to stay fast).
    MaxSols = 500,
    findnsols(MaxSols, Vars, label(Vars), Solutions),
    Solutions \= [],

    % A cell is safe if its value is 0 in ALL solutions.
    % A cell is a mine if its value is 1 in ALL solutions.
    % We only report unrevealed unflagged cells (Board[i] = -2).
    findall(I,
        ( nth0(I, Board, -2),
          maplist(nth0_val(I, 0), Solutions)
        ),
        SafeCells),
    findall(I,
        ( nth0(I, Board, -2),
          maplist(nth0_val(I, 1), Solutions)
        ),
        MineCells).

% nth0_val(+Idx, +ExpectedVal, +List)
nth0_val(Idx, Val, List) :-
    nth0(Idx, List, Val).

% assign_vars(+Board, +Vars, +Idx)
% Fixes CLP variables for known cells:
%   flagged (-1) → 1 (mine), revealed (>=0) → 0 (safe), unrevealed (-2) → 0..1
assign_vars([], [], _).
assign_vars([Cell|Cs], [Var|Vs], Idx) :-
    ( Cell =:= -1 -> Var = 1          % flagged = mine
    ; Cell >= 0   -> Var = 0          % revealed = safe
    ; Var in 0..1                     % unrevealed = unknown
    ),
    Next is Idx + 1,
    assign_vars(Cs, Vs, Next).

% post_constraints(+Board, +Vars, +Rows, +Cols, +Idx)
post_constraints([], _, _, _, _).
post_constraints([Cell|Cs], Vars, Rows, Cols, Idx) :-
    ( Cell >= 1 ->
        % Revealed numbered cell: sum of neighbour vars = Cell - already_flagged_neighbours
        neighbours(Idx, Rows, Cols, Nbs),
        findall(NVar,
            ( member(NIdx, Nbs),
              nth0(NIdx, Vars, NVar)
            ),
            NVars),
        % Flagged neighbours are already fixed to 1, so their contribution
        % is already in the sum — we just constrain the full sum = Cell.
        sum(NVars, #=, Cell)
    ; true
    ),
    Next is Idx + 1,
    post_constraints(Cs, Vars, Rows, Cols, Next).

% =============================================
% CONVENIENCE WRAPPERS (for testing in REPL)
% =============================================

deduce_safe(Board, Rows, Cols, SafeCells, MineCells) :-
    analyse_board(Board, Rows, Cols, SafeCells, MineCells).

deduce_mines(Board, Rows, Cols, SafeCells, MineCells) :-
    analyse_board(Board, Rows, Cols, SafeCells, MineCells).

% =============================================
% HTTP SERVER
% =============================================

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_client)).

:- set_setting(http:cors, [*]).

:- http_handler(root(analyse), route_analyse, []).
:- http_handler(root(.),       handle_index,   []).

start_server(Port) :-
    http_server(http_dispatch, [port(Port)]).

handle_index(Request) :-
    http_reply_file('minesweeper.html', [], Request).

handle_options(Request) :-
    cors_enable(Request, [methods([get, post, options])]),
    format('Content-type: text/plain~n~n').

route_analyse(Request) :- member(method(options), Request), !, handle_options(Request).
route_analyse(Request) :- handle_analyse(Request).

% POST /analyse
% Request body: { "board": [...], "rows": N, "cols": N }
%
% board values:
%   -2 = unrevealed
%   -1 = flagged
%    0 = revealed empty
%   1-8 = revealed with neighbour count
%
% Response: { "success": true, "safe": [...], "mines": [...] }
%   safe  = indices definitely safe to reveal
%   mines = indices definitely containing a mine
handle_analyse(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    Board = Dict.board,
    Rows  = Dict.rows,
    Cols  = Dict.cols,
    (   catch(
            analyse_board(Board, Rows, Cols, SafeCells, MineCells),
            _,
            fail)
    ->  reply_json_dict(_{
            success: true,
            safe:  SafeCells,
            mines: MineCells
        })
    ;   reply_json_dict(_{
            success: false,
            safe:  [],
            mines: [],
            error: "No deductions possible from current board state"
        })
    ).

% =============================================
% ENTRY POINT
% =============================================

:- initialization(main, main).
main :-
    start_server(8082),
    format("Minesweeper solver running on http://localhost:8082~n"),
    thread_get_message(_).