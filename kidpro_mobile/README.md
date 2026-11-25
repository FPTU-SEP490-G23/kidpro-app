# kidpro_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Connecting to the deployed backend

The mobile app sends face check-in and liveness requests to the application
backend. The backend calls the private AI service over its Docker network, so
the app must not connect to port `8000`.

Configure the backend URL in the login screen, or provide it at build/run time:

```bash
flutter run --dart-define=BASE_URL=http://<EC2_PUBLIC_IP>:8080
flutter build apk --release --dart-define=BASE_URL=https://YOUR_API_DOMAIN
```

Replace `YOUR_EC2_PUBLIC_IP` with the EC2 public or Elastic IP and ensure port
`8080` is reachable from the device. For production, use HTTPS and a stable
domain rather than sending face images over plain HTTP.
