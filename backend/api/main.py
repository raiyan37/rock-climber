import io
import os
import cv2
import imutils
import numpy as np

from dotenv import load_dotenv
from fastapi import FastAPI, UploadFile, HTTPException, status
from pydantic import BaseModel
from google.oauth2 import id_token
from google.auth.transport import requests
from starlette.responses import StreamingResponse

# Load environment variables from .env file
load_dotenv()

from src import config, image_utils, objects_detector
from src.aruco_marker import ArucoMarker
from src.route_generator import RouteGenerator
from . import session_store
from . import user_store

app = FastAPI(title="Climbing Crux Route Generator")


class ClimbEventBody(BaseModel):
    status: str
    attempts: int
    durationSeconds: int


class GoogleAuthBody(BaseModel):
    idToken: str


@app.post("/boulder/generate")
async def generate_boulder(file: UploadFile) -> StreamingResponse:
    """
    Generate a boulder route from an image.

    For now, the route planner assumes a simple bottom-to-top progression.
    Generate a boulder route from an image.

    For now, the route planner assumes a simple bottom-to-top progression.
    """
    started = time.perf_counter()
    started = time.perf_counter()
    contents = await file.read()

    validate_file(file, contents)
    print(f"[boulder/generate] received filename={file.filename} content_type={file.content_type} bytes={len(contents)}")
    validate_file(file, contents)
    print(f"[boulder/generate] received filename={file.filename} content_type={file.content_type} bytes={len(contents)}")

    np_img = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(np_img, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid image file")
    if img is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid image file")

    img = imutils.resize(img, width=1216)

    try:
        detected_objects = objects_detector.detect(img)
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc

    try:
        route_holds = plan_bottom_to_top_route(
            detected_objects,
            img_width=img.shape[1],
            img_height=img.shape[0],
        detected_objects = objects_detector.detect(img)
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc

    try:
        route_holds = plan_bottom_to_top_route(
            detected_objects,
            img_width=img.shape[1],
            img_height=img.shape[0],
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc)
        ) from exc

    img = image_utils.draw_bboxes(
        img=img,
        detected_objects=detected_objects,
        bbox_color=config.BBOX_COLOR,
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
    img = image_utils.draw_bboxes(
        img=img,
        detected_objects=detected_objects,
        bbox_color=config.BBOX_COLOR,
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


def validate_file(file: UploadFile) -> None:
    if file.content_type not in config.ACCEPTED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Unsupported file type",
        )

    if len(contents) > config.MAXIMUM_FILE_SIZE:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Too large")
    if len(contents) > config.MAXIMUM_FILE_SIZE:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Too large")
