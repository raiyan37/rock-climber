import numpy as np

from src.model.detected_object import DetectedObject
from src.model.point import Point
from src.route_planner import plan_bottom_to_top_route


def _obj(class_name: str, x: int, y: int, size: int = 20) -> DetectedObject:
    half = size // 2
    bbox = np.array([x - half, y - half, x + half, y + half], dtype=int)
    return DetectedObject(class_name=class_name, bbox=bbox, center=Point(x=x, y=y))


def test_plans_bottom_to_top_route_with_monotonic_y() -> None:
    img_width = 1000
    img_height = 800

    holds = [
        _obj("hold", 500, 750),
        _obj("hold", 520, 650),
        _obj("hold", 480, 550),
        _obj("hold", 510, 450),
        _obj("hold", 495, 350),
        _obj("hold", 505, 250),
        _obj("hold", 500, 150),
        _obj("hold", 500, 80),
    ]

    route = plan_bottom_to_top_route(
        holds,
        img_width=img_width,
        img_height=img_height,
        max_holds=6,
        top_margin_ratio=0.1,
        bottom_region_ratio=0.25,
    )

    assert route[0].center.y == 750
    assert 2 <= len(route) <= 6
    assert all(route[i].center.y < route[i - 1].center.y for i in range(1, len(route)))


def test_falls_back_to_non_hold_objects_when_no_holds_detected() -> None:
    img_width = 1000
    img_height = 800

    objects = [
        _obj("volume", 500, 750),
        _obj("volume", 500, 400),
        _obj("volume", 500, 100),
    ]

    route = plan_bottom_to_top_route(
        objects,
        img_width=img_width,
        img_height=img_height,
        max_holds=4,
    )

    assert route[0].class_name == "volume"
    assert all(route[i].center.y < route[i - 1].center.y for i in range(1, len(route)))


def test_prefers_central_holds_when_available() -> None:
    img_width = 1000
    img_height = 800

    edge_holds = [
        _obj("hold", 10, 760),
        _obj("hold", 990, 600),
    ]
    central_holds = [
        _obj("hold", 500, 750),
        _obj("hold", 520, 500),
        _obj("hold", 480, 250),
        _obj("hold", 500, 80),
    ]

    route = plan_bottom_to_top_route(
        edge_holds + central_holds,
        img_width=img_width,
        img_height=img_height,
        max_holds=6,
        side_margin_ratio=0.10,
    )

    assert all(100 <= hold.center.x <= 900 for hold in route)

