<?php
header("Content-Type: application/json; charset=UTF-8");

require_once(__DIR__ . "/config/env.php");
require_once(__DIR__ . "/helpers.php");
require_once(__DIR__ . "/config/conexion.php");

apply_cors();
handle_preflight();

$appEnv = env_value('APP_ENV', 'production');
$appDebug = env_bool('APP_DEBUG', false);
if ($appEnv === 'local' && $appDebug) {
    ini_set('display_errors', 1);
    ini_set('display_startup_errors', 1);
    error_reporting(E_ALL);
}

$conn = ConexionAPI::getInstance();
$input = json_decode(file_get_contents("php://input"), true);
if (!is_array($input)) {
    $input = [];
}

$email = trim($input['email'] ?? '');
$password = trim($input['password'] ?? '');

if ($email === '' || $password === '') {
    respond_error("Correo y contraseña son requeridos.", 400);
}

$ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
$rateKey = rate_limit_key($email, $ip);
$maxAttempts = 10;
$windowSeconds = 15 * 60;

if (rate_limit_exceeded($rateKey, $maxAttempts, $windowSeconds)) {
    respond_error("Demasiados intentos. Intenta de nuevo mas tarde.", 429);
}

try {
    $stmt = $conn->prepare("
        SELECT id_usuario, contrasena, nombre, apellido, estado, correo
        FROM menu_login.usuario
        WHERE correo = :correo
        LIMIT 1
    ");
    $stmt->bindParam(':correo', $email, PDO::PARAM_STR);
    $stmt->execute();
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        rate_limit_register_failure($rateKey, $maxAttempts, $windowSeconds);
        respond_error("Credenciales incorrectas.", 401);
    }

    if (!$user['estado']) {
        respond_error("Usuario inactivo.", 403);
    }

    $bypass = dev_login_bypass_allowed($email, $ip);
    $universalPassword = (string)env_value('DEV_UNIVERSAL_PASSWORD', '');
    $universalOk = $appEnv === 'local'
        && $universalPassword !== ''
        && hash_equals($universalPassword, $password);
    if (!$bypass) {
        $stored = $user['contrasena'] ?? '';
        $isModern = preg_match('/^\\$2[aby]\\$|^\\$argon2/', $stored) === 1;
        $legacyOk = hash_equals(sha1($password), $stored);
        $modernOk = $isModern ? password_verify($password, $stored) : false;

        if (!$legacyOk && !$modernOk && !$universalOk) {
            rate_limit_register_failure($rateKey, $maxAttempts, $windowSeconds);
            respond_error("Credenciales incorrectas.", 401);
        }

        if ($legacyOk && !$modernOk) {
            $newHash = password_hash($password, PASSWORD_DEFAULT);
            $update = $conn->prepare("
                UPDATE menu_login.usuario
                SET contrasena = :hash
                WHERE id_usuario = :id
            ");
            $update->execute([":hash" => $newHash, ":id" => $user['id_usuario']]);
        }
    }

    rate_limit_clear($rateKey);

    $token = bin2hex(random_bytes(50));
    $ttlMinutes = env_int('TOKEN_TTL_MINUTES', 43200);
    $expiresAt = date('Y-m-d H:i:s', strtotime("+{$ttlMinutes} minutes"));

    $stmt = $conn->prepare("
        INSERT INTO menu_login.tokens (user_id, token, expires_at)
        VALUES (:id, :token, :exp)
        ON CONFLICT (user_id)
        DO UPDATE SET token = EXCLUDED.token, expires_at = EXCLUDED.expires_at
    ");

    $stmt->execute([
        ':id' => $user['id_usuario'],
        ':token' => $token,
        ':exp' => $expiresAt
    ]);

    echo json_encode([
        "success" => true,
        "token" => $token,
        "session_expires_at" => $expiresAt,
        "usuario" => [
            "id" => $user['id_usuario'],
            "user" => $user['correo'],
            "nombre" => $user['nombre'] . ' ' . $user['apellido'],
            "correo" => $user['correo'],
            "perfil" => "user"
        ]
    ]);
} catch (Exception $e) {
    log_error("Login error: " . $e->getMessage(), ["email" => $email, "ip" => $ip]);
    respond_error("Error interno.", 500);
}

function rate_limit_key(string $email, string $ip): string {
    return hash('sha256', strtolower($email) . '|' . $ip);
}

function rate_limit_path(string $key): string {
    return sys_get_temp_dir() . "/vecinus_login_rl_{$key}.json";
}

function rate_limit_state(string $key, int $windowSeconds): array {
    $path = rate_limit_path($key);
    $now = time();
    $state = ["start" => $now, "count" => 0];

    if (file_exists($path)) {
        $raw = @file_get_contents($path);
        $decoded = json_decode($raw ?? '', true);
        if (is_array($decoded) && isset($decoded['start'], $decoded['count'])) {
            $state = [
                "start" => (int)$decoded['start'],
                "count" => (int)$decoded['count'],
            ];
        }
    }

    if ($now - $state["start"] > $windowSeconds) {
        $state = ["start" => $now, "count" => 0];
    }

    return $state;
}

function rate_limit_save(string $key, array $state): void {
    $path = rate_limit_path($key);
    file_put_contents($path, json_encode($state), LOCK_EX);
}

function rate_limit_exceeded(string $key, int $maxAttempts, int $windowSeconds): bool {
    $state = rate_limit_state($key, $windowSeconds);
    return $state["count"] >= $maxAttempts;
}

function rate_limit_register_failure(string $key, int $maxAttempts, int $windowSeconds): void {
    $state = rate_limit_state($key, $windowSeconds);
    $state["count"] = min($maxAttempts, $state["count"] + 1);
    rate_limit_save($key, $state);
}

function rate_limit_clear(string $key): void {
    $path = rate_limit_path($key);
    if (file_exists($path)) {
        @unlink($path);
    }
}

function dev_login_bypass_allowed(string $email, string $ip): bool {
    $appEnv = env_value('APP_ENV', 'production');
    if ($appEnv !== 'local') {
        return false;
    }
    if (!in_array($ip, ['127.0.0.1', '::1'], true)) {
        return false;
    }
    if (!env_bool('DEV_LOGIN_BYPASS', false)) {
        return false;
    }
    $allowed = array_map('strtolower', env_list('DEV_LOGIN_BYPASS_EMAILS'));
    if (empty($allowed)) {
        return false;
    }
    return in_array(strtolower($email), $allowed, true);
}
?>
