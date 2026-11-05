# Publica la copia de sólo lectura del Panel PepsiCo en GitHub Pages
# (repo marianozeballos-tp/panel-pepsico, rama main).
#
# Antes de correrlo tienen que estar al día, en la carpeta docs:
#   pedido.json          foto del pedido sugerido (consulta del panel en Base Gescom, 14 días)
#   objetivos.json       objetivos de la base del panel, { "AAAA-MM": {mes, toneladas, actualizado} }
#   recibido-AAAA-MM.json  los arma recibido-pepsico.ps1
#   activos-AAAA-MM.json   lista de artículos activos de cada mes
#
# Uso: powershell -ExecutionPolicy Bypass -File publicar-github.ps1

param(
  [string]$Repo = (Join-Path (Split-Path $PSScriptRoot -Parent) 'panel-pepsico-web'),
  [string]$Remoto = 'https://github.com/marianozeballos-tp/panel-pepsico.git',
  [switch]$SinSubir
)

$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
$docs = Join-Path $src 'docs'
$enc = New-Object System.Text.UTF8Encoding($false)
$leer = { param($f) Get-Content -Raw $f -Encoding UTF8 | ConvertFrom-Json }

New-Item -ItemType Directory -Force $Repo | Out-Null
if (-not (Test-Path (Join-Path $Repo '.git'))) {
  git -C $Repo init -b main | Out-Null
  git -C $Repo remote add origin $Remoto
  git -C $Repo config user.name 'marianozeballos-tp'
  git -C $Repo config user.email 'marianozeballos-tp@users.noreply.github.com'
}

# Datos: un archivo por colección, { id: documento }, como la base del panel.
$datos = Join-Path $Repo 'datos'
New-Item -ItemType Directory -Force $datos | Out-Null
foreach ($col in 'recibido', 'activos') {
  $o = [ordered]@{}
  Get-ChildItem $docs -Filter "$col-*.json" | Sort-Object Name | ForEach-Object {
    $d = & $leer $_.FullName
    $o[$d.mes] = $d
  }
  [IO.File]::WriteAllText((Join-Path $datos "$col.json"), (ConvertTo-Json $o -Depth 6 -Compress), $enc)
}
Copy-Item (Join-Path $docs 'objetivos.json') (Join-Path $datos 'objetivos.json') -Force
Copy-Item (Join-Path $docs 'pedido.json') (Join-Path $datos 'pedido.json') -Force

# Página: el panel de claude.ai con el reemplazo de sólo lectura de window.claude.
$panel = [IO.File]::ReadAllText((Join-Path $src 'panel-pepsico.html'), $enc)
$marca = '<div class="wrap">'
if ($panel.IndexOf($marca) -lt 0) { throw "Falta '$marca' en panel-pepsico.html" }
$panel = $panel.Replace($marca, "<script src=""claude-shim.js""></script>`n" + $marca)
$cabeza = "<!doctype html>`n<html lang=""es"">`n<meta charset=""utf-8"">`n<meta name=""viewport"" content=""width=device-width, initial-scale=1"">`n"
[IO.File]::WriteAllText((Join-Path $Repo 'index.html'), $cabeza + $panel, $enc)

Copy-Item (Join-Path $src 'claude-shim.js') $Repo -Force
Copy-Item (Join-Path $src 'panel-pepsico.html') $Repo -Force
Copy-Item (Join-Path $src 'recibido-pepsico.ps1') $Repo -Force
Copy-Item (Join-Path $src 'publicar-github.ps1') $Repo -Force
Copy-Item (Join-Path $src 'disponibilidad-pepsico.md') $Repo -Force
if (Test-Path (Join-Path $src 'README.md')) { Copy-Item (Join-Path $src 'README.md') $Repo -Force }
[IO.File]::WriteAllText((Join-Path $Repo '.nojekyll'), '', $enc)

if ($SinSubir) { "Armado en $Repo, sin subir."; return }
git -C $Repo add -A
$cambios = git -C $Repo status --porcelain
if (-not $cambios) { 'Sin cambios para publicar.'; return }
$p = & $leer (Join-Path $docs 'pedido.json')
$msg = "Datos al $($p.generado.Substring(0, 10))`n`nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C $Repo commit -q -m $msg
git -C $Repo push -u origin main
if ($LASTEXITCODE -ne 0) { throw 'git push no pudo subir los cambios' }
'Publicado: https://marianozeballos-tp.github.io/panel-pepsico/'
