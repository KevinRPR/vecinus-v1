<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once(__DIR__ . "/config/conexion.php");
require_once(__DIR__ . "/helpers.php");

$conn = ConexionAPI::getInstance();
$input = json_decode(file_get_contents("php://input"), true) ?? [];

$token = trim($input['token'] ?? '');
$action = strtolower(trim($input['accion'] ?? 'consultar'));

if (!$token) {
    respond_error("Token requerido.", 400);
}

try {
    $userId = resolve_user_id_from_token($conn, $token);
} catch (Exception $e) {
    respond_error("Token inválido o expirado.", 401);
}

try {
    switch ($action) {
        case 'actualizar':
        case 'update':
            update_profile($conn, $userId, $input);
            break;
        case 'password':
        case 'contrasena':
        case 'cambiar_password':
            change_password($conn, $userId, $input);
            break;
        case 'avatar':
        case 'foto':
        case 'imagen':
            update_avatar($conn, $userId, $input);
            break;
        default:
            send_profile($conn, $userId);
            break;
    }
} catch (Exception $e) {
    respond_error($e->getMessage(), 400);
}

function resolve_user_id_from_token(PDO $conn, string $token): int {
    $stmt = $conn->prepare("
        SELECT user_id
        FROM menu_login.tokens
        WHERE token = :token
          AND expires_at > NOW()
        LIMIT 1
    ");
    $stmt->execute([":token" => $token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        throw new Exception("Token inválido");
    }

    return (int) $row['user_id'];
}

function send_profile(PDO $conn, int $userId): void {
    $stmt = $conn->prepare("
        SELECT id_usuario, nombre, apellido, correo
        FROM menu_login.usuario
        WHERE id_usuario = :id
        LIMIT 1
    ");
    $stmt->execute([":id" => $userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        respond_error("Usuario no encontrado.", 404);
    }

    respond_success(["usuario" => build_user_payload($user)]);
}

function update_profile(PDO $conn, int $userId, array $input): void {
    $nombre = trim($input['nombre'] ?? '');
    $apellido = trim($input['apellido'] ?? '');
    $correo = trim($input['correo'] ?? '');

    if ($nombre === '' || $apellido === '') {
        throw new Exception("Nombre y apellido son requeridos.");
    }

    $fields = [
        "nombre" => $nombre,
        "apellido" => $apellido,
    ];

    if ($correo !== '') {
        if (!filter_var($correo, FILTER_VALIDATE_EMAIL)) {
            throw new Exception("Correo inválido.");
        }
        $fields["correo"] = $correo;
    }

    $setParts = [];
    $params = [":id" => $userId];

    foreach ($fields as $key => $value) {
        $setParts[] = "{$key} = :{$key}";
        $params[":{$key}"] = $value;
    }

    $sql = "UPDATE menu_login.usuario SET " . implode(', ', $setParts) . " WHERE id_usuario = :id";
    $stmt = $conn->prepare($sql);
    $stmt->execute($params);

    send_profile($conn, $userId);
}

function change_password(PDO $conn, int $userId, array $input): void {
    $current = $input['password_actual'] ?? '';
    $new = $input['password_nueva'] ?? '';

    if (!$current || !$new) {
        throw new Exception("Debe indicar contraseña actual y nueva.");
    }

    if (strlen($new) < 6) {
        throw new Exception("La nueva contraseña debe tener al menos 6 caracteres.");
    }

    $stmt = $conn->prepare("
        SELECT contrasena
        FROM menu_login.usuario
        WHERE id_usuario = :id
        LIMIT 1
    ");
    $stmt->execute([":id" => $userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row || sha1($current) !== $row['contrasena']) {
        throw new Exception("La contraseña actual no es válida.");
    }

    $stmt = $conn->prepare("
        UPDATE menu_login.usuario
        SET contrasena = :password
        WHERE id_usuario = :id
    ");
    $stmt->execute([
        ":password" => sha1($new),
        ":id" => $userId
    ]);

    respond_success(["message" => "Contraseña actualizada."]);
}

function update_avatar(PDO $conn, int $userId, array $input): void {
    $imageData = $input['avatar_base64'] ?? '';

    if (!$imageData) {
        throw new Exception("Imagen requerida.");
    }

    $url = save_avatar_from_base64($userId, $imageData);
    respond_success([
        "avatar_url" => $url
    ]);
}
