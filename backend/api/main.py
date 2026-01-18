import io
import os
import time

import cv2
import imutils
import numpy as np
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, UploadFile, status
from google.auth.transport import requests
from google.oauth2 import id_token
from pydantic import BaseModel
from starlette.responses import StreamingResponse

from src import config, hold_color, image_utils, objects_detector
from src.route_planner import plan_bottom_to_top_route

from . import session_store
from . import user_store

load_dotenv()

app = FastAPI(title="Climbing Crux Route Generator")


class ClimbEventBody(BaseModel):
    status: str
    attempts: int
    durationSeconds: int


class GoogleAuthBody(BaseModel):
    idToken: str


@app.get("/health")
async def health() -> dict:
    return {"message": "ok"}


@app.post("/boulder/generate")
async def generate_boulder(file: UploadFile) -> StreamingResponse:
    """
    Generate a boulder route from an image.

    - Detect holds with YOLO
    - Plan a simple bottom-to-top route
    - Return an annotated PNG overlay
    """
    started = time.perf_counter()
    contents = await file.read()

    validate_file(file, contents)
    print(
        f"[boulder/generate] received filename={file.filename} "
        f"content_type={file.content_type} bytes={len(contents)}"
    )

    np_img = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(np_img, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid image file")

    img = imutils.resize(img, width=1216)

    try:
        detected_objects = objects_detector.detect(img)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Object detection failed: {exc}",
        ) from exc

    try:
        img_width = img.shape[1]
        img_height = img.shape[0]

        holds = [obj for obj in detected_objects if obj.class_name == "hold"]
        selected_group_id: int | None = None
        if holds:
            hold_color.annotate_hold_colors(img, holds)
            group_id_to_label = hold_color.assign_color_groups(holds)
            groups = hold_color.group_holds_by_color_group(holds)

            best_route: list | None = None
            best_score: tuple[int, ...] | None = None
            for group_id, group_holds in groups.items():
                if len(group_holds) < 3:
                    continue
                if group_id_to_label.get(group_id, "unknown") == "unknown":
                    continue

                candidate_route = plan_bottom_to_top_route(
                    group_holds,
                    img_width=img_width,
                    img_height=img_height,
                )
                vertical_gain = candidate_route[0].center.y - candidate_route[-1].center.y
                top_y = int(round(img_height * 0.12))
                bottom_y = int(round(img_height * 0.80))
                has_top = any(h.center.y <= top_y for h in group_holds)
                has_bottom = any(h.center.y >= bottom_y for h in group_holds)
                score = (
                    0 if has_bottom else 1,
                    0 if has_top else 1,
                    -len(candidate_route),
                    -vertical_gain,
                    candidate_route[-1].center.y,
                    -len(group_holds),
                )
                if best_score is None or score < best_score:
                    best_score = score
                    best_route = candidate_route
                    selected_group_id = group_id

            route_holds = best_route or plan_bottom_to_top_route(
                detected_objects,
                img_width=img_width,
                img_height=img_height,
            )
        else:
            route_holds = plan_bottom_to_top_route(
                detected_objects,
                img_width=img_width,
                img_height=img_height,
            )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    img = image_utils.draw_bboxes(
        img=img,
        detected_objects=detected_objects,
        bbox_color=config.BBOX_COLOR,
        bbox_center_color=config.BBOX_CENTER_COLOR,
        line_width=config.LINE_WIDTH,
        draw_labels=False,
        draw_centers=False,
    )

    if holds and selected_group_id is not None:
        selected_group_holds = [h for h in holds if h.color_group == selected_group_id]
        img = image_utils.draw_bboxes(
            img=img,
            detected_objects=selected_group_holds,
            bbox_color=config.SELECTED_COLOR_GROUP_BBOX_COLOR,
            bbox_center_color=config.BBOX_CENTER_COLOR,
            line_width=config.LINE_WIDTH,
            draw_labels=False,
            draw_centers=False,
        )

    img = image_utils.draw_bboxes(
        img=img,
        detected_objects=route_holds,
        bbox_color=config.PROBLEM_STEP_BBOX_COLOR,
        bbox_center_color=config.BBOX_CENTER_COLOR,
        line_width=config.LINE_WIDTH,
        draw_labels=False,
        draw_centers=True,
    )

    for start_hold, end_hold in zip(route_holds, route_holds[1:]):
        img = image_utils.draw_line(
            img=img,
            start_point=start_hold.center,
            end_point=end_hold.center,
            color=config.ROUTE_LINE_COLOR,
            line_width=config.ROUTE_LINE_WIDTH,
        )

    _, im_png = cv2.imencode(".png", img)
    print(f"[boulder/generate] done in {time.perf_counter() - started:.2f}s")
    return StreamingResponse(io.BytesIO(im_png.tobytes()), media_type="image/png")


@app.post("/api/users/{user_id}/sessions/today/start")
def start_today_session(user_id: str) -> dict:
    session_store.start_today_session(user_id)
    return session_store.get_today_session_stats(user_id)


@app.post("/api/users/{user_id}/sessions/today/end")
def end_today_session(user_id: str) -> dict:
    session_store.end_today_session(user_id)
    return session_store.get_today_session_stats(user_id)


@app.get("/api/users/{user_id}/sessions/today")
def get_today_session(user_id: str) -> dict:
    return session_store.get_today_session_stats(user_id)


@app.post("/api/users/{user_id}/sessions/today/climbs")
def add_today_climb(user_id: str, body: ClimbEventBody) -> dict:
    session_store.add_climb_event(
        user_id=user_id,
        status=body.status,
        attempts=body.attempts,
        duration_seconds=body.durationSeconds,
    )
    return session_store.get_today_session_stats(user_id)


@app.post("/api/auth/google")
def authenticate_google(body: GoogleAuthBody) -> dict:
    client_id = os.getenv("GOOGLE_OAUTH_IOS_CLIENT_ID")
    if not client_id:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Missing GOOGLE_OAUTH_IOS_CLIENT_ID",
        )

    try:
        payload = id_token.verify_oauth2_token(
            body.idToken,
            requests.Request(),
            audience=client_id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google ID token",
        ) from exc

    email = payload.get("email", "")
    google_sub = payload.get("sub", "")
    if not email or not google_sub:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid token payload",
        )

    result = user_store.upsert_google_user(
        google_sub=google_sub,
        email=email,
        given_name=payload.get("given_name"),
        family_name=payload.get("family_name"),
        picture_url=payload.get("picture"),
    )

    user = result["user"]
    return {
        "user": {
            "id": user["id"],
            "email": user["email"],
            "firstName": user.get("firstName") or "",
            "lastName": user.get("lastName") or "",
            "photoURL": user.get("photoURL"),
        },
        "token": result["token"],
        "isNewUser": result["isNewUser"],
    }


def validate_file(file: UploadFile, contents: bytes) -> None:
    if file.content_type not in config.ACCEPTED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Unsupported file type",
        )

    if not contents:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty file")

    if len(contents) > config.MAXIMUM_FILE_SIZE:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Too large")
