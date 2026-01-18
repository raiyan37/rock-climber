from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass

import cv2
import numpy as np

from src.model.detected_object import DetectedObject


@dataclass(frozen=True)
class HoldColorEstimate:
    bgr: tuple[int, int, int] | None
    hsv: tuple[float, float, float] | None
    label: str


def annotate_hold_colors(
    img: cv2.typing.MatLike,
    holds: Sequence[DetectedObject],
    *,
    inset_ratio: float = 0.18,
    min_saturation: int = 40,
    min_value: int = 40,
    min_mask_pixels: int = 40,
) -> None:
    for hold in holds:
        estimate = estimate_hold_color(
            img,
            hold.bbox,
            inset_ratio=inset_ratio,
            min_saturation=min_saturation,
            min_value=min_value,
            min_mask_pixels=min_mask_pixels,
        )
        hold.color_bgr = estimate.bgr
        hold.color_hsv = estimate.hsv
        hold.color_label = estimate.label


def assign_color_groups(
    holds: Sequence[DetectedObject],
    *,
    unknown_label: str = "unknown",
) -> dict[int, str]:
    """
    Assigns `DetectedObject.color_group` based on `DetectedObject.color_label`.

    Returns:
        dict[group_id] -> label
    """
    label_to_holds: dict[str, list[DetectedObject]] = {}
    for hold in holds:
        label = hold.color_label or unknown_label
        label_to_holds.setdefault(label, []).append(hold)

    sorted_labels = sorted(label_to_holds.keys(), key=lambda k: (-len(label_to_holds[k]), k))
    group_id_to_label: dict[int, str] = {}
    for group_id, label in enumerate(sorted_labels):
        group_id_to_label[group_id] = label
        for hold in label_to_holds[label]:
            hold.color_group = group_id

    return group_id_to_label


def estimate_hold_color(
    img: cv2.typing.MatLike,
    bbox: np.ndarray,
    *,
    inset_ratio: float = 0.18,
    min_saturation: int = 40,
    min_value: int = 40,
    min_mask_pixels: int = 40,
) -> HoldColorEstimate:
    if img is None or getattr(img, "size", 0) == 0:
        return HoldColorEstimate(bgr=None, hsv=None, label="unknown")

    img_h, img_w = img.shape[:2]
    x1, y1, x2, y2 = (int(v) for v in bbox.tolist())
    x1, y1, x2, y2 = _clip_bbox(x1, y1, x2, y2, img_w, img_h)
    if x2 <= x1 or y2 <= y1:
        return HoldColorEstimate(bgr=None, hsv=None, label="unknown")

    x1i, y1i, x2i, y2i = _inset_bbox(x1, y1, x2, y2, inset_ratio=inset_ratio)
    x1i, y1i, x2i, y2i = _clip_bbox(x1i, y1i, x2i, y2i, img_w, img_h)
    if x2i <= x1i or y2i <= y1i:
        x1i, y1i, x2i, y2i = x1, y1, x2, y2

    roi = img[y1i:y2i, x1i:x2i]
    if roi.size == 0:
        return HoldColorEstimate(bgr=None, hsv=None, label="unknown")

    hsv_roi = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
    hue = hsv_roi[:, :, 0].astype(np.int32)
    s = hsv_roi[:, :, 1].astype(np.float32)
    v = hsv_roi[:, :, 2].astype(np.float32)

    roi_area = int(hue.size)

    # Weight hue votes by saturation (strongly) and brightness (lightly) to remain
    # robust to chalk/dirt while avoiding dark/noisy pixels dominating.
    weights = ((s / 255.0) ** 2) * (v / 255.0)
    total_weight = float(weights.sum())
    min_total_weight = max(1.0, roi_area * 0.002)

    if total_weight < min_total_weight:
        mean_bgr = _mean_bgr(roi)
        label = _label_achromatic(roi)
        return HoldColorEstimate(bgr=mean_bgr, hsv=None, label=label)

    hist = np.bincount(hue.reshape(-1), weights=weights.reshape(-1), minlength=180)
    dominant_hue = int(hist.argmax())

    mean_s = float((s * weights).sum() / total_weight)
    mean_v = float((v * weights).sum() / total_weight)
    mean_bgr = _mean_bgr(roi, weights=weights)

    peak_ratio = float(hist[dominant_hue]) / total_weight if total_weight > 0 else 0.0
    channel_spread = max(mean_bgr) - min(mean_bgr)
    if mean_s < 25 and channel_spread < 25:
        label = _label_achromatic(roi)
        return HoldColorEstimate(bgr=mean_bgr, hsv=None, label=label)
    if peak_ratio < 0.10:
        label = _label_achromatic(roi)
        return HoldColorEstimate(bgr=mean_bgr, hsv=None, label=label)

    label = _label_from_hue(dominant_hue, mean_s=mean_s, mean_v=mean_v)

    return HoldColorEstimate(
        bgr=mean_bgr,
        hsv=(float(dominant_hue), mean_s, mean_v),
        label=label,
    )


def group_holds_by_color_group(holds: Iterable[DetectedObject]) -> dict[int, list[DetectedObject]]:
    groups: dict[int, list[DetectedObject]] = {}
    for hold in holds:
        if hold.color_group is None:
            continue
        groups.setdefault(hold.color_group, []).append(hold)
    return groups


def _clip_bbox(x1: int, y1: int, x2: int, y2: int, img_w: int, img_h: int) -> tuple[int, int, int, int]:
    x1 = max(0, min(img_w, x1))
    x2 = max(0, min(img_w, x2))
    y1 = max(0, min(img_h, y1))
    y2 = max(0, min(img_h, y2))
    return x1, y1, x2, y2


def _inset_bbox(x1: int, y1: int, x2: int, y2: int, *, inset_ratio: float) -> tuple[int, int, int, int]:
    w = max(0, x2 - x1)
    h = max(0, y2 - y1)
    dx = int(round(w * inset_ratio))
    dy = int(round(h * inset_ratio))
    return x1 + dx, y1 + dy, x2 - dx, y2 - dy


def _mean_bgr(
    roi: np.ndarray,
    *,
    mask: np.ndarray | None = None,
    weights: np.ndarray | None = None,
) -> tuple[int, int, int]:
    if weights is not None:
        weights_f = weights.astype(np.float32)
        total_weight = float(weights_f.sum())
        if total_weight <= 1e-6:
            mean = roi.reshape(-1, 3).mean(axis=0)
        else:
            roi_f = roi.astype(np.float32)
            mean = (roi_f * weights_f[:, :, None]).sum(axis=(0, 1)) / total_weight
    elif mask is None:
        mean = roi.reshape(-1, 3).mean(axis=0)
    else:
        pixels = roi[mask]
        if pixels.size == 0:
            mean = roi.reshape(-1, 3).mean(axis=0)
        else:
            mean = pixels.mean(axis=0)

    b, g, r = (int(round(v)) for v in mean.tolist())
    return _clamp_u8(b), _clamp_u8(g), _clamp_u8(r)


def _label_from_hue(hue: int, *, mean_s: float, mean_v: float) -> str:
    if mean_v < 60 and mean_s < 60:
        return "black"

    if hue <= 10 or hue >= 170:
        return "red"
    if 11 <= hue <= 25:
        return "orange"
    if 26 <= hue <= 35:
        return "yellow"
    if 36 <= hue <= 85:
        return "green"
    if 86 <= hue <= 100:
        return "cyan"
    if 101 <= hue <= 130:
        return "blue"
    if 131 <= hue <= 160:
        return "purple"
    if 161 <= hue <= 169:
        return "pink"

    return "unknown"


def _label_achromatic(roi: np.ndarray) -> str:
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    median_v = float(np.median(gray))
    p20_v = float(np.percentile(gray, 20))
    if median_v >= 210:
        return "white"
    if p20_v <= 95:
        return "black"
    return "gray"


def _clamp_u8(value: int) -> int:
    return max(0, min(255, int(value)))
