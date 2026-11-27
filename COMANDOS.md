# Comandos (equipo sin GPU: todo en CPU, dentro de Ubuntu-24.04 en WSL)

> Uso normal: doble clic en **FORENSE.cmd** (menú guiado con casos, hashes y registro).
> Lo de abajo es para correr las herramientas a mano.

Abrir Ubuntu desde PowerShell:

```powershell
wsl -d Ubuntu-24.04 -u root
```

Dentro de Ubuntu, la carpeta del repo se ve como `/mnt/c/...` (`wslpath -a 'C:\ruta\al\repo'` la muestra).
Los entornos de Python viven en `/root/venvs/` (en disco Linux: sobre /mnt/c serían muy lentos).

```bash
F=$(wslpath -a 'C:\ruta\al\repo')   # cambiá la ruta por la tuya
```

## Nivel 1 — Localización de manipulación

Masked-convolutions + TruFor, enmascarado automático de logos (`-idc`). ~2 min/imagen, ~3,5 GB RAM.
Este modo guarda solo `map` (sin `conf` ni `score`).

```bash
cd $F/Masked-convolutions/TruFor
/root/venvs/localizacion/bin/python test.py -g -1 -w $F/pesos/trufor.pth.tar -idc -in <imagen_o_carpeta> -out <salida>
# máscara manual (PNG blanco = ignorar, mismo tamaño y nombre que la imagen):
/root/venvs/localizacion/bin/python test.py -g -1 -w $F/pesos/trufor.pth.tar -in <imagen> -cover <mascaras> -out <salida>
```

TruFor oficial (contraste; da `map`, `conf` y `score`). ~1 min/imagen.

```bash
cd $F/TruFor/test_docker/src
/root/venvs/localizacion/bin/python trufor_test.py -gpu -1 -in <imagen_o_carpeta> -out <salida> TEST.MODEL_FILE $F/pesos/trufor.pth.tar
```

CAT-Net (enmascarado) — **falta el peso**: Google Drive no deja bajarlo por script.
Bajalo a mano desde el navegador: carpeta oficial
https://drive.google.com/drive/folders/1hBEfnFtGG6q_srBHVEmbF3fTq0IhP8jq → `trained weight/CAT_full_v2.pth.tar`
y guardalo en `forense\pesos\`. Luego:

```bash
cd $F/Masked-convolutions/CAT-Net
/root/venvs/localizacion/bin/python test.py -g -1 -w $F/pesos/CAT_full_v2.pth.tar -idc -in <imagen> -out <salida>
```

(`test.py` de CAT-Net fue parcheado para CPU: `.cuda()` → `.to(device)` y `map_location` en `torch.load`.)

## Nivel 2 — ¿Generada por IA?

```bash
A=/root/venvs/aidetector/bin/aidetect
$A detect foto.jpg --backend ultra
$A detect foto.jpg --backend sentry-convnext-small     # segundo backend, siempre comparar
$A detect <carpeta> --backend ultra --csv informe.csv
$A serve                                                # interfaz web local
```

0,45–0,55 = evidencia débil. En la prueba de instalación ningún backend marcó como IA la imagen IA de ejemplo del repo: calibrar con material propio antes de fiarse.

## Nivel 5 — Procedencia C2PA (Windows, PowerShell)

```powershell
.\c2patool\c2patool\c2patool.exe foto.jpg --detailed   # desde la carpeta del repo
```

## Memoria

Recomendado en `%USERPROFILE%\.wslconfig`: `[wsl2]` con `memory=5GB` y `swap=4GB` (después, `wsl --shutdown`).
Docker comparte esa memoria: con los contenedores corriendo, los modelos pueden morir por falta de RAM.
