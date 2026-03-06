# Dependency Upgrade Notes

## Direct deps updated
- `flutter_hooks` -> ^0.21.3+1 (minor)
- `rive` -> ^0.13.20 (minor)
- `local_auth` -> ^2.3.0 (minor)
- `flutter_secure_storage` -> ^9.2.4 (patch)
- `intl` -> ^0.20.2 (minor)
- `sentry_flutter` -> ^9.14.0 (new, observabilidad)
- `vibration` -> ^3.1.8 (minor, fix build error con Flutter actual)

## Pendientes (no actualizados por riesgo)
- `flutter_lints` sigue en ^4.0.0 (upgrade a 6.x es mayor y puede exigir cambios).

## Paquete discontinuado `js`
- Es una dependencia **transitiva** (no usada directamente por la app).
- No se elimina sin cambiar dependencias upstream. Recomendacion: esperar upgrade de plugins que lo remuevan.
