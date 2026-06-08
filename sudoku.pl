:- module(sudoku, [
    solve_sudoku/2,
    verify_sudoku/2,
    get_hint/3
]).

:- use_module(library(clpfd)).

% =============================================
% SUDOKU SOLVER using CLP(FD)
% =============================================

% solve_sudoku(+Puzzle, -Solution)
% Puzzle is a list of 81 values (0 = empty)
solve_sudoku(Puzzle, Solution) :-
    length(Puzzle, 81),
    length(Solution, 81),
    % Map 0s to variables, keep given digits
    maplist(init_cell, Puzzle, Solution),
    % Apply sudoku constraints
    sudoku_constraints(Solution).

init_cell(0, _) :- !.
init_cell(N, N) :- integer(N), N >= 1, N =< 9.

sudoku_constraints(Board) :-
    % All cells must be in 1..9
    Board ins 1..9,
    % Split into rows
    rows(Board, Rows),
    % Split into columns
    transpose(Rows, Cols),
    % Split into 3x3 boxes
    boxes(Board, Boxes),
    % All rows, cols, boxes must have distinct values
    maplist(all_distinct, Rows),
    maplist(all_distinct, Cols),
    maplist(all_distinct, Boxes),
    % Label (find values)
    label(Board).

rows([], []).
rows(Board, [Row|Rows]) :-
    length(Row, 9),
    append(Row, Rest, Board),
    rows(Rest, Rows).

boxes(Board, Boxes) :-
    rows(Board, Rows),
    Rows = [R1,R2,R3,R4,R5,R6,R7,R8,R9],
    box_from_rows(R1,R2,R3,B1,B2,B3),
    box_from_rows(R4,R5,R6,B4,B5,B6),
    box_from_rows(R7,R8,R9,B7,B8,B9),
    Boxes = [B1,B2,B3,B4,B5,B6,B7,B8,B9].

box_from_rows(R1,R2,R3,B1,B2,B3) :-
    R1 = [A1,A2,A3,B1_1,B1_2,B1_3,C1,C2,C3],
    R2 = [A4,A5,A6,B1_4,B1_5,B1_6,C4,C5,C6],
    R3 = [A7,A8,A9,B1_7,B1_8,B1_9,C7,C8,C9],
    B1 = [A1,A2,A3,A4,A5,A6,A7,A8,A9],
    B2 = [B1_1,B1_2,B1_3,B1_4,B1_5,B1_6,B1_7,B1_8,B1_9],
    B3 = [C1,C2,C3,C4,C5,C6,C7,C8,C9].

% =============================================
% VERIFY - check current board state
% =============================================

% verify_sudoku(+Puzzle, +Current)
% Returns which cells are incorrect (non-zero, non-matching solution)
verify_sudoku(Puzzle, Current) :-
    solve_sudoku(Puzzle, Solution),
    check_cells(Current, Solution, 0).

check_cells([], [], _).
check_cells([C|Cs], [S|Ss], Idx) :-
    (C =\= 0 ->
        (C =:= S -> Status = correct ; Status = incorrect)
    ;
        Status = empty
    ),
    format("~w:~w~n", [Idx, Status]),
    Next is Idx + 1,
    check_cells(Cs, Ss, Next).

% =============================================
% HINT - returns one empty cells correct value
% =============================================

get_hint(Puzzle, Current, hint(Index, Value)) :-
    solve_sudoku(Puzzle, Solution),
    find_hint(Current, Solution, 0, Index, Value).

find_hint([C|_], [S|_], Idx, Idx, S) :-
    C =:= 0, !.
find_hint([_|Cs], [_|Ss], Idx, HintIdx, HintVal) :-
    Next is Idx + 1,
    find_hint(Cs, Ss, Next, HintIdx, HintVal).

% =============================================
% HTTP SERVER
% =============================================

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).

:- set_setting(http:cors, [*]).

:- http_handler(root(solve),   route_solve,   []).
:- http_handler(root(verify),  route_verify,  []).
:- http_handler(root(hint),    route_hint,    []).
:- http_handler(root(.),       handle_index,  []).

start_server(Port) :-
    http_server(http_dispatch, [port(Port)]).

handle_index(Request) :-
    http_reply_file('index.html', [], Request).

handle_options(Request) :-
    cors_enable(Request, [methods([get, post, options])]),
    format('Content-type: text/plain~n~n').

route_solve(Request) :- member(method(options), Request), !, handle_options(Request).
route_solve(Request) :- handle_solve(Request).

route_verify(Request) :- member(method(options), Request), !, handle_options(Request).
route_verify(Request) :- handle_verify(Request).

route_hint(Request) :- member(method(options), Request), !, handle_options(Request).
route_hint(Request) :- handle_hint(Request).

% POST /solve  { "puzzle": [0,5,0,...] }
handle_solve(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    Puzzle = Dict.puzzle,
    (   catch(solve_sudoku(Puzzle, Solution), _, fail)
    ->  reply_json_dict(_{success: true, solution: Solution})
    ;   reply_json_dict(_{success: false, error: "No solution found"})
    ).

% POST /verify  { "puzzle": [..], "current": [..] }
handle_verify(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    Puzzle  = Dict.puzzle,
    Current = Dict.current,
    (   catch(solve_sudoku(Puzzle, Solution), _, fail)
    ->  verify_cells(Current, Solution, 0, Results),
        reply_json_dict(_{success: true, results: Results})
    ;   reply_json_dict(_{success: false, error: "Cannot verify: no solution"})
    ).

verify_cells([], [], _, []).
verify_cells([C|Cs], [S|Ss], Idx, [_{index:Idx, status:Status}|Rest]) :-
    (C =:= 0 -> Status = empty
    ; C =:= S -> Status = correct
    ; Status = incorrect),
    Next is Idx + 1,
    verify_cells(Cs, Ss, Next, Rest).

% POST /hint  { "puzzle": [..], "current": [..] }
handle_hint(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    Puzzle  = Dict.puzzle,
    Current = Dict.current,
    (   catch(solve_sudoku(Puzzle, Solution), _, fail)
    ->  (   find_hint_cells(Current, Solution, 0, HintIdx, HintVal)
        ->  reply_json_dict(_{success: true, index: HintIdx, value: HintVal})
        ;   reply_json_dict(_{success: true, index: -1, value: -1, message: "Board complete!"})
        )
    ;   reply_json_dict(_{success: false, error: "Cannot generate hint: no solution"})
    ).

find_hint_cells([C|_], [S|_], Idx, Idx, S) :-
    C =:= 0, !.
find_hint_cells([_|Cs], [_|Ss], Idx, HintIdx, HintVal) :-
    Next is Idx + 1,
    find_hint_cells(Cs, Ss, Next, HintIdx, HintVal).

:- initialization(main, main).
main :-
    start_server(8080),
    format("Sudoku server running on http://localhost:8080~n"),
    thread_get_message(_).