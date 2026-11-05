# Guarda en docs\pedido.json la foto del pedido sugerido que la tarea programada acaba de
# consultar en Base Gescom (consultar_base con pedido-pepsico.sql).
# La respuesta de la herramienta queda en la transcripción de la sesión (.jsonl): este script
# busca la más reciente que tenga una respuesta con las columnas del pedido y la copia.
#
# Uso: powershell -ExecutionPolicy Bypass -File guardar-pedido.ps1

param([int]$Minutos = 60)

$ErrorActionPreference = 'Stop'
$enc = New-Object System.Text.UTF8Encoding($false)
$raiz = '\\?\' + (Join-Path $env:USERPROFILE '.claude\projects')
$desde = (Get-Date).AddMinutes(-$Minutos)
$archivos = Get-ChildItem -LiteralPath $raiz -Recurse -Filter '*.jsonl' -File |
  Where-Object { $_.LastWriteTime -ge $desde } | Sort-Object LastWriteTime -Descending

$payload = $null
foreach ($a in $archivos) {
  $lineas = [IO.File]::ReadAllLines($a.FullName)
  for ($i = $lineas.Count - 1; $i -ge 0 -and -not $payload; $i--) {
    $l = $lineas[$i]
    if (-not ($l.Contains('tool_result') -and $l.Contains('\"ventas_hasta\"') -and $l.Contains('{\"filas\"'))) { continue }
    $o = $l | ConvertFrom-Json
    foreach ($c in ($o.message.content | ForEach-Object { $_ })) {
      $x = $c.content
      if ($x -isnot [string]) { $x = (@($x | ForEach-Object { $_ }) | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text }
      if ($x -and $x.TrimStart().StartsWith('{"filas"') -and $x.Contains('"ventas_hasta"')) { $payload = $x }
    }
  }
  if ($payload) { break }
}
if (-not $payload) { throw "No encontré la respuesta de la consulta del pedido en las últimas $Minutos minutos" }

$p = $payload | ConvertFrom-Json
$filas = @($p.datos | ForEach-Object { $_ })
if ($filas.Count -eq 0) { throw 'La consulta del pedido vino sin filas' }
$doc = [ordered]@{
  generado  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  cobertura = 14; plazo = 0; descontar = $true
  recortado = [bool]$p.recortado
  datos     = $filas
}
$out = Join-Path $PSScriptRoot 'docs\pedido.json'
[IO.File]::WriteAllText($out, (ConvertTo-Json $doc -Depth 4 -Compress), $enc)
'{0} articulos, stock al {1} -> {2}' -f $filas.Count, $filas[0].fecha_stock, $out
