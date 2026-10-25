# ==============================================================================
# Local AI Assistant Installer (Windows 10/11 PowerShell)
# Installs Ollama, downloads optimized coding models (Qwen2.5-Coder),
# and automatically configures Zed Editor and/or Continue.dev.
# ==============================================================================

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host @"
  _                     _       _    ___   ____      _             
 | |    ___   ___  __ _| |     / \  |_ _| / ___|___ | | _____ _ __ 
 | |   / _ \ / __|/ _` | |    / _ \  | | | |   / _ \| |/ / _ \ '__|
 | |__| (_) | (__| (_| | |   / ___ \ | | | |__| (_) |   <  __/ |   
 |_____\___/ \___|\__,_|_|  /_/   \_\___| \____\___/|_|\_\___|_|   
"@ -ForegroundColor Cyan

Write-Host "Instalador interactivo de asistente de código local para Windows" -ForegroundColor White
Write-Host "================================================================`n"

# ------------------------------------------------------------------------------
# 1. DETECCIÓN DE HARDWARE
# ------------------------------------------------------------------------------
Write-Host "==> Detectando hardware y memoria RAM..." -ForegroundColor Blue

try {
    $totalMemoryBytes = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum
    $ramGb = [math]::Round($totalMemoryBytes / 1GB)
} catch {
    $ramGb = 16
}

try {
    $gpuName = (Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name | Select-Object -First 1)
} catch {
    $gpuName = "GPU estándar / CPU"
}

Write-Host "  • Sistema:    Windows ($([System.Environment]::OSVersion.Version))"
Write-Host "  • Memoria:    $ramGb GB RAM"
Write-Host "  • Gráfica:    $gpuName`n"

# ------------------------------------------------------------------------------
# 2. SELECCIÓN DE PERFIL
# ------------------------------------------------------------------------------
Write-Host "==> Selecciona el perfil de modelos:" -ForegroundColor Blue

$defaultProfile = "2"
if ($ramGb -le 8) {
    $defaultProfile = "1"
} elseif ($ramGb -ge 32) {
    $defaultProfile = "3"
}

Write-Host "  [1] Ligero      (Para 8 GB RAM o solo CPU)"
Write-Host "      • Autocompletado: qwen2.5-coder:1.5b (~1 GB RAM)"
Write-Host "      • Asistente/Chat: qwen2.5-coder:1.5b (~1 GB RAM)`n"

Write-Host "  [2] Equilibrado (Recomendado para 16 GB RAM / GPU dedicada) [Recomendado]" -ForegroundColor Green
Write-Host "      • Autocompletado: qwen2.5-coder:1.5b (~1 GB RAM, respuesta instantanea)"
Write-Host "      • Asistente/Chat: qwen2.5-coder:7b   (~4.7 GB RAM, alta calidad)`n"

Write-Host "  [3] Potente     (Para 32 GB+ RAM / GPU con 12GB+ VRAM)"
Write-Host "      • Autocompletado: qwen2.5-coder:7b   (~4.7 GB RAM)"
Write-Host "      • Asistente/Chat: qwen2.5-coder:14b  (~9 GB RAM, razonamiento maximo)`n"

Write-Host "  [4] Personalizado (Elegir manualmente)`n"

$choice = Read-Host "Elige una opción [1-4] (por defecto: $defaultProfile)"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultProfile }

switch ($choice) {
    "1" {
        $autocompleteModel = "qwen2.5-coder:1.5b"
        $chatModel = "qwen2.5-coder:1.5b"
    }
    "2" {
        $autocompleteModel = "qwen2.5-coder:1.5b"
        $chatModel = "qwen2.5-coder:7b"
    }
    "3" {
        $autocompleteModel = "qwen2.5-coder:7b"
        $chatModel = "qwen2.5-coder:14b"
    }
    "4" {
        $autocompleteModel = Read-Host "Modelo para autocompletado [qwen2.5-coder:1.5b]"
        if ([string]::IsNullOrWhiteSpace($autocompleteModel)) { $autocompleteModel = "qwen2.5-coder:1.5b" }
        $chatModel = Read-Host "Modelo para chat/asistente [qwen2.5-coder:7b]"
        if ([string]::IsNullOrWhiteSpace($chatModel)) { $chatModel = "qwen2.5-coder:7b" }
    }
    Default {
        $autocompleteModel = "qwen2.5-coder:1.5b"
        $chatModel = "qwen2.5-coder:7b"
    }
}

Write-Host "`n✓ Modelos seleccionados:" -ForegroundColor Green
Write-Host "  • Autocompletado (Tab): $autocompleteModel"
Write-Host "  • Asistente (Chat):     $chatModel`n"

# ------------------------------------------------------------------------------
# 3. VERIFICACIÓN / INSTALACIÓN DE OLLAMA
# ------------------------------------------------------------------------------
Write-Host "==> Verificando instalación de Ollama..." -ForegroundColor Blue

$ollamaInstalled = Get-Command ollama -ErrorAction SilentlyContinue

if (-not $ollamaInstalled) {
    Write-Host "! Ollama no está detectado en PATH." -ForegroundColor Yellow
    $installNow = Read-Host "¿Deseas instalar Ollama automáticamente con winget? [S/n]"
    if ([string]::IsNullOrWhiteSpace($installNow)) { $installNow = "S" }

    if ($installNow -match "^[SsYy]") {
        Write-Host "Instalando Ollama vía winget..."
        winget install --id Ollama.Ollama -e --silent --accept-package-agreements --accept-source-agreements
        # Refrescar PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } else {
        Write-Host "Ollama es necesario. Descárgalo desde https://ollama.com e inténtalo de nuevo." -ForegroundColor Red
        Exit 1
    }
} else {
    Write-Host "✓ Ollama ya está instalado." -ForegroundColor Green
}

# Iniciar Ollama si no está corriendo
try {
    $null = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 2
    Write-Host "✓ Servicio Ollama activo y respondiendo." -ForegroundColor Green
} catch {
    Write-Host "Iniciando servicio de Ollama en segundo plano..." -ForegroundColor Yellow
    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 3
}

# ------------------------------------------------------------------------------
# 4. DESCARGA DE MODELOS
# ------------------------------------------------------------------------------
Write-Host "`n==> Descargando modelos en Ollama..." -ForegroundColor Blue

Write-Host "`n[1/2] Descargando modelo de autocompletado: $autocompleteModel..." -ForegroundColor Cyan
& ollama pull $autocompleteModel

if ($autocompleteModel -ne $chatModel) {
    Write-Host "`n[2/2] Descargando modelo de chat: $chatModel..." -ForegroundColor Cyan
    & ollama pull $chatModel
}

Write-Host "`n✓ Modelos descargados y listos." -ForegroundColor Green

# ------------------------------------------------------------------------------
# 5. CONFIGURACIÓN DE EDITORES
# ------------------------------------------------------------------------------
Write-Host "`n==> Configuración de editores de código" -ForegroundColor Blue

$configZed = Read-Host "¿Deseas configurar Zed Editor automáticamente? [S/n]"
if ([string]::IsNullOrWhiteSpace($configZed)) { $configZed = "S" }

if ($configZed -match "^[SsYy]") {
    $zedDir = Join-Path $env:APPDATA "Zed"
    if (-not (Test-Path $zedDir)) {
        New-Item -ItemType Directory -Path $zedDir -Force | Out-Null
    }
    $zedFile = Join-Path $zedDir "settings.json"

    $jsonConfig = @"
{
  "show_edit_predictions": true,
  "edit_predictions": {
    "provider": "ollama",
    "mode": "eager",
    "ollama": {
      "model": "$autocompleteModel",
      "api_url": "http://localhost:11434",
      "prompt_format": "qwen",
      "max_output_tokens": 64
    }
  },
  "language_models": {
    "ollama": {
      "api_url": "http://localhost:11434"
    }
  },
  "assistant": {
    "version": "2",
    "default_model": {
      "provider": "ollama",
      "model": "$chatModel"
    }
  }
}
"@
    Set-Content -Path $zedFile -Value $jsonConfig -Encoding UTF8
    Write-Host "✓ Zed Editor configurado en: $zedFile" -ForegroundColor Green
}

$configContinue = Read-Host "¿Deseas configurar Continue.dev (VS Code / JetBrains)? [s/N]"
if ([string]::IsNullOrWhiteSpace($configContinue)) { $configContinue = "N" }

if ($configContinue -match "^[SsYy]") {
    $continueDir = Join-Path $env:USERPROFILE ".continue"
    if (-not (Test-Path $continueDir)) {
        New-Item -ItemType Directory -Path $continueDir -Force | Out-Null
    }
    $continueFile = Join-Path $continueDir "config.yaml"

    $yamlConfig = @"
name: Local AI Assistant
version: 0.0.1
schema: v1

models:
  - name: $chatModel (Chat)
    provider: ollama
    model: $chatModel
    roles:
      - chat
      - edit

autocompleteModels:
  - name: $autocompleteModel (Autocomplete FIM)
    provider: ollama
    model: $autocompleteModel
    roles:
      - autocomplete
"@
    Set-Content -Path $continueFile -Value $yamlConfig -Encoding UTF8
    Write-Host "✓ Continue.dev configurado en: $continueFile" -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 6. RESUMEN FINAL
# ------------------------------------------------------------------------------
Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host "       ¡INSTALACIÓN Y CONFIGURACIÓN COMPLETADAS CON ÉXITO!        " -ForegroundColor Green
Write-Host "==================================================================`n" -ForegroundColor Green

Write-Host "Tu entorno local de desarrollo con IA está listo:"
Write-Host "  • Motor:               Ollama (http://localhost:11434)"
Write-Host "  • Autocompletado Tab:  $autocompleteModel (FIM <100ms)"
Write-Host "  • Asistente / Chat:    $chatModel"
Write-Host ""
Write-Host "Atajos para Zed:" -ForegroundColor Cyan
Write-Host "  • Tab:          Aceptar sugerencia de autocompletado inline."
Write-Host "  • Ctrl + Enter: Abrir asistente en línea para refactorizar."
Write-Host "  • Ctrl + R:     Abrir panel de chat del proyecto."
Write-Host ""
