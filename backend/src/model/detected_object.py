from __future__ import annotations

from dataclasses import dataclass
import numpy as np

from src.model.point import Point


@dataclass
class DetectedObject:
    class_name: str
    bbox: np.ndarray
    center: Point
    color_bgr: tuple[int, int, int] | None = None
    color_hsv: tuple[float, float, float] | None = None
    color_group: int | None = None
    color_label: str | None = None

    def __eq__(self, other):
        return self.class_name == other.class_name and np.array_equal(self.bbox, other.bbox)
