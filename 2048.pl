:- module(game_2048, [start_server/1]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_client)).
:- use_module(library(clpfd)).
:- use_module(library(random)).
:- use_module(library(lists)).

:- set_setting(http:cors, [*]).

:- http_handler(root(new), route_new, []).
:- http_handler(root(move), route_move, []).

start_server(Port) :-
    http_server(http_dispatch, [port(Port)]).

% --------- Game Logic ---------

remove_zeros([], []).
remove_zeros([0|T], Rest) :- remove_zeros(T, Rest).
remove_zeros([X|T], [X|Rest]) :- X \= 0, remove_zeros(T, Rest).

merge_row([], [], 0) :- !.
merge_row([X], [X], 0) :- !.
merge_row([X,X|T], [Y|Rest], Score) :- 
    !, Y is X * 2, 
    merge_row(T, Rest, S), Score is S + Y.
merge_row([X,Y|T], [X|Rest], Score) :- 
    !, merge_row([Y|T], Rest, Score).

slide_left_row(Row, NewRow, Score) :-
    remove_zeros(Row, NonZeros),
    merge_row(NonZeros, Merged, Score),
    length(Merged, L),
    PadLength is 4 - L,
    length(Pad, PadLength),
    maplist(=(0), Pad),
    append(Merged, Pad, NewRow).

slide_left_board([], [], 0).
slide_left_board([Row|Rest], [NewRow|NewRest], Score) :-
    slide_left_row(Row, NewRow, S1),
    slide_left_board(Rest, NewRest, S2),
    Score is S1 + S2.

slide_right_board(Board, NewBoard, Score) :-
    maplist(reverse, Board, RevBoard),
    slide_left_board(RevBoard, RevNew, Score),
    maplist(reverse, RevNew, NewBoard).

slide_up_board(Board, NewBoard, Score) :-
    transpose(Board, Transposed),
    slide_left_board(Transposed, TransNew, Score),
    transpose(TransNew, NewBoard).

slide_down_board(Board, NewBoard, Score) :-
    transpose(Board, Transposed),
    slide_right_board(Transposed, TransNew, Score),
    transpose(TransNew, NewBoard).

slide_board(left, Board, NewBoard, Score) :- slide_left_board(Board, NewBoard, Score).
slide_board(right, Board, NewBoard, Score) :- slide_right_board(Board, NewBoard, Score).
slide_board(up, Board, NewBoard, Score) :- slide_up_board(Board, NewBoard, Score).
slide_board(down, Board, NewBoard, Score) :- slide_down_board(Board, NewBoard, Score).

% Spawning
spawn_tile(Board, NewBoard, SpawnIdx, SpawnVal) :-
    flatten(Board, Flat),
    findall(I, nth0(I, Flat, 0), EmptyIndices),
    ( EmptyIndices \= [] ->
        random_member(SpawnIdx, EmptyIndices),
        random(0, 10, R),
        ( R < 9 -> SpawnVal = 2 ; SpawnVal = 4 ),
        replace_nth0(Flat, SpawnIdx, SpawnVal, NewFlat),
        list_to_matrix(NewFlat, 4, NewBoard)
    ;   
        NewBoard = Board, SpawnIdx = -1, SpawnVal = 0
    ).

replace_nth0([_|T], 0, V, [V|T]) :- !.
replace_nth0([H|T], I, V, [H|R]) :-
    I > 0, I1 is I - 1,
    replace_nth0(T, I1, V, R).

list_to_matrix([], _, []).
list_to_matrix(List, Size, [Row|Matrix]) :-
    length(Row, Size),
    append(Row, Rest, List),
    list_to_matrix(Rest, Size, Matrix).

game_over(Board) :-
    flatten(Board, Flat),
    \+ member(0, Flat),
    \+ can_merge(Board).

can_merge(Board) :- slide_left_board(Board, B1, _), B1 \= Board, !.
can_merge(Board) :- slide_right_board(Board, B2, _), B2 \= Board, !.
can_merge(Board) :- slide_up_board(Board, B3, _), B3 \= Board, !.
can_merge(Board) :- slide_down_board(Board, B4, _), B4 \= Board, !.

% HTTP Handlers
route_new(Request) :-
    member(method(Method), Request),
    ( Method == options -> handle_options(Request)
    ; Method == post -> handle_new(Request)
    ; format('Status: 405~n~nMethod not allowed~n')
    ).

route_move(Request) :-
    member(method(Method), Request),
    ( Method == options -> handle_options(Request)
    ; Method == post -> handle_move(Request)
    ; format('Status: 405~n~nMethod not allowed~n')
    ).

handle_options(Request) :-
    cors_enable(Request, [methods([post, options])]),
    format('Content-type: text/plain~n~n').

handle_new(_Request) :-
    cors_enable,
    length(EmptyFlat, 16), maplist(=(0), EmptyFlat),
    list_to_matrix(EmptyFlat, 4, EmptyBoard),
    spawn_tile(EmptyBoard, B1, Idx1, Val1),
    spawn_tile(B1, B2, Idx2, Val2),
    flatten(B2, FlatFinal),
    reply_json_dict(_{success: true, board: FlatFinal, spawns: [_{index:Idx1, value:Val1}, _{index:Idx2, value:Val2}]}).

handle_move(Request) :-
    cors_enable,
    http_read_json_dict(Request, Dict),
    FlatBoard = Dict.board,
    DirectionStr = Dict.direction,
    atom_string(Direction, DirectionStr),
    
    list_to_matrix(FlatBoard, 4, Board),
    slide_board(Direction, Board, SlidBoard, Score),
    
    ( Board \= SlidBoard ->
        spawn_tile(SlidBoard, FinalBoard, SpawnIdx, SpawnVal),
        ( game_over(FinalBoard) -> GameOver = true ; GameOver = false ),
        flatten(FinalBoard, FlatFinal),
        reply_json_dict(_{success: true, 
                          changed: true,
                          board: FlatFinal, 
                          score: Score, 
                          spawn_idx: SpawnIdx, 
                          spawn_val: SpawnVal,
                          game_over: GameOver})
    ;   
        reply_json_dict(_{success: true, changed: false})
    ).

:- initialization(main, main).
main :-
    start_server(8083),
    format("2048 server running on http://localhost:8083~n"),
    thread_get_message(_).
