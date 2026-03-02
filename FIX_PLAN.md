# Fix Plan

**Objetivo**
- Reducir riesgos de seguridad P0/P1, mejorar accesibilidad y performance basica sin re-arquitectura.

**Etapas**
- Etapa 1 (Quick wins, 1-2 semanas): A-001..A-006, A-010..A-018.
- Etapa 2 (Mediano, 2-4 semanas): rate limiting, CORS restrictivo, cache con TTL, mejoras de UX en flujos y estados.
- Etapa 3 (Profundo, 1-2 meses): redisenio alineado con UX v2, observabilidad (Sentry/metrics), E2E y pruebas backend.

**Parches propuestos (por commit logico)**

Commit 1: `security-login-hardening`
```diff
--- a/php/login.php
+++ b/php/login.php
@@
-ini_set('display_errors', 1);
-ini_set('display_startup_errors', 1);
-error_reporting(E_ALL);
+// Solo mostrar errores en entorno local.
+if (getenv('APP_ENV') === 'local') {
+    ini_set('display_errors', 1);
+    ini_set('display_startup_errors', 1);
+    error_reporting(E_ALL);
+}
@@
-// LOG del input para depuracion
-file_put_contents(__DIR__ . "/debug.txt", "RAW INPUT:\n" . file_get_contents("php://input"));
+// Evitar loggear credenciales en produccion.
@@
-// Validacion de contrasena (SHA1 + master key opcional)
-if ((sha1($password) !== $user['contrasena']) && ($password !== '12345')) {
+// Validacion con hash moderno y fallback SHA1 temporal para migracion.
+$stored = $user['contrasena'] ?? '';
+$legacyOk = hash_equals(sha1($password), $stored);
+$modernOk = password_verify($password, $stored);
+if (!$legacyOk && !$modernOk) {
     http_response_code(401);
-    echo json_encode(["error" => "Contrasena incorrecta"]);
+    echo json_encode(["error" => "Contrasena incorrecta"]);
     exit;
 }
+if ($legacyOk && !$modernOk) {
+    $newHash = password_hash($password, PASSWORD_DEFAULT);
+    $stmt = $conn->prepare("UPDATE menu_login.usuario SET contrasena = :hash WHERE id_usuario = :id");
+    $stmt->execute([":hash" => $newHash, ":id" => $user['id_usuario']]);
+}
```

Commit 2: `security-token-expiry`
```diff
--- a/php/helpers.php
+++ b/php/helpers.php
@@
-    $stmt = $conn->prepare("
-        SELECT user_id
-        FROM menu_login.tokens
-        WHERE token = :token
-        LIMIT 1
-    ");
+    $stmt = $conn->prepare("
+        SELECT user_id, expires_at
+        FROM menu_login.tokens
+        WHERE token = :token
+        LIMIT 1
+    ");
@@
-    if (!$row || !isset($row["user_id"])) {
+    if (!$row || !isset($row["user_id"])) {
         throw new Exception("Token invalido o expirado.");
     }
+    if (empty($row["expires_at"]) || strtotime($row["expires_at"]) < time()) {
+        throw new Exception("Token invalido o expirado.");
+    }
```

Commit 3: `security-secure-storage`
```diff
--- a/lib/services/auth_service.dart
+++ b/lib/services/auth_service.dart
@@
-import 'package:shared_preferences/shared_preferences.dart';
+import 'package:flutter_secure_storage/flutter_secure_storage.dart';
@@
 class AuthService {
   static const String _tokenKey = "auth_token";
   static const String _userKey = "auth_user";
   static const String _expiryKey = "auth_expiration";
+  static const FlutterSecureStorage _secure = FlutterSecureStorage();
@@
   static Future<void> saveSession(String token, Map<String, dynamic> user) async {
-    final prefs = await SharedPreferences.getInstance();
-    await prefs.setString(_tokenKey, token);
-    await prefs.setString(_userKey, jsonEncode(user));
+    await _secure.write(key: _tokenKey, value: token);
+    await _secure.write(key: _userKey, value: jsonEncode(user));
@@
-      await prefs.setString(_expiryKey, expiresAt);
+      await _secure.write(key: _expiryKey, value: expiresAt);
     } else if (expiresAt is DateTime) {
-      await prefs.setString(_expiryKey, expiresAt.toIso8601String());
+      await _secure.write(key: _expiryKey, value: expiresAt.toIso8601String());
     } else {
-      await prefs.remove(_expiryKey);
+      await _secure.delete(key: _expiryKey);
     }
   }
@@
   static Future<String?> getToken() async {
-    final prefs = await SharedPreferences.getInstance();
-    return prefs.getString(_tokenKey);
+    return await _secure.read(key: _tokenKey);
   }
@@
   static Future<Map<String, dynamic>?> getUser() async {
-    final prefs = await SharedPreferences.getInstance();
-    final json = prefs.getString(_userKey);
+    final json = await _secure.read(key: _userKey);
     if (json == null) return null;
     return jsonDecode(json);
   }
@@
   static Future<void> logout() async {
-    final prefs = await SharedPreferences.getInstance();
-    await prefs.remove(_tokenKey);
-    await prefs.remove(_userKey);
-    await prefs.remove(_expiryKey);
+    await _secure.delete(key: _tokenKey);
+    await _secure.delete(key: _userKey);
+    await _secure.delete(key: _expiryKey);
   }
@@
   static Future<DateTime?> _getExpiration() async {
-    final prefs = await SharedPreferences.getInstance();
-    final raw = prefs.getString(_expiryKey);
+    final raw = await _secure.read(key: _expiryKey);
     if (raw == null || raw.isEmpty) return null;
     return DateTime.tryParse(raw);
   }
 }
```

Commit 4: `tests-update-deprecations`
```diff
--- a/test/widget_test.dart
+++ b/test/widget_test.dart
@@
   testWidgets('Login renders brand content', (WidgetTester tester) async {
-    final binding = TestWidgetsFlutterBinding.ensureInitialized();
-    binding.window.physicalSizeTestValue = const Size(1080, 1920);
-    binding.window.devicePixelRatioTestValue = 1.0;
+    TestWidgetsFlutterBinding.ensureInitialized();
+    final view = tester.view;
+    view.physicalSize = const Size(1080, 1920);
+    view.devicePixelRatio = 1.0;
     addTearDown(() {
-      binding.window.clearPhysicalSizeTestValue();
-      binding.window.clearDevicePixelRatioTestValue();
+      view.resetPhysicalSize();
+      view.resetDevicePixelRatio();
     });
```

**Notas de implementacion**
- A-001 requiere rotar credenciales y moverlas fuera del repo (variables de entorno o secret manager).
- A-010 (mojibake) requiere guardar archivos en UTF-8 y revisar editor/CI.
- A-015 (listas) y A-016 (cache) deben probarse con cuentas con muchos inmuebles.
