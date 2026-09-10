@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

rem ============================================================
rem Motion Prompt - GitHub one-click bootstrap / upload / deploy
rem Target: https://github.com/ko9ma7/motion-prompt
rem Put this file in the project root next to index.html, then run it.
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

cls
echo ============================================================
echo [CHECK] Motion Prompt GitHub Bootstrap
echo [CHECK] Project    : %CD%
echo [CHECK] Repository : %REPO_URL%
echo [CHECK] Pages      : %PAGES_URL%
echo ============================================================
echo.

rem ------------------------------------------------------------
rem 0. Make sure this CMD is actually in the project folder.
rem ------------------------------------------------------------
if not exist "index.html" (
  echo [ERROR] index.html was not found in this folder.
  echo [ERROR] Put github-bootstrap.cmd in the SAME folder as index.html.
  echo [ERROR] Current folder: %CD%
  goto :fatal
)

echo [OK] Project root detected.

rem ------------------------------------------------------------
rem 1. Git
rem ------------------------------------------------------------
call :ensure_git
if errorlevel 1 goto :fatal
for /f "delims=" %%V in ('git --version 2^>nul') do echo [OK] %%V

rem ------------------------------------------------------------
rem 2. GitHub CLI
rem ------------------------------------------------------------
call :ensure_gh
if errorlevel 1 goto :fatal
for /f "delims=" %%V in ('gh --version 2^>nul ^| findstr /b /c:"gh version"') do echo [OK] %%V

rem ------------------------------------------------------------
rem 3. GitHub login
rem ------------------------------------------------------------
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
echo [OK] GitHub authentication is ready.

for /f "usebackq delims=" %%U in (`gh api user --jq ".login" 2^>nul`) do set "GH_LOGIN=%%U"
for /f "usebackq delims=" %%I in (`gh api user --jq ".id" 2^>nul`) do set "GH_ID=%%I"
if not defined GH_LOGIN (
  echo [ERROR] Could not read the logged-in GitHub username.
  echo [ERROR] Recovery command: gh auth status
  goto :fatal
)
if /i not "%GH_LOGIN%"=="%GITHUB_OWNER%" (
  echo [WARN] Logged in as %GH_LOGIN%, but target owner is %GITHUB_OWNER%.
  echo [WARN] Continuing only if this account has write permission to %GITHUB_OWNER%/%REPO_NAME%.
)

rem ------------------------------------------------------------
rem 4. Git author identity
rem ------------------------------------------------------------
echo [CHECK] Checking Git author identity...
for /f "usebackq delims=" %%N in (`git config --get user.name 2^>nul`) do set "GIT_NAME=%%N"
if not defined GIT_NAME (
  git config user.name "%GH_LOGIN%"
  set "GIT_NAME=%GH_LOGIN%"
)
for /f "usebackq delims=" %%E in (`git config --get user.email 2^>nul`) do set "GIT_EMAIL=%%E"
if not defined GIT_EMAIL (
  if defined GH_ID (
    set "GIT_EMAIL=%GH_ID%+%GH_LOGIN%@users.noreply.github.com"
  ) else (
    set "GIT_EMAIL=%GH_LOGIN%@users.noreply.github.com"
  )
  git config user.email "!GIT_EMAIL!"
)
echo [OK] Git user.name  = !GIT_NAME!
echo [OK] Git user.email = !GIT_EMAIL!

rem ------------------------------------------------------------
rem 5. Initialize local repository
rem ------------------------------------------------------------
if not exist ".git" (
  echo [CHECK] Initializing local Git repository...
  git init
  if errorlevel 1 (
    echo [ERROR] git init failed.
    goto :fatal
  )
  echo [OK] Local repository initialized.
) else (
  echo [OK] Local Git repository already exists.
)

git branch -M "%DEFAULT_BRANCH%" >nul 2>&1
if errorlevel 1 (
  echo [WARN] Could not rename the current branch yet. It will be set after the first commit.
)

rem ------------------------------------------------------------
rem 6. Create or verify GitHub repository
rem ------------------------------------------------------------
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
    echo [ERROR] Recovery command:
    echo         gh repo create %GITHUB_OWNER%/%REPO_NAME% --%REPO_VISIBILITY%
    goto :fatal
  )
  echo [OK] Repository created.
) else (
  echo [OK] Repository already exists.
)

rem ------------------------------------------------------------
rem 7. Fix origin remote
rem ------------------------------------------------------------
set "CURRENT_ORIGIN="
for /f "delims=" %%R in ('git remote get-url origin 2^>nul') do set "CURRENT_ORIGIN=%%R"
if not defined CURRENT_ORIGIN (
  git remote add origin "%REMOTE_URL%"
  if errorlevel 1 (
    echo [ERROR] Could not add origin remote.
    echo [ERROR] Recovery command: git remote add origin %REMOTE_URL%
    goto :fatal
  )
  echo [OK] origin added: %REMOTE_URL%
) else (
  if /i not "!CURRENT_ORIGIN!"=="%REMOTE_URL%" (
    echo [WARN] origin currently points to: !CURRENT_ORIGIN!
    echo [CHECK] Replacing origin with %REMOTE_URL% ...
    git remote set-url origin "%REMOTE_URL%"
    if errorlevel 1 goto :fatal
  )
  echo [OK] origin = %REMOTE_URL%
)

rem ------------------------------------------------------------
rem 8. If local has no commits but remote main already exists,
rem    base this working tree on remote main without deleting files.
rem ------------------------------------------------------------
git rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 (
  git ls-remote --exit-code --heads origin "%DEFAULT_BRANCH%" >nul 2>&1
  if not errorlevel 1 (
    echo [CHECK] Remote main already exists. Fetching it first...
    git fetch origin "%DEFAULT_BRANCH%"
    if errorlevel 1 goto :fatal
    git reset --mixed "origin/%DEFAULT_BRANCH%"
    if errorlevel 1 goto :fatal
    echo [OK] Local working files preserved and based on remote main.
  )
)

rem ------------------------------------------------------------
rem 9. Basic project validation
rem ------------------------------------------------------------
echo [CHECK] Validating project files...
call :required "index.html"
call :required "styles.css"
call :required "app.js"
call :required "prompt-engine.js"
call :required "i18n.js"
call :required "README.md"
call :required ".github\workflows\deploy.yml"
if "%REQUIRED_FAILED%"=="1" goto :fatal

echo [OK] Required project files are present.

where node >nul 2>&1
if not errorlevel 1 (
  echo [CHECK] Running JavaScript syntax checks...
  node --check "app.js"
  if errorlevel 1 goto :js_error
  node --check "prompt-engine.js"
  if errorlevel 1 goto :js_error
  node --check "i18n.js"
  if errorlevel 1 goto :js_error
  echo [OK] JavaScript syntax checks passed.
) else (
  echo [WARN] Node.js is not installed. This static project does not require Node.js to upload.
)

rem ------------------------------------------------------------
rem 10. Add + commit ALL project files
rem ------------------------------------------------------------
echo [CHECK] Staging ALL files...
git add -A
if errorlevel 1 (
  echo [ERROR] git add -A failed.
  goto :fatal
)

for /f "delims=" %%C in ('git status --short 2^>nul') do set "HAS_STATUS=1"
if defined HAS_STATUS (
  echo [CHECK] Creating commit...
  git commit -m "%COMMIT_MESSAGE%"
  if errorlevel 1 (
    echo [ERROR] Commit failed.
    echo [ERROR] Recovery commands:
    echo         git status
    echo         git add -A
    echo         git commit -m "%COMMIT_MESSAGE%"
    goto :fatal
  )
  echo [OK] Commit created.
) else (
  git rev-parse --verify HEAD >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] There is nothing to commit and no existing commit was found.
    echo [ERROR] Check .gitignore and project files.
    goto :fatal
  )
  echo [OK] No new changes to commit.
)

git branch -M "%DEFAULT_BRANCH%"
if errorlevel 1 goto :fatal

rem ------------------------------------------------------------
rem 11. Push. If remote moved, safely merge remote and retry.
rem ------------------------------------------------------------
echo [CHECK] Uploading files to GitHub...
git push -u origin "%DEFAULT_BRANCH%"
if errorlevel 1 (
  echo [WARN] First push failed. Trying to synchronize with remote main...
  git fetch origin "%DEFAULT_BRANCH%"
  if errorlevel 1 (
    echo [ERROR] git fetch failed.
    goto :fatal
  )

  git merge "origin/%DEFAULT_BRANCH%" --allow-unrelated-histories -X ours --no-edit
  if errorlevel 1 (
    echo [ERROR] Automatic merge failed. No force-push was attempted.
    echo [ERROR] Recovery commands:
    echo         git merge --abort
    echo         git status
    echo         git pull origin %DEFAULT_BRANCH% --allow-unrelated-histories
    echo         git push -u origin %DEFAULT_BRANCH%
    goto :fatal
  )

  git push -u origin "%DEFAULT_BRANCH%"
  if errorlevel 1 (
    echo [ERROR] Push failed again.
    echo [ERROR] Recovery commands:
    echo         git status
    echo         git log --oneline --decorate -10
    echo         git push -u origin %DEFAULT_BRANCH%
    goto :fatal
  )
)
echo [OK] Project files were uploaded to GitHub.

rem ------------------------------------------------------------
rem 12. Repository metadata
rem ------------------------------------------------------------
echo [CHECK] Applying repository metadata...
gh repo edit "%GITHUB_OWNER%/%REPO_NAME%" --description "%REPO_DESCRIPTION%" --homepage "%PAGES_URL%" --default-branch "%DEFAULT_BRANCH%" >nul 2>&1
if errorlevel 1 (
  echo [WARN] Description/homepage could not be updated automatically.
) else (
  echo [OK] Repository description and homepage updated.
)

gh repo edit "%GITHUB_OWNER%/%REPO_NAME%" --add-topic prompt-engineering --add-topic sprite-sheet --add-topic animation --add-topic image-generation --add-topic github-pages --add-topic javascript --add-topic i18n >nul 2>&1
if errorlevel 1 (
  echo [WARN] Some repository topics could not be updated.
) else (
  echo [OK] Repository topics updated.
)

rem ------------------------------------------------------------
rem 13. Enable Pages for Actions deployment
rem ------------------------------------------------------------
echo [CHECK] Enabling GitHub Pages...
gh api "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" >nul 2>&1
if errorlevel 1 (
  gh api --method POST "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" -f build_type=workflow >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Pages could not be enabled by API.
    echo [WARN] Open this page and set Source to GitHub Actions:
    echo        %REPO_URL%/settings/pages
  ) else (
    echo [OK] GitHub Pages enabled.
  )
) else (
  gh api --method PUT "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" -f build_type=workflow >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Pages exists, but switching build type automatically failed.
  ) else (
    echo [OK] GitHub Pages is configured for Actions.
  )
)

rem ------------------------------------------------------------
rem 14. Ensure workflow runs and wait for it
rem ------------------------------------------------------------
echo [CHECK] Looking for deployment workflow...
set "RUN_ID="
timeout /t 5 /nobreak >nul
for /f "usebackq delims=" %%I in (`gh run list --repo "%GITHUB_OWNER%/%REPO_NAME%" --workflow "%WORKFLOW_FILE%" --branch "%DEFAULT_BRANCH%" --limit 1 --json databaseId --jq ".[0].databaseId" 2^>nul`) do set "RUN_ID=%%I"

if not defined RUN_ID (
  echo [CHECK] No run found yet. Dispatching deploy.yml manually...
  gh workflow run "%WORKFLOW_FILE%" --repo "%GITHUB_OWNER%/%REPO_NAME%" --ref "%DEFAULT_BRANCH%" >nul 2>&1
  timeout /t 5 /nobreak >nul
  for /f "usebackq delims=" %%I in (`gh run list --repo "%GITHUB_OWNER%/%REPO_NAME%" --workflow "%WORKFLOW_FILE%" --branch "%DEFAULT_BRANCH%" --limit 1 --json databaseId --jq ".[0].databaseId" 2^>nul`) do set "RUN_ID=%%I"
)

if defined RUN_ID (
  echo [CHECK] Waiting for GitHub Actions run !RUN_ID! ...
  gh run watch !RUN_ID! --repo "%GITHUB_OWNER%/%REPO_NAME%" --exit-status --compact
  if errorlevel 1 (
    echo [WARN] The deployment workflow did not finish successfully.
    echo [WARN] Repository upload itself DID succeed.
    echo [WARN] Inspect with:
    echo        gh run view !RUN_ID! -R %GITHUB_OWNER%/%REPO_NAME% --log-failed
  ) else (
    echo [OK] GitHub Pages deployment completed.
  )
) else (
  echo [WARN] Could not find a workflow run yet.
  echo [WARN] Repository upload itself DID succeed.
  echo [WARN] Check Actions: %REPO_URL%/actions
)

rem ------------------------------------------------------------
rem 15. Tag + release, idempotently
rem ------------------------------------------------------------
echo [CHECK] Checking initial tag %INITIAL_TAG%...
git rev-parse "%INITIAL_TAG%" >nul 2>&1
if errorlevel 1 (
  git tag -a "%INITIAL_TAG%" -m "Motion Prompt %INITIAL_TAG%"
  if not errorlevel 1 echo [OK] Local tag %INITIAL_TAG% created.
) else (
  echo [OK] Local tag %INITIAL_TAG% already exists.
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
  echo [OK] Remote tag %INITIAL_TAG% already exists.
)

gh release view "%INITIAL_TAG%" --repo "%GITHUB_OWNER%/%REPO_NAME%" >nul 2>&1
if errorlevel 1 (
  gh release create "%INITIAL_TAG%" --repo "%GITHUB_OWNER%/%REPO_NAME%" --title "%INITIAL_TAG%" --generate-notes >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Release was not created. This does not affect Pages.
  ) else (
    echo [OK] GitHub Release %INITIAL_TAG% created.
  )
) else (
  echo [OK] GitHub Release %INITIAL_TAG% already exists.
)

rem ------------------------------------------------------------
rem 16. Final result
rem ------------------------------------------------------------
set "DEPLOYED_URL=%PAGES_URL%"
for /f "usebackq delims=" %%P in (`gh api "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" --jq ".html_url" 2^>nul`) do set "DEPLOYED_URL=%%P"

echo.
echo ============================================================
echo [OK] UPLOAD COMPLETE
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
  echo [ERROR] winget is unavailable.
  echo [ERROR] Install Git, then run this CMD again.
  exit /b 1
)
echo [CHECK] Installing Git with winget...
winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
if errorlevel 1 exit /b 1
if exist "%ProgramFiles%\Git\cmd" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
where git >nul 2>&1
if errorlevel 1 (
  echo [WARN] Git was installed, but this CMD cannot see the new PATH yet.
  echo [WARN] Close this window and run github-bootstrap.cmd again.
  exit /b 1
)
exit /b 0

:ensure_gh
where gh >nul 2>&1
if not errorlevel 1 exit /b 0

echo [WARN] GitHub CLI is not installed or not in PATH.
where winget >nul 2>&1
if errorlevel 1 (
  echo [ERROR] winget is unavailable.
  echo [ERROR] Install GitHub CLI, then run this CMD again.
  exit /b 1
)
echo [CHECK] Installing GitHub CLI with winget...
winget install --id GitHub.cli -e --source winget --accept-source-agreements --accept-package-agreements
if errorlevel 1 exit /b 1
if exist "%ProgramFiles%\GitHub CLI" set "PATH=%ProgramFiles%\GitHub CLI;%PATH%"
where gh >nul 2>&1
if errorlevel 1 (
  echo [WARN] GitHub CLI was installed, but this CMD cannot see the new PATH yet.
  echo [WARN] Close this window and run github-bootstrap.cmd again.
  exit /b 1
)
exit /b 0

:js_error
echo [ERROR] JavaScript syntax validation failed.
echo [ERROR] Fix the file named above and rerun this CMD.
goto :fatal

:fatal
echo.
echo ============================================================
echo [ERROR] Bootstrap stopped.
echo [ERROR] Nothing is force-pushed or deleted automatically.
echo [ERROR] Read the last error above, fix it, and run again.
echo ============================================================
echo.
pause
exit /b 1
