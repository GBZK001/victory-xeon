@echo off
setlocal
rem Fork Xeon/NVIDIA (sem ReBAR) do P1nkman/VIctory - iniciador de exemplo.
rem Uso: jogar-xeon.cmd [luz|turbo|padrao|traduzir]   (padrao deste PC: luz)
rem Antes: compile (cargo build --release -p victory), copie o Agility SDK do D3D12 para a pasta D3D12
rem ao lado do repositorio (Windows 10) e TROQUE a linha JOGO abaixo pela pasta da SUA copia do jogo.

rem >>> TROQUE pela pasta da sua copia (a que tem o executavel do jogo) <<<
set "JOGO=C:\caminho\da\sua\copia"

set "EXE=%~dp0..\target\release\victory.exe"
rem dados (cache, saves, logs) ao lado do repositorio
set "DADOS=%~dp0..\dados"
rem Agility SDK do D3D12 (Shader Model 6.6 no Windows 10)
set "VICTORY_D3D12_DIR=%~dp0..\D3D12"
rem controle virtual (arquivo de texto com o estado do controle; veja o README)
set "VICTORY_VIRTUAL_PAD=%~dp0..\pad.txt"
set "VICTORY_GAME_DIR=%JOGO%"
set "VICTORY_CACHE_DIR=%DADOS%\cache"
set "VICTORY_DATA_DIR=%DADOS%\data"
set "VICTORY_LOG=warn,victory_gpu::host=info,victory_gpu::copystat=info,victory_gpu::watch=info,victory_gpu::port=info,victory_hle::modules::xmem=info,victory_gpu::texback=info,victory_gpu::ambient=info"
set "MODO=%~1"
rem padrao deste PC: luz (NVIDIA nao roda a luz por ray tracing; sem isso as sombras ficam pretas)
if "%MODO%"=="" set "MODO=luz"
if /i "%MODO%"=="traduzir" goto traduzir
rem chaves do soldsawn (scripts\play-nvidia-8gb.ps1)
rem (sem VICTORY_RESOLUTION: o remendo de resolucao deixa a imagem num canto da janela; o modo rapido reduz pelo perfil Series S)
rem 1 (era 0): cada textura ocupa 1/4 da memoria; com 0, 5.700-7.200 texturas ficavam
rem esperando vaga na placa (pele e roupas pretas). 94: texturas podem usar ate 94% da placa
set "VICTORY_TEXTURE_DROP_MIPS=1"
set "VICTORY_TEXTURE_ROOM_PERCENT=94"
set "VICTORY_TEXTURE_STAGE_MB=96"
set "VICTORY_ASYNC_SUBMIT=1"
set "VICTORY_VIEW_KNOWN=1"
rem o driver nao recompila programas em segundo plano (perfil c14: 4 threads de 60-95% de um nucleo)
set "VICTORY_D3D12_BACKGROUND=0"
rem threads auxiliares (copias/comparacoes) e montadores de pipeline: ajustar ao Xeon
if not defined VICTORY_WIDE_THREADS set "VICTORY_WIDE_THREADS=12"
if not defined VICTORY_PIPELINE_THREADS set "VICTORY_PIPELINE_THREADS=12"
rem c13: sem bloqueio fixo. Agua (5dc3, 6f22) e luz das particulas (2561, c06a) saem da forma "em pares"
rem (blocos escuros no mar, chuva preta); as sombras ficam em pares (na forma aproximada viram blocos)
set "VICTORY_WAVE_PAIRS_OFF=5dc3b25986622949,6f225b641c5b0708,2561af9577c47289,c06aa62112ffba4c"
rem a agua (5dc3, 6f22) fora da forma em pares pede ondas de 64 e escurece o mar: fica de fora desde a partida
rem skinning so do ray tracing (30 CSComputeSkinning*): sem ray tracing nada le o que eles escrevem (edsuuu ab4571df)
set "VICTORY_DENY_SHADERS=5dc3b25986622949,6f225b641c5b0708,b8e420aac4197681,f16876929fa64f9f,4518151afe8c6c09,77edaab306206e9a,9ffcaff533995118,75bd00da58a1615c,90a0692af4320129,d3022ba8427bc72c,904e7a51e3fab26c,60b09004fef7f2f1,96d1ef386a0ddcfb,3cf39f4495b908d0,cd34b8dd52ee5c0c,d28b4922384831fe,9db486cee396e315,822e62ded676ef45,82a2ad6d07417d36,c7213dc64c67638b,ca2c77616107b128,c968414adaaeb93d,878933b499cfa14d,71ab19b0a4669299,023439f44041b689,cb90a66c7fe122aa,827b309e779552d7,b5a672a450b321e2,8f9eb68d0c6dd5cf,dd24ff46af3ae6ee,c7aef9c89f12051f,e06a21f3cea46973"
rem bloqueio ao vivo: hashes neste arquivo ficam de fora enquanto o jogo roda
set "VICTORY_DENY_FILE=%~dp0..\negar.txt"
set "VICTORY_COPY_PLAIN=1"
set "VICTORY_INDIRECT_GATHER=1"
set "VICTORY_HEAP_WORKER=1"
set "VICTORY_ALIAS_ONCE=1"
set "VICTORY_JOIN_PARTS=1"
set "VICTORY_BACK_OWN_VIEW=1"
set "VICTORY_INDIRECT_WINDOW_DRAWS=1"
set "VICTORY_GUARD_HOLES_FRAME=1"
set "VICTORY_COPY_CHANGED=1"
set "VICTORY_CARD_WINDOWS_MB=2048"
set "VICTORY_CARD_BUFFERS_MB=1024"
set "VICTORY_CLAMP_WAITS=0"
set "VICTORY_WIDE_MERGE=1"
set "VICTORY_RELAY_OWN_QUEUE=1"
rem processador Intel: a espera monitorx/mwaitx do jogo dorme em vez de girar em excecoes
rem (libera uma thread inteira da CPU para a thread que alimenta a placa)
set "VICTORY_MWAITX_SLEEP=1"
rem consulta write-watch uma vez por quadro (medido no Xeon: 54 ms/quadro em 2.196 consultas)
set "VICTORY_ASK_PER_FRAME=1"
rem janelas de memoria do jogo fora de buffers usadas no lugar, sem copia (nivel 1)
rem INPLACE desligado: no victory-laptop-8gb causou reset da placa (0x887A0005)
rem ligado: a placa le a memoria do jogo direto pelo PCIe (sem copia nem exame na CPU)
set "VICTORY_INPLACE=1"
rem remendo 1 do avatarmanz: heap de constantes do jogo lido pela placa no lugar, sem copia
set "VICTORY_PORT_CONSTANTS=1"
rem reserva dinamica de descritores maior (NVIDIA): sem ela desenhos sumiam no Series S
set "VICTORY_DYNAMIC_SLOTS=524288"
rem medido no README.soldsawn: 104 -> 97 ms por quadro junto com INDIRECT_GATHER
set "VICTORY_CARD_REHASH_RUNS=1"
rem agua: copia de volta das texturas (4 formatos)
set "VICTORY_TEXTURE_BACK=1"
rem perfil Series S: menos memoria para o jogo (PC no limite de RAM) e ~5 ms a menos de CPU
set "CONSOLE=series-s"
rem otimizacoes do turbo (todos os modos menos padrao)
if /i not "%MODO%"=="padrao" (
  rem desligado: nivel de textura sem memoria na placa e lido como zero (pele, roupa e objetos piscando pretos)
  set "VICTORY_LEVELS_ON_DEMAND=0"
  set "VICTORY_CARD_WINDOWS_MB=3072"
  set "VICTORY_CARD_BUFFERS_MIN_KB=64"
  set "VICTORY_CARD_BUFFERS_MB=1280"
  set "VICTORY_SKIP_WC_COMPARE=1"
  set "VICTORY_WIDE_TEXTURES=1"
)
if /i "%MODO%"=="luz" (
  set "VICTORY_AMBIENT=0.6"
) else if /i "%MODO%"=="rapido" (
  set "CONSOLE=series-s"
) else if /i "%MODO%"=="8gb" (
  rem 8 GB de VRAM e 16 GB de RAM: o perfil Series S da ao jogo menos memoria
  set "CONSOLE=series-s"
  set "VICTORY_TEXTURE_DROP_MIPS=2"
  set "VICTORY_CARD_WINDOWS_MB=2048"
  set "VICTORY_CARD_BUFFERS_MB=1024"
) else if /i "%MODO%"=="leve" (
  set "VICTORY_TEXTURE_DROP_MIPS=2"
  rem placas de 8 GB: a memoria da placa do soldsawn para 8 GB
  set "VICTORY_CARD_WINDOWS_MB=2048"
  set "VICTORY_CARD_BUFFERS_MB=1024"
) else if /i not "%MODO%"=="padrao" if /i not "%MODO%"=="turbo" (
  echo Modo desconhecido: %MODO%. Use turbo, padrao, luz, rapido, leve, 8gb ou traduzir. & pause & exit /b 1
)
if not exist "%EXE%" (echo Programa nao encontrado: %EXE% & echo Compile antes: veja o README. & pause & exit /b 1)
if not exist "%JOGO%\game_scarlett_master.exe" (echo Jogo nao encontrado em %JOGO%. Edite a linha JOGO deste arquivo. & pause & exit /b 1)
if not exist "%VICTORY_DATA_DIR%" mkdir "%VICTORY_DATA_DIR%"
rem copia de seguranca dos saves antes de cada execucao
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "AGORA=%%t"
if exist "%VICTORY_DATA_DIR%\7952987A\saves" robocopy "%VICTORY_DATA_DIR%\7952987A\saves" "%DADOS%\backup-saves\%AGORA%" /E /NFL /NDL /NJH /NJS /NP >nul
set "N=1"
:proximo
if not exist "%DADOS%\logs" mkdir "%DADOS%\logs"
if exist "%DADOS%\logs\p1nkman-%MODO%-%N%.log" (set /a N+=1 & goto proximo)
echo P1nkman VI - modo %MODO% (perfil %CONSOLE%)
echo Copia dos saves: %DADOS%\backup-saves\%AGORA%
echo Log: %DADOS%\logs\p1nkman-%MODO%-%N%.log
"%EXE%" run "%JOGO%\game_scarlett_master.exe" --execute --console %CONSOLE% > "%DADOS%\logs\p1nkman-%MODO%-%N%.log" 2>&1
echo P1nkman encerrado. Codigo: %errorlevel%.
pause
exit /b 0
:traduzir
set "VICTORY_HOST_WAVE=32"
set "VICTORY_VIEW_LIMIT=999999"
if not exist "%DADOS%\logs" mkdir "%DADOS%\logs"
echo Pre-traduzindo todos os shaders para o cache do P1nkman (alguns minutos)...
"%EXE%" translate --warm all > "%DADOS%\logs\p1nkman-traduzir.log" 2>&1
echo Fim. Codigo: %errorlevel%.
pause
