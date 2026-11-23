param(
    [Parameter(Mandatory=$true)][string]$ProjetoThirdPerson,
    [string]$UnrealRoot = ''
)
$ErrorActionPreference = 'Stop'
$Pasta = Split-Path -Parent $MyInvocation.MyCommand.Path
$UprojectOriginal = (Resolve-Path -LiteralPath $ProjetoThirdPerson).Path
if (-not $UprojectOriginal.EndsWith('.uproject', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Selecione o .uproject de um projeto Third Person oficial da Unreal Engine 5.'
}
$OrigemDir = Split-Path -Parent $UprojectOriginal
$GameMode = Join-Path $OrigemDir 'Content\ThirdPerson\Blueprints\BP_ThirdPersonGameMode.uasset'
if (-not (Test-Path -LiteralPath $GameMode)) {
    throw 'Projeto Third Person nao encontrado. Use Games > Third Person > Blueprint > Variant None.'
}
$Destino = Join-Path $Pasta 'ProjetoBaseplate'
if (Test-Path -LiteralPath $Destino) {
    throw 'A pasta ProjetoBaseplate ja existe. Renomeie-a para nao sobrescrever arquivos.'
}
New-Item -ItemType Directory -Path $Destino | Out-Null
& robocopy.exe $OrigemDir $Destino /E /XD Binaries Intermediate Saved DerivedDataCache .git /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw 'Falha ao copiar o projeto.' }
$Uproject = Join-Path $Destino (Split-Path -Leaf $UprojectOriginal)

$Descriptor = Get-Content -LiteralPath $Uproject -Raw | ConvertFrom-Json
$Plugins = @()
if ($Descriptor.PSObject.Properties.Name -contains 'Plugins') {
    $Plugins = @($Descriptor.Plugins)
}
if (-not ($Plugins | Where-Object { $_.Name -eq 'PythonScriptPlugin' })) {
    $Plugins += [PSCustomObject]@{ Name='PythonScriptPlugin'; Enabled=$true }
}
if ($Descriptor.PSObject.Properties.Name -contains 'Plugins') {
    $Descriptor.Plugins = $Plugins
} else {
    $Descriptor | Add-Member -NotePropertyName 'Plugins' -NotePropertyValue $Plugins
}
$Descriptor | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $Uproject -Encoding UTF8

if ([string]::IsNullOrWhiteSpace($UnrealRoot)) {
    $Instalacoes = @(Get-ChildItem 'C:\Program Files\Epic Games' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^UE_5\.' } | Sort-Object Name -Descending)
    if ($Instalacoes.Count -gt 0) { $UnrealRoot = $Instalacoes[0].FullName }
}
if ([string]::IsNullOrWhiteSpace($UnrealRoot)) {
    $UnrealRoot = Read-Host 'Pasta da Unreal Engine 5 instalada'
}
$Editor = Join-Path $UnrealRoot 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe'
$UAT = Join-Path $UnrealRoot 'Engine\Build\BatchFiles\RunUAT.bat'
if (-not (Test-Path -LiteralPath $Editor) -or -not (Test-Path -LiteralPath $UAT)) {
    throw 'A instalacao da Unreal nao foi encontrada.'
}
& $Editor $Uproject '-run=pythonscript' "-script=$(Join-Path $Pasta 'criar_mapa.py')" '-unattended' '-nop4' '-nosplash'
if ($LASTEXITCODE -ne 0) { throw 'Falha na geracao do mapa.' }
if (-not (Test-Path -LiteralPath (Join-Path $Destino 'Content\Maps\Baseplate.umap'))) {
    throw 'A Unreal nao gerou o mapa Baseplate. Consulte Saved\Logs.'
}
$DefaultEngine = Join-Path $Destino 'Config\DefaultEngine.ini'
$Ini = Get-Content -LiteralPath $DefaultEngine -Raw
$Linhas = @(
    'EditorStartupMap=/Game/Maps/Baseplate',
    'GameDefaultMap=/Game/Maps/Baseplate',
    'GlobalDefaultGameMode=/Game/ThirdPerson/Blueprints/BP_ThirdPersonGameMode.BP_ThirdPersonGameMode_C'
)
foreach ($Linha in $Linhas) {
    $Chave = $Linha.Split('=')[0]
    $Ini = [regex]::Replace($Ini, "(?m)^\s*${Chave}\s*=.*(?:\r?\n|$)", '')
}
$Ini += "`r`n[/Script/EngineSettings.GameMapsSettings]`r`n" + ($Linhas -join "`r`n") + "`r`n"
Set-Content -LiteralPath $DefaultEngine -Value $Ini -Encoding UTF8
$Exportar = Join-Path $Pasta 'JogoWindows'
New-Item -ItemType Directory -Path $Exportar -ErrorAction SilentlyContinue | Out-Null
& $UAT 'BuildCookRun' "-project=$Uproject" '-noP4' '-platform=Win64' '-clientconfig=Shipping' '-cook' '-stage' '-pak' '-package' '-archive' "-archivedirectory=$Exportar" '-build'
if ($LASTEXITCODE -ne 0) { throw 'Falha no empacotamento para Windows.' }
$Exes = @(Get-ChildItem -Path $Exportar -Filter '*.exe' -Recurse -File -ErrorAction SilentlyContinue)
if ($Exes.Count -eq 0) { throw 'Nenhum executavel foi encontrado na pasta JogoWindows.' }
Write-Host 'Executavel gerado. Distribua a pasta JogoWindows completa.'
$Exes | ForEach-Object { Write-Host $_.FullName }
