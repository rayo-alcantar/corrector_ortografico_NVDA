@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ===========================
REM Config hardcodeada
REM ===========================
set "REPO_OWNER=rayo-alcantar"
set "REPO_NAME=corrector_ortografico_NVDA"
set "REPO=%REPO_OWNER%/%REPO_NAME%"
set "SCONS_CMD=scons"

REM ===========================
REM Helpers
REM ===========================
where git >nul 2>&1 || (echo ERROR: git no esta en PATH.& exit /b 1)
where gh  >nul 2>&1 || (echo ERROR: gh (GitHub CLI) no esta en PATH.& exit /b 1)
where %SCONS_CMD% >nul 2>&1 || (echo ERROR: %SCONS_CMD% no esta en PATH.& exit /b 1)

REM ===========================
REM 1) Pedir version
REM ===========================
set "VERSION="
set /p VERSION=Introduce el numero de version/tag (ej: 2026.2.13): 
if "%VERSION%"=="" (
  echo ERROR: Version vacia.
  exit /b 1
)

REM ===========================
REM 2) Build con scons
REM ===========================
echo.
echo ===== Ejecutando build: %SCONS_CMD% =====
%SCONS_CMD%
if errorlevel 1 (
  echo ERROR: scons fallo.
  exit /b 1
)

REM ===========================
REM 3) Detectar .nvda-addon (elige el mas reciente)
REM ===========================
set "ADDON_FILE="
for /f "delims=" %%F in ('dir /b /a:-d /o:-d "*.nvda-addon" 2^>nul') do (
  set "ADDON_FILE=%%F"
  goto :foundAddon
)

:foundAddon
if "%ADDON_FILE%"=="" (
  echo ERROR: No se encontro ningun archivo .nvda-addon en:
  echo %CD%
  exit /b 1
)

echo.
echo Addon detectado: "%ADDON_FILE%"

REM ===========================
REM 4) Git: add, commit, tag, push
REM ===========================
echo.
echo ===== Git add/commit/tag/push =====
git add -A
if errorlevel 1 (
  echo ERROR: git add fallo.
  exit /b 1
)

REM commit solo si hay cambios
git diff --cached --quiet
if not errorlevel 1 (
  echo No hay cambios para commit. Continuo con tag/release de todas formas...
) else (
  git commit -m "Release %VERSION%"
  if errorlevel 1 (
    echo ERROR: commit fallo.
    exit /b 1
  )
)

REM Crear tag (si ya existe, aborta)
git tag "%VERSION%" >nul 2>&1
if not errorlevel 1 (
  echo ERROR: El tag "%VERSION%" ya existe localmente.
  exit /b 1
)
git tag "%VERSION%"
if errorlevel 1 (
  echo ERROR: No se pudo crear el tag.
  exit /b 1
)

git push
if errorlevel 1 (
  echo ERROR: git push fallo.
  exit /b 1
)

git push origin "%VERSION%"
if errorlevel 1 (
  echo ERROR: git push del tag fallo.
  exit /b 1
)

REM ===========================
REM 5) GitHub Release: crear y subir asset
REM ===========================
echo.
echo ===== Creando release en GitHub y subiendo asset =====

REM Si ya existe la release, solo sube/reemplaza asset.
gh release view "%VERSION%" --repo "%REPO%" >nul 2>&1
if errorlevel 1 (
  gh release create "%VERSION%" "%ADDON_FILE%" --repo "%REPO%" --title "%VERSION%" --notes "Release %VERSION%"
  if errorlevel 1 (
    echo ERROR: No se pudo crear la release/subir el asset.
    exit /b 1
  )
) else (
  gh release upload "%VERSION%" "%ADDON_FILE%" --repo "%REPO%" --clobber
  if errorlevel 1 (
    echo ERROR: No se pudo subir/reemplazar el asset.
    exit /b 1
  )
)

echo.
echo ===========================
echo OK: Publicado %VERSION%
echo Repo: %REPO%
echo Asset: %ADDON_FILE%
echo ===========================
endlocal
pause
