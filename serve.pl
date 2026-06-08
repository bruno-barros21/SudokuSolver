% serve.pl — serve games.html over HTTP on port 8000
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_cors)).

:- set_setting(http:cors, [*]).

:- http_handler(root(.), serve_root, [prefix]).

serve_root(Request) :-
    http_reply_from_files('.', [indexes(['games.html'])], Request).

:- initialization(main, main).
main :-
    http_server(http_dispatch, [port(8000)]),
    format("Games server running on http://localhost:8000/games.html~n"),
    thread_get_message(_).
