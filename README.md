# aaffine

A new Flutter project.

Use this --dart-define flag to build for web due to CanvasKit bug:

`flutter run -d chrome --web-renderer canvaskit --dart-define=BROWSER_IMAGE_DECODING_ENABLED=false --release`
