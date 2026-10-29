# 공개 배포 전 점검: 저장소/GitHub Pages로 나갈 파일에 KBO 기록·비공개 자료가 섞이지 않았는지,
# 공개 데이터는 허용된 MLB 시연 데이터(CC BY-SA 3.0)뿐인지 확인한다.
# 실행: powershell -ExecutionPolicy Bypass -File scripts\check_public.ps1                 (프로젝트 폴더, .gitignore 적용)
#       powershell -ExecutionPolicy Bypass -File scripts\check_public.ps1 -Target PUBLIC_RELEASE  (배포 폴더 전체를 공개 대상으로 검사)
param([string]$Target = '')
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$fail = @()

# 1. 공개 대상 파일 목록
if ($Target) {
  $root = (Resolve-Path (Join-Path $project $Target) -ErrorAction SilentlyContinue).Path
  if (-not $root) { $root = (Resolve-Path $Target).Path }
  $public = Get-ChildItem $root -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($root.Length + 1) }
  foreach ($p in $public) { if ($p -match '(^|\\)(sources|derived|private|snapshots|tests|\.claude|\.git)(\\|$)') { $fail += "배포 폴더에 비공개 경로: $p" } }
} else {
  $root = $project
  $ignored = Get-Content (Join-Path $root '.gitignore') -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim().TrimEnd('/').Replace('/', '\') }
  $public = Get-ChildItem $root -Recurse -File -Force | Where-Object {
    $rel = $_.FullName.Substring($root.Length + 1)
    -not ($ignored | Where-Object { $rel -eq $_ -or $rel.StartsWith($_ + '\') }) -and -not $rel.StartsWith('.git\')
  } | ForEach-Object { $_.FullName.Substring($root.Length + 1) }
}
Write-Host "검사 대상: $root"
Write-Host "공개 대상 파일 $($public.Count)개:"; $public | ForEach-Object { Write-Host "  $_" }

# 2. git 추적 파일과 커밋 이력 (프로젝트 모드에서만)
if ($Target) { Write-Host '배포 폴더 모드: git 검사 생략 (웹 업로드 대상 폴더 자체를 검사)' }
elseif (Test-Path (Join-Path $root '.git')) {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    $tracked = git -C $root ls-files
    $hist = git -C $root log --all --name-only --pretty=format: | Sort-Object -Unique
    foreach ($p in @($tracked) + @($hist)) { if ($p -match '^(data/sources|data/derived|private)/') { $fail += "git 추적/이력에 비공개 경로: $p" } }
  } else { $fail += '.git 폴더가 있으나 git 명령이 없어 추적 파일·이력을 점검하지 못함' }
} else { Write-Host '.git 없음: 아직 저장소가 아니므로 추적 파일·커밋 이력 없음' }

# 3. 데이터·스크립트 파일 허용 목록
$allowedData = @('data\schema.csv', 'data\public\mlb_lahman_2023_2025.csv', 'data\public\mlb_lahman_2023_2025.js')
foreach ($p in $public) {
  if ($p -match '\.(csv|tsv|json|xlsx|xls|parquet|zip|mdb|bak|txt|sqlite|db)$' -and $allowedData -notcontains $p) { $fail += "허용되지 않은 데이터 파일: $p" }
  # JS는 assets\ 아래 코드(디자인 작업으로 늘어날 수 있음)와 MLB 공개 데이터만 허용
  if ($p -match '\.(js|mjs)$' -and $allowedData -notcontains $p -and -not $p.StartsWith('assets\')) { $fail += "허용되지 않은 스크립트 위치: $p" }
}
if (Test-Path (Join-Path $root 'data\schema.csv')) {
  $schema = @(Get-Content (Join-Path $root 'data\schema.csv') -Encoding UTF8 | Where-Object { $_.Trim() })
  if ($schema.Count -ne 1) { $fail += "data/schema.csv에 헤더 외 $($schema.Count - 1)행이 있음" }
} else { $fail += 'data/schema.csv 없음 (페이지의 헤더 예시 링크가 깨짐)' }

# 4. MLB 공개 시연 데이터: league가 전부 MLB이고 라이선스 표기가 있는지
$mlbCsv = Join-Path $root 'data\public\mlb_lahman_2023_2025.csv'
if (Test-Path $mlbCsv) {
  $bad = @(Import-Csv $mlbCsv -Encoding UTF8 | Where-Object { $_.league -ne 'MLB' }).Count
  if ($bad) { $fail += "MLB 공개 CSV에 MLB가 아닌 행 $bad개" }
  $js = Get-Content (Join-Path $root 'data\public\mlb_lahman_2023_2025.js') -Raw -Encoding UTF8
  if ($js -notmatch 'CC BY-SA 3.0' -or $js -notmatch 'Lahman') { $fail += 'MLB 공개 JS에 라이선스/출처 표기가 없음' }
  if ($js -match '"(KBO|FUTURES)"') { $fail += 'MLB 공개 JS에 KBO/FUTURES 리그 값이 있음' }
  if (-not (Test-Path (Join-Path $root 'data\public\README.md'))) { $fail += 'data/public/README.md(라이선스 안내) 없음' }
}

# 5. HTML/JS에 KBO 데이터 내장·외부 전송 흔적
foreach ($p in $public | Where-Object { $_ -match '\.(html|js)$' }) {
  $t = Get-Content (Join-Path $root $p) -Raw -Encoding UTF8
  foreach ($pat in 'NV_DATA', 'data/derived', 'data/sources', 'fetch\(', 'XMLHttpRequest', 'sendBeacon', 'WebSocket', 'localStorage', 'sessionStorage', 'indexedDB') { if ($t -match $pat) { $fail += "$p : '$pat' 발견" } }
  # 외부 스크립트 금지 (업로드한 KBO 파일이 외부 코드와 같은 페이지에 놓이지 않도록). 로컬 assets/ 스크립트와 MLB 데이터만 허용
  foreach ($m in [regex]::Matches($t, '<script[^>]+src="([^"]+)"')) { $s = $m.Groups[1].Value -replace '^(\.\./)+', ''; if ($s -notmatch '^assets/' -and $s -ne 'data/public/mlb_lahman_2023_2025.js') { $fail += "$p : 외부/허용 외 스크립트 $($m.Groups[1].Value)" } }
}

# 6. KBO 선수명 노출 검사 (로컬 KBO 정규화 CSV의 명단으로 공개 텍스트 파일 전체를 검색)
$names = Join-Path $project 'data\derived\kbo_hitters_2024_2025.csv'
if (Test-Path $names) {
  $list = Import-Csv $names -Encoding UTF8 | ForEach-Object player_name | Where-Object { $_.Length -ge 2 } | Sort-Object -Unique
  foreach ($p in $public | Where-Object { $_ -match '\.(html|js|md|csv|txt|json|ps1)$' }) {
    $t = Get-Content (Join-Path $root $p) -Raw -Encoding UTF8
    $hits = $list | Where-Object { $t.Contains($_) }
    if ($hits) { $fail += "$p : KBO 선수명 $(@($hits).Count)개 ($((@($hits) | Select-Object -First 8) -join ', '))" }
  }
  Write-Host "KBO 선수명 $($list.Count)개로 공개 텍스트 파일 검색 완료"
} else { Write-Host '로컬 KBO 정규화 CSV가 없어 선수명 검사는 건너뜀' }

# 7. 인증정보 패턴
foreach ($p in $public | Where-Object { $_ -ne 'scripts\check_public.ps1' -and $_ -match '\.(html|js|css|md|csv|ps1|json|txt|svg|yml|yaml)$' }) {
  $t = Get-Content (Join-Path $root $p) -Raw -Encoding UTF8
  if ($t -match '(ghp_[A-Za-z0-9]{20,}|github_pat_|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY)') { $fail += "$p : 토큰/키로 보이는 문자열" }
}

# 8. 경로 검사: GitHub Pages 프로젝트 하위 경로(/<저장소명>/)에서도 깨지지 않도록
#    HTML의 src/href와 CSS의 url()이 상대경로이고, 대소문자까지 정확히 같은 파일을 가리키는지 확인한다(Pages는 대소문자 구분).
$caseSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($p in $public) { [void]$caseSet.Add($p.Replace('\', '/')) }
$external = @()
foreach ($p in $public | Where-Object { $_ -match '\.(html|css)$' -and $_ -notmatch '^tests\\' }) {
  $t = Get-Content (Join-Path $root $p) -Raw -Encoding UTF8
  $refs = @([regex]::Matches($t, '(?:src|href)\s*=\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value }) + @([regex]::Matches($t, 'url\(\s*[''"]?([^''")]+)[''"]?\s*\)') | ForEach-Object { $_.Groups[1].Value })
  $dir = Split-Path $p.Replace('\', '/') -Parent; if ($dir) { $dir = $dir.Replace('\', '/') }
  foreach ($r in $refs) {
    if ($r -match '^(https?:|mailto:|data:|javascript:|#|\$\{)' -or $r -eq '') { if ($r -match '^https?:') { $external += "$p -> $r" }; continue }
    if ($r.StartsWith('/')) { $fail += "$p : 절대경로 '$r' (Pages 하위 경로에서 깨짐)"; continue }
    $clean = ($r -split '[?#]')[0]
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($seg in (($(if ($dir) { "$dir/$clean" } else { $clean })) -split '/')) { if ($seg -eq '..') { if ($parts.Count) { $parts.RemoveAt($parts.Count - 1) } else { $fail += "$p : 폴더 밖을 가리킴 '$r'" } } elseif ($seg -ne '.' -and $seg -ne '') { $parts.Add($seg) } }
    $target = $parts -join '/'
    if (-not $caseSet.Contains($target)) { $fail += "$p : '$r' 대상 파일 없음 또는 대소문자 불일치 ($target)" }
  }
}
Write-Host "외부 링크 $($external.Count)개 (참고용, 실패 아님)"

if ($fail.Count) { Write-Host "`nFAIL ($($fail.Count))"; $fail | ForEach-Object { Write-Host "  - $_" }; exit 1 }
Write-Host "`nPASS: 공개 대상에 KBO 기록·비공개 자료·인증정보·외부 전송 코드 없음, 공개 데이터는 MLB 시연 데이터(CC BY-SA 3.0)뿐"
