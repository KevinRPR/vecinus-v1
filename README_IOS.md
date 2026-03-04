# iOS Setup (Vecinus v1)

## Requisitos
- macOS con Xcode instalado
- CocoaPods (`sudo gem install cocoapods`)
- Flutter SDK instalado y configurado

## Pasos
1) Desde la raiz del repo:
   - `flutter clean`
   - `flutter pub get`
2) Instalar pods:
   - `cd ios && pod install`
3) Abrir el workspace:
   - `open Runner.xcworkspace`
4) Build/Run desde Xcode.

## Notas
- `ios/Podfile` es requerido para plugins como `local_auth` y `flutter_secure_storage`.
- Si usas variables por entorno:
  - `--dart-define=API_BASE_URL=https://.../movil/`
  - `--dart-define=SENTRY_DSN=...` (opcional)
  - `--dart-define=APP_ENV=staging` (opcional)
