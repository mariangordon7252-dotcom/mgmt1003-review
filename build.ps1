# 校验 data\w*.json 并把题库内嵌进 app.template.html，生成两个文件：
#   MGMT1003复习.html  —— 本地双击打开（带完整 html 骨架）
#   index.html         —— 同上，供 GitHub Pages 使用
#   artifact.html      —— 用于 claude.ai 在线发布（无骨架）
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)
$weeks = @()
$report = @()
foreach ($f in Get-ChildItem "$root\data" -Filter 'w*.json' | Sort-Object Name) {
  $raw = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
  try { $obj = $raw | ConvertFrom-Json } catch { throw "JSON 无效: $($f.Name) — $($_.Exception.Message)" }
  $problems = @()
  foreach ($q in @($obj.mcq)) {
    if (@($q.options).Count -ne 4) { $problems += "mcq 选项数≠4: $($q.q.Substring(0,[Math]::Min(40,$q.q.Length)))" }
    if ($q.answer -lt 0 -or $q.answer -gt 3) { $problems += "mcq answer 越界" }
  }
  foreach ($q in @($obj.tf)) { if ($q.a -isnot [bool]) { $problems += "tf a 不是布尔" } }
  foreach ($mt in @($obj.match)) {
    $l = @($mt.pairs | ForEach-Object { $_[0] }); $r = @($mt.pairs | ForEach-Object { $_[1] })
    if (($l | Select-Object -Unique).Count -ne $l.Count -or ($r | Select-Object -Unique).Count -ne $r.Count) { $problems += "match 有重复项: $($mt.title)" }
  }
  foreach ($c in @($obj.concepts)) { if (-not $c.one -or -not $c.eg -or -not $c.like) { $problems += "concept 缺 one/eg/like: $($c.term)" } }
  foreach ($e in @($obj.essay)) { if (-not $e.model -or @($e.points).Count -lt 2) { $problems += "essay 缺 model/points" } }
  if ($problems.Count) { throw "$($f.Name): " + ($problems -join '; ') }
  $weeks += $raw.Trim()
  $report += "{0}: summary {1}, concepts {2}, tf {3}, mcq {4}, match {5}, essay {6}" -f $f.Name, @($obj.summary).Count, @($obj.concepts).Count, @($obj.tf).Count, @($obj.mcq).Count, @($obj.match).Count, @($obj.essay).Count
}
$data = 'window.MGMT_DATA=[' + ($weeks -join ",`n") + '];'
$data = $data.Replace('</', '<\/')
# 边练边学：data\learn\w*.json（按考点顺序排列的题目），可以只有部分周
$learn = @()
if (Test-Path "$root\data\learn") {
  foreach ($f in Get-ChildItem "$root\data\learn" -Filter 'w*.json' | Sort-Object Name) {
    $raw = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    try { $obj = $raw | ConvertFrom-Json } catch { throw "JSON 无效: learn\$($f.Name) — $($_.Exception.Message)" }
    $problems = @()
    foreach ($p in @($obj.points)) {
      if (-not $p.id -or -not $p.title -or -not $p.kp -or -not $p.howTo) { $problems += "考点缺 id/title/kp/howTo: $($p.title)" }
      foreach ($q in @($p.items)) {
        if (@($q.how).Count -lt 1) { $problems += "题目缺 how: $($q.q.Substring(0,[Math]::Min(40,$q.q.Length)))" }
        if ($q.type -eq 'mcq' -and (@($q.options).Count -ne 4 -or $q.answer -lt 0 -or $q.answer -gt 3)) { $problems += "mcq 选项/答案有误: $($q.q.Substring(0,[Math]::Min(40,$q.q.Length)))" }
        if ($q.type -eq 'tf' -and $q.a -isnot [bool]) { $problems += "tf a 不是布尔" }
      }
    }
    if ($problems.Count) { throw "learn\$($f.Name): " + ($problems -join '; ') }
    $learn += $raw.Trim()
    $report += "learn\{0}: {1} 个考点, {2} 道题" -f $f.Name, @($obj.points).Count, (@($obj.points | ForEach-Object { @($_.items).Count }) | Measure-Object -Sum).Sum
  }
}
$learnJs = ('window.MGMT_LEARN=[' + ($learn -join ",`n") + '];').Replace('</', '<\/')
# 题目中文对照：data\zh\w*.json（按题目 ID 对应；缺的题只显示英文）
$zh = @()
if (Test-Path "$root\data\zh") {
  foreach ($f in Get-ChildItem "$root\data\zh" -Filter 'w*.json' | Sort-Object Name) {
    $raw = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    try { $obj = $raw | ConvertFrom-Json } catch { throw "JSON 无效: zh\$($f.Name) — $($_.Exception.Message)" }
    $all = @($obj.items.PSObject.Properties); $done = @($all | Where-Object { $_.Value.q }).Count
    $report += "zh\{0}: {1} / {2} 题已翻译" -f $f.Name, $done, $all.Count
    $zh += $raw.Trim()
  }
}
$learnJs += ("`nwindow.MGMT_ZH=[" + ($zh -join ",`n") + '];').Replace('</', '<\/')
$tpl = [System.IO.File]::ReadAllText("$root\app.template.html", [System.Text.Encoding]::UTF8)
$page = $tpl.Replace('/*__DATA__*/', $data).Replace('/*__LEARN__*/', $learnJs)
[System.IO.File]::WriteAllText("$root\artifact.html", $page, $utf8)
$local = "<!doctype html>`n<html lang=`"zh-CN`">`n<head>`n<meta charset=`"utf-8`">`n<meta name=`"viewport`" content=`"width=device-width,initial-scale=1,viewport-fit=cover`">`n</head>`n<body>`n" + $page + "`n</body>`n</html>`n"
[System.IO.File]::WriteAllText("$root\MGMT1003复习.html", $local, $utf8)
[System.IO.File]::WriteAllText("$root\index.html", $local, $utf8)   # GitHub Pages 入口，内容与上一行相同
$report
"OK: {0} weeks, {1:N0} KB" -f $weeks.Count, ((Get-Item "$root\artifact.html").Length / 1KB)
