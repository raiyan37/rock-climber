# Send

A climbing app where you snap a photo of any wall and instantly see optimal routes mapped out using OpenCV. Track your climbs, record attempts, and build your climbing portfolio with computer vision route detection.

## Overview

Send combines YOLO-based hold detection with intelligent route planning to help climbers visualize paths up any wall. The app includes session tracking, progress analytics, and real-time climb recording to help you improve your technique and reach your goals.

**Tech Stack:**
- Backend: Python, FastAPI, YOLO (Ultralytics), OpenCV
- iOS: SwiftUI, AVFoundation
- CV Pipeline: Hold detection, ArUco marker calibration, bottom-to-top route planning

## Repository Structure

- `backend/`: FastAPI service that takes a climbing wall image, detects holds (YOLO), calibrates scale using an ArUco marker, and returns an annotated PNG route overlay.
- `ios/`: SwiftUI iOS client with camera capture, route visualization, and progress tracking.

## Backend quickstart

```bash
cd backend

# create + activate venv
python3 -m venv venv
source venv/bin/activate

# install deps
pip install -r requirements.txt

# run API
uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload
```

Open `http://localhost:8000/docs`.

## Generate a route

```bash
curl -X POST "http://localhost:8000/boulder/generate" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@climbing_wall.jpg" \
  --output route.png
```

## ArUco calibration

The backend uses an ArUco marker to convert pixel distances into centimeters. Print the marker in `backend/resources/aruco_marker_5x5.png` and make sure it’s fully visible in the photo (avoid cutting it off at the image boundary).

## Tests

```bash
cd backend
pytest
```

## iOS app

The iOS client reads the backend host/port from iOS Settings (Settings → Send → Backend Server). If unset, it falls back to `ios/rock-climbing-app/Info.plist:1` (`BackendBaseURL`).

- iOS Simulator: `BackendBaseURL` default `http://localhost:8000` works if the backend is running on your Mac.
- Physical device: set the IP to your Mac’s LAN IP (e.g. `172.20.x.x`/`192.168.x.x`) and run `uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload`.
- Quick sanity check: visit `http://<mac-ip>:8000/health` (should return `{"message":"ok"}`).
