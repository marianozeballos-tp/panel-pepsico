# Baja de Gescom los remitos de ingreso (REMI-I) de PepsiCo y deja un renglón por artículo
# con sus kilos, para la pestaña "Objetivo de compra" del tablero Pedido PepsiCo.
# Hace 2 llamadas a la API: compras del proveedor 100 y el maestro de artículos (pesos).
#
# Uso: powershell -ExecutionPolicy Bypass -File recibido-pepsico.ps1 [-Desde 2026-08-01]

param(
  [string]$Desde = '2026-08-01',
  [string]$Salida = (Join-Path $PSScriptRoot 'recibido-pepsico.json')
)

$ErrorActionPreference = 'Stop'

# La tarea baja después objetivos y activos a base\ con ArtifactData out_dir, que no pisa archivos
# existentes: se vacía acá para que cada corrida los baje de nuevo.
$base = Join-Path $PSScriptRoot 'base'
if (Test-Path $base) { Remove-Item $base -Recurse -Force }

$gescom = Join-Path $env:USERPROFILE '.claude\skills\gescom\gescom.ps1'
$tmp = Join-Path $env:TEMP 'recibido-pepsico'
New-Item -ItemType Directory -Force $tmp | Out-Null

# fechahasta es exclusivo y filtra por fecha de carga: pedir hasta mañana.
$hasta = (Get-Date).AddDays(1).ToString('yyyy-MM-dd')

# Una sola página: get-articulos ignora la paginación y devuelve todo el maestro de una vez.
& $gescom -Endpoint inventario/api/v2/get-articulos -OutFile "$tmp\articulos.json" -Preview 0 | Out-Null
& $gescom -Endpoint compras/api/v1/get -Query "fechadesde=$Desde&fechahasta=$hasta&proveedores=100&pagesize=500" -OutFile "$tmp\compras.json" -Preview 0 | Out-Null

# En PowerShell 5.1 ConvertFrom-Json entrega el arreglo como un solo objeto: se desarma con ForEach-Object.
$leer = { param($f) (Get-Content -Raw $f -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } }

$articulos = @{}
& $leer "$tmp\articulos.json" |
  Where-Object { $_.codigoEmpresa -eq '1' } |
  ForEach-Object { $articulos[$_.codigo] = $_ }

$compras = @(& $leer "$tmp\compras.json")
if ($compras.Count -ge 500) { throw "Gescom devolvió 500 compras o más: hace falta paginar" }

$filas = foreach ($c in $compras | Where-Object { $_.codigoTipoDeComprobante -eq 'REMI-I' }) {
  foreach ($i in $c.items) {
    $a = $articulos[$i.codigoItem]
    $gramos = if ($a) { [double]$a.factorPeso } else { 0 }
    $unidades = [double]$i.cantidad * [double]$i.unidadFactor
    [pscustomobject][ordered]@{
      mes          = $c.fechaComprobante.Substring(0, 7)
      fecha        = $c.fechaComprobante.Substring(0, 10)
      fecha_carga  = $c.fechaCarga.Substring(0, 10)
      empresa      = $c.codigoEmpresa
      remito       = '{0}-{1}' -f $c.codigoPuntoVenta, $c.numeroComprobante
      codigo       = $i.codigoItem
      articulo     = if ($a) { $a.descripcion } else { '' }
      deposito     = $i.codigoDeposito
      bultos       = [double]$i.cantidad
      unid_bulto   = [double]$i.unidadFactor
      unidades     = $unidades
      gramos       = $gramos
      kg           = [math]::Round($unidades * $gramos / 1000, 3)
    }
  }
}

$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($Salida, (ConvertTo-Json @($filas) -Depth 3 -Compress), $enc)

# Un documento por mes para la página "Objetivo de compra PepsiCo" (colección recibido/<mes>).
$docs = Join-Path $PSScriptRoot 'docs'
New-Item -ItemType Directory -Force $docs | Out-Null
Get-ChildItem $docs -Filter 'recibido-*.json' | Remove-Item -Force
$ahora = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
foreach ($g in $filas | Group-Object mes) {
  $remitos = foreach ($r in $g.Group | Group-Object remito) {
    $p = $r.Group[0]
    [pscustomobject][ordered]@{
      remito      = $r.Name
      fecha       = $p.fecha
      fecha_carga = $p.fecha_carga
      bultos      = ($r.Group | Measure-Object bultos -Sum).Sum
      kg          = [math]::Round(($r.Group | Measure-Object kg -Sum).Sum, 1)
    }
  }
  # Por artículo: para la disponibilidad (cada artículo activo tiene que comprarse en el mes).
  $articulos = foreach ($a in $g.Group | Group-Object codigo) {
    [pscustomobject][ordered]@{
      codigo  = $a.Name
      bultos  = ($a.Group | Measure-Object bultos -Sum).Sum
      kg      = [math]::Round(($a.Group | Measure-Object kg -Sum).Sum, 1)
      primera = ($a.Group | ForEach-Object { $_.fecha } | Sort-Object | Select-Object -First 1)
      ultima  = ($a.Group | ForEach-Object { $_.fecha } | Sort-Object | Select-Object -Last 1)
    }
  }
  $doc = [ordered]@{
    mes            = $g.Name
    kg_total       = [math]::Round(($g.Group | Measure-Object kg -Sum).Sum, 1)
    remitos        = @($remitos | Sort-Object fecha)
    articulos      = @($articulos | Sort-Object codigo)
    ultimo_cargado = ($g.Group | ForEach-Object { $_.fecha_carga } | Sort-Object | Select-Object -Last 1)
    actualizado    = $ahora
  }
  [IO.File]::WriteAllText((Join-Path $docs "recibido-$($g.Name).json"), (ConvertTo-Json $doc -Depth 4 -Compress), $enc)
}
$kg = ($filas | ForEach-Object { $_.kg } | Measure-Object -Sum).Sum
'{0} renglones de {1} remitos, {2:N1} t -> {3}' -f @($filas).Count, @($filas | ForEach-Object { $_.remito } | Sort-Object -Unique).Count, ($kg / 1000), $Salida
