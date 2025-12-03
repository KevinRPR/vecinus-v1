<?php
file_put_contents(__DIR__.'/log_mis_inmuebles.txt', "INPUT:\n".file_get_contents("php://input"));

header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once(__DIR__ . "/config/conexion.php");
$conn = ConexionAPI::getInstance();

// 1️⃣ Leer token
$input = json_decode(file_get_contents("php://input"), true);
$token = trim($input["token"] ?? "");

if (!$token) {
    http_response_code(400);
    echo json_encode(["error" => "Token requerido."]);
    exit;
}

// 2️⃣ Buscar usuario por token
try {
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
        http_response_code(401);
        echo json_encode(["error" => "Token inválido o expirado."]);
        exit;
    }

    $idUsuario = $row["user_id"];

    // 3️⃣ Obtener los inmuebles del usuario desde public.inmueble
    $sql = "
        SELECT 
            id_inmueble,
            id_condominio,
            id_usuario,
            alicuota,
            estado,
            torre,
            piso,
            identificacion,
            manzana,
            calle,
            avenida,
            tipo,
            correlativo
        FROM public.inmueble
        WHERE id_usuario = :id_usuario
        ORDER BY id_inmueble ASC
    ";

    $stmt2 = $conn->prepare($sql);
    $stmt2->execute([":id_usuario" => $idUsuario]);
    $inmuebles = $stmt2->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        "success" => true,
        "inmuebles" => $inmuebles
    ]);

} catch (Exception $e) {

    file_put_contents(
        __DIR__."/debug_error.txt",
        "ERROR SQL:\n".$e->getMessage()
    );

    http_response_code(500);
    echo json_encode(["error" => "Error consultando inmuebles"]);
}
