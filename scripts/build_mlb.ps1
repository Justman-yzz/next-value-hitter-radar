# NEXT VALUE — Hitter Radar - SABR Lahman Baseball Database(CC BY-SA 3.0)로 MLB 공개 시연 데이터를 만든다.
# 실행: powershell -ExecutionPolicy Bypass -File scripts\build_mlb.ps1
# 입력: data\sources\lahman_2025\{Batting,People,Teams,Fielding}.csv  (https://sabr.org/lahman-database/ , 2025판)
# 출력(공개): data\public\mlb_lahman_2023_2025.csv, data\public\mlb_lahman_2023_2025.js
# 출력(로컬): data\derived\mlb_audit.json
# 변경 사항: 시즌별 구단 stint를 선수-시즌 1행으로 합산, PA = AB+BB+HBP+SH+SF 계산, 주 포지션·나이(6/30 기준) 부여, 0타석 행 제외.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'data\sources\lahman_2025'
$pub = Join-Path $root 'data\public'
New-Item -ItemType Directory -Force $pub, (Join-Path $root 'data\derived') | Out-Null
$years = '2023', '2024', '2025'

$bat = Import-Csv "$src\Batting.csv" | Where-Object { $_.yearID -in $years }
$people = @{}; Import-Csv "$src\People.csv" | ForEach-Object { $people[$_.playerID] = $_ }
$teamBR = @{}; Import-Csv "$src\Teams.csv" | Where-Object { $_.yearID -in $years } | ForEach-Object { $teamBR["$($_.yearID)|$($_.teamID)"] = $_ }
# 주 포지션: 해당 시즌 수비 경기 수가 가장 많은 포지션 (수비 기록이 없으면 DH)
$posG = @{}
Import-Csv "$src\Fielding.csv" | Where-Object { $_.yearID -in $years } | ForEach-Object {
  $k = "$($_.yearID)|$($_.playerID)"; if (-not $posG[$k]) { $posG[$k] = @{} }; $posG[$k][$_.POS] = [int]$posG[$k][$_.POS] + [int]$_.G }

$cnt = 'G','AB','H','2B','3B','HR','BB','SO','HBP','SH','SF','IBB'
$out = @(); $audit = [ordered]@{ seasons = [ordered]@{} }
foreach ($g in ($bat | Group-Object yearID, playerID)) {
  $parts = @($g.Group | Sort-Object { [int]$_.stint })
  $s = @{}; foreach ($c in $cnt) { $s[$c] = ($parts | ForEach-Object { [int]$_.$c } | Measure-Object -Sum).Sum }
  $pa = $s.AB + $s.BB + $s.HBP + $s.SH + $s.SF
  if ($pa -le 0) { continue }
  $y = $parts[0].yearID; $id = $parts[0].playerID; $p = $people[$id]
  $age = $null
  if ($p -and $p.birthYear) {
    $age = [int]$y - [int]$p.birthYear
    if ($p.birthMonth -and ([int]$p.birthMonth -gt 6)) { $age -= 1 }   # 6월 30일 기준 나이
  }
  $pos = 'DH'; $pg = $posG["$y|$id"]; if ($pg) { $pos = ($pg.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key }
  if ($pos -eq 'P' -and $pa -ge 100) { $pos = 'P/DH' }   # Lahman 수비 기록에는 지명타자가 없어 투타겸업 선수를 따로 표기
  $teams = ($parts | ForEach-Object { $t = $teamBR["$y|$($_.teamID)"]; if ($t -and $t.teamIDBR) { $t.teamIDBR } else { $_.teamID } }) -join '→'
  $out += [pscustomobject][ordered]@{
    season = $y; league = 'MLB'; player_id = $id; player_name = if ($p) { "$($p.nameFirst) $($p.nameLast)" } else { $id }
    team = $teams; lg = (($parts | ForEach-Object lgID | Select-Object -Unique) -join '/'); age = $age; pos = $pos
    G = $s.G; PA = $pa; AB = $s.AB; H = $s.H; '2B' = $s['2B']; '3B' = $s['3B']; HR = $s.HR
    BB = $s.BB; SO = $s.SO; HBP = $s.HBP; SF = $s.SF; SH = $s.SH; team_rows = $parts.Count
  }
}
$out = $out | Sort-Object season, player_id
foreach ($y in $years) {
  $r = @($bat | Where-Object yearID -eq $y); $o = @($out | Where-Object season -eq $y)
  $teamTot = Import-Csv "$src\Teams.csv" | Where-Object yearID -eq $y
  $chk = [ordered]@{}; foreach ($c in 'AB','H','HR','BB','SO','HBP','SF') { $chk[$c] = [ordered]@{ players = ($o | Measure-Object $c -Sum).Sum; teams = ($teamTot | Measure-Object $c -Sum).Sum } }
  $audit.seasons[$y] = [ordered]@{
    batting_rows = $r.Count; unique_player_ids = @($r.playerID | Sort-Object -Unique).Count; multi_stint_players = @($r | Group-Object playerID | Where-Object Count -gt 1).Count
    output_rows_pa_ge_1 = $o.Count; pa_ge_30 = @($o | Where-Object { $_.PA -ge 30 }).Count; pa_ge_100 = @($o | Where-Object { $_.PA -ge 100 }).Count
    missing_age = @($o | Where-Object { $null -eq $_.age }).Count; teams = @($r.teamID | Sort-Object -Unique).Count
    player_vs_team_totals = $chk
  }
}
$csv = Join-Path $pub 'mlb_lahman_2023_2025.csv'
$out | Export-Csv $csv -NoTypeInformation -Encoding UTF8
$hdr = @('season','league','player_id','player_name','team','lg','age','pos','G','PA','AB','H','2B','3B','HR','BB','SO','HBP','SF','SH','team_rows')
$rows = $out | ForEach-Object { $o = $_; ,@($hdr | ForEach-Object { $o.$_ }) }
$meta = [ordered]@{
  title = 'MLB 공개 시연 데이터 (SABR Lahman Baseball Database 2025판 가공)'
  source = 'SABR Lahman Baseball Database 1871-2025, https://sabr.org/lahman-database/'
  license = 'CC BY-SA 3.0 (https://creativecommons.org/licenses/by-sa/3.0/)'
  attribution = 'Copyright 1996-2025 SABR, via donation from Sean Lahman. 이 가공 데이터도 CC BY-SA 3.0을 따른다.'
  changes = '2023-2025 타격 기록만 사용; 구단 stint 합산; PA=AB+BB+HBP+SH+SF; 6/30 기준 나이; 주 포지션; 0타석 제외'
  source_sha256 = (Get-FileHash "$src\Batting.csv" -Algorithm SHA256).Hash
  built = (Get-Date -Format 'yyyy-MM-dd')
  seasons = $years
}
$payload = [ordered]@{ meta = $meta; header = $hdr; rows = $rows } | ConvertTo-Json -Depth 5 -Compress
$js = Join-Path $pub 'mlb_lahman_2023_2025.js'
[IO.File]::WriteAllText($js, "// MLB 공개 시연 데이터 · CC BY-SA 3.0 · 출처: SABR Lahman Baseball Database (https://sabr.org/lahman-database/)`nwindow.NV_MLB=$payload;`n", (New-Object Text.UTF8Encoding $false))
$audit.outputs = [ordered]@{ csv_sha256 = (Get-FileHash $csv -Algorithm SHA256).Hash; js_sha256 = (Get-FileHash $js -Algorithm SHA256).Hash; rows = $out.Count; js_bytes = (Get-Item $js).Length }
$audit | ConvertTo-Json -Depth 6 | Out-File (Join-Path $root 'data\derived\mlb_audit.json') -Encoding utf8
$audit | ConvertTo-Json -Depth 6
