% ============================================================
%  Star Battle Solver -- SWI-Prolog
%
%  Run:
%    swipl -g "solve_all,halt" star.pl
%
%  Interactive:
%    swipl star.pl
%    ?- solve_and_print.       % solves the first puzzle (5x5)
%    ?- solve_and_print(6).    % solves the 6x6 puzzle
%    ?- solve_and_print(7).    % solves the 7x7 puzzle
%    ?- solve_and_print(8).    % solves the 8x8 puzzle
%    ?- solve_all.             % solves every defined puzzle
% ============================================================

:- use_module(library(lists)).
:- use_module(library(random)).

% ------------------------------------------------------------
%  PUZZLE DEFINITION
%
%  puzzle(?N, ?Stars, ?Regions)
%    N       : grid size  (NxN)
%    Stars   : stars required per row, column, and region
%    Regions : list of N lists of N region-ID atoms
%
%  Rules:
%    - Every cell belongs to exactly one region.
%    - There are exactly N distinct regions.
%    - Each row, column, and region contains exactly Stars stars.
%    - No two stars touch, even diagonally (king move).
% ------------------------------------------------------------

%% 5x5 puzzle -- 1 star per row / col / region
puzzle(5, 1,
    [ [a, a, b, c, c],
      [a, b, b, c, c],
      [a, b, d, d, c],
      [a, e, d, d, c],
      [e, e, e, d, d] ]).

%% 6x6 puzzle -- 1 star per row / col / region
puzzle(6, 1,
    [ [a, a, b, b, c, c],
      [a, a, b, b, c, c],
      [d, d, b, b, e, e],
      [d, d, f, f, e, e],
      [d, d, f, f, e, e],
      [d, d, f, f, e, e] ]).

%% 7x7 puzzle -- 1 star per row / col / region
puzzle(7, 1,
    [ [a, a, b, b, c, c, c],
      [a, a, b, b, c, c, c],
      [a, a, b, b, d, d, d],
      [a, a, e, e, d, d, d],
      [f, f, e, e, d, d, d],
      [f, f, e, e, g, g, g],
      [f, f, e, e, g, g, g] ]).

%% 8x8 puzzle -- 1 star per row / col / region
puzzle(8, 1,
    [ [a, a, b, b, b, c, c, c],
      [a, a, b, b, b, c, c, c],
      [a, a, b, b, d, d, c, c],
      [a, a, e, e, d, d, c, c],
      [a, a, e, e, d, d, f, f],
      [g, g, e, e, d, d, f, f],
      [g, g, h, h, d, d, f, f],
      [g, g, h, h, h, h, f, f] ]).

% ============================================================
%  TOP-LEVEL
% ============================================================

%% solve_and_print/0 -- solve the first puzzle/3 fact and print the result.
solve_and_print :-
    puzzle(N, Stars, Regions),
    !,
    solve_one(N, Stars, Regions).

%% solve_and_print/1 -- solve the puzzle of the given size N.
solve_and_print(N) :-
    ( puzzle(N, Stars, Regions)
    -> solve_one(N, Stars, Regions)
    ;  format("No puzzle defined for size ~wx~w.~n", [N, N])
    ).

%% solve_all/0 -- solve every defined puzzle in order.
solve_all :-
    forall(puzzle(N, Stars, Regions),
           ( solve_one(N, Stars, Regions), nl )).

solve_one(N, Stars, Regions) :-
    format("Solving ~wx~w Star Battle (~w star(s) per row/col/region)...~n",
           [N, N, Stars]),
    ( solve_puzzle(N, Stars, Regions, Solution)
    -> format("Solution found!~n~n"),
       print_solution(Solution, N)
    ;  format("No solution exists for this puzzle.~n")
    ).

% ============================================================
%  SOLVER
%
%  Strategy: row-by-row backtracking -- Prolog's native search.
%
%  For each row (in order), we non-deterministically choose which
%  Stars cells become stars (is_bit/1 + length check).  After
%  committing to a row we immediately prune dead branches with
%  three constraint checks:
%
%    1. check_columns   -- no column so far exceeds Stars stars
%    2. check_regions   -- no region so far exceeds Stars stars
%    3. check_adjacency -- no two placed stars are king-adjacent
%
%  When all N rows are placed the row constraint (exactly Stars per
%  row) combined with the column / region "at most" checks implies
%  the column and region counts are exact (pigeonhole), so no
%  separate "exactly" check is needed at the end.
% ============================================================

%% solve_puzzle(+N, +Stars, +Regions, -Solution)
%%   Solution is a list of N lists of N integers: 1 = star, 0 = empty.
solve_puzzle(N, Stars, Regions, Solution) :-
    length(Solution, N),
    maplist(make_row(N), Solution),
    collect_region_ids(Regions, RegionIds),
    solve_rows(Solution, Regions, RegionIds, N, Stars, 0).

make_row(N, Row) :- length(Row, N).

collect_region_ids(Regions, Ids) :-
    flatten(Regions, Flat),
    list_to_set(Flat, Ids).

%% Base case: all N rows have been placed successfully.
solve_rows(_, _, _, N, _, N) :- !.

%% Recursive case: place row R, check constraints, continue.
solve_rows(Solution, Regions, RegionIds, N, Stars, R) :-
    R < N,
    nth0(R, Solution, Row),
    place_stars_in_row(Row, Stars),
    check_columns(Solution, N, Stars, R),
    check_regions(Solution, Regions, RegionIds, Stars),
    check_adjacency(Solution, R),
    R1 is R + 1,
    solve_rows(Solution, Regions, RegionIds, N, Stars, R1).

%% Non-deterministically assign 0/1 to each cell so that exactly
%% Stars cells are 1.  Prolog backtracks over is_bit choices.
place_stars_in_row(Row, Stars) :-
    maplist(is_bit, Row),
    include(==(1), Row, Ones),
    length(Ones, Stars).

is_bit(0).
is_bit(1).

% ---- Constraint 1: columns -----------------------------------------

check_columns(Solution, N, Stars, R) :-
    N1 is N - 1,
    numlist(0, N1, Cols),
    maplist(check_col(Solution, Stars, R), Cols).

check_col(Solution, Stars, R, C) :-
    numlist(0, R, Rows),
    maplist(cell_val(Solution, C), Rows, Vals),
    include(==(1), Vals, Ones),
    length(Ones, Count),
    Count =< Stars.

cell_val(Solution, C, R, V) :-
    nth0(R, Solution, Row),
    nth0(C, Row, V).

% ---- Constraint 2: regions -----------------------------------------

check_regions(Solution, Regions, RegionIds, Stars) :-
    maplist(check_region(Solution, Regions, Stars), RegionIds).

check_region(Solution, Regions, Stars, RegId) :-
    findall(V, region_placed_cell(Solution, Regions, RegId, V), Vals),
    include(==(1), Vals, Ones),
    length(Ones, Count),
    Count =< Stars.

%% Only count cells in rows that have been fully instantiated (ground).
region_placed_cell(Solution, Regions, RegId, V) :-
    nth0(R, Regions, RegRow),
    nth0(C, RegRow, RegId),
    nth0(R, Solution, SolRow),
    nth0(C, SolRow, V),
    ground(V).

% ---- Constraint 3: adjacency (king move) ---------------------------

%% Fail if any two stars in rows 0..R are king-adjacent (8-connected).
check_adjacency(Solution, R) :-
    numlist(0, R, Rows),
    \+ ( member(R1, Rows), member(R2, Rows),
         stars_adjacent(Solution, R1, R2) ).

stars_adjacent(Solution, R1, R2) :-
    nth0(R1, Solution, Row1), nth0(C1, Row1, 1),
    nth0(R2, Solution, Row2), nth0(C2, Row2, 1),
    ( R1 \= R2 ; C1 \= C2 ),
    Rdiff is abs(R1 - R2), Rdiff =< 1,
    Cdiff is abs(C1 - C2), Cdiff =< 1.

% ============================================================
%  PRINTING
% ============================================================

print_solution(Solution, N) :-
    print_border(N),
    maplist(print_row, Solution),
    print_border(N), nl.

print_border(N) :-
    format("+"),
    forall(between(1, N, _), format("---+")),
    nl.

print_row(Row) :-
    format("| "),
    maplist(print_cell, Row),
    nl.

print_cell(1) :- format("* | ").
print_cell(0) :- format("  | ").



% ============================================================
%  RANDOM PUZZLE GENERATOR
%
%  Generation method:
%    1. Create a random valid hidden star solution with one star in
%       every row and every column, with no king-adjacent stars.
%    2. Create exactly N connected regions by seeding one region on
%       each star and randomly growing those regions until the whole
%       board is covered.
%    3. Because each region is grown from exactly one star seed, the
%       generated board is guaranteed to have at least one valid
%       solution: the hidden solution generated in step 1.
% ============================================================

generate_random_puzzle(N, 1, Regions, FlatSolution) :-
    integer(N), N >= 5, N =< 10,
    generate_random_solution(N, SolutionRows, StarCells),
    grow_random_regions(N, StarCells, RegionFlat),
    flat_to_rows(RegionFlat, N, Regions),
    flatten(SolutionRows, FlatSolution).

generate_random_solution(N, SolutionRows, StarCells) :-
    N1 is N - 1,
    numlist(0, N1, Cols),
    repeat,
      random_permutation(Cols, StarCols),
      no_adjacent_star_columns(StarCols),
    !,
    solution_rows_from_cols(StarCols, N, 0, SolutionRows, StarCells).

no_adjacent_star_columns([]).
no_adjacent_star_columns([_]).
no_adjacent_star_columns([A,B|Rest]) :-
    Diff is abs(A - B),
    Diff > 1,
    no_adjacent_star_columns([B|Rest]).

solution_rows_from_cols([], _, _, [], []).
solution_rows_from_cols([C|Cs], N, R, [Row|Rows], [cell(R,C,R)|Cells]) :-
    row_with_star(N, C, Row),
    R1 is R + 1,
    solution_rows_from_cols(Cs, N, R1, Rows, Cells).

row_with_star(N, StarCol, Row) :-
    N1 is N - 1,
    findall(V,
            (between(0, N1, C), (C =:= StarCol -> V = 1 ; V = 0)),
            Row).

% Start with one region seed at each generated star, then grow regions.
grow_random_regions(N, StarCells, RegionFlat) :-
    Total is N * N,
    length(Empty, Total),
    maplist(=(-1), Empty),
    seed_regions(N, StarCells, Empty, Seeded),
    grow_until_full(N, Seeded, RegionFlat).

seed_regions(_, [], Flat, Flat).
seed_regions(N, [cell(R,C,Reg)|Rest], Flat0, Flat) :-
    index_of(N, R, C, Idx),
    set_nth0(Flat0, Idx, Reg, Flat1),
    seed_regions(N, Rest, Flat1, Flat).

grow_until_full(_, Flat, Flat) :-
    \+ member(-1, Flat), !.
grow_until_full(N, Flat0, Flat) :-
    findall(choice(Idx, Reg), frontier_choice(N, Flat0, Idx, Reg), Choices0),
    Choices0 \= [],
    random_permutation(Choices0, [choice(Idx, Reg)|_]),
    set_nth0(Flat0, Idx, Reg, Flat1),
    grow_until_full(N, Flat1, Flat).

frontier_choice(N, Flat, Idx, Reg) :-
    nth0(Idx, Flat, -1),
    row_col_of(N, Idx, R, C),
    orthogonal_neighbor(N, R, C, NR, NC),
    index_of(N, NR, NC, NIdx),
    nth0(NIdx, Flat, Reg),
    Reg =\= -1.

orthogonal_neighbor(N, R, C, NR, C) :- NR is R - 1, NR >= 0, NR < N.
orthogonal_neighbor(N, R, C, NR, C) :- NR is R + 1, NR >= 0, NR < N.
orthogonal_neighbor(N, R, C, R, NC) :- NC is C - 1, NC >= 0, NC < N.
orthogonal_neighbor(N, R, C, R, NC) :- NC is C + 1, NC >= 0, NC < N.

index_of(N, R, C, Idx) :- Idx is R * N + C.
row_col_of(N, Idx, R, C) :- R is Idx // N, C is Idx mod N.

set_nth0([_|Xs], 0, V, [V|Xs]) :- !.
set_nth0([X|Xs], I, V, [X|Ys]) :-
    I > 0,
    I1 is I - 1,
    set_nth0(Xs, I1, V, Ys).

flat_to_rows([], _, []).
flat_to_rows(Flat, N, [Row|Rows]) :-
    length(Row, N),
    append(Row, Rest, Flat),
    flat_to_rows(Rest, N, Rows).

% ============================================================
%  HTTP SERVER FOR HTML FRONTEND
%
%  Run:
%    swipl star.pl
%  Then open star.html in the browser.
%  The frontend calls:
%    GET  /status
%    POST /generate {"n":5}
%    POST /solve   {"n":5,"stars":1,"regions":[[0,0,...],...]}
%    POST /verify  {"n":5,"stars":1,"regions":[...],"current":[0,1,0,...]}
%    POST /hint    {"n":5,"stars":1,"regions":[...],"current":[0,1,0,...]}
% ============================================================

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_files)).

:- set_setting(http:cors, [*]).

:- http_handler(root(status),   route_status,   []).
:- http_handler(root(solve),     route_solve,    []).
:- http_handler(root(generate),  route_generate, []).
:- http_handler(root(verify),    route_verify,   []).
:- http_handler(root(hint),      route_hint,     []).
:- http_handler(root(.),         handle_index,   []).

start_server(Port) :-
    http_server(http_dispatch, [port(Port)]).

handle_index(Request) :-
    http_reply_file('star.html', [], Request).

handle_options(Request) :-
    cors_enable(Request, [methods([get, post, options])]),
    format('Content-type: text/plain~n~n').

route_status(Request) :- member(method(options), Request), !, handle_options(Request).
route_status(Request) :- handle_status(Request).

route_solve(Request) :- member(method(options), Request), !, handle_options(Request).
route_solve(Request) :- handle_http_solve(Request).

route_generate(Request) :- member(method(options), Request), !, handle_options(Request).
route_generate(Request) :- handle_http_generate(Request).

route_verify(Request) :- member(method(options), Request), !, handle_options(Request).
route_verify(Request) :- handle_http_verify(Request).

route_hint(Request) :- member(method(options), Request), !, handle_options(Request).
route_hint(Request) :- handle_http_hint(Request).

handle_status(_Request) :-
    cors_enable,
    reply_json_dict(_{success:true, engine:"SWI-Prolog Star Battle solver"}).

% POST /generate  { "n": 5 }
handle_http_generate(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    N = Dict.n,
    Stars = 1,
    (   catch(generate_random_puzzle(N, Stars, Regions, FlatSolution), Error, true),
        var(Error)
    ->  reply_json_dict(_{success:true, n:N, stars:Stars, regions:Regions, solution:FlatSolution})
    ;   reply_json_dict(_{success:false, error:"Could not generate puzzle"})
    ).

% POST /solve
handle_http_solve(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    N = Dict.n,
    Stars = Dict.stars,
    Regions = Dict.regions,
    (   catch(solve_puzzle(N, Stars, Regions, SolutionRows), Error, true),
        var(Error),
        flatten(SolutionRows, FlatSolution)
    ->  reply_json_dict(_{success:true, solution:FlatSolution})
    ;   reply_json_dict(_{success:false, error:"No solution found"})
    ).

% POST /verify
handle_http_verify(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    N = Dict.n,
    Stars = Dict.stars,
    Regions = Dict.regions,
    Current = Dict.current,
    (   catch(solve_puzzle(N, Stars, Regions, SolutionRows), Error, true),
        var(Error),
        flatten(SolutionRows, FlatSolution)
    ->  verify_star_cells(Current, FlatSolution, 0, Results),
        reply_json_dict(_{success:true, solution:FlatSolution, results:Results})
    ;   reply_json_dict(_{success:false, error:"Cannot verify: no solution"})
    ).

verify_star_cells([], [], _, []).
verify_star_cells([C|Cs], [S|Ss], Idx, [_{index:Idx, status:Status}|Rest]) :-
    (   C =:= 1, S =:= 1 -> Status = correct
    ;   C =:= 1, S =\= 1 -> Status = incorrect
    ;   C =\= 1, S =:= 1 -> Status = missing
    ;   Status = empty
    ),
    Next is Idx + 1,
    verify_star_cells(Cs, Ss, Next, Rest).

% POST /hint
handle_http_hint(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    N = Dict.n,
    Stars = Dict.stars,
    Regions = Dict.regions,
    Current = Dict.current,
    (   catch(solve_puzzle(N, Stars, Regions, SolutionRows), Error, true),
        var(Error),
        flatten(SolutionRows, FlatSolution)
    ->  (   find_missing_star(Current, FlatSolution, 0, HintIdx)
        ->  reply_json_dict(_{success:true, index:HintIdx, value:1, solution:FlatSolution})
        ;   reply_json_dict(_{success:true, index: -1, value:0, solution:FlatSolution, message:"Board complete"})
        )
    ;   reply_json_dict(_{success:false, error:"Cannot generate hint: no solution"})
    ).

find_missing_star([C|_], [S|_], Idx, Idx) :-
    C =\= 1,
    S =:= 1,
    !.
find_missing_star([_|Cs], [_|Ss], Idx, HintIdx) :-
    Next is Idx + 1,
    find_missing_star(Cs, Ss, Next, HintIdx).

:- initialization(main, main).
main :-
    start_server(8081),
    format("Star Battle Prolog server running on http://localhost:8081~n"),
    thread_get_message(_).
