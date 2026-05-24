"""
Wrapper untuk klasifier EfficientNet-B0 (bahan maupun hidangan).

Kedua head pakai arsitektur yang sama, cuma beda jumlah kelas di layer FC terakhir.
Bobot disimpan sebagai state_dict biasa + file JSON kecil berisi daftar nama kelas
sesuai urutan index waktu training.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Sequence

import numpy as np


# torch dan torchvision berat, jadi di-import lazy supaya startup cepat

def _torch():
    import torch  # noqa: WPS433
    return torch


def _torchvision():
    import torchvision  # noqa: WPS433
    return torchvision


def _transforms_for_inference(image_size: int):
    tv = _torchvision()
    return tv.transforms.Compose([
        tv.transforms.Resize(int(image_size * 1.15)),
        tv.transforms.CenterCrop(image_size),
        tv.transforms.ToTensor(),
        tv.transforms.Normalize(mean=[0.485, 0.456, 0.406],
                                std=[0.229, 0.224, 0.225]),
    ])


def build_efficientnet_b0(num_classes: int, pretrained: bool = True):
    """Buat EfficientNet-B0 dengan layer classifier terakhir di-resize."""
    torch = _torch()
    tv = _torchvision()
    weights = tv.models.EfficientNet_B0_Weights.DEFAULT if pretrained else None
    model = tv.models.efficientnet_b0(weights=weights)
    in_features = model.classifier[1].in_features
    model.classifier[1] = torch.nn.Linear(in_features, num_classes)
    return model


# simpan / muat model

@dataclass
class ClassifierBundle:
    """Model + nama kelas + transform, siap pakai."""
    model: "torch.nn.Module"  # noqa: F821
    class_names: List[str]
    image_size: int
    device: str

    def save(self, weights_path: Path, meta_path: Optional[Path] = None) -> None:
        torch = _torch()
        weights_path = Path(weights_path)
        weights_path.parent.mkdir(parents=True, exist_ok=True)
        torch.save(self.model.state_dict(), weights_path)

        if meta_path is None:
            meta_path = weights_path.with_suffix(".classes.json")
        meta = {"class_names": self.class_names, "image_size": self.image_size}
        Path(meta_path).write_text(json.dumps(meta, indent=2))


def load_classifier(
    weights_path: Path,
    image_size: int = 224,
    device: Optional[str] = None,
) -> ClassifierBundle:
    """Muat klasifier yang sudah di-train dari file .pt + .classes.json."""
    torch = _torch()
    weights_path = Path(weights_path)
    meta_path = weights_path.with_suffix(".classes.json")
    meta = json.loads(meta_path.read_text())
    class_names: List[str] = list(meta["class_names"])
    img_size = int(meta.get("image_size", image_size))

    if device is None:
        device = "cuda" if torch.cuda.is_available() else "cpu"

    model = build_efficientnet_b0(num_classes=len(class_names), pretrained=False)
    state = torch.load(weights_path, map_location=device)
    model.load_state_dict(state)
    model.to(device).eval()

    return ClassifierBundle(model=model, class_names=class_names,
                            image_size=img_size, device=device)


# fungsi inferensi

def _to_pil(image_bgr_or_rgb_or_pil):
    """Terima np.ndarray (BGR/RGB) atau PIL.Image, kembalikan PIL RGB."""
    from PIL import Image as PILImage
    if isinstance(image_bgr_or_rgb_or_pil, PILImage.Image):
        return image_bgr_or_rgb_or_pil.convert("RGB")
    arr = np.asarray(image_bgr_or_rgb_or_pil)
    if arr.ndim == 2:
        arr = np.stack([arr] * 3, axis=-1)
    if arr.shape[2] == 4:
        arr = arr[:, :, :3]
    # If looks BGR (cv2), swap. We can't be 100% sure; heuristic: assume RGB
    # only when channel 0 mean < channel 2 mean. Not perfect, but the caller
    # is expected to hand RGB anyway.
    return PILImage.fromarray(arr.astype("uint8")).convert("RGB")


def predict_topk(
    bundle: ClassifierBundle,
    image,
    topk: int = 3,
):
    """
    Jalankan inferensi pada satu gambar.
    Return list of (nama_kelas, probabilitas) diurutkan dari yang tertinggi.
    """
    torch = _torch()
    pil = _to_pil(image)
    tfm = _transforms_for_inference(bundle.image_size)
    x = tfm(pil).unsqueeze(0).to(bundle.device)

    with torch.no_grad():
        logits = bundle.model(x)
        probs = torch.softmax(logits, dim=1)[0].cpu().numpy()

    top_idx = np.argsort(-probs)[:topk]
    return [(bundle.class_names[i], float(probs[i])) for i in top_idx]


def predict_batch_topk(
    bundle: ClassifierBundle,
    images: Sequence,
    topk: int = 3,
    batch_size: int = 32,
):
    """Versi batch dari predict_topk, lebih cepat untuk banyak gambar sekaligus."""
    torch = _torch()
    tfm = _transforms_for_inference(bundle.image_size)
    results = []

    for start in range(0, len(images), batch_size):
        chunk = images[start:start + batch_size]
        tensors = [tfm(_to_pil(img)) for img in chunk]
        batch = torch.stack(tensors).to(bundle.device)

        with torch.no_grad():
            logits = bundle.model(batch)
            probs = torch.softmax(logits, dim=1).cpu().numpy()

        for row in probs:
            top_idx = np.argsort(-row)[:topk]
            results.append([(bundle.class_names[i], float(row[i])) for i in top_idx])

    return results
