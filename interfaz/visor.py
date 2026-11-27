"""Convierte los .npz de TruFor oficial en PNG (imagen | mapa | confianza) y un resumen ordenado por score.

Uso: visor.py <carpeta_npz> <carpeta_imagenes>
"""
import glob
import os
import sys

import matplotlib

matplotlib.use("Agg")  # sin ventana: corre dentro de WSL
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image

out_dir, img_dir = sys.argv[1], sys.argv[2]
scores = []
for f in sorted(glob.glob(os.path.join(out_dir, "*.npz"))):
    d = np.load(f)
    name = os.path.basename(f)[: -len(".npz")]
    img = os.path.join(img_dir, name)
    panels = [("Imagen", np.asarray(Image.open(img).convert("RGB")), {})] if os.path.exists(img) else []
    panels.append(("Mapa de anomalia (rojo = sospechoso)", d["map"], {"cmap": "RdBu_r", "vmin": 0, "vmax": 1}))
    if "conf" in d.files:
        panels.append(("Confianza (negro = NO fiarse del mapa)", d["conf"], {"cmap": "gray", "vmin": 0, "vmax": 1}))
    fig, axs = plt.subplots(1, len(panels), figsize=(6 * len(panels), 6), squeeze=False)
    for ax, (title, data, kw) in zip(axs[0], panels):
        ax.imshow(data, **kw)
        ax.set_title(title)
        ax.axis("off")
    score = float(d["score"]) if "score" in d.files else None
    fig.suptitle(name + (f"   score={score:.3f}" if score is not None else ""))
    png = f[: -len(".npz")] + "_visual.png"
    fig.savefig(png, dpi=100, bbox_inches="tight")
    plt.close(fig)
    if score is not None:
        scores.append((score, name))
    print("  ->", os.path.basename(png))

if scores:
    with open(os.path.join(out_dir, "resumen_scores.txt"), "w", encoding="utf-8") as fh:
        fh.write("Ranking relativo dentro del caso (NO es probabilidad de falsedad)\n\n")
        for s, n in sorted(scores, reverse=True):
            fh.write(f"{s:.3f}  {n}\n")
    print("  -> resumen_scores.txt")
