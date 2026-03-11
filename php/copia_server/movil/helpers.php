<?php

require_once(__DIR__ . "/config/env.php");

function request_id(): string {
    static $id = null;
    if ($id === null) {
        $id = bin2hex(random_bytes(8));
    }
    return $id;
}

function log_error(string $message, array $context = []): void {
    $entry = "[" . request_id() . "] " . $message;
    if (!empty($context)) {
        $entry .= " " . json_encode($context);
    }
    error_log($entry);
}

function apply_cors(): void {
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    $allowed = env_list('CORS_ALLOWED_ORIGINS');
    $allowAny = in_array('*', $allowed, true);

    if ($origin !== '' && ($allowAny || in_array($origin, $allowed, true))) {
        header("Access-Control-Allow-Origin: {$origin}");
        header("Vary: Origin");
    }
    header("Access-Control-Allow-Methods: POST, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, Authorization");
}

function handle_preflight(): void {
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function api_base_url(): string {
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $scriptDir = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? ''));
    $scriptDir = rtrim($scriptDir, '/');
    return rtrim($scheme . '://' . $host . ($scriptDir ? '/' . ltrim($scriptDir, '/') : ''), '/') . '/';
}

function avatar_relative_path($userId): string {
    return 'uploads/avatars/' . $userId . '.jpg';
}

function avatar_storage_path($userId): string {
    $directory = __DIR__ . '/uploads/avatars';
    if (!is_dir($directory)) {
        mkdir($directory, 0775, true);
    }
    return $directory . '/' . $userId . '.jpg';
}

function avatar_public_url($userId): ?string {
    $filePath = avatar_storage_path($userId);
    if (!file_exists($filePath)) {
        return null;
    }
    $relative = avatar_relative_path($userId);
    return api_base_url() . $relative . '?v=' . filemtime($filePath);
}

function save_avatar_from_base64($userId, string $rawData): string {
    $cleanData = preg_replace('/^data:image\/[a-zA-Z]+;base64,/', '', $rawData);
    $binary = base64_decode($cleanData, true);

    if ($binary === false) {
        throw new Exception('Imagen invalida.');
    }

    $maxBytes = env_int('AVATAR_MAX_BYTES', 2000000);
    if (strlen($binary) > $maxBytes) {
        throw new Exception('La imagen supera el tamano maximo permitido.');
    }

    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = $finfo->buffer($binary);
    $allowed = ['image/jpeg', 'image/pjpeg'];
    if (!in_array($mime, $allowed, true)) {
        throw new Exception('Formato de imagen no permitido.');
    }

    $filePath = avatar_storage_path($userId);
    file_put_contents($filePath, $binary, LOCK_EX);

    return avatar_public_url($userId) ?? '';
}

function respond_success(array $payload = []): void {
    http_response_code(200);
    echo json_encode(array_merge(["success" => true], $payload));
    exit;
}

function respond_error(string $message, int $status = 400): void {
    http_response_code($status);
    $payload = ["error" => $message];
    if (env_bool('APP_DEBUG', false)) {
        $payload["request_id"] = request_id();
    }
    echo json_encode($payload);
    exit;
}

function resolve_user_id_from_token(PDO $conn, string $token): int {
    $stmt = $conn->prepare("
        SELECT user_id, expires_at
        FROM menu_login.tokens
        WHERE token = :token
        LIMIT 1
    ");
    $stmt->execute([":token" => $token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row || !isset($row["user_id"])) {
        throw new Exception("Token invalido o expirado.");
    }

    $expiresAtRaw = $row["expires_at"] ?? '';
    $expiresAt = strtotime($expiresAtRaw);
    if ($expiresAt === false || $expiresAt < time()) {
        throw new Exception("Token invalido o expirado.");
    }

    $ttlMinutes = env_int('TOKEN_TTL_MINUTES', 43200);
    $refreshMinutes = env_int('TOKEN_REFRESH_THRESHOLD_MINUTES', 10);
    $remainingSeconds = $expiresAt - time();
    if ($remainingSeconds <= ($refreshMinutes * 60)) {
        $newExpires = date('Y-m-d H:i:s', strtotime("+{$ttlMinutes} minutes"));
        $update = $conn->prepare("
            UPDATE menu_login.tokens
            SET expires_at = :exp
            WHERE token = :token
        ");
        $update->execute([":exp" => $newExpires, ":token" => $token]);
    }

    return (int)$row["user_id"];
}

function build_user_payload(array $userRow): array {
    $userId = $userRow['id_usuario'] ?? $userRow['id'] ?? $userRow['user_id'] ?? null;

    if ($userId === null) {
        return [
            "id_usuario" => null,
            "nombre" => $userRow['nombre'] ?? '',
            "apellido" => $userRow['apellido'] ?? '',
            "correo" => $userRow['correo'] ?? '',
            "perfil" => $userRow['perfil'] ?? 'user',
            "avatar_url" => null,
        ];
    }

    return [
        "id_usuario" => $userId,
        "nombre" => $userRow['nombre'] ?? '',
        "apellido" => $userRow['apellido'] ?? '',
        "correo" => $userRow['correo'] ?? ($userRow['email'] ?? ''),
        "perfil" => $userRow['perfil'] ?? 'user',
        "avatar_url" => avatar_public_url($userId)
    ];
}
