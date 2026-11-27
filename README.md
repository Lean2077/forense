# forense

Menú para Windows que guía el análisis forense de una foto (por ejemplo, una
foto de prensa sospechosa) con herramientas abiertas, en una PC sin placa de
video. Corre los modelos dentro de WSL y cuida la cadena de custodia: copia el
original en solo lectura, calcula su SHA-256, trabaja siempre sobre una copia y
anota cada paso en un registro.

Cada análisis termina con un "CÓMO LEERLO" que explica qué significa el
resultado y qué **no** significa. Ningún resultado es prueba por sí solo.

| Opción | Herramienta | Qué busca |
|---|---|---|
| 3 | ExifTool | Metadatos: fechas, cámara, software |
| 4 | c2patool | Credenciales de procedencia C2PA |
| 5 | TruFor + Masked-convolutions | Zonas manipuladas, ignorando logos y rótulos |
| 6 | TruFor oficial | Mapa de anomalía + mapa de confianza + score |
| 7 | CAT-Net | Recortes pegados de otro JPEG (solo JPEG) |
| 8 | ai-image-detector | ¿Generada por IA? (dos backends) |
| 9 | — | Verifica que los hashes sigan iguales |

## Requisitos

- Windows 10/11 con WSL2 y la distro `Ubuntu-24.04` (`wsl --install -d Ubuntu-24.04`).
- 8 GB de RAM como mínimo: cada modelo usa 3-4 GB. Conviene darle 5 GB o más
  a WSL en `%USERPROFILE%\.wslconfig` (`[wsl2]` → `memory=5GB`, `swap=4GB`).
- Unos 6 GB libres de disco.

## Instalación

1. Cloná o descargá este repo en una carpeta **sin `&` ni `%` en la ruta**.
2. En PowerShell, dentro de esa carpeta:
   ```powershell
   wsl -d Ubuntu-24.04 -u root -e bash instalar.sh
   ```
   Baja los tres repos de terceros en versiones fijas, crea los entornos de
   Python en `/root/venvs`, baja los pesos de TruFor y los modelos del
   detector de IA. Tarda un rato.
3. ExifTool: `winget install -e --id OliverBetz.ExifTool`
4. c2patool: bajá la versión para Windows desde
   <https://github.com/contentauth/c2pa-rs/releases> (archivos `c2patool-*-windows`)
   y dejá el ejecutable en `c2patool\c2patool\c2patool.exe`.
5. Opcional, CAT-Net: Google Drive no deja bajar el peso por script. Bajá
   `trained weight/CAT_full_v2.pth.tar` desde la
   [carpeta oficial](https://drive.google.com/drive/folders/1hBEfnFtGG6q_srBHVEmbF3fTq0IhP8jq)
   y guardalo en `pesos\`.

## Uso

Doble clic en `FORENSE.cmd` y seguí el menú en orden (1 → 2 → 3 …). La opción
`G` muestra la guía de buen uso (`interfaz/GUIA.txt`). Los casos quedan en
`casos\<nombre>\` con `original\`, `trabajo\`, `resultados\`, `hashes.txt` y
`registro.txt`. La carpeta `casos\` nunca se sube a git.

Para correr las herramientas a mano, ver [COMANDOS.md](COMANDOS.md).

## Límites conocidos

- El score de TruFor no está calibrado: sirve para ordenar imágenes de un
  mismo caso, no como probabilidad.
- En la prueba de instalación ningún backend del detector de IA marcó como IA
  la imagen IA de ejemplo. Calibralo con material propio antes de fiarte.
- Las fotos que pasaron por WhatsApp, redes o CDNs pierden buena parte de las
  trazas que buscan TruFor y CAT-Net.
- `registro.txt` y `hashes.txt` son texto plano: sirven de bitácora, no son a
  prueba de manipulación. Para un caso serio, guardá el SHA-256 también fuera
  de la PC.
- Una ruta con `&` o `%` rompe el menú: renombrá el archivo antes de ingresarlo.

## Licencias

El código de este repo es MIT. Las herramientas que baja `instalar.sh` tienen
sus propias licencias: **TruFor (GRIP-UNINA) y CAT-Net permiten solo uso no
comercial**; Masked-convolutions se apoya en ambas; ai-image-detector es MIT;
c2patool es MIT/Apache-2.0. `parches/catnet-cpu.patch` modifica cinco líneas
de CAT-Net para que corra en CPU.

Créditos: [TruFor](https://github.com/grip-unina/TruFor),
[CAT-Net](https://github.com/mjkwon2021/CAT-Net),
[Masked-convolutions](https://github.com/IDLabMedia/Masked-convolutions),
[ai-image-detector](https://github.com/lynote-ai/ai-image-detector),
[c2pa-rs](https://github.com/contentauth/c2pa-rs),
[ExifTool](https://exiftool.org).
