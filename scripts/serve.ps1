# 로컬 미리보기용 정적 서버 (Python/Node 없이). 실행: powershell -ExecutionPolicy Bypass -File scripts\serve.ps1 [-Port 8765]
param([int]$Port = 8765)
$root = Split-Path $PSScriptRoot -Parent
$types = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.csv'='text/csv; charset=utf-8'; '.json'='application/json; charset=utf-8'; '.md'='text/plain; charset=utf-8'; '.svg'='image/svg+xml' }
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$Port/"
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
  if ($rel -eq '') { $rel = 'index.html' }
  $path = [IO.Path]::GetFullPath((Join-Path $root $rel))
  if (Test-Path $path -PathType Container) { $path = Join-Path $path 'index.html' }   # GitHub Pages처럼 폴더 주소는 index.html로
  if ($path.StartsWith($root) -and (Test-Path $path -PathType Leaf)) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $ext = [IO.Path]::GetExtension($path).ToLower()
    $ctx.Response.ContentType = if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' }
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  } else { $ctx.Response.StatusCode = 404 }
  $ctx.Response.Close()
}
