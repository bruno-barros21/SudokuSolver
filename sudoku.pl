:- use_module(library(clpfd)).

%% sudoku(+Puzzle, -Solution)
%% Puzzle is a list of 81 integers, 0 = unknown cell.
sudoku(Puzzle, Solution) :-
    length(Puzzle, 81),
    length(Solution, 81),
    
    % Bind knowns and constrain unknowns to 1..9
    maplist(cell, Puzzle, Solution),
    
    % Split into rows
    Solution = [
        A1,A2,A3,A4,A5,A6,A7,A8,A9,
        B1,B2,B3,B4,B5,B6,B7,B8,B9,
        C1,C2,C3,C4,C5,C6,C7,C8,C9,
        D1,D2,D3,D4,D5,D6,D7,D8,D9,
        E1,E2,E3,E4,E5,E6,E7,E8,E9,
        F1,F2,F3,F4,F5,F6,F7,F8,F9,
        G1,G2,G3,G4,G5,G6,G7,G8,G9,
        H1,H2,H3,H4,H5,H6,H7,H8,H9,
        I1,I2,I3,I4,I5,I6,I7,I8,I9
    ],

    % All rows must have distinct values
    all_distinct([A1,A2,A3,A4,A5,A6,A7,A8,A9]),
    all_distinct([B1,B2,B3,B4,B5,B6,B7,B8,B9]),
    all_distinct([C1,C2,C3,C4,C5,C6,C7,C8,C9]),
    all_distinct([D1,D2,D3,D4,D5,D6,D7,D8,D9]),
    all_distinct([E1,E2,E3,E4,E5,E6,E7,E8,E9]),
    all_distinct([F1,F2,F3,F4,F5,F6,F7,F8,F9]),
    all_distinct([G1,G2,G3,G4,G5,G6,G7,G8,G9]),
    all_distinct([H1,H2,H3,H4,H5,H6,H7,H8,H9]),
    all_distinct([I1,I2,I3,I4,I5,I6,I7,I8,I9]),

    % All columns must have distinct values
    all_distinct([A1,B1,C1,D1,E1,F1,G1,H1,I1]),
    all_distinct([A2,B2,C2,D2,E2,F2,G2,H2,I2]),
    all_distinct([A3,B3,C3,D3,E3,F3,G3,H3,I3]),
    all_distinct([A4,B4,C4,D4,E4,F4,G4,H4,I4]),
    all_distinct([A5,B5,C5,D5,E5,F5,G5,H5,I5]),
    all_distinct([A6,B6,C6,D6,E6,F6,G6,H6,I6]),
    all_distinct([A7,B7,C7,D7,E7,F7,G7,H7,I7]),
    all_distinct([A8,B8,C8,D8,E8,F8,G8,H8,I8]),
    all_distinct([A9,B9,C9,D9,E9,F9,G9,H9,I9]),

    % All 3x3 boxes must have distinct values
    all_distinct([A1,A2,A3,B1,B2,B3,C1,C2,C3]),
    all_distinct([A4,A5,A6,B4,B5,B6,C4,C5,C6]),
    all_distinct([A7,A8,A9,B7,B8,B9,C7,C8,C9]),
    all_distinct([D1,D2,D3,E1,E2,E3,F1,F2,F3]),
    all_distinct([D4,D5,D6,E4,E5,E6,F4,F5,F6]),
    all_distinct([D7,D8,D9,E7,E8,E9,F7,F8,F9]),
    all_distinct([G1,G2,G3,H1,H2,H3,I1,I2,I3]),
    all_distinct([G4,G5,G6,H4,H5,H6,I4,I5,I6]),
    all_distinct([G7,G8,G9,H7,H8,H9,I7,I8,I9]),

    % Label: search for values that satisfy all constraints
    label(Solution).

%% cell(+Given, -Var): if Given is 0 (unknown), constrain Var in 1..9;
%% otherwise unify Var with the given digit.
cell(0, Var) :- Var in 1..9.
cell(Given, Given) :- Given in 1..9.

%% print_board(+Board): pretty-print an 81-element list as a 9x9 grid.
print_board(Board) :-
    print_board(Board, 0).

print_board([], _).
print_board([H|T], N) :-
    ( N mod 9 =:= 0, N > 0 ->
        ( N mod 27 =:= 0 -> writeln('------+-------+------') ; true ),
        nl
    ; N mod 3 =:= 0, N > 0 ->
        write(' | ')
    ;   true ),
    write(H), write(' '),
    N1 is N + 1,
    print_board(T, N1).

%% Example puzzles — 0 = empty cell
example(easy, [
    5,3,0, 0,7,0, 0,0,0,
    6,0,0, 1,9,5, 0,0,0,
    0,9,8, 0,0,0, 0,6,0,

    8,0,0, 0,6,0, 0,0,3,
    4,0,0, 8,0,3, 0,0,1,
    7,0,0, 0,2,0, 0,0,6,

    0,6,0, 0,0,0, 2,8,0,
    0,0,0, 4,1,9, 0,0,5,
    0,0,0, 0,8,0, 0,7,9
]).

example(hard, [
    0,0,0, 0,0,0, 0,0,0,
    0,0,0, 0,0,3, 0,8,5,
    0,0,1, 0,2,0, 0,0,0,

    0,0,0, 5,0,7, 0,0,0,
    0,0,4, 0,0,0, 1,0,0,
    0,9,0, 0,0,0, 0,0,0,

    5,0,0, 0,0,0, 0,7,3,
    0,0,2, 0,1,0, 0,0,0,
    0,0,0, 0,4,0, 0,0,9
]).

%% --- Entry points ---

%% solve_example(+Difficulty)
%% Usage: solve_example(easy).   solve_example(hard).
solve_example(Diff) :-
    example(Diff, Puzzle),
    format("Puzzle (~w):~n", [Diff]),
    print_board(Puzzle), nl,
    sudoku(Puzzle, Solution),
    writeln("Solution:"),
    print_board(Solution), nl.

%% solve_custom(+List81)
%% Usage: solve_custom([5,3,0,...]).
solve_custom(Puzzle) :-
    sudoku(Puzzle, Solution),
    writeln("Solution:"),
    print_board(Solution), nl.