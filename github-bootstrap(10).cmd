@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

rem ============================================================
rem Motion Prompt - GitHub one-click bootstrap / upload / deploy
rem Target: https://github.com/ko9ma7/motion-prompt
rem Place this file in the project root next to index.html.
rem ============================================================
set "GITHUB_OWNER=ko9ma7"
set "REPO_NAME=motion-prompt"
set "REPO_VISIBILITY=public"
set "DEFAULT_BRANCH=main"
set "WORKFLOW_FILE=deploy.yml"
set "INITIAL_TAG=v1.0.0"
set "COMMIT_MESSAGE=feat: publish Motion Prompt"
set "REPO_DESCRIPTION=Multilingual motion and sprite-sheet prompt builder for image generation"
set "REPO_URL=https://github.com/ko9ma7/motion-prompt"
set "REMOTE_URL=https://github.com/ko9ma7/motion-prompt.git"
set "PAGES_URL=https://ko9ma7.github.io/motion-prompt/"
set "REQUIRED_FAILED=0"
set "HAS_STATUS="
set "RUN_ID="

cls
echo ============================================================
echo [CHECK] Motion Prompt GitHub Bootstrap
echo [CHECK] Project    : %CD%
echo [CHECK] Repository : %REPO_URL%
echo [CHECK] Pages      : %PAGES_URL%
echo ============================================================
echo.

rem 0. Project root check
if not exist "index.html" (
  echo [ERROR] index.html was not found in this folder.
  echo [ERROR] Put github-bootstrap-fixed.cmd in the SAME folder as index.html.
  echo [ERROR] Current folder: %CD%
  goto :fatal
)
echo [OK] Project root detected.

rem 1. Git
call :ensure_git
if errorlevel 1 goto :fatal
for /f "delims=" %%V in ('git --version 2^>nul') do echo [OK] %%V

rem 2. GitHub CLI
call :ensure_gh
if errorlevel 1 goto :fatal
for /f "delims=" %%V in ('gh --version 2^>nul ^| findstr /b /c:"gh version"') do echo [OK] %%V

rem 3. GitHub auth
echo [CHECK] Checking GitHub login...
gh auth status >nul 2>&1
if errorlevel 1 (
  echo [WARN] GitHub CLI is not logged in.
  echo [CHECK] Starting browser login...
  gh auth login --hostname github.com --git-protocol https --web
  if errorlevel 1 (
    echo [ERROR] GitHub login failed.
    echo [ERROR] Recovery command: gh auth login --web
    goto :fatal
  )
)
gh auth setup-git >nul 2>&1
if errorlevel 1 echo [WARN] gh auth setup-git could not update Git credential settings.
for /f "usebackq delims=" %%U in (`gh api user --jq ".login" 2^>nul`) do set "GH_LOGIN=%%U"
for /f "usebackq delims=" %%I in (`gh api user --jq ".id" 2^>nul`) do set "GH_ID=%%I"
if not defined GH_LOGIN (
  echo [ERROR] Could not read the logged-in GitHub username.
  echo [ERROR] Recovery command: gh auth status
  goto :fatal
)
echo [OK] GitHub authentication is ready as !GH_LOGIN!.
if /i not "!GH_LOGIN!"=="%GITHUB_OWNER%" (
  echo [WARN] Logged in as !GH_LOGIN!, target owner is %GITHUB_OWNER%.
  echo [WARN] Continuing only if this account can write to %GITHUB_OWNER%/%REPO_NAME%.
)

rem 4. Git identity
echo [CHECK] Checking Git author identity...
for /f "usebackq delims=" %%N in (`git config --get user.name 2^>nul`) do set "GIT_NAME=%%N"
if not defined GIT_NAME (
  git config user.name "!GH_LOGIN!"
  set "GIT_NAME=!GH_LOGIN!"
)
for /f "usebackq delims=" %%E in (`git config --get user.email 2^>nul`) do set "GIT_EMAIL=%%E"
if not defined GIT_EMAIL (
  if defined GH_ID (
    set "GIT_EMAIL=!GH_ID!+!GH_LOGIN!@users.noreply.github.com"
  ) else (
    set "GIT_EMAIL=!GH_LOGIN!@users.noreply.github.com"
  )
  git config user.email "!GIT_EMAIL!"
)
echo [OK] Git user.name  = !GIT_NAME!
echo [OK] Git user.email = !GIT_EMAIL!

rem 5. Init repo
if not exist ".git" (
  echo [CHECK] Initializing local Git repository...
  git init
  if errorlevel 1 goto :fatal
  echo [OK] Local repository initialized.
) else (
  echo [OK] Local Git repository already exists.
)

git branch -M "%DEFAULT_BRANCH%" >nul 2>&1

rem 6. Verify/create GitHub repo
echo [CHECK] Checking GitHub repository...
gh repo view "%GITHUB_OWNER%/%REPO_NAME%" >nul 2>&1
if errorlevel 1 (
  echo [WARN] Repository does not exist. Creating it now...
  if /i "%REPO_VISIBILITY%"=="private" (
    gh repo create "%GITHUB_OWNER%/%REPO_NAME%" --private --description "%REPO_DESCRIPTION%"
  ) else (
    gh repo create "%GITHUB_OWNER%/%REPO_NAME%" --public --description "%REPO_DESCRIPTION%"
  )
  if errorlevel 1 (
    echo [ERROR] Repository creation failed.
    echo [ERROR] Recovery: gh repo create %GITHUB_OWNER%/%REPO_NAME% --%REPO_VISIBILITY%
    goto :fatal
  )
  echo [OK] Repository created.
) else (
  echo [OK] Repository already exists.
)

rem 7. Origin
set "CURRENT_ORIGIN="
for /f "delims=" %%R in ('git remote get-url origin 2^>nul') do set "CURRENT_ORIGIN=%%R"
if not defined CURRENT_ORIGIN (
  git remote add origin "%REMOTE_URL%"
  if errorlevel 1 goto :fatal
  echo [OK] origin added: %REMOTE_URL%
) else (
  if /i not "!CURRENT_ORIGIN!"=="%REMOTE_URL%" (
    echo [WARN] origin currently points to: !CURRENT_ORIGIN!
    git remote set-url origin "%REMOTE_URL%"
    if errorlevel 1 goto :fatal
  )
  echo [OK] origin = %REMOTE_URL%
)

rem 8. If local has no commit but remote main exists, base safely on remote main
git rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 (
  git ls-remote --exit-code --heads origin "%DEFAULT_BRANCH%" >nul 2>&1
  if not errorlevel 1 (
    echo [CHECK] Remote main exists. Fetching before first commit...
    git fetch origin "%DEFAULT_BRANCH%"
    if errorlevel 1 goto :fatal
    git reset --mixed "origin/%DEFAULT_BRANCH%"
    if errorlevel 1 goto :fatal
    echo [OK] Existing remote history loaded without deleting local files.
  )
)

rem 9. Validate required files only. Do NOT use node --check on ESM browser files.
echo [CHECK] Validating project files...
call :required "index.html"
call :required "styles.css"
call :required "app.js"
call :required "prompt-engine.js"
call :required "i18n.js"
call :required "README.md"
call :required ".github\workflows\deploy.yml"
if "%REQUIRED_FAILED%"=="1" goto :fatal

findstr /i /c:"type=\"module\"" index.html >nul 2>&1
if errorlevel 1 (
  echo [WARN] index.html does not appear to use script type="module".
  echo [WARN] If app.js uses import/export, make sure its script tag is type="module".
) else (
  echo [OK] ES module script mode detected in index.html.
)

echo [OK] Required project files are present.

rem 10. Optional Node syntax validation using temporary package.json to force ESM parsing
where node >nul 2>&1
if not errorlevel 1 (
  echo [CHECK] Running safe ES module syntax checks...
  if exist "package.json" (
    echo [CHECK] Existing package.json detected; skipping temporary ESM package creation.
    node --check "prompt-engine.js" >nul 2>&1
    if errorlevel 1 echo [WARN] Node syntax check skipped or incompatible with project package settings.
  ) else (
    >".__bootstrap_package.json.tmp" echo {"type":"module"}
    move /y ".__bootstrap_package.json.tmp" "package.json" >nul
    node --check "app.js"
    if errorlevel 1 goto :js_cleanup_error
    node --check "prompt-engine.js"
    if errorlevel 1 goto :js_cleanup_error
    node --check "i18n.js"
    if errorlevel 1 goto :js_cleanup_error
    del /q "package.json" >nul 2>&1
    echo [OK] ES module syntax checks passed.
  )
) else (
  echo [WARN] Node.js not found. This static project can still be uploaded and deployed.
)

rem 11. Stage + commit
echo [CHECK] Staging ALL files...
git add -A
if errorlevel 1 goto :fatal
for /f "delims=" %%C in ('git status --short 2^>nul') do set "HAS_STATUS=1"
if defined HAS_STATUS (
  echo [CHECK] Creating commit...
  git commit -m "%COMMIT_MESSAGE%"
  if errorlevel 1 (
    echo [ERROR] Commit failed.
    echo [ERROR] Recovery: git status ^& git add -A ^& git commit -m "%COMMIT_MESSAGE%"
    goto :fatal
  )
  echo [OK] Commit created.
) else (
  git rev-parse --verify HEAD >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] No files to commit and no existing commit found.
    goto :fatal
  )
  echo [OK] No new changes to commit.
)

git branch -M "%DEFAULT_BRANCH%"
if errorlevel 1 goto :fatal

rem 12. Push, with safe retry if remote moved
echo [CHECK] Uploading files to GitHub...
git push -u origin "%DEFAULT_BRANCH%"
if errorlevel 1 (
  echo [WARN] First push failed. Synchronizing with remote main...
  git fetch origin "%DEFAULT_BRANCH%"
  if errorlevel 1 goto :fatal
  git merge "origin/%DEFAULT_BRANCH%" --allow-unrelated-histories -X ours --no-edit
  if errorlevel 1 (
    echo [ERROR] Automatic merge failed. No force-push attempted.
    echo [ERROR] Recovery:
    echo         git merge --abort
    echo         git pull origin %DEFAULT_BRANCH% --allow-unrelated-histories
    echo         git push -u origin %DEFAULT_BRANCH%
    goto :fatal
  )
  git push -u origin "%DEFAULT_BRANCH%"
  if errorlevel 1 goto :fatal
)
echo [OK] Project files uploaded to GitHub.

rem 13. Metadata
echo [CHECK] Applying repository metadata...
gh repo edit "%GITHUB_OWNER%/%REPO_NAME%" --description "%REPO_DESCRIPTION%" --homepage "%PAGES_URL%" >nul 2>&1
if errorlevel 1 (
  echo [WARN] Description/homepage update skipped.
) else (
  echo [OK] Description and homepage updated.
)

gh repo edit "%GITHUB_OWNER%/%REPO_NAME%" --add-topic prompt-engineering --add-topic sprite-sheet --add-topic animation --add-topic image-generation --add-topic github-pages --add-topic javascript --add-topic i18n >nul 2>&1
if errorlevel 1 (
  echo [WARN] Some topics could not be updated.
) else (
  echo [OK] Repository topics updated.
)

rem 14. Pages via Actions
echo [CHECK] Configuring GitHub Pages...
gh api "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" >nul 2>&1
if errorlevel 1 (
  gh api --method POST "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" -f build_type=workflow >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Pages API setup failed.
    echo [WARN] Open: %REPO_URL%/settings/pages
    echo [WARN] Set Source to GitHub Actions.
  ) else (
    echo [OK] GitHub Pages enabled for Actions.
  )
) else (
  gh api --method PUT "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" -f build_type=workflow >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Existing Pages site could not be switched automatically.
  ) else (
    echo [OK] GitHub Pages is configured for Actions.
  )
)

rem 15. Find current workflow run; dispatch if none
echo [CHECK] Looking for deployment workflow...
timeout /t 3 /nobreak >nul
for /f "usebackq delims=" %%I in (`gh run list --repo "%GITHUB_OWNER%/%REPO_NAME%" --workflow "%WORKFLOW_FILE%" --branch "%DEFAULT_BRANCH%" --limit 1 --json databaseId --jq ".[0].databaseId" 2^>nul`) do set "RUN_ID=%%I"
if not defined RUN_ID (
  echo [CHECK] No run found. Dispatching deploy workflow...
  gh workflow run "%WORKFLOW_FILE%" --repo "%GITHUB_OWNER%/%REPO_NAME%" --ref "%DEFAULT_BRANCH%" >nul 2>&1
  timeout /t 3 /nobreak >nul
  for /f "usebackq delims=" %%I in (`gh run list --repo "%GITHUB_OWNER%/%REPO_NAME%" --workflow "%WORKFLOW_FILE%" --branch "%DEFAULT_BRANCH%" --limit 1 --json databaseId --jq ".[0].databaseId" 2^>nul`) do set "RUN_ID=%%I"
)
if defined RUN_ID (
  echo [CHECK] Waiting for GitHub Actions run !RUN_ID! ...
  gh run watch !RUN_ID! --repo "%GITHUB_OWNER%/%REPO_NAME%" --exit-status --compact
  if errorlevel 1 (
    echo [WARN] Deployment workflow failed or was cancelled.
    echo [WARN] Upload itself succeeded.
    echo [WARN] Inspect: gh run view !RUN_ID! -R %GITHUB_OWNER%/%REPO_NAME% --log-failed
  ) else (
    echo [OK] GitHub Pages deployment completed.
  )
) else (
  echo [WARN] Could not locate a workflow run yet.
  echo [WARN] Check: %REPO_URL%/actions
)

rem 16. Tag/release, idempotent
echo [CHECK] Checking initial tag %INITIAL_TAG%...
git rev-parse "%INITIAL_TAG%" >nul 2>&1
if errorlevel 1 (
  git tag -a "%INITIAL_TAG%" -m "Motion Prompt %INITIAL_TAG%"
  if not errorlevel 1 echo [OK] Local tag created.
) else (
  echo [OK] Local tag already exists.
)

git ls-remote --exit-code --tags origin "refs/tags/%INITIAL_TAG%" >nul 2>&1
if errorlevel 1 (
  git push origin "%INITIAL_TAG%" >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Could not push tag %INITIAL_TAG%.
  ) else (
    echo [OK] Tag %INITIAL_TAG% pushed.
  )
) else (
  echo [OK] Remote tag already exists.
)

gh release view "%INITIAL_TAG%" --repo "%GITHUB_OWNER%/%REPO_NAME%" >nul 2>&1
if errorlevel 1 (
  gh release create "%INITIAL_TAG%" --repo "%GITHUB_OWNER%/%REPO_NAME%" --title "%INITIAL_TAG%" --generate-notes >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Release creation skipped or failed; Pages is unaffected.
  ) else (
    echo [OK] GitHub Release created.
  )
) else (
  echo [OK] GitHub Release already exists.
)

rem 17. Final URL
set "DEPLOYED_URL=%PAGES_URL%"
for /f "usebackq delims=" %%P in (`gh api "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" --jq ".html_url" 2^>nul`) do set "DEPLOYED_URL=%%P"
echo.
echo ============================================================
echo [OK] BOOTSTRAP COMPLETE
echo [OK] Repository : %REPO_URL%
echo [OK] Pages      : !DEPLOYED_URL!
echo [OK] Actions    : %REPO_URL%/actions
echo ============================================================
echo.
echo Press any key to open the repository and close this window.
pause >nul
start "" "%REPO_URL%" >nul 2>&1
exit /b 0

:required
if not exist "%~1" (
  echo [ERROR] Missing required file: %~1
  set "REQUIRED_FAILED=1"
  exit /b 0
)
echo [OK] Found %~1
exit /b 0

:ensure_git
where git >nul 2>&1
if not errorlevel 1 exit /b 0
echo [WARN] Git is not installed or not in PATH.
where winget >nul 2>&1
if errorlevel 1 (
  echo [ERROR] winget unavailable. Install Git manually, then rerun.
  exit /b 1
)
echo [CHECK] Installing Git with winget...
winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
if errorlevel 1 exit /b 1
if exist "%ProgramFiles%\Git\cmd" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
where git >nul 2>&1
if errorlevel 1 (
  echo [WARN] Git installed, but this terminal cannot see the new PATH yet.
  echo [WARN] Close this window and rerun this CMD.
  exit /b 1
)
exit /b 0

:ensure_gh
where gh >nul 2>&1
if not errorlevel 1 exit /b 0
echo [WARN] GitHub CLI is not installed or not in PATH.
where winget >nul 2>&1
if errorlevel 1 (
  echo [ERROR] winget unavailable. Install GitHub CLI manually, then rerun.
  exit /b 1
)
echo [CHECK] Installing GitHub CLI with winget...
winget install --id GitHub.cli -e --source winget --accept-source-agreements --accept-package-agreements
if errorlevel 1 exit /b 1
if exist "%ProgramFiles%\GitHub CLI" set "PATH=%ProgramFiles%\GitHub CLI;%PATH%"
where gh >nul 2>&1
if errorlevel 1 (
  echo [WARN] GitHub CLI installed, but this terminal cannot see the new PATH yet.
  echo [WARN] Close this window and rerun this CMD.
  exit /b 1
)
exit /b 0

:js_cleanup_error
if exist "package.json" del /q "package.json" >nul 2>&1
echo [ERROR] JavaScript ES module syntax validation failed.
echo [ERROR] Fix the file reported by Node, then rerun.
goto :fatal

:fatal
if exist ".__bootstrap_package.json.tmp" del /q ".__bootstrap_package.json.tmp" >nul 2>&1
echo.
echo ============================================================
echo [ERROR] Bootstrap stopped.
echo [ERROR] Nothing is force-pushed or deleted automatically.
echo [ERROR] Read the last error above, fix it, and run again.
echo ============================================================
echo.
pause
exit /b 1
