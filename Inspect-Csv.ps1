<#
.SYNOPSIS
  Profiles a CSV: shape, delimiter, missing values, duplicates, and per-column stats.

.EXAMPLE
  .\Inspect-Csv.ps1 -Path .\vehicle-registration.csv

.EXAMPLE
  .\Inspect-Csv.ps1 -Path .\somefile.csv -Delimiter ',' -KeyColumns 'Date','Area Name' -CountyColumn 'Area Name'

.PARAMETER Path
  The CSV file to inspect.

.PARAMETER Delimiter
  Field delimiter. Default ',' — pass ';' for semicolon-delimited files (common in EU/exported Excel data).

.PARAMETER KeyColumns
  One or more column names that together should uniquely identify a row (e.g. Date + Area Name).
  When given, the script reports how many rows violate that uniqueness.

.PARAMETER GroupColumn
  A column to group by for a coverage check (e.g. a county/category column) — reports row count per
  group, so uneven coverage (a group with fewer rows than the rest) stands out immediately.
#>
param(
  [Parameter(Mandatory = $true)] [string]$Path,
  [string]$Delimiter = ',',
  [string[]]$KeyColumns,
  [string]$GroupColumn
)

if (-not (Test-Path $Path)) { throw "File not found: $Path" }

$rows = Import-Csv -Path $Path -Delimiter $Delimiter
$columns = $rows[0].PSObject.Properties.Name

Write-Host "`n=== SHAPE ===" -ForegroundColor Cyan
"Rows: {0}   Columns: {1}" -f $rows.Count, $columns.Count
"Columns: " + ($columns -join ' | ')

Write-Host "`n=== MISSING VALUES BY COLUMN ===" -ForegroundColor Cyan
foreach ($c in $columns) {
  $blanks = ($rows | Where-Object { [string]::IsNullOrWhiteSpace($_.$c) }).Count
  if ($blanks -gt 0) {
    "{0,-30} {1,6} blank ({2:P1})" -f $c, $blanks, ($blanks / $rows.Count)
  }
}
Write-Host "`n=== NUMERIC COLUMN SUMMARY ===" -ForegroundColor Cyan
foreach ($c in $columns) {
  $vals = $rows | ForEach-Object { $_.$c } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  if ($vals.Count -eq 0) { continue }
  $asNum = $vals | ForEach-Object { $_ -as [double] }
  $numericCount = ($asNum | Where-Object { $_ -ne $null }).Count
  if ($numericCount -eq $vals.Count -and $numericCount -gt 0) {
    $stats = $asNum | Measure-Object -Minimum -Maximum -Average -Sum
    $negCount = ($asNum | Where-Object { $_ -lt 0 }).Count
    "{0,-30} min={1,-12:N2} max={2,-12:N2} avg={3,-12:N2} negatives={4}" -f $c, $stats.Minimum, $stats.Maximum, $stats.Average, $negCount
  }
}

if ($KeyColumns) {
  Write-Host "`n=== DUPLICATE KEY CHECK ($($KeyColumns -join ' + ')) ===" -ForegroundColor Cyan
  $dupes = $rows | Group-Object { $r = $_; ($KeyColumns | ForEach-Object { $r.$_ }) -join '|' } | Where-Object { $_.Count -gt 1 }
  "Duplicate rows on that key: " + $dupes.Count
  if ($dupes.Count -gt 0) {
    "First few duplicate keys:"
    $dupes | Select-Object -First 5 | ForEach-Object { "  " + $_.Name + "  (" + $_.Count + "x)" }
  }
}

if ($GroupColumn) {
  Write-Host "`n=== COVERAGE BY '$GroupColumn' ===" -ForegroundColor Cyan
  $byGroup = $rows | Group-Object $GroupColumn | Sort-Object Count
  $counts = $byGroup | Select-Object -ExpandProperty Count -Unique
  "Distinct row-counts per group: " + ($counts -join ', ')
  if ($counts.Count -gt 1) {
    "Groups with unusual counts:"
    $mode = ($byGroup | Group-Object Count | Sort-Object Count -Descending | Select-Object -First 1).Name
    $byGroup | Where-Object { $_.Count -ne $mode } | ForEach-Object { "  {0,-30} {1} rows (expected {2})" -f $_.Name, $_.Count, $mode }
  } else {
    "All groups have {0} rows each - evenly covered." -f $counts[0]
  }
}

Write-Host "`n=== FIRST 3 ROWS ===" -ForegroundColor Cyan
$rows | Select-Object -First 3 | Format-Table -AutoSize | Out-String -Width 200
