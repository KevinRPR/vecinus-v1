<?php

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
    $binary = base64_decode($cleanData);

    if ($binary === false) {
        throw new Exception('Imagen inválida.');
    }

    $filePath = avatar_storage_path($userId);
    file_put_contents($filePath, $binary);

    return avatar_public_url($userId) ?? '';
}

function respond_success(array $payload = []): void {
    http_response_code(200);
    echo json_encode(array_merge(["success" => true], $payload));
    exit;
}

function respond_error(string $message, int $status = 400): void {
    http_response_code($status);
    echo json_encode(["error" => $message]);
    exit;
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
