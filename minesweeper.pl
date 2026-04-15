:- use_module(library(clpfd)).

% Predicado principal que a vossa interface vai chamar
% Recebe uma lista de casas e resolve as variáveis ocultas.
resolver_minesweeper(Tabuleiro) :-
    % 1. Extrair todas as variáveis ocultas do tabuleiro
    extrair_variaveis(Tabuleiro, Vars),
    
    % 2. Definir o domínio: Cada variável só pode ser 0 (Seguro) ou 1 (Mina)
    Vars ins 0..1,
    
    % 3. Aplicar as equações matemáticas para cada casa revelada
    aplicar_regras(Tabuleiro, Tabuleiro),
    
    % 4. Procurar a solução: o Prolog tenta atribuir 0s e 1s que respeitem as regras
    labeling([ff], Vars).

% ---------------------------------------------------------
% PREDICADOS AUXILIARES
% ---------------------------------------------------------

% Filtra a lista do tabuleiro e guarda apenas os Valores que são variáveis (casas ocultas)
extrair_variaveis([], []).
extrair_variaveis([cell(_, _, V)|T], [V|VarsRestantes]) :-
    var(V), !, % Se V for uma variável livre (não é um número)
    extrair_variaveis(T, VarsRestantes).
extrair_variaveis([_|T], Vars) :-
    extrair_variaveis(T, Vars).

% Percorre o tabuleiro e cria uma equação para cada casa com um número
aplicar_regras([], _).
aplicar_regras([cell(X, Y, Valor)|T], TabuleiroCompleto) :-
    integer(Valor), !, % Se a casa tem um número revelado (ex: 1, 2, 3...)
    encontrar_vizinhos(X, Y, TabuleiroCompleto, Vizinhos),
    sum(Vizinhos, #=, Valor), % RESTRIÇÃO MÁGICA: A soma dos vizinhos TEM de ser igual ao Valor
    aplicar_regras(T, TabuleiroCompleto).
aplicar_regras([_|T], TabuleiroCompleto) :-
    % Ignora as casas ocultas nesta fase, só queremos aplicar regras onde há números
    aplicar_regras(T, TabuleiroCompleto).

% Encontra as variáveis ou números nas 8 casas à volta de uma coordenada (X,Y)
encontrar_vizinhos(X, Y, Tabuleiro, Vizinhos) :-
    findall(V, 
        (
            member(cell(NX, NY, V), Tabuleiro),
            abs(X - NX) =< 1, % O vizinho está à distância de 1 ou 0 no eixo X
            abs(Y - NY) =< 1, % O vizinho está à distância de 1 ou 0 no eixo Y
            (X \= NX ; Y \= NY) % Garantir que não estamos a contar a própria casa (X,Y)
        ), 
        Vizinhos).