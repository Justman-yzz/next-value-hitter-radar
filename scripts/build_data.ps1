# NEXT VALUE — Hitter Radar - 원본 CSV를 schema.csv 형식으로 정규화하고 검사 결과를 출력한다.
# 실행: powershell -ExecutionPolicy Bypass -File scripts\build_data.ps1
# 입력: data\sources\minse0n_Toyproject-ML\kbo_batting_stats_by_season_1982-2025.csv
#       (https://github.com/minse0n/Toyproject-ML/blob/main/data/raw/kbo_batting_stats_by_season_1982-2025.csv)
# 출력: data\derived\kbo_hitters_2024_2025.csv, data\derived\audit.json  (둘 다 로컬 전용, git 제외)
# 공개 페이지에는 데이터를 내장하지 않는다. 대시보드에서 위 CSV를 직접 선택해 불러온다.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'data\sources\minse0n_Toyproject-ML\kbo_batting_stats_by_season_1982-2025.csv'
$outDir = Join-Path $root 'data\derived'
New-Item -ItemType Directory -Force $outDir | Out-Null
$inv = [Globalization.CultureInfo]::InvariantCulture

$all = Import-Csv $src -Encoding UTF8
$rows = $all | Where-Object { $_.Year -in '2024', '2025' }
$required = 'Id','Name','Team','Age','PA','AB','H','2B','3B','HR','BB','HP','SO','SF','AVG','OBP','SLG'
$counting = 'G','PA','AB','H','2B','3B','HR','BB','HP','SO','SF'

$audit = [ordered]@{
  source_file = 'data/sources/minse0n_Toyproject-ML/kbo_batting_stats_by_season_1982-2025.csv'
  source_sha256 = (Get-FileHash $src -Algorithm SHA256).Hash
  source_rows_all_years = $all.Count
  seasons = [ordered]@{}
}

# 원본 비율 지표와 계산식의 일치 확인 (OBP = (H+BB+HP)/(AB+BB+HP+SF), SLG = TB/AB)
$formulaMismatch = @()
foreach ($r in $rows) {
  $ab = [int]$r.AB; if ($ab -eq 0) { continue }
  $obpDen = $ab + [int]$r.BB + [int]$r.HP + [int]$r.SF
  $obp = if ($obpDen) { ([int]$r.H + [int]$r.BB + [int]$r.HP) / $obpDen } else { 0 }
  $slg = ([int]$r.H + [int]$r.'2B' + 2 * [int]$r.'3B' + 3 * [int]$r.HR) / $ab
  if ([math]::Abs($obp - [double]::Parse($r.OBP, $inv)) -gt 0.0006 -or [math]::Abs($slg - [double]::Parse($r.SLG, $inv)) -gt 0.0006) {
    $formulaMismatch += "$($r.Year) $($r.Name) $($r.Team)"
  }
}
$audit.formula_mismatch_rows = $formulaMismatch

$out = @()
foreach ($season in '2024', '2025') {
  $s = @($rows | Where-Object Year -eq $season)
  $missing = [ordered]@{}
  foreach ($c in $required) { $missing[$c] = @($s | Where-Object { [string]::IsNullOrWhiteSpace($_.$c) }).Count }
  $byId = $s | Group-Object Id
  $sameName = $s | Group-Object Name | Where-Object { @($_.Group.Id | Sort-Object -Unique).Count -gt 1 } | ForEach-Object { $_.Name + ' (' + ((@($_.Group.Id | Sort-Object -Unique)) -join ', ') + ')' }
  $audit.seasons[$season] = [ordered]@{
    source_rows = $s.Count
    unique_player_ids = $byId.Count
    teams = @($s.Team | Sort-Object -Unique)
    exact_duplicate_rows = @($s | Group-Object Id, Team | Where-Object Count -gt 1).Count
    multi_team_players = @($byId | Where-Object Count -gt 1 | ForEach-Object { $_.Group[0].Name + ': ' + (($_.Group | ForEach-Object { $_.Team + ' ' + $_.PA + 'PA' }) -join ' + ') })
    same_name_different_id = @($sameName)
    missing_required = $missing
    zero_pa_rows = @($s | Where-Object { [int]$_.PA -eq 0 }).Count
  }

  # 시즌 중 이적 선수는 공식 기록실처럼 선수-시즌 1행으로 합산하고 비율 지표는 합산값으로 다시 계산한다.
  foreach ($g in $byId) {
    $parts = @($g.Group)
    $sum = @{}
    foreach ($c in $counting) { $sum[$c] = ($parts | ForEach-Object { [int]$_.$c } | Measure-Object -Sum).Sum }
    $first = $parts[0]
    $ab = $sum.AB
    $obpDen = $ab + $sum.BB + $sum.HP + $sum.SF
    if ($parts.Count -eq 1) {
      $avg = [double]::Parse($first.AVG, $inv); $obp = [double]::Parse($first.OBP, $inv); $slg = [double]::Parse($first.SLG, $inv)
    } else {
      $avg = if ($ab) { $sum.H / $ab } else { 0 }
      $obp = if ($obpDen) { ($sum.H + $sum.BB + $sum.HP) / $obpDen } else { 0 }
      $slg = if ($ab) { ($sum.H + $sum['2B'] + 2 * $sum['3B'] + 3 * $sum.HR) / $ab } else { 0 }
    }
    $out += [pscustomobject][ordered]@{
      season = $season; league = 'KBO'; player_id = $first.Id; player_name = $first.Name
      team = (($parts | ForEach-Object Team) -join '→'); age = [int]$first.Age
      PA = $sum.PA; AB = $sum.AB; H = $sum.H; '2B' = $sum['2B']; '3B' = $sum['3B']; HR = $sum.HR
      BB = $sum.BB; HBP = $sum.HP; SO = $sum.SO; SF = $sum.SF
      AVG = [math]::Round($avg, 3); OBP = [math]::Round($obp, 3); SLG = [math]::Round($slg, 3)
      pos = $first.'Pos.'; G = $sum.G; team_rows = $parts.Count
    }
  }
  $audit.seasons[$season].normalized_rows = @($out | Where-Object season -eq $season).Count
}

$csvPath = Join-Path $outDir 'kbo_hitters_2024_2025.csv'
$out | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8

$audit.derived = [ordered]@{
  csv = 'data/derived/kbo_hitters_2024_2025.csv'; csv_sha256 = (Get-FileHash $csvPath -Algorithm SHA256).Hash
  rows = $out.Count
}
$audit | ConvertTo-Json -Depth 6 | Out-File (Join-Path $outDir 'audit.json') -Encoding utf8
$audit | ConvertTo-Json -Depth 6
