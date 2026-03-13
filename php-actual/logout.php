<?php
header("Content-Type: application/json; charset=UTF-8");

require_once(__DIR__ . "/config/conexion.php");
require_once(__DIR__ . "/helpers.php");

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
    $stmt = $conn->prepare("DELETE FROM menu_login.tokens WHERE token = :token");
    $stmt->execute([":token" => $token]);
    respond_success(["revoked" => $stmt->rowCount() > 0]);
} catch (Throwable $e) {
    log_error("Logout error: " . $e->getMessage());
    respond_error("Error interno.", 500);
}

