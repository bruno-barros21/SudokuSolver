:- use_module(library(clpfd)).
:- use_module(library(random)).

%% ================================================================
%%  Generic Sudoku — any box size N
%%  solve(N)  ->  generates and solves a puzzle of size N^2 x N^2
%% ================================================================

solve(N) :-
    Size is N * N,
    format('~nGenerating ~wx~w sudoku...~n~n', [Size, Size]),
    generate(N, Puzzle),
    format('Puzzle:~n'),
    print_board_n(Puzzle, N),
    format('~nSolving...~n~n'),
    sudoku_n(N, Puzzle, Solution),
    format('Solution:~n'),
    print_board_n(Solution, N).

solve_custom(N, Puzzle) :-
    Size is N * N,
    format('~nSolving ~wx~w sudoku...~n~n', [Size, Size]),
    format('Puzzle:~n'),
    print_board_n(Puzzle, N),
    format('~nSolving...~n~n'),
    sudoku_n(N, Puzzle, Solution),
    format('Solution:~n'),
    print_board_n(Solution, N).

%% ================================================================
%%  Puzzle generator
%%  1. Solve an empty board to get a valid filled grid
%%  2. Randomly remove ~60% of cells
%% ================================================================

generate(N, Puzzle) :-
    Size is N * N,
    Total is Size * Size,
    length(Empty, Total),
    maplist(=(0), Empty),
    sudoku_n(N, Empty, Filled),        %% get a valid complete grid
    remove_cells(Filled, N, Puzzle).

remove_cells(Filled, N, Puzzle) :-
    Size is N * N,
    Total is Size * Size,
    Clues is max(Total // 4, Size * 2), %% keep ~25% clues, at least 2*Size
    remove_cells(Filled, Total, Clues, Puzzle).

remove_cells(Board, Total, Clues, Puzzle) :-
    numlist(1, Total, AllIdxs),
    length(KeepIdxs, Clues),
    random_subset(AllIdxs, KeepIdxs),  %% pick which indices to keep
    mask_board(Board, AllIdxs, KeepIdxs, Puzzle).

%% Keep a cell if its index is in KeepIdxs, else zero it out
mask_board([], [], _, []).
mask_board([V|Vs], [I|Is], KeepIdxs, [Out|Outs]) :-
    ( memberchk(I, KeepIdxs) -> Out = V ; Out = 0 ),
    mask_board(Vs, Is, KeepIdxs, Outs).

%% Pick K random elements from a list (no replacement)
random_subset(List, Subset) :-
    length(Subset, K),
    length(List, Len),
    random_subset_(List, Len, K, Subset).

random_subset_(_, _, 0, []) :- !.
random_subset_(List, Len, K, [X|Rest]) :-
    random_between(1, Len, Pos),
    nth1(Pos, List, X),
    select(X, List, Remaining),
    Len1 is Len - 1,
    K1   is K - 1,
    random_subset_(Remaining, Len1, K1, Rest).

%% ================================================================
%%  Solver
%% ================================================================

sudoku_n(N, Puzzle, Solution) :-
    Size is N * N,
    Total is Size * Size,
    length(Solution, Total),
    Solution ins 1..Size,
    post_givens(Puzzle, Solution),
    Size1 is Size - 1,
    numlist(0, Size1, Idxs),
    maplist(check_row(Solution, Size, Idxs), Idxs),
    maplist(check_col(Solution, Size, Idxs), Idxs),
    check_boxes(Solution, N, Size),
    label(Solution).

post_givens([], []).
post_givens([0|Ps], [_|Ss]) :- post_givens(Ps, Ss).
post_givens([P|Ps], [P|Ss]) :- P > 0, post_givens(Ps, Ss).

check_row(Board, Size, ColIdxs, R) :-
    maplist(board_at(Board, Size, R), ColIdxs, Row),
    all_distinct(Row).

check_col(Board, Size, RowIdxs, C) :-
    maplist(board_at_col(Board, Size, C), RowIdxs, Col),
    all_distinct(Col).

board_at(Board, Size, R, C, V) :-
    Pos is R * Size + C,
    nth0(Pos, Board, V).

board_at_col(Board, Size, C, R, V) :-
    Pos is R * Size + C,
    nth0(Pos, Board, V).

check_boxes(Board, N, Size) :-
    Size1 is Size - 1,
    numlist(0, Size1, All),
    include(divisible_by(N), All, Starts),
    maplist(check_boxes_row(Board, N, Size, Starts), Starts).

check_boxes_row(Board, N, Size, ColStarts, BR) :-
    maplist(check_box(Board, N, Size, BR), ColStarts).

check_box(Board, N, Size, BR, BC) :-
    N1 is N - 1,
    numlist(0, N1, Ls),
    maplist(check_box_row(Board, Size, BR, BC, Ls), Ls, Rows),
    append(Rows, Box),
    all_distinct(Box).

check_box_row(Board, Size, BR, BC, ColOffsets, DR, Row) :-
    maplist(box_element(Board, Size, BR, BC, DR), ColOffsets, Row).

box_element(Board, Size, BR, BC, DR, DC, V) :-
    R is BR + DR,
    C is BC + DC,
    Pos is R * Size + C,
    nth0(Pos, Board, V).

divisible_by(N, X) :- X mod N =:= 0.

%% ================================================================
%%  Pretty printer
%% ================================================================

print_board_n(Board, N) :-
    Size is N * N,
    Size1 is Size - 1,
    numlist(0, Size1, RowIdxs),
    maplist(print_row_n(Board, N, Size), RowIdxs),
    nl.

print_row_n(Board, N, Size, R) :-
    ( R > 0, R mod N =:= 0 -> print_hsep(N) ; true ),
    Size1 is Size - 1,
    numlist(0, Size1, ColIdxs),
    maplist(print_cell_n(Board, N, Size, R), ColIdxs),
    nl.

print_cell_n(Board, N, Size, R, C) :-
    ( C > 0, C mod N =:= 0 -> write('| ') ; true ),
    Pos is R * Size + C,
    nth0(Pos, Board, V),
    ( integer(V), V =:= 0 -> write('.  ')
    ; integer(V), V < 10  -> format('~w  ', [V])
    ; integer(V)          -> format('~w ', [V])
    ;                        write('.  ')
    ).

print_hsep(N) :-
    Size is N * N,
    Dashes is Size * 3 + N - 1,
    length(Ds, Dashes),
    maplist(=('-'), Ds),
    atom_chars(Sep, Ds),
    writeln(Sep).