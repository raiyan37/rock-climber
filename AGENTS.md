# rock-climber codebase guide

## Repo layout

- `backend/`: FastAPI service that detects holds (YOLO) and returns a PNG with a suggested route overlay.
- `ios/`: SwiftUI iOS client that captures/selects a photo and uploads it to the backend.

## Backend (FastAPI + CV)

### Entry points

- `backend/api/main.py`: FastAPI app.
  - `GET /health`: returns `{"message":"ok"}`.
  - `POST /boulder/generate`: multipart upload (`file`) → returns an annotated `image/png`.

### How route generation works

- Hold detection: `backend/src/objects_detector.py`
  - Uses Ultralytics YOLO.
  - Expects weights at `backend/src/config.py:YOLO_MODEL_PATH` (set via `backend/.env` `YOLO_MODEL_PATH=...`).
- Route planning (current): `backend/src/route_planner.py`
  - `plan_bottom_to_top_route(...)` picks a simple bottom-to-top sequence of holds (pixel-space heuristic).
- Overlay rendering: `backend/src/image_utils.py`
  - Draws detected hold boxes + route line + highlighted route holds.
- Tunables: `backend/src/config.py`
  - `MAXIMUM_FILE_SIZE`, `ACCEPTED_MIME_TYPES`, and route overlay colors/width.

### Run locally

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload
```

Docs: `http://localhost:8000/docs`

### Tests

- `backend/tests/` (example: `backend/tests/test_aruco_marker.py`)
- Run with `pytest` (in a venv with deps installed).

## iOS app (SwiftUI)

### Key files

- App entry: `ios/rock-climbing-app/rock_climbing_appApp.swift`
- Tabs: `ios/rock-climbing-app/Views/ContentView.swift`
- “Scan Route” flows:
  - Camera: `ios/rock-climbing-app/Views/CameraView.swift`
    - Captures via `ios/rock-climbing-app/Managers/CameraManager.swift`
    - Uploads to `POST /boulder/generate` and navigates to `RouteAnalysisView`
  - Photo Library: `ios/rock-climbing-app/Views/PhotoLibraryView.swift`
- Backend client: `ios/rock-climbing-app/Managers/HTTPSetup.swift` (`APIClient`)
  - Base URL comes from iOS Settings (preferred) or `ios/rock-climbing-app/Info.plist` (`BackendBaseURL`).

### Networking gotchas

- Simulator: `http://localhost:8000` works if the backend is running on your Mac.
- Physical device: set `BackendBaseURL` (or Settings override) to your Mac’s LAN IP and run uvicorn with `--host 0.0.0.0`.

