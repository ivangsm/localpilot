#!/usr/bin/env bash
# ==============================================================================
# LocalPilot Installer (Linux & macOS)
# Installs Ollama, downloads optimized coding models (Qwen2.5-Coder),
# and automatically configures Zed Editor and/or Continue.dev.
# ==============================================================================

set -e

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}${BOLD}"
cat << 'EOF'
  _                     _ ____  _ _       _   
 | |    ___   ___ __ _| |  _ \(_) | ___ | |_ 
 | |   / _ \ / __/ _` | | |_) | | |/ _ \| __|
 | |__| (_) | (_| (_| | |  __/| | | (_) | |_ 
 |_____\___/ \___\__,_|_|_|   |_|_|\___/ \__|
EOF
echo -e "${NC}"
echo -e "${BOLD}LocalPilot — Tu asistente de código local, privado y sin límites${NC}\n"

# ------------------------------------------------------------------------------
# 1. DETECCIÓN DEL SISTEMA Y HARDWARE
# ------------------------------------------------------------------------------
OS_TYPE="$(uname -s)"
DISTRO="Unknown"
RAM_GB=0
GPU_INFO="CPU Only"

echo -e "${BLUE}==>${NC} ${BOLD}Detectando hardware y sistema operativo...${NC}"

if [ "$OS_TYPE" = "Darwin" ]; then
    DISTRO="macOS ($(sw_vers -productVersion))"
    TOTAL_MEM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    RAM_GB=$((TOTAL_MEM_BYTES / 1024 / 1024 / 1024))
    CHIP_NAME=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")
    GPU_INFO="$CHIP_NAME (Aceleración Metal unificada)"
elif [ "$OS_TYPE" = "Linux" ]; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$NAME $VERSION_ID"
    fi
    TOTAL_MEM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    RAM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    
    # Detect GPU
    if command -v nvidia-smi >/dev/null 2>&1; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1)
        GPU_INFO="NVIDIA $GPU_NAME (CUDA)"
    elif command -v rocm-smi >/dev/null 2>&1; then
        GPU_INFO="AMD Radeon (ROCm)"
    elif lspci 2>/dev/null | grep -i "vga\|3d" | grep -iq "intel"; then
        GPU_INFO="Intel Graphics / Arc"
    fi
fi

echo -e "  • ${BOLD}Sistema:${NC}    $DISTRO"
echo -e "  • ${BOLD}Memoria:${NC}    ${RAM_GB} GB RAM"
echo -e "  • ${BOLD}Acelerador:${NC} $GPU_INFO\n"

# ------------------------------------------------------------------------------
# 2. SELECCIÓN DE PERFIL SEGÚN HARDWARE
# ------------------------------------------------------------------------------
echo -e "${BLUE}==>${NC} ${BOLD}Selecciona el perfil de modelos a instalar:${NC}"

# Sugerencia inteligente por RAM
DEFAULT_PROFILE="2"
if [ "$RAM_GB" -le 8 ]; then
    DEFAULT_PROFILE="1"
elif [ "$RAM_GB" -ge 32 ]; then
    DEFAULT_PROFILE="3"
fi

echo -e "  ${BOLD}[1] Ligero${NC}       (Para 8 GB RAM o solo CPU)"
echo -e "      • Autocompletado: ${CYAN}qwen2.5-coder:1.5b${NC} (~1 GB RAM)"
echo -e "      • Asistente/Chat: ${CYAN}qwen2.5-coder:1.5b${NC} (~1 GB RAM)"
echo -e ""
echo -e "  ${BOLD}[2] Equilibrado${NC}  (Recomendado para 16 GB RAM / Mac M1-M4 / GPU 8GB+) ${GREEN}[Recomendado]${NC}"
echo -e "      • Autocompletado: ${CYAN}qwen2.5-coder:1.5b${NC} (~1 GB RAM, respuesta <100ms)"
echo -e "      • Asistente/Chat: ${CYAN}qwen2.5-coder:7b${NC}   (~4.7 GB RAM, alta inteligencia)"
echo -e ""
echo -e "  ${BOLD}[3] Potente${NC}      (Para 32 GB+ RAM / Mac Pro-Max / GPU 16GB+)"
echo -e "      • Autocompletado: ${CYAN}qwen2.5-coder:7b${NC}   (~4.7 GB RAM)"
echo -e "      • Asistente/Chat: ${CYAN}qwen2.5-coder:14b${NC}  (~9 GB RAM, razonamiento avanzado)"
echo -e ""
echo -e "  ${BOLD}[4] Personalizado${NC} (Elegir manualmente)"
echo ""

read -rp "Elige una opción [1-4] (por defecto: $DEFAULT_PROFILE): " PROFILE_CHOICE
PROFILE_CHOICE="${PROFILE_CHOICE:-$DEFAULT_PROFILE}"

case "$PROFILE_CHOICE" in
    1)
        AUTOCOMPLETE_MODEL="qwen2.5-coder:1.5b"
        CHAT_MODEL="qwen2.5-coder:1.5b"
        ;;
    2)
        AUTOCOMPLETE_MODEL="qwen2.5-coder:1.5b"
        CHAT_MODEL="qwen2.5-coder:7b"
        ;;
    3)
        AUTOCOMPLETE_MODEL="qwen2.5-coder:7b"
        CHAT_MODEL="qwen2.5-coder:14b"
        ;;
    4)
        read -rp "Modelo para autocompletado [qwen2.5-coder:1.5b]: " AUTOCOMPLETE_MODEL
        AUTOCOMPLETE_MODEL="${AUTOCOMPLETE_MODEL:-qwen2.5-coder:1.5b}"
        read -rp "Modelo para chat/asistente [qwen2.5-coder:7b]: " CHAT_MODEL
        CHAT_MODEL="${CHAT_MODEL:-qwen2.5-coder:7b}"
        ;;
    *)
        echo -e "${RED}Opción inválida. Usando perfil equilibrado.${NC}"
        AUTOCOMPLETE_MODEL="qwen2.5-coder:1.5b"
        CHAT_MODEL="qwen2.5-coder:7b"
        ;;
esac

echo -e "\n${GREEN}✓${NC} Modelos seleccionados:"
echo -e "  • Autocompletado (Tab): ${BOLD}$AUTOCOMPLETE_MODEL${NC}"
echo -e "  • Asistente (Chat):     ${BOLD}$CHAT_MODEL${NC}\n"

# ------------------------------------------------------------------------------
# 3. INSTALACIÓN / VERIFICACIÓN DE OLLAMA
# ------------------------------------------------------------------------------
echo -e "${BLUE}==>${NC} ${BOLD}Verificando instalación de Ollama...${NC}"

if ! command -v ollama >/dev/null 2>&1; then
    echo -e "${YELLOW}! Ollama no está instalado.${NC}"
    read -rp "¿Deseas instalar Ollama automáticamente ahora? [S/n]: " INSTALL_OLLAMA
    INSTALL_OLLAMA="${INSTALL_OLLAMA:-S}"
    
    if [[ "$INSTALL_OLLAMA" =~ ^[SsYy]$ ]]; then
        if [ "$OS_TYPE" = "Darwin" ]; then
            if command -v brew >/dev/null 2>&1; then
                echo -e "Instalando Ollama vía Homebrew..."
                brew install ollama
                brew services start ollama
            else
                echo -e "${YELLOW}Homebrew no detectado. Descargando Ollama para macOS...${NC}"
                curl -fsSL https://ollama.com/download/Ollama-darwin.zip -o /tmp/Ollama.zip
                unzip -q /tmp/Ollama.zip -d /Applications/
                open /Applications/Ollama.app
            fi
        elif [ "$OS_TYPE" = "Linux" ]; then
            echo -e "Instalando Ollama vía script oficial de Linux..."
            curl -fsSL https://ollama.com/install.sh | sh
            if command -v systemctl >/dev/null 2>&1; then
                sudo systemctl enable --now ollama || true
            fi
        fi
    else
        echo -e "${RED}Ollama es necesario para continuar. Por favor instálalo desde https://ollama.com${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} Ollama ya está instalado ($(ollama --version 2>/dev/null || echo 'versión detectada'))."
fi

# Asegurar que el servicio de Ollama esté respondiendo
echo -e "\n${BLUE}==>${NC} ${BOLD}Comprobando estado del servicio Ollama (http://localhost:11434)...${NC}"
OLLAMA_READY=false
for i in {1..5}; do
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        OLLAMA_READY=true
        break
    fi
    echo "Iniciando servicio de Ollama en segundo plano (intento $i)..."
    if [ "$OS_TYPE" = "Darwin" ]; then
        brew services start ollama 2>/dev/null || ollama serve >/dev/null 2>&1 &
    else
        sudo systemctl start ollama 2>/dev/null || ollama serve >/dev/null 2>&1 &
    fi
    sleep 2
done

if [ "$OLLAMA_READY" = false ]; then
    echo -e "${YELLOW}Advertencia: No se pudo verificar la API de Ollama en localhost:11434.${NC}"
    echo -e "Asegúrate de ejecutar 'ollama serve' en otra terminal si es necesario."
else
    echo -e "${GREEN}✓${NC} Servicio Ollama activo y respondiendo."
fi

# ------------------------------------------------------------------------------
# 4. DESCARGA DE MODELOS
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}==>${NC} ${BOLD}Descargando modelos en Ollama...${NC}"

echo -e "\n[1/2] Descargando modelo de autocompletado: ${CYAN}$AUTOCOMPLETE_MODEL${NC}..."
ollama pull "$AUTOCOMPLETE_MODEL"

if [ "$AUTOCOMPLETE_MODEL" != "$CHAT_MODEL" ]; then
    echo -e "\n[2/2] Descargando modelo de chat: ${CYAN}$CHAT_MODEL${NC}..."
    ollama pull "$CHAT_MODEL"
fi

echo -e "\n${GREEN}✓${NC} Modelos listos en Ollama."

# ------------------------------------------------------------------------------
# 5. CONFIGURACIÓN DE EDITORES
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}==>${NC} ${BOLD}Configuración de editores de código${NC}"

# A) Configurar Zed
read -rp "¿Deseas configurar Zed Editor automáticamente? [S/n]: " CONFIGURE_ZED
CONFIGURE_ZED="${CONFIGURE_ZED:-S}"

if [[ "$CONFIGURE_ZED" =~ ^[SsYy]$ ]]; then
    ZED_CONFIG_DIR="$HOME/.config/zed"
    ZED_SETTINGS_FILE="$ZED_CONFIG_DIR/settings.json"
    mkdir -p "$ZED_CONFIG_DIR"

    if [ -f "$ZED_SETTINGS_FILE" ]; then
        echo -e "Actualizando configuración existente en: $ZED_SETTINGS_FILE..."
        # Utilizar Python para mezclar el JSON de forma segura respetando el resto del archivo
        python3 - << EOF
import json, re, sys

path = "$ZED_SETTINGS_FILE"
try:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remover comentarios de una sola linea para parsear JSON
    clean = re.sub(r'^\s*//.*$', '', content, flags=re.MULTILINE)
    data = json.loads(clean)
except Exception:
    data = {}

data["show_edit_predictions"] = True
data["edit_predictions"] = {
    "provider": "ollama",
    "mode": "eager",
    "ollama": {
        "model": "$AUTOCOMPLETE_MODEL",
        "api_url": "http://localhost:11434",
        "prompt_format": "qwen",
        "max_output_tokens": 64
    }
}
if "language_models" not in data:
    data["language_models"] = {}
data["language_models"]["ollama"] = {
    "api_url": "http://localhost:11434"
}
data["assistant"] = {
    "version": "2",
    "default_model": {
        "provider": "ollama",
        "model": "$CHAT_MODEL"
    }
}

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
EOF
    else
        echo -e "Creando nueva configuración en: $ZED_SETTINGS_FILE..."
        cat << EOF > "$ZED_SETTINGS_FILE"
{
  "show_edit_predictions": true,
  "edit_predictions": {
    "provider": "ollama",
    "mode": "eager",
    "ollama": {
      "model": "$AUTOCOMPLETE_MODEL",
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
      "model": "$CHAT_MODEL"
    }
  }
}
EOF
    fi
    echo -e "${GREEN}✓${NC} Zed Editor configurado con éxito."
fi

# B) Configurar Continue.dev (VS Code / Cursor / JetBrains)
read -rp "¿Deseas configurar la extensión Continue.dev (VS Code / Cursor / JetBrains)? [s/N]: " CONFIGURE_CONTINUE
CONFIGURE_CONTINUE="${CONFIGURE_CONTINUE:-N}"

if [[ "$CONFIGURE_CONTINUE" =~ ^[SsYy]$ ]]; then
    CONTINUE_DIR="$HOME/.continue"
    mkdir -p "$CONTINUE_DIR"
    CONTINUE_FILE="$CONTINUE_DIR/config.yaml"
    
    cat << EOF > "$CONTINUE_FILE"
name: Local AI Assistant
version: 0.0.1
schema: v1

models:
  - name: $CHAT_MODEL (Chat)
    provider: ollama
    model: $CHAT_MODEL
    roles:
      - chat
      - edit

autocompleteModels:
  - name: $AUTOCOMPLETE_MODEL (Autocomplete FIM)
    provider: ollama
    model: $AUTOCOMPLETE_MODEL
    roles:
      - autocomplete
EOF
    echo -e "${GREEN}✓${NC} Continue.dev configurado en: $CONTINUE_FILE"
fi

# ------------------------------------------------------------------------------
# 6. RESUMEN Y FINALIZACIÓN
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}${BOLD}==================================================================${NC}"
echo -e "${GREEN}${BOLD}       ¡INSTALACIÓN Y CONFIGURACIÓN COMPLETADAS CON ÉXITO!        ${NC}"
echo -e "${GREEN}${BOLD}==================================================================${NC}\n"

echo -e "Tu entorno local de desarrollo con IA está listo:"
echo -e "  • ${BOLD}Motor:${NC}               Ollama (http://localhost:11434)"
echo -e "  • ${BOLD}Autocompletado Tab:${NC}  $AUTOCOMPLETE_MODEL (Latencia mínima, FIM)"
echo -e "  • ${BOLD}Asistente / Chat:${NC}    $CHAT_MODEL"
echo ""
echo -e "${CYAN}Atajos para usar en Zed:${NC}"
echo -e "  • ${BOLD}Tab${NC}:                   Aceptar sugerencia de autocompletado inline."
echo -e "  • ${BOLD}Ctrl + Enter${NC}:          Abrir el Asistente en línea para refactorizar código."
echo -e "  • ${BOLD}Cmd + R${NC} (Ctrl+R):       Abrir panel de chat lateral del proyecto."
echo ""
