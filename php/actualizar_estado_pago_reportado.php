<?php
header("Content-Type: application/json; charset=UTF-8");

@session_start();
require_once(__DIR__ . "/config/conexion.php");

function ensure_columns(PDO $conn): void {
    $conn->exec("
        ALTER TABLE pago_reportado_app
            ADD COLUMN IF NOT EXISTS estado TEXT NOT NULL DEFAULT 'EN_PROCESO',
            ADD COLUMN IF NOT EXISTS motivo_rechazo TEXT NULL,
            ADD COLUMN IF NOT EXISTS aprobado_at TIMESTAMP NULL,
            ADD COLUMN IF NOT EXISTS rechazado_at TIMESTAMP NULL,
            ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
            ADD COLUMN IF NOT EXISTS client_uuid UUID NULL,
            ADD COLUMN IF NOT EXISTS ip INET NULL,
            ADD COLUMN IF NOT EXISTS user_agent TEXT NULL,
            ADD COLUMN IF NOT EXISTS evidencia_path TEXT NULL,
            ADD COLUMN IF NOT EXISTS evidencia_url TEXT NULL;
    ");
    $conn->exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_pra_client_uuid ON pago_reportado_app (client_uuid)");
    $conn->exec("CREATE INDEX IF NOT EXISTS idx_pra_estado ON pago_reportado_app (estado)");
    $conn->exec("CREATE INDEX IF NOT EXISTS idx_pra_user_created ON pago_reportado_app (id_usuario, created_at DESC)");
}

if (!isset($_SESSION["userid"])) {
    http_response_code(401);
    echo json_encode(["error" => "Sesion no valida"]);
    exit;
}

$id = isset($_POST["id"]) ? (int)$_POST["id"] : 0;
$estado = strtoupper(trim($_POST["estado"] ?? ""));
$motivo = trim($_POST["motivo"] ?? "");

if ($id <= 0) {
    echo json_encode(["error" => "ID requerido"]);
    exit;
}

if (!in_array($estado, ["APROBADO", "RECHAZADO"], true)) {
    echo json_encode(["error" => "Estado invalido"]);
    exit;
}

if ($estado === "RECHAZADO" && $motivo === "") {
    echo json_encode(["error" => "Motivo requerido para rechazo"]);
    exit;
}

try {
    $conn = ConexionAPI::getInstance();
    ensure_columns($conn);

    if ($estado === "APROBADO") {
        $stmt = $conn->prepare("
            UPDATE pago_reportado_app
            SET estado = 'APROBADO',
                aprobado_at = NOW(),
                rechazado_at = NULL,
                motivo_rechazo = NULL,
                updated_at = NOW()
            WHERE id = :id
        ");
        $stmt->execute([":id" => $id]);
    } else {
        $stmt = $conn->prepare("
            UPDATE pago_reportado_app
            SET estado = 'RECHAZADO',
                rechazado_at = NOW(),
                motivo_rechazo = :motivo,
                aprobado_at = NULL,
                updated_at = NOW()
            WHERE id = :id
        ");
        $stmt->execute([":id" => $id, ":motivo" => $motivo]);
    }

    echo json_encode(["success" => true, "id" => $id, "estado" => $estado]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["error" => $e->getMessage()]);
}
