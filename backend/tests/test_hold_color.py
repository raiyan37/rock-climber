import numpy as np

from src.hold_color import annotate_hold_colors, assign_color_groups, group_holds_by_color_group
from src.model.detected_object import DetectedObject
from src.model.point import Point
from src.route_planner import plan_bottom_to_top_route


def _hold(img: np.ndarray, *, bgr: tuple[int, int, int], x: int, y: int, size: int = 24) -> DetectedObject:
    half = size // 2
    x1, y1, x2, y2 = x - half, y - half, x + half, y + half
    img[y1:y2, x1:x2] = np.array(bgr, dtype=np.uint8)
    bbox = np.array([x1, y1, x2, y2], dtype=int)
    return DetectedObject(class_name="hold", bbox=bbox, center=Point(x=x, y=y))


def test_estimates_basic_hold_color_labels() -> None:
    img = np.full((200, 200, 3), 128, dtype=np.uint8)  # gray background
    red_hold = _hold(img, bgr=(0, 0, 255), x=60, y=100)
    blue_hold = _hold(img, bgr=(255, 0, 0), x=140, y=100)

    holds = [red_hold, blue_hold]
    annotate_hold_colors(img, holds)

    assert red_hold.color_label == "red"
    assert blue_hold.color_label == "blue"


def test_assigns_color_groups_by_label() -> None:
    img = np.full((200, 200, 3), 128, dtype=np.uint8)
    red_hold_1 = _hold(img, bgr=(0, 0, 255), x=60, y=80)
    red_hold_2 = _hold(img, bgr=(0, 0, 255), x=60, y=120)
    blue_hold = _hold(img, bgr=(255, 0, 0), x=140, y=100)

    holds = [red_hold_1, red_hold_2, blue_hold]
    annotate_hold_colors(img, holds)
    group_id_to_label = assign_color_groups(holds)

    label_to_group_id = {label: gid for gid, label in group_id_to_label.items()}
    assert set(label_to_group_id.keys()) >= {"red", "blue"}
    assert red_hold_1.color_group == label_to_group_id["red"]
    assert red_hold_2.color_group == label_to_group_id["red"]
    assert blue_hold.color_group == label_to_group_id["blue"]


def test_color_groups_enable_single_color_route_selection() -> None:
    img_width = 1000
    img_height = 800
    img = np.full((img_height, img_width, 3), 128, dtype=np.uint8)

    blue_holds = [
        _hold(img, bgr=(255, 0, 0), x=500, y=y)
        for y in [750, 650, 550, 450, 350, 250, 150, 80]
    ]
    green_holds = [_hold(img, bgr=(0, 255, 0), x=520, y=y) for y in [760, 680, 620]]

    holds = blue_holds + green_holds
    annotate_hold_colors(img, holds)
    group_id_to_label = assign_color_groups(holds)
    groups = group_holds_by_color_group(holds)

    selected_label = None
    best_score = None
    for group_id, group_holds in groups.items():
        if group_id_to_label.get(group_id) == "unknown":
            continue
        if len(group_holds) < 3:
            continue
        route = plan_bottom_to_top_route(group_holds, img_width=img_width, img_height=img_height, max_holds=6)
        vertical_gain = route[0].center.y - route[-1].center.y
        top_y = int(round(img_height * 0.12))
        bottom_y = int(round(img_height * 0.80))
        has_top = any(h.center.y <= top_y for h in group_holds)
        has_bottom = any(h.center.y >= bottom_y for h in group_holds)
        score = (
            0 if has_bottom else 1,
            0 if has_top else 1,
            -len(route),
            -vertical_gain,
            route[-1].center.y,
            -len(group_holds),
        )
        if best_score is None or score < best_score:
            best_score = score
            selected_label = group_id_to_label[group_id]

    assert selected_label == "blue"


def test_black_holds_with_chalk_stay_black() -> None:
    img = np.full((200, 200, 3), 128, dtype=np.uint8)  # gray background
    black_hold = _hold(img, bgr=(0, 0, 0), x=100, y=100, size=60)

    x1, y1, x2, y2 = (int(v) for v in black_hold.bbox.tolist())
    img[y1 + 20:y1 + 35, x1 + 20:x1 + 35] = np.array((255, 255, 255), dtype=np.uint8)

    annotate_hold_colors(img, [black_hold])
    assert black_hold.color_label == "black"
