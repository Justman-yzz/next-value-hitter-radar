# 과제 1 제출용: graph.html이 참조하는 스크립트(MLB 공개 시연 데이터, assets/model.js)를 HTML 안에 넣어
# 파일 하나만으로 실행되는 submission\graph_standalone.html을 만든다. KBO 데이터는 넣지 않는다.
# 실행: powershell -ExecutionPolicy Bypass -File scripts\build_standalone.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$utf8 = New-Object Text.UTF8Encoding $false
$html = [IO.File]::ReadAllText((Join-Path $root 'graph.html'), $utf8)
$allowed = @('data/public/mlb_lahman_2023_2025.js', 'assets/model.js', 'assets/scatter.js')
# 로컬 스타일시트도 HTML 안에 넣는다 (외부 웹폰트 CSS는 그대로 두고, 오프라인이면 시스템 글꼴로 대체됨)
$html = [regex]::Replace($html, '<link rel="stylesheet" href="(assets/[^"]+\.css)">', {
  param($m)
  $css = [IO.File]::ReadAllText((Join-Path $root $m.Groups[1].Value), $utf8)
  "<style>/* inlined: $($m.Groups[1].Value) */`n$css</style>"
})
$html = [regex]::Replace($html, '<script src="([^"]+)"></script>', {
  param($m)
  $src = $m.Groups[1].Value
  if ($allowed -notcontains $src) { throw "허용되지 않은 스크립트: $src" }
  $code = [IO.File]::ReadAllText((Join-Path $root $src), $utf8).Replace('</script', '<\/script')
  "<script>/* inlined: $src */`n$code</script>"
})
# submission/ 폴더에 놓이므로 사이트 내부 상대 링크는 한 단계 위를 가리키게 바꾼다 (공개 사이트에서는 그대로 작동).
$html = [regex]::Replace($html, '(href|src)="(?!https?:|mailto:|data:|#|\.\./|\$\{)([^"]+)"', '$1="../$2"')
# 단독 파일만 따로 열면 상대 링크가 깨지므로 안내 문구를 덧붙인다.
$html = $html.Replace('<p class="stat" style="margin-top:16px"><a href="index.html">', '<p class="stat" style="margin-top:16px">단독 실행용 파일입니다. MLB 데이터 CSV, 대시보드, 소개 페이지 링크는 공개 사이트에서 이용하세요. <a href="index.html">')
$outDir = Join-Path $root 'submission'; New-Item -ItemType Directory -Force $outDir | Out-Null
$out = Join-Path $outDir 'graph_standalone.html'
[IO.File]::WriteAllText($out, $html, $utf8)
"{0} ({1:N0} bytes) SHA256 {2}" -f $out, (Get-Item $out).Length, (Get-FileHash $out -Algorithm SHA256).Hash
