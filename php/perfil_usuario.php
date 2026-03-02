<?php
header("Content-Type: application/json; charset=UTF-8");

require_once(__DIR__ . "/config/conexion.php");
require_once(__DIR__ . "/helpers.php");

apply_cors();
handle_preflight();

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
    respond_error("Token invalido o expirado.", 401);
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
            throw new Exception("Correo invalido.");
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
        throw new Exception("Debe indicar contrasena actual y nueva.");
    }

    if (strlen($new) < 6) {
        throw new Exception("La nueva contrasena debe tener al menos 6 caracteres.");
    }

    $stmt = $conn->prepare("
        SELECT contrasena
        FROM menu_login.usuario
        WHERE id_usuario = :id
        LIMIT 1
    ");
    $stmt->execute([":id" => $userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    $stored = $row['contrasena'] ?? '';
    $isModern = preg_match('/^\\$2[aby]\\$|^\\$argon2/', $stored) === 1;
    $legacyOk = hash_equals(sha1($current), $stored);
    $modernOk = $isModern ? password_verify($current, $stored) : false;

    if (!$legacyOk && !$modernOk) {
        throw new Exception("La contrasena actual no es valida.");
    }

    $newHash = password_hash($new, PASSWORD_DEFAULT);
    $stmt = $conn->prepare("
        UPDATE menu_login.usuario
        SET contrasena = :password
        WHERE id_usuario = :id
    ");
    $stmt->execute([
        ":password" => $newHash,
        ":id" => $userId
    ]);

    respond_success(["message" => "Contrasena actualizada."]);
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
?>
