@echo off
title Prolog Arcade - Start All Servers
color 0A

echo ===============================================
echo   PROLOG ARCADE - A iniciar todos os servidores
echo ===============================================
echo.

echo [8080] Sudoku...
start "Sudoku :8080" cmd /k "title Sudoku :8080 && color 0B && swipl -s sudoku.pl"
timeout /t 1 /nobreak >nul

echo [8081] Star Battle...
start "Star Battle :8081" cmd /k "title Star Battle :8081 && color 0D && swipl -s star.pl"
timeout /t 1 /nobreak >nul

echo [8082] Minesweeper...
start "Minesweeper :8082" cmd /k "title Minesweeper :8082 && color 0E && swipl -s minesweeper.pl"
timeout /t 1 /nobreak >nul

echo [8083] 2048...
start "2048 :8083" cmd /k "title 2048 :8083 && color 06 && swipl -s 2048.pl"
timeout /t 1 /nobreak >nul

echo [8000] A servir games.html...
start "Games HTML :8000" cmd /k "title Games HTML :8000 && color 0A && swipl -s serve.pl"
timeout /t 2 /nobreak >nul

echo.
echo ===============================================
echo   A abrir o browser em http://localhost:8000/games.html
echo ===============================================
start "" "http://localhost:8000/games.html"

timeout /t 2 /nobreak >nul
exit
