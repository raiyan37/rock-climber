from __future__ import annotations

from collections.abc import Sequence

from src.model.detected_object import DetectedObject


def plan_bottom_to_top_route(
    detected_objects: Sequence[DetectedObject],
    *,
    img_width: int,
    img_height: int,
    max_holds: int = 12,
    top_margin_ratio: float = 0.12,
    side_margin_ratio: float = 0.10,
    bottom_region_ratio: float = 0.20,
    min_vertical_gain_ratio: float = 0.04,
) -> list[DetectedObject]:
    """
    Very simple bottom-to-top route planner.

    Assumptions:
    - y=0 is top of image; increasing y goes down.
    - The "start" is a hold near the bottom.
    - The route progresses upward by picking holds above the previous hold.
    """
    if img_width <= 0 or img_height <= 0:
        raise ValueError("Invalid image dimensions")
    if max_holds < 2:
        raise ValueError("max_holds must be >= 2")

    if not detected_objects:
        raise ValueError("No holds detected")

    holds = [obj for obj in detected_objects if obj.class_name == "hold"]
    if not holds:
        holds = list(detected_objects)

    side_min_x = int(round(img_width * side_margin_ratio))
    side_max_x = int(round(img_width * (1.0 - side_margin_ratio)))
    central_holds = [h for h in holds if side_min_x <= h.center.x <= side_max_x]
    if len(central_holds) >= 3:
        holds = central_holds

    top_y = int(round(img_height * top_margin_ratio))
    bottom_y = int(round(img_height * (1.0 - bottom_region_ratio)))
    min_gain_px = max(1, int(round(img_height * min_vertical_gain_ratio)))

    start_candidates = [h for h in holds if h.center.y >= bottom_y]
    if not start_candidates:
        start_candidates = holds

    start = max(start_candidates, key=lambda h: h.center.y)
    route: list[DetectedObject] = [start]
    used = {_obj_key(start)}

    while route[-1].center.y > top_y and len(route) < max_holds:
        current = route[-1]
        remaining_budget = max_holds - len(route)
        desired_gain = (current.center.y - top_y) / max(1, remaining_budget)

        candidates: list[DetectedObject] = [
            h for h in holds
            if _obj_key(h) not in used and (current.center.y - h.center.y) >= min_gain_px
        ]
        if not candidates:
            break

        def score(candidate: DetectedObject) -> float:
            gain = current.center.y - candidate.center.y
            dx = abs(candidate.center.x - current.center.x)
            return (abs(gain - desired_gain) / img_height) + (0.75 * dx / img_width)

        best = min(candidates, key=score)
        route.append(best)
        used.add(_obj_key(best))

    if route[-1].center.y > top_y and len(route) < max_holds:
        remaining = [h for h in holds if _obj_key(h) not in used]
        if remaining:
            finish = min(remaining, key=lambda h: h.center.y)
            if finish.center.y < route[-1].center.y:
                route.append(finish)

    return route


def _obj_key(obj: DetectedObject) -> tuple[str, int, int, int, int]:
    x1, y1, x2, y2 = obj.bbox
    return obj.class_name, int(x1), int(y1), int(x2), int(y2)

