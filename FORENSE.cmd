@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Forense - analisis de imagenes

set "BASE=%~dp0"
set "BASE=%BASE:~0,-1%"
set "DISTRO=Ubuntu-24.04"
set "PY_LOC=/root/venvs/localizacion/bin/python"
set "AID=/root/venvs/aidetector/bin/aidetect"
set "C2PA=%BASE%\c2patool\c2patool\c2patool.exe"
set "CASOS=%BASE%\casos"
set "GUIA=%BASE%\interfaz\GUIA.txt"
set "CASO="
set "CDIR="
set "VACIO=0"
if not exist "%CASOS%" mkdir "%CASOS%"

:menu
cls
echo ===================================================================
echo   FORENSE - analisis de imagenes            (G = guia de buen uso)
echo ===================================================================
if defined CASO (echo   Caso activo: %CASO%) else (echo   Caso activo: ninguno - empeza por la opcion 1)
echo -------------------------------------------------------------------
echo   PREPARAR
echo    1  Crear o abrir caso
echo    2  Agregar evidencia  (original - hash SHA-256 - copia de trabajo)
echo   RAPIDO
echo    3  Metadatos (ExifTool)
echo    4  Procedencia C2PA (c2patool)
echo   LOCALIZAR MANIPULACION                      (cerra Docker antes)
echo    5  TruFor enmascarado - ignora logos         ~2 min por imagen
echo    6  TruFor oficial - mapa + confianza + score ~1 min por imagen
echo    7  CAT-Net - compresion JPEG (solo .jpg)
echo   GENERADA POR IA
echo    8  Detector de IA (ultra + sentry)
echo   CERRAR
echo    9  Verificar integridad (hashes)
echo    A  Abrir carpeta del caso
echo    G  Guia de buen uso
echo    0  Salir
echo -------------------------------------------------------------------
echo   Se analiza siempre la COPIA de trabajo, nunca el original.
echo ===================================================================
set "OP="
set /p "OP=Opcion: "
if defined OP set "OP=%OP:"=%"
rem sin consola (entrada agotada) set /p devuelve vacio para siempre: cortar en vez de repetir el menu
if not defined OP (set /a VACIO+=1) else (set "VACIO=0")
if %VACIO% gtr 30 exit /b 1
if "%OP%"=="1" goto caso
if "%OP%"=="2" goto evidencia
if "%OP%"=="3" goto metadatos
if "%OP%"=="4" goto c2pa
if "%OP%"=="5" goto trufor_mask
if "%OP%"=="6" goto trufor_of
if "%OP%"=="7" goto catnet
if "%OP%"=="8" goto ia
if "%OP%"=="9" goto verificar
if /i "%OP%"=="A" goto abrir
if /i "%OP%"=="G" goto guia
if "%OP%"=="0" exit /b 0
goto menu

rem ================================================================ casos
:caso
echo.
echo Casos existentes:
dir /b /ad "%CASOS%" 2>nul || echo   (ninguno)
echo.
set "N="
set /p "N=Nombre del caso (letras, numeros, - y _; Enter = volver): "
if not defined N goto menu
set "N=%N:"=%"
rem validacion en PowerShell: lee la variable de entorno, sin que cmd interprete & | > en el texto
powershell -NoProfile -Command "exit [int](-not ($env:N -cmatch '^[A-Za-z0-9_-]{1,60}$'))" <nul
if errorlevel 1 (echo Nombre invalido: usa solo letras, numeros, - y _. & pause & goto menu)
set "CASO=%N%"
set "CDIR=%CASOS%\%N%"
if exist "%CDIR%" (
  echo Caso abierto: %CASO%
) else (
  mkdir "%CDIR%\original" "%CDIR%\trabajo" "%CDIR%\resultados"
  >"%CDIR%\hashes.txt" echo # SHA256^|archivo^|ingreso^|origen
  call :log "Caso creado"
  echo Caso creado: %CDIR%
)
call :log "Caso abierto"
pause
goto menu

rem ============================================================ evidencia
:evidencia
if not defined CASO goto sin_caso
echo.
echo Usa la descarga ORIGINAL del sitio, nunca una miniatura ni una captura.
echo Si paso por WhatsApp o redes, las trazas de manipulacion se degradan.
echo.
set "SRC="
set /p "SRC=Arrastra el archivo a esta ventana y Enter (Enter = volver): "
if not defined SRC goto menu
set "SRC=%SRC:"=%"
rem shortcut: una ruta con & o %% rompe las lineas de cmd que la usan; si aparece, renombrar el archivo antes de ingresarlo
if exist "%SRC%\*" (echo Es una carpeta: agrega los archivos de a uno. & pause & goto menu)
if not exist "%SRC%" (echo No existe: %SRC% & pause & goto menu)
for %%F in ("%SRC%") do set "FN=%%~nxF"
if exist "%CDIR%\original\%FN%" (echo Ya hay un original con ese nombre en el caso. & pause & goto menu)

call :sha "%SRC%" H_SRC
copy /b "%SRC%" "%CDIR%\original\%FN%" >nul || (echo No se pudo copiar. & pause & goto menu)
call :sha "%CDIR%\original\%FN%" H_ORI
if /i not "%H_SRC%"=="%H_ORI%" (
  call :log "ERROR copia de %FN% no coincide con el origen"
  echo ERROR: la copia no coincide con el origen. No uses esta evidencia.
  pause
  goto menu
)
attrib +R "%CDIR%\original\%FN%"
copy /b "%CDIR%\original\%FN%" "%CDIR%\trabajo\%FN%" >nul
attrib -R "%CDIR%\trabajo\%FN%"
call :sha "%CDIR%\trabajo\%FN%" H_TRA
>>"%CDIR%\hashes.txt" echo %H_ORI%^|%FN%^|%date% %time%^|%SRC%
call :log "Evidencia %FN% ingresada SHA256=%H_ORI% origen=%SRC%"
echo.
echo   Archivo : %FN%
echo   SHA-256 : %H_ORI%
echo   Original en solo lectura, copia de trabajo creada (hash identico: %H_TRA%).
echo   Anota el SHA-256 en tu informe.
pause
goto menu

rem ============================================================ metadatos
:metadatos
call :need || goto menu
where exiftool >nul 2>&1 || (echo No encuentro exiftool. Cerra y reabri esta ventana o reinstalalo: winget install -e --id OliverBetz.ExifTool & pause & goto menu)
set "OUT=%CDIR%\resultados\metadatos"
if not exist "%OUT%" mkdir "%OUT%"
call :log "Metadatos ExifTool inicio"
for %%F in ("%CDIR%\trabajo\*") do (
  exiftool -a -u -G1 -s "%%F" >"%OUT%\%%~nxF.txt" 2>&1
  echo.
  echo === %%~nxF
  findstr /i /c:"DateTimeOriginal" /c:"CreateDate" /c:"ModifyDate" /c:" Make " /c:" Model " /c:"Software" /c:"GPSLatitude " /c:"GPSLongitude " /c:"ImageSize" /c:"Comment" "%OUT%\%%~nxF.txt"
)
call :log "Metadatos ExifTool fin"
echo.
echo COMO LEERLO: los metadatos se editan facilmente. Que falten no prueba
echo manipulacion (las redes los borran); que esten no prueba autenticidad.
echo Fijate si Software, fechas y camara son coherentes con la historia.
echo Detalle completo en: %OUT%
pause
goto menu

rem ================================================================= c2pa
:c2pa
call :need || goto menu
set "OUT=%CDIR%\resultados\c2pa"
if not exist "%OUT%" mkdir "%OUT%"
call :log "C2PA inicio"
for %%F in ("%CDIR%\trabajo\*") do (
  "%C2PA%" "%%F" --detailed >"%OUT%\%%~nxF.json" 2>&1 && (echo   %%~nxF: TIENE credenciales C2PA - revisa %%~nxF.json) || (echo   %%~nxF: sin credenciales C2PA)
)
call :log "C2PA fin"
echo.
echo COMO LEERLO: sin credenciales no significa nada (casi nadie las usa).
echo Si las trae, revisa la cadena de ediciones, el software y quien firma.
pause
goto menu

rem ===================================================== TruFor enmascarado
:trufor_mask
call :need || goto menu
call :memcheck || goto menu
set "OUT=%CDIR%\resultados\trufor_enmascarado"
if not exist "%OUT%" mkdir "%OUT%"
call :wslp "%CDIR%\trabajo" IN_L
call :wslp "%OUT%" OUT_L
call :wslp "%BASE%\pesos\trufor.pth.tar" W_L
call :log "TruFor enmascarado (-idc) inicio"
echo Analizando... ~2 min por imagen. No cierres la ventana.
rem -cover None: sin esto usaria las mascaras de ejemplo del repo si un nombre coincide
wsl -d %DISTRO% -u root --cd "%BASE%\Masked-convolutions\TruFor" -e %PY_LOC% test.py -g -1 -w "%W_L%" -idc -cover None -in "%IN_L%" -out "%OUT_L%" <nul
call :log "TruFor enmascarado fin (codigo %errorlevel%)"
echo.
echo COMO LEERLO: el PNG muestra el mapa de anomalia (rojo = sospechoso)
echo con los logos y rotulos ya ignorados. Este modo NO da confianza ni score:
echo contrastalo con la opcion 6. El mapa marca lo mas raro de la escena,
echo no necesariamente lo pegado.
call :abrir_out
goto menu

rem ========================================================= TruFor oficial
:trufor_of
call :need || goto menu
call :memcheck || goto menu
set "OUT=%CDIR%\resultados\trufor_oficial"
if not exist "%OUT%" mkdir "%OUT%"
call :wslp "%CDIR%\trabajo" IN_L
call :wslp "%OUT%" OUT_L
call :wslp "%BASE%\pesos\trufor.pth.tar" W_L
call :wslp "%BASE%\interfaz\visor.py" VIS_L
call :log "TruFor oficial inicio"
echo Analizando... ~1 min por imagen. No cierres la ventana.
wsl -d %DISTRO% -u root --cd "%BASE%\TruFor\test_docker\src" -e %PY_LOC% trufor_test.py -gpu -1 -in "%IN_L%" -out "%OUT_L%" TEST.MODEL_FILE "%W_L%" <nul
call :log "TruFor oficial fin (codigo %errorlevel%)"
echo Generando imagenes de resultado...
wsl -d %DISTRO% -u root -e %PY_LOC% "%VIS_L%" "%OUT_L%" "%IN_L%" <nul
echo.
if exist "%OUT%\resumen_scores.txt" type "%OUT%\resumen_scores.txt"
echo.
echo COMO LEERLO: el score NO es "probabilidad de falsa"; usalo como ranking
echo entre imagenes del mismo caso. Mira el mapa SOLO donde la confianza es
echo clara: donde es negra, el mapa no vale.
call :abrir_out
goto menu

rem ================================================================ CAT-Net
:catnet
call :need || goto menu
if not exist "%BASE%\pesos\CAT_full_v2.pth.tar" (
  echo.
  echo Falta el peso de CAT-Net. Google Drive no deja bajarlo por script:
  echo   1. Abri https://drive.google.com/drive/folders/1hBEfnFtGG6q_srBHVEmbF3fTq0IhP8jq
  echo   2. Entra en "trained weight" y baja CAT_full_v2.pth.tar
  echo   3. Guardalo en %BASE%\pesos\
  pause
  goto menu
)
dir /b "%CDIR%\trabajo\*.jp*g" >nul 2>&1 ||(echo CAT-Net solo analiza JPEG y no hay ninguno en el caso. & pause & goto menu)
call :memcheck || goto menu
set "OUT=%CDIR%\resultados\catnet"
if not exist "%OUT%" mkdir "%OUT%"
call :wslp "%CDIR%\trabajo" IN_L
call :wslp "%OUT%" OUT_L
call :wslp "%BASE%\pesos\CAT_full_v2.pth.tar" W_L
call :log "CAT-Net inicio"
echo Analizando JPEG... No cierres la ventana.
wsl -d %DISTRO% -u root --cd "%BASE%\Masked-convolutions\CAT-Net" -e %PY_LOC% test.py -g -1 -w "%W_L%" -idc -cov None -in "%IN_L%/*.[jJ][pP]*[gG]" -out "%OUT_L%" <nul
call :log "CAT-Net fin (codigo %errorlevel%)"
echo.
echo COMO LEERLO: CAT-Net mira tablas de cuantizacion y doble compresion.
echo Una zona marcada sugiere un recorte que venia de otro JPEG. Si la foto
echo se recomprimio entera (redes, CDN) la senal se borra.
call :abrir_out
goto menu

rem ========================================================== Detector IA
:ia
call :need || goto menu
call :memcheck || goto menu
set "OUT=%CDIR%\resultados\ia"
if not exist "%OUT%" mkdir "%OUT%"
call :wslp "%CDIR%\trabajo" IN_L
call :wslp "%OUT%" OUT_L
call :log "Detector IA inicio"
rem HF_HUB_OFFLINE: los modelos ya estan en cache; nada sale a internet
echo --- Backend ultra
wsl -d %DISTRO% -u root -e env HF_HUB_OFFLINE=1 HF_HUB_DISABLE_TELEMETRY=1 %AID% detect "%IN_L%" --backend ultra --device cpu --csv "%OUT_L%/ultra.csv" <nul
echo --- Backend sentry-convnext-small
wsl -d %DISTRO% -u root -e env HF_HUB_OFFLINE=1 HF_HUB_DISABLE_TELEMETRY=1 %AID% detect "%IN_L%" --backend sentry-convnext-small --device cpu --csv "%OUT_L%/sentry.csv" <nul
call :log "Detector IA fin (codigo %errorlevel%)"
echo.
echo COMO LEERLO: entre 0,45 y 0,55 = evidencia debil. Si los dos backends
echo no coinciden, no hay conclusion. En la prueba de instalacion NINGUN
echo backend detecto la imagen IA de ejemplo: calibralo con material propio.
echo Si la imagen paso por redes sociales, desconfia del resultado.
call :abrir_out
goto menu

rem ============================================================ integridad
:verificar
if not defined CASO goto sin_caso
set "FALLAS=0"
set "TOTAL=0"
for /f "usebackq eol=# tokens=1,2 delims=|" %%a in ("%CDIR%\hashes.txt") do call :check "%%a" "%%b"
echo.
echo   %TOTAL% archivos revisados, %FALLAS% con diferencias.
call :log "Verificacion de integridad: %TOTAL% revisados, %FALLAS% fallas"
if not "%FALLAS%"=="0" echo   ATENCION: hay diferencias. Registralo y volve a copiar desde original\.
pause
goto menu

:check
set /a TOTAL+=1
call :sha "%CDIR%\original\%~2" H_O
call :sha "%CDIR%\trabajo\%~2" H_T
set "R=OK"
if /i not "%H_O%"=="%~1" set "R=FALLA original"
if /i not "%H_T%"=="%~1" set "R=FALLA copia de trabajo"
if not "%R%"=="OK" set /a FALLAS+=1
echo   [%R%] %~2
exit /b

rem ================================================================ varios
:abrir
if not defined CASO goto sin_caso
start "" "%CDIR%"
goto menu

:guia
cls
rem sin chcp: cambiar la pagina de codigos rompe set /p; PowerShell convierte el UTF-8 a la de la consola
powershell -NoProfile -Command "Get-Content -Encoding UTF8 -LiteralPath $env:GUIA" <nul
pause
goto menu

:sin_caso
echo Primero crea o abri un caso (opcion 1).
pause
goto menu

rem ----- subrutinas
:need
if not defined CASO (echo Primero crea o abri un caso - opcion 1. & pause & exit /b 1)
dir /b /a-d "%CDIR%\trabajo" >nul 2>&1 || (echo El caso no tiene evidencia todavia - opcion 2. & pause & exit /b 1)
exit /b 0

:memcheck
set "NCONT=0"
for /f %%c in ('docker ps -q 2^>nul ^| find /c /v ""') do set "NCONT=%%c"
if "%NCONT%"=="0" exit /b 0
echo.
echo AVISO: hay %NCONT% contenedores de Docker corriendo. Comparten la memoria
echo con los modelos y el analisis puede cortarse solo por falta de RAM.
choice /c SN /m "Seguir igual"
if errorlevel 2 exit /b 1
exit /b 0

:wslp
set "%~2="
for /f "usebackq delims=" %%p in (`wsl -d %DISTRO% -u root -e wslpath -a "%~1" ^<nul`) do set "%~2=%%p"
exit /b

:sha
set "%~2="
for /f "skip=1 delims=" %%h in ('certutil -hashfile "%~1" SHA256 ^<nul') do if not defined %~2 set "%~2=%%h"
exit /b

:abrir_out
choice /c SN /m "Abrir la carpeta de resultados"
if not errorlevel 2 start "" "%OUT%"
exit /b

:log
>>"%CDIR%\registro.txt" echo [%date% %time%] %USERNAME% - %~1
exit /b
