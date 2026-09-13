# TikSave

TikSave is a full-stack TikTok downloader project built with:

- Backend: Node.js + Express
- Frontend: Flutter
- Purpose: fetch TikTok metadata and save video/audio files from a TikTok URL

This project includes a Node API that resolves a TikTok URL and returns media metadata or a downloadable file, plus a Flutter mobile app that lets the user paste a link and download the media to the device.

## Project Structure

```text
.
├── Backend/
│   ├── src/
│   │   ├── server.js
│   │   └── downloader.js
│   ├── test/
│   ├── package.json
│   ├── README.md
│   └── Dockerfile
├── frontend/
│   └── tiktokdownloader/
│       ├── lib/
│       ├── ios/
│       ├── android/
│       ├── pubspec.yaml
│       └── README.md
├── README.md
└── .gitignore
```

## Features

- Fetch TikTok metadata from a URL
- Generate a download endpoint for video/audio assets
- Save downloaded files on the device
- View saved media history in the app
- Support local backend testing and iOS/Android app development

## Architecture

### Backend
The backend uses a small Express API to expose endpoints like:

- `GET /health`
- `POST /v1/info`
- `POST /v1/download`
- `GET /v1/files/:token`

This API resolves the TikTok media source and returns either metadata or a temporary file URL.

### Frontend
The Flutter frontend provides:

- URL input form
- metadata preview
- video/audio download actions
- progress indicator
- saved file list/history screen

## Prerequisites

Before running the project, install:

- Node.js 20+
- npm
- Flutter SDK
- yt-dlp (required by the backend for media extraction)
- ffmpeg (recommended for stream/media handling)

For macOS/Linux:

```bash
python3 -m pip install --user yt-dlp
```

For Ubuntu/Debian:

```bash
sudo apt-get update && sudo apt-get install -y ffmpeg
```

## Backend Setup

```bash
cd Backend
npm install
npm run check
npm start
```

The backend usually runs on:

```text
http://127.0.0.1:8000
```

To run on a custom port:

```bash
PORT=9000 npm start
```

Optional environment variables:

```bash
API_KEY=your_api_key
RATE_LIMIT_PER_MINUTE=10
DOWNLOAD_TIMEOUT_SECONDS=120
MAX_DOWNLOAD_BYTES=262144000
YTDLP_BIN=yt-dlp
```

For local development, the backend can run without an API key unless configured.

## Frontend Setup

```bash
cd frontend/tiktokdownloader
flutter pub get
flutter run
```

For iOS local testing, the app may need to use a real LAN IP instead of localhost, and iOS requires ATS configuration for local HTTP access.

Example:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

## Usage

1. Start the backend.
2. Launch the Flutter app.
3. Paste a public TikTok video URL.
4. Fetch metadata.
5. Download the video or audio.
6. Open or manage downloaded files from the history screen.

## Important Notes

- This project is intended for authorized or legally permissible content only.
- Respect TikTok terms of service, copyright, and privacy rules.
- Some URLs may not be publicly accessible or may require browser/session cookies.
- Downloading protected media without permission may violate laws or platform policies.

## Development Notes

- Android storage and iOS storage are different; the app uses the app sandbox for saved files.
- In iOS development, `NSAppTransportSecurity` may need to be configured when hitting a local HTTP backend.
- For a public or production deployment, prefer HTTPS, API authentication, and proper abuse controls.

## License

This project is provided as a learning/demo project. Please review and comply with all applicable platform policies before using it in production.

## Support

If you are working on this project locally, make sure both services are running:

- backend server
- Flutter mobile app

If the app cannot connect to the backend, check:

- backend port
- local IP address
- iOS ATS settings
- whether the server is still running
