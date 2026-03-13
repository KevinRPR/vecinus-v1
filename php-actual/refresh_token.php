<?php
header("Content-Type: application/json; charset=UTF-8");

require_once(__DIR__ . "/config/env.php");
require_once(__DIR__ . "/helpers.php");
require_once(__DIR__ . "/config/conexion.php");

apply_cors();
handle_preflight();

$conn = ConexionAPI::getInstance();
$input = json_decode(file_get_contents("php://input"), true);
if (!is_array($input)) {
    $input = [];
}

$token = trim((string)($input["token"] ?? ""));
if ($token === "") {
    respond_error("Token requerido.", 400);
}

try {
    $stmt = $conn->prepare("
        SELECT
            t.user_id,
            t.expires_at,
            u.nombre,
            u.apellido,
            u.correo,
            u.estado
        FROM menu_login.tokens t
        INNER JOIN menu_login.usuario u ON u.id_usuario = t.user_id
        WHERE t.token = :token
        LIMIT 1
    ");
    $stmt->execute([":token" => $token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        respond_error("Token invalido o expirado.", 401);
    }

    if (!($row["estado"] ?? false)) {
        respond_error("Usuario inactivo.", 403);
    }

    $expiresAtRaw = (string)($row["expires_at"] ?? "");
    $expiresAt = strtotime($expiresAtRaw);
    if ($expiresAt === false || $expiresAt < time()) {
        $cleanup = $conn->prepare("DELETE FROM menu_login.tokens WHERE token = :token");
        $cleanup->execute([":token" => $token]);
        respond_error("Token invalido o expirado.", 401);
    }

    $newToken = bin2hex(random_bytes(50));
    $ttlMinutes = env_int("TOKEN_TTL_MINUTES", 43200);
    $newExpiresAt = date("Y-m-d H:i:s", strtotime("+{$ttlMinutes} minutes"));

    $update = $conn->prepare("
        UPDATE menu_login.tokens
        SET token = :new_token,
            expires_at = :expires_at
        WHERE user_id = :user_id
          AND token = :old_token
    ");
    $update->execute([
        ":new_token" => $newToken,
        ":expires_at" => $newExpiresAt,
        ":user_id" => $row["user_id"],
        ":old_token" => $token,
    ]);

    if ($update->rowCount() === 0) {
        respond_error("No se pudo refrescar la sesion.", 409);
    }

    respond_success([
        "token" => $newToken,
        "session_expires_at" => $newExpiresAt,
        "usuario" => [
            "id" => (int)$row["user_id"],
            "user" => (string)$row["correo"],
            "nombre" => trim((string)$row["nombre"] . " " . (string)$row["apellido"]),
            "correo" => (string)$row["correo"],
            "perfil" => "user",
        ],
    ]);
} catch (Throwable $e) {
    log_error("Refresh token error: " . $e->getMessage());
    respond_error("Error interno.", 500);
}

