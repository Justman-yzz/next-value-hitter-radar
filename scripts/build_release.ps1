# GitHub 웹 업로드용 공개 폴더를 만든다. 허용 목록에 있는 파일만 복사하고, 복사본을 다시 검사한다.
# 실행: powershell -ExecutionPolicy Bypass -File scripts\build_release.ps1                 (→ PUBLIC_RELEASE\)
#       powershell -ExecutionPolicy Bypass -File scripts\build_release.ps1 -OutDir _release_check\next-value-hitter-radar   (시험 빌드)
# 이 폴더의 "내용물"을 저장소 최상위에 올리면 index.html, graph.html, dashboard.html이 그대로 작동한다.
param([string]$OutDir = 'PUBLIC_RELEASE')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$out = [IO.Path]::GetFullPath((Join-Path $root $OutDir))
# 안전장치: 프로젝트 안의 지정 폴더만 지우고 다시 만든다.
if (-not $out.StartsWith($root + '\') -or $out -match '\\(data|assets|scripts|private|snapshots|tests|submission)(\\|$)') { throw "출력 폴더가 안전하지 않음: $out" }
if (Test-Path $out) { Remove-Item $out -Recurse -Force -Confirm:$false }
New-Item -ItemType Directory -Force $out | Out-Null

# 1. 과제 1 단독 HTML을 최신 graph.html로 다시 만든다.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build_standalone.ps1') | Out-Host

# 2. 허용 목록 (사이트 파일 + 공개 데이터 + 문서 + 재현 스크립트). 그 밖의 파일은 복사하지 않는다.
$files = @(
  'index.html', 'graph.html', 'dashboard.html',
  'data\schema.csv', 'data\public\mlb_lahman_2023_2025.csv', 'data\public\mlb_lahman_2023_2025.js', 'data\public\README.md',
  'submission\graph_standalone.html',
  'README.md', 'CHANGELOG.md', 'DATA_AUDIT.md', 'DATA_VERIFICATION.md', 'DESIGN_DECISIONS.md', 'DESIGN_QA.md',
  'scripts\build_mlb.ps1', 'scripts\build_data.ps1', 'scripts\build_standalone.ps1', 'scripts\build_release.ps1', 'scripts\check_public.ps1', 'scripts\serve.ps1'
)
# assets\ 아래의 디자인·코드 자원(디자인 작업으로 늘어날 수 있음)은 형식으로 허용한다.
$assetExt = '\.(js|css|svg|png|jpg|jpeg|webp|gif|ico|woff2?|ttf|otf)$'
$assets = Get-ChildItem (Join-Path $root 'assets') -Recurse -File | ForEach-Object { $_.FullName.Substring($root.Length + 1) }
foreach ($a in $assets) { if ($a -match $assetExt) { $files += $a } else { Write-Host "건너뜀(허용 형식 아님): $a" } }
# 디자인 검수 스크린샷(MLB 공개 데이터 화면만 담김)
$shots = Get-ChildItem (Join-Path $root 'docs\screenshots') -Filter *.png -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring($root.Length + 1) }
$files += $shots

foreach ($f in $files) {
  $src = Join-Path $root $f
  if (-not (Test-Path $src)) { throw "필수 파일 없음: $f" }
  $dst = Join-Path $out $f
  New-Item -ItemType Directory -Force (Split-Path $dst -Parent) | Out-Null
  Copy-Item $src $dst -Force
}
# Jekyll 처리를 끄면 파일이 있는 그대로 제공된다 (밑줄로 시작하는 경로·Markdown 변환 문제 방지).
New-Item -ItemType File -Force (Join-Path $out '.nojekyll') | Out-Null

# 3. 목록과 해시 기록
$manifest = Get-ChildItem $out -Recurse -File -Force | Where-Object { $_.Name -ne 'RELEASE_MANIFEST.md' } | ForEach-Object {
  $rel = $_.FullName.Substring($out.Length + 1).Replace('\', '/')
  "| ``$rel`` | $($_.Length) | ``$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.Substring(0,16))`` |"
}
$head = "# 공개 배포 파일 목록`n`n생성: $(Get-Date -Format 'yyyy-MM-dd HH:mm') · scripts/build_release.ps1`n`n| 파일 | 바이트 | SHA256(앞 16자) |`n|---|---|---|"
[IO.File]::WriteAllText((Join-Path $out 'RELEASE_MANIFEST.md'), ($head + "`n" + ($manifest -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
Write-Host "복사 완료: $out ($(@(Get-ChildItem $out -Recurse -File -Force).Count)개 파일)"

# 4. 복사본 자체를 공개 대상으로 검사
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_public.ps1') -Target $out
if ($LASTEXITCODE -ne 0) { Write-Host "`n배포 폴더 검사 실패: 업로드하지 마세요."; exit 1 }
Write-Host "`n배포 폴더 준비 완료: $out 의 내용물을 저장소 최상위에 업로드하세요."
