# 🚀 LocalPilot — Tu Copilot Local, Privado y Sin Límites (Zed & Continue)

Instalador interactivo y multiplataforma para desplegar un entorno de asistencia de código con Inteligencia Artificial **100% local, privado y sin límites**, equivalente a GitHub Copilot o Tabnine Pro.

Soporta autocompletado inline instantáneo (*ghost text* al escribir) y asistente de chat/refactorización inteligente impulsado por **Ollama** y la familia de modelos **Qwen2.5-Coder**.

---

## 💻 Requisitos del Sistema

La memoria RAM/VRAM disponible es el factor determinante para la fluidez y velocidad del autocompletado.

### Tabla de Perfiles y Requisitos de Hardware

| Perfil | RAM Mínima | VRAM Recomendada | Modelo Autocompletado (Tab) | Modelo Chat / Refactor | Rendimiento en Token/s |
| :--- | :---: | :---: | :--- | :--- | :---: |
| **Ligero** | **8 GB** | Integrada / CPU | `qwen2.5-coder:1.5b` (~1.0 GB) | `qwen2.5-coder:1.5b` (~1.0 GB) | Rápido (~30-60 t/s) |
| **Equilibrado (Recomendado)** | **16 GB** | **6 GB - 8 GB** | `qwen2.5-coder:1.5b` (~1.0 GB) | `qwen2.5-coder:7b` (~4.7 GB) | Ultrarrápido (>80-120 t/s) |
| **Potente** | **32 GB+** | **12 GB - 16 GB** | `qwen2.5-coder:7b` (~4.7 GB) | `qwen2.5-coder:14b` (~9.0 GB) | Inteligencia máxima |

---

### Requisitos por Plataforma

#### 🍎 macOS (Apple Silicon)
* **Requisitos mínimos:** Chip Apple Silicon (M1, M2, M3 o M4) con **8 GB de Memoria Unificada**.
* **Requisitos recomendados:** Chip M-Series con **16 GB o más de Memoria Unificada**.
  * En Apple Silicon, la memoria es compartida entre CPU y Metal GPU. En equipos de 16 GB, ambos modelos (`1.5b` y `7b`) se mantienen precargados simultáneamente en la GPU sin recurrir a memoria *swap*.
* **Espacio en disco:** 10 GB a 20 GB libres (SSD).

#### 🐧 Linux (Ubuntu, Debian, Fedora, Arch Linux, openSUSE)
* **Requisitos mínimos:** CPU de 4 núcleos modernos (x86_64), 8 GB de RAM y 15 GB de disco SSD.
* **Requisitos recomendados:**
  * **GPU NVIDIA:** GTX 1070/1660 o superior (con controladores propietarios NVIDIA y soporte CUDA). 6 GB+ de VRAM recomendados.
  * **GPU AMD:** Tarjetas Radeon compatibles con ROCm.
  * **CPU pura:** Funciona adecuadamente para el modelo `1.5b` (~20-40 t/s).
* **Distribuciones soportadas por el script:**
  * Ubuntu / Debian / Linux Mint / Pop!_OS
  * Fedora / Red Hat Enterprise Linux / CentOS Stream
  * Arch Linux / Manjaro / EndeavourOS
  * openSUSE Leap / Tumbleweed

#### 🪟 Windows (10 y 11)
* **Requisitos mínimos:** Windows 10 (versión 2004+) o Windows 11 de 64 bits, 8 GB de RAM.
* **Requisitos recomendados:** 16 GB de RAM y GPU dedicada NVIDIA RTX (3060, 4060 o superior con CUDA) o AMD Radeon moderna.

---

## ⚡ Instalación Rápida

### 1. En Linux o macOS

Clona este repositorio y ejecuta el script interactivo:

```bash
git clone https://github.com/tu-usuario/localpilot.git
cd localpilot
./install.sh
```

El script detectará automáticamente:
1. Tu sistema operativo y distribución.
2. Tu cantidad de memoria RAM y aceleración por GPU (Metal, CUDA o ROCm).
3. Te sugerirá el perfil óptimo para tu máquina.
4. Verificará/instalará **Ollama** y lo configurará como servicio en segundo plano.
5. Descargará los modelos correspondientes.
6. Configurará **Zed Editor** y/o **Continue.dev** automáticamente sin romper tus configuraciones previas.

---

### 2. En Windows (PowerShell)

Abre **PowerShell** como administrador o usuario normal y ejecuta:

```powershell
git clone https://github.com/tu-usuario/localpilot.git
cd localpilot
Set-ExecutionPolicy RemoteSigned -Scope Process
.\install.ps1
```

---

## ⚙️ ¿Cómo está configurado Zed Editor?

El script inyecta la configuración en `~/.config/zed/settings.json` (o `%APPDATA%\Zed\settings.json` en Windows):

```json
{
  "show_edit_predictions": true,
  "edit_predictions": {
    "provider": "ollama",
    "mode": "eager",
    "ollama": {
      "model": "qwen2.5-coder:1.5b",
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
      "model": "qwen2.5-coder:7b"
    }
  }
}
```

### Parámetros técnicos clave:
1. **`prompt_format: "qwen"`**:
   Indica a Zed que envíe los marcadores Fill-In-The-Middle nativos de Qwen (`<|fim_prefix|>`, `<|fim_suffix|>`, `<|fim_middle|>`). Sin esto, el modelo genera texto libre en lugar de autocompletar la línea.
2. **`max_output_tokens: 64`**:
   Limita la longitud del autocompletado para que sugiera una o dos líneas de código en vez de redactar archivos o clases enteras.
3. **`mode: "eager"`**:
   Muestra las predicciones en texto gris tenue en cuanto pausas la escritura.

---

## ⌨️ Atajos de Teclado

### En Zed Editor:
* **`Tab`**: Aceptar la sugerencia de autocompletado inline.
* **`Ctrl + Enter`** (o `Cmd + Enter`): Abrir el **Inline Assistant** para pedirle refactorizaciones o código al modelo 7B directamente en tu archivo.
* **`Cmd + R`** (o `Ctrl + R` en Linux/Windows): Abrir el panel de Chat del proyecto.

### En VS Code / Continue.dev:
* **`Tab`**: Aceptar autocompletado inline.
* **`Cmd + I`** (o `Ctrl + I`): Asistente de edición en línea.
* **`Cmd + L`** (o `Ctrl + L`): Panel lateral de chat.

---

## 💡 Solución de Problemas

### 1. Comprobar que Ollama esté corriendo:
```bash
curl http://localhost:11434/api/tags
```
Si no responde:
* **macOS:** `brew services restart ollama`
* **Linux:** `sudo systemctl restart ollama`
* **Windows:** Abre la aplicación Ollama desde el menú inicio o ejecuta `ollama serve`.

### 2. Ver modelos cargados en memoria y consumo de GPU:
```bash
ollama ps
```
Te mostrará los modelos cargados en RAM/VRAM y qué porcentaje se ejecuta en la GPU.

---

## 📄 Licencia
Este proyecto está bajo la licencia [MIT](LICENSE). Modelos Qwen2.5-Coder bajo licencia Apache 2.0.
