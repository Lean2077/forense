#!/usr/bin/env bash
# Instala las herramientas de terceros dentro de Ubuntu (WSL), sin GPU.
# Uso, desde PowerShell en la carpeta del repo:
#   wsl -d Ubuntu-24.04 -u root -e bash instalar.sh
# Se puede volver a correr: lo que ya está instalado no se repite.
set -euo pipefail
cd "$(dirname "$0")"

# Versiones probadas. Cambiar un commit es cambiar el resultado de los análisis.
TRUFOR=ae54475df6f41a491d7615100feb19263dec13f7
MASKED=8d22ecdc15f1d5e54b9eb5e38821ce6cd1f4d972
AIDET=d3f4976d36c59974a25f55a0a7850b9866d3223b
VENVS=/root/venvs   # en disco Linux: sobre /mnt/c los entornos son muy lentos
CPU_INDEX=https://download.pytorch.org/whl/cpu

echo "== Paquetes del sistema"
apt-get update -qq
apt-get install -y -qq build-essential libgl1 libglib2.0-0 git curl unzip >/dev/null

command -v uv >/dev/null || [ -x /root/.local/bin/uv ] || curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="/root/.local/bin:$PATH"

clonar() {  # carpeta url commit
  [ -d "$1/.git" ] || git clone -q "$2" "$1"
  git -C "$1" fetch -q origin "$3" 2>/dev/null || true
  git -C "$1" checkout -q "$3"
}
echo "== Repositorios"
clonar TruFor https://github.com/grip-unina/TruFor.git "$TRUFOR"
clonar Masked-convolutions https://github.com/IDLabMedia/Masked-convolutions.git "$MASKED"
clonar ai-image-detector https://github.com/lynote-ai/ai-image-detector.git "$AIDET"

# CAT-Net trae .cuda() fijo; el parche lo pasa a CPU.
if git -C Masked-convolutions apply --check ../parches/catnet-cpu.patch 2>/dev/null; then
  git -C Masked-convolutions apply ../parches/catnet-cpu.patch
fi

echo "== Entornos de Python (tarda: baja PyTorch para CPU)"
mkdir -p "$VENVS"
[ -x "$VENVS/localizacion/bin/python" ] || uv venv -q --python 3.10 "$VENVS/localizacion"
uv pip install -q --python "$VENVS/localizacion/bin/python" \
  --extra-index-url "$CPU_INDEX" --index-strategy unsafe-best-match -r requisitos/localizacion.txt
[ -x "$VENVS/aidetector/bin/python" ] || uv venv -q --python 3.11 "$VENVS/aidetector"
uv pip install -q --python "$VENVS/aidetector/bin/python" \
  --extra-index-url "$CPU_INDEX" --index-strategy unsafe-best-match -r requisitos/aidetector.txt
uv pip install -q --python "$VENVS/aidetector/bin/python" --no-deps -e ./ai-image-detector

echo "== Pesos de TruFor"
mkdir -p pesos
if [ ! -f pesos/trufor.pth.tar ]; then
  tmp=$(mktemp -d)
  curl -fL --retry 3 -o "$tmp/w.zip" https://www.grip.unina.it/download/prog/TruFor/TruFor_weights.zip
  unzip -q "$tmp/w.zip" -d "$tmp"
  f=$(find "$tmp" -name 'trufor.pth.tar' | head -1)
  [ -n "$f" ] || { echo "El zip de TruFor no trae trufor.pth.tar"; exit 1; }
  mv "$f" pesos/trufor.pth.tar
  rm -rf "$tmp"
fi

# FORENSE.cmd corre el detector sin internet: los modelos tienen que quedar en caché ahora.
echo "== Modelos del detector de IA (primera descarga)"
for b in ultra sentry-convnext-small; do
  "$VENVS/aidetector/bin/aidetect" detect ai-image-detector/test_images/human.jpeg --backend "$b" --device cpu >/dev/null
done

echo
echo "Listo. Falta en Windows: ExifTool (winget install -e --id OliverBetz.ExifTool),"
echo "c2patool en c2patool\\c2patool\\c2patool.exe y, opcional, el peso de CAT-Net (ver README)."
