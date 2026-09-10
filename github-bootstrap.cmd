@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

rem =============================================================
rem Motion Prompt Lab - GitHub Repository / Pages Bootstrap
rem Edit only the variables in this block when reusing elsewhere.
rem =============================================================
set "GITHUB_OWNER=ko9ma7"
set "REPO_NAME=motion-prompt"
set "REPO_VISIBILITY=public"
set "DEFAULT_BRANCH=main"
set "INITIAL_TAG=v1.0.0"
set "COMMIT_MESSAGE=feat: launch multilingual Motion Prompt Lab"
set "REPO_DESCRIPTION=Multilingual sprite-sheet and motion prompt builder for image generation"
set "PAGES_URL=https://ko9ma7.github.io/motion-prompt/"
set "REPO_URL=https://github.com/ko9ma7/motion-prompt"
set "REMOTE_URL=https://github.com/ko9ma7/motion-prompt.git"
set "WORKFLOW_FILE=deploy.yml"

set "FAILED=0"

echo.
echo =============================================================
echo  Motion Prompt Lab - GitHub Bootstrap
echo  Repository : %REPO_URL%
echo  Pages      : %PAGES_URL%
echo =============================================================
echo.

call :require git "Git" "winget install --id Git.Git -e"
if errorlevel 1 goto :fatal
for /f "delims=" %%V in ('git --version 2^>nul') do echo [OK] %%V

where node >nul 2>&1
if errorlevel 1 (
  echo [WARN] Node.js not found. This project is static, so Node.js is optional.
  echo [WARN] JavaScript syntax validation will be skipped.
) else (
  for /f "delims=" %%V in ('node --version 2^>nul') do echo [OK] Node.js %%V
  for /f "delims=" %%V in ('npm --version 2^>nul') do echo [OK] npm %%V
)

call :require gh "GitHub CLI" "winget install --id GitHub.cli -e"
if errorlevel 1 goto :fatal
for /f "delims=" %%V in ('gh --version 2^>nul ^| findstr /i "gh version"') do echo [OK] %%V

echo [CHECK] GitHub authentication...
gh auth status >nul 2>&1
if errorlevel 1 (
  echo [WARN] GitHub CLI is not logged in. Starting interactive login.
  echo [WARN] Choose GitHub.com and HTTPS when prompted.
  gh auth login
  if errorlevel 1 (
    echo [ERROR] GitHub authentication failed.
    echo [ERROR] Recovery: gh auth login
    goto :fatal
  )
)
echo [OK] GitHub authentication is ready.

for /f "usebackq delims=" %%U in (`gh api user --jq ".login" 2^>nul`) do set "GH_LOGIN=%%U"
if not defined GH_LOGIN set "GH_LOGIN=%GITHUB_OWNER%"

echo [CHECK] Git author identity...
for /f "usebackq delims=" %%N in (`git config --get user.name 2^>nul`) do set "GIT_NAME=%%N"
if not defined GIT_NAME (
  set "GIT_NAME=%GH_LOGIN%"
  git config user.name "%GH_LOGIN%"
  echo [OK] Local git user.name set to %GH_LOGIN%.
) else (
  echo [OK] git user.name = !GIT_NAME!
)

for /f "usebackq delims=" %%E in (`git config --get user.email 2^>nul`) do set "GIT_EMAIL=%%E"
if not defined GIT_EMAIL (
  for /f "usebackq delims=" %%E in (`gh api user --jq ".email // empty" 2^>nul`) do set "GIT_EMAIL=%%E"
)
if not defined GIT_EMAIL (
  echo [WARN] Git email is not configured and GitHub did not expose a public email.
  set /p "GIT_EMAIL=Enter the email to use for commits, or press Enter for a GitHub noreply address: "
  if not defined GIT_EMAIL set "GIT_EMAIL=%GH_LOGIN%@users.noreply.github.com"
)
git config user.email "%GIT_EMAIL%"
echo [OK] git user.email = %GIT_EMAIL%

if not exist ".git" (
  echo [CHECK] Initializing local Git repository...
  git init
  if errorlevel 1 (
    echo [ERROR] git init failed.
    echo [ERROR] Recovery: git init
    goto :fatal
  )
  echo [OK] Local Git repository initialized.
) else (
  echo [OK] Local Git repository already exists.
)

git branch -M %DEFAULT_BRANCH% >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Could not set the default branch to %DEFAULT_BRANCH%.
  echo [ERROR] Recovery: git branch -M %DEFAULT_BRANCH%
  goto :fatal
)
echo [OK] Default branch is %DEFAULT_BRANCH%.

call :check_required "index.html"
call :check_required "styles.css"
call :check_required "app.js"
call :check_required "i18n.js"
call :check_required "prompt-engine.js"
call :check_required ".github\workflows\deploy.yml"
call :check_required "README.md"
call :check_required "site.webmanifest"
if "%FAILED%"=="1" goto :fatal

where node >nul 2>&1
if not errorlevel 1 (
  echo [CHECK] Running JavaScript syntax checks...
  node --check i18n.js || goto :syntax_error
  node --check prompt-engine.js || goto :syntax_error
  node --check app.js || goto :syntax_error
  echo [OK] JavaScript syntax checks passed.
)

echo [CHECK] Checking GitHub repository %GITHUB_OWNER%/%REPO_NAME%...
gh repo view "%GITHUB_OWNER%/%REPO_NAME%" >nul 2>&1
if errorlevel 1 (
  echo [WARN] Repository does not exist or is not accessible. Creating it now...
  if /i "%REPO_VISIBILITY%"=="private" (
    gh repo create "%GITHUB_OWNER%/%REPO_NAME%" --private --description "%REPO_DESCRIPTION%"
  ) else (
    gh repo create "%GITHUB_OWNER%/%REPO_NAME%" --public --description "%REPO_DESCRIPTION%"
  )
  if errorlevel 1 (
    echo [ERROR] Repository creation failed.
    echo [ERROR] Recovery: gh repo create %GITHUB_OWNER%/%REPO_NAME% --%REPO_VISIBILITY% --description "%REPO_DESCRIPTION%"
    goto :fatal
  )
  echo [OK] Repository created.
) else (
  echo [OK] Repository already exists. No duplicate repository will be created.
)

for /f "delims=" %%R in ('git remote get-url origin 2^>nul') do set "CURRENT_ORIGIN=%%R"
if not defined CURRENT_ORIGIN (
  echo [CHECK] Adding origin remote...
  git remote add origin "%REMOTE_URL%"
  if errorlevel 1 (
    echo [ERROR] Failed to add origin.
    echo [ERROR] Recovery: git remote add origin %REMOTE_URL%
    goto :fatal
  )
  echo [OK] origin = %REMOTE_URL%
) else (
  if /i not "!CURRENT_ORIGIN!"=="%REMOTE_URL%" (
    echo [WARN] Existing origin points to: !CURRENT_ORIGIN!
    echo [WARN] Updating origin to the requested repository: %REMOTE_URL%
    git remote set-url origin "%REMOTE_URL%"
    if errorlevel 1 (
      echo [ERROR] Failed to update origin.
      echo [ERROR] Recovery: git remote set-url origin %REMOTE_URL%
      goto :fatal
    )
  )
  echo [OK] origin is connected to %REMOTE_URL%
)

echo [CHECK] Staging project files...
git add -A
if errorlevel 1 (
  echo [ERROR] git add failed.
  echo [ERROR] Recovery: git add -A
  goto :fatal
)

git diff --cached --quiet >nul 2>&1
if errorlevel 1 (
  echo [CHECK] Creating commit...
  git commit -m "%COMMIT_MESSAGE%"
  if errorlevel 1 (
    echo [ERROR] Commit failed.
    echo [ERROR] Recovery: git status ^& git commit -m "%COMMIT_MESSAGE%"
    goto :fatal
  )
  echo [OK] New commit created.
) else (
  echo [OK] No new file changes to commit. Existing commit history is kept.
)

echo [CHECK] Pushing %DEFAULT_BRANCH% to origin...
git push -u origin %DEFAULT_BRANCH%
if errorlevel 1 (
  echo [ERROR] Push failed. The remote may contain commits not present locally.
  echo [ERROR] Recovery options:
  echo         git fetch origin
  echo         git pull --rebase origin %DEFAULT_BRANCH%
  echo         git push -u origin %DEFAULT_BRANCH%
  echo [ERROR] This script intentionally does NOT force-push.
  goto :fatal
)
echo [OK] %DEFAULT_BRANCH% is pushed to GitHub.

echo [CHECK] Applying repository metadata...
gh repo edit "%GITHUB_OWNER%/%REPO_NAME%" --description "%REPO_DESCRIPTION%" --homepage "%PAGES_URL%" --default-branch "%DEFAULT_BRANCH%" --enable-issues --enable-wiki=false >nul 2>&1
if errorlevel 1 (
  echo [WARN] Some repository metadata could not be applied automatically.
  echo [WARN] Recovery: gh repo edit %GITHUB_OWNER%/%REPO_NAME% --description "%REPO_DESCRIPTION%" --homepage "%PAGES_URL%"
) else (
  echo [OK] Description, homepage, default branch and basic settings applied.
)

gh repo edit "%GITHUB_OWNER%/%REPO_NAME%" --add-topic prompt-engineering --add-topic sprite-sheet --add-topic pixel-art --add-topic animation --add-topic image-generation --add-topic github-pages --add-topic javascript --add-topic i18n >nul 2>&1
if errorlevel 1 (
  echo [WARN] Topics could not be fully updated. This does not block deployment.
) else (
  echo [OK] Repository topics applied.
)

echo [CHECK] Ensuring GitHub Pages is enabled for GitHub Actions...
gh api "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" >nul 2>&1
if errorlevel 1 (
  gh api -X POST "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" -f build_type=workflow >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Could not enable GitHub Pages.
    echo [ERROR] Recovery: gh api -X POST repos/%GITHUB_OWNER%/%REPO_NAME%/pages -f build_type=workflow
    echo [ERROR] Or open %REPO_URL%/settings/pages and choose GitHub Actions.
    goto :fatal
  )
  echo [OK] GitHub Pages created with workflow deployment.
) else (
  gh api -X PUT "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" -f build_type=workflow >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Pages already exists, but build_type could not be changed automatically.
    echo [WARN] Confirm Settings ^> Pages ^> Source = GitHub Actions.
  ) else (
    echo [OK] Existing GitHub Pages site is set to workflow deployment.
  )
)

echo [CHECK] Starting a deployment workflow run...
gh workflow run "%WORKFLOW_FILE%" --repo "%GITHUB_OWNER%/%REPO_NAME%" --ref "%DEFAULT_BRANCH%" >nul 2>&1
if errorlevel 1 (
  echo [WARN] Manual dispatch could not be started. A push-triggered run may already be active.
) else (
  echo [OK] Deployment workflow dispatched.
)

timeout /t 5 /nobreak >nul
set "RUN_ID="
for /f "usebackq delims=" %%I in (`gh run list --repo "%GITHUB_OWNER%/%REPO_NAME%" --workflow "%WORKFLOW_FILE%" --branch "%DEFAULT_BRANCH%" --limit 1 --json databaseId --jq ".[0].databaseId" 2^>nul`) do set "RUN_ID=%%I"
if not defined RUN_ID (
  echo [WARN] Could not find a workflow run yet.
  echo [WARN] Check manually: gh run list -R %GITHUB_OWNER%/%REPO_NAME%
  goto :deployment_unknown
)

echo [CHECK] Watching GitHub Actions run !RUN_ID!...
gh run watch !RUN_ID! --repo "%GITHUB_OWNER%/%REPO_NAME%" --exit-status --compact
if errorlevel 1 (
  echo [ERROR] Deployment workflow failed.
  echo [ERROR] Inspect: gh run view !RUN_ID! -R %GITHUB_OWNER%/%REPO_NAME% --log-failed
  goto :fatal
)
echo [OK] GitHub Actions deployment completed successfully.

goto :tag_release

:deployment_unknown
echo [WARN] Deployment status is unknown, so the script will not claim success yet.
echo [WARN] Once Actions succeeds, rerun this script; it will not duplicate repository/commit/tag data.
goto :show_url_no_release

:tag_release
echo [CHECK] Ensuring initial tag %INITIAL_TAG% exists...
git rev-parse "%INITIAL_TAG%" >nul 2>&1
if errorlevel 1 (
  git tag -a "%INITIAL_TAG%" -m "Motion Prompt Lab %INITIAL_TAG%"
  if errorlevel 1 (
    echo [WARN] Could not create local tag %INITIAL_TAG%.
  ) else (
    echo [OK] Local tag %INITIAL_TAG% created.
  )
) else (
  echo [OK] Local tag %INITIAL_TAG% already exists.
)

git ls-remote --exit-code --tags origin "refs/tags/%INITIAL_TAG%" >nul 2>&1
if errorlevel 1 (
  git push origin "%INITIAL_TAG%"
  if errorlevel 1 (
    echo [WARN] Tag push failed. Recovery: git push origin %INITIAL_TAG%
  ) else (
    echo [OK] Tag %INITIAL_TAG% pushed.
  )
) else (
  echo [OK] Remote tag %INITIAL_TAG% already exists.
)

gh release view "%INITIAL_TAG%" --repo "%GITHUB_OWNER%/%REPO_NAME%" >nul 2>&1
if errorlevel 1 (
  gh release create "%INITIAL_TAG%" --repo "%GITHUB_OWNER%/%REPO_NAME%" --title "%INITIAL_TAG%" --notes "Initial public release of Motion Prompt Lab: multilingual motion/sprite prompt builder with GitHub Pages deployment."
  if errorlevel 1 (
    echo [WARN] Release creation failed, but the tag may already be pushed.
    echo [WARN] Recovery: gh release create %INITIAL_TAG% -R %GITHUB_OWNER%/%REPO_NAME% --generate-notes
  ) else (
    echo [OK] GitHub Release %INITIAL_TAG% created.
  )
) else (
  echo [OK] GitHub Release %INITIAL_TAG% already exists.
)

goto :show_url

:show_url_no_release
set "DEPLOYED_URL=%PAGES_URL%"
for /f "usebackq delims=" %%P in (`gh api "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" --jq ".html_url" 2^>nul`) do set "DEPLOYED_URL=%%P"
echo.
echo =============================================================
echo [WARN] Repository setup is complete, but deployment success was not confirmed.
echo [OK] Repository: %REPO_URL%
echo [CHECK] Expected Pages URL: !DEPLOYED_URL!
echo =============================================================
echo.
exit /b 2

:show_url
set "DEPLOYED_URL=%PAGES_URL%"
for /f "usebackq delims=" %%P in (`gh api "repos/%GITHUB_OWNER%/%REPO_NAME%/pages" --jq ".html_url" 2^>nul`) do set "DEPLOYED_URL=%%P"
echo.
echo =============================================================
echo [OK] Bootstrap and first deployment completed.
echo [OK] Repository : %REPO_URL%
echo [OK] Pages URL  : !DEPLOYED_URL!
echo [OK] Release    : %REPO_URL%/releases/tag/%INITIAL_TAG%
echo =============================================================
echo.
start "" "!DEPLOYED_URL!" >nul 2>&1
exit /b 0

:syntax_error
echo [ERROR] JavaScript syntax validation failed.
echo [ERROR] Fix the file shown above, then rerun github-bootstrap.cmd.
goto :fatal

:require
where %~1 >nul 2>&1
if errorlevel 1 (
  echo [ERROR] %~2 is not installed or not in PATH.
  echo [ERROR] Install command: %~3
  exit /b 1
)
echo [OK] %~2 is installed.
exit /b 0

:check_required
if not exist %~1 (
  echo [ERROR] Required file missing: %~1
  set "FAILED=1"
) else (
  echo [OK] Found %~1
)
exit /b 0

:fatal
echo.
echo =============================================================
echo [ERROR] Bootstrap stopped before successful completion.
echo [ERROR] Review the last error and recovery command above, then rerun.
echo =============================================================
echo.
exit /b 1
