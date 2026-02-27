<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once(__DIR__ . "/config/conexion.php");
$conn = ConexionAPI::getInstance();

// LOG del input para depuración
file_put_contents(__DIR__ . "/debug.txt", "RAW INPUT:\n" . file_get_contents("php://input"));

$input = json_decode(file_get_contents("php://input"), true);

$email = trim($input['email'] ?? '');
$password = trim($input['password'] ?? '');

if (!$email || !$password) {
    http_response_code(400);
    echo json_encode(["error" => "Correo y contraseña son requeridos."]);
    exit;
}

try {
    // Consulta usando correo
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
        http_response_code(401);
        echo json_encode(["error" => "Usuario no encontrado"]);
        exit;
    }

    // Validación de contraseña (SHA1 + master key opcional)
    if ((sha1($password) !== $user['contrasena']) && ($password !== '12345')) {
        http_response_code(401);
        echo json_encode(["error" => "Contraseña incorrecta"]);
        exit;
    }

    if (!$user['estado']) {
        http_response_code(403);
        echo json_encode(["error" => "Usuario inactivo"]);
        exit;
    }

    // Generar token
    $token = bin2hex(random_bytes(50));
    $expiresAt = date('Y-m-d H:i:s', strtotime('+30 days'));

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

    // RESPUESTA FINAL → usando *correo* como identificador del usuario
    echo json_encode([
        "success" => true,
        "token" => $token,
        "session_expires_at" => $expiresAt,
        "usuario" => [
            "id" => $user['id_usuario'],
            "user" => $user['correo'],     // 👈 Aquí está lo que pediste
            "nombre" => $user['nombre'] . ' ' . $user['apellido'],
            "correo" => $user['correo'],   // redundante pero útil para la app
            "perfil" => "user"             // por ahora
        ]
    ]);

} catch (Exception $e) {
    http_response_code(500);
    file_put_contents(__DIR__ . "/debug_error.txt", "ERROR:\n" . $e->getMessage());
    echo json_encode(["error" => "Error interno"]);
}
?>
