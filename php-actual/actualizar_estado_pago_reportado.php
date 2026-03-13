<?php
header("Content-Type: application/json; charset=UTF-8");

@session_start();
require_once(__DIR__ . "/config/conexion.php");
require_once(__DIR__ . "/helpers.php");

apply_cors();
handle_preflight();

function ensure_columns(PDO $conn): void {
    $conn->exec("
        ALTER TABLE pago_reportado_app
            ADD COLUMN IF NOT EXISTS estado TEXT NOT NULL DEFAULT 'EN_PROCESO',
            ADD COLUMN IF NOT EXISTS motivo_rechazo TEXT NULL,
            ADD COLUMN IF NOT EXISTS comentario_admin TEXT NULL,
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
    respond_error("Sesion no valida", 401);
}

$input = json_decode(file_get_contents("php://input"), true) ?? [];
if (empty($input)) {
    $input = $_POST;
}

$id = isset($input["id"]) ? (int)$input["id"] : 0;
$estado = strtoupper(trim((string)($input["estado"] ?? "")));
$comentarioAdmin = trim((string)($input["comentario_admin"] ?? $input["motivo"] ?? ""));

if ($id <= 0) {
    respond_error("ID requerido", 400);
}

if (!in_array($estado, ["APROBADO", "RECHAZADO"], true)) {
    respond_error("Estado invalido", 400);
}

if ($estado === "RECHAZADO" && $comentarioAdmin === "") {
    respond_error("Comentario requerido para rechazo", 400);
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
                comentario_admin = :comentario_admin,
                updated_at = NOW()
            WHERE id = :id
        ");
        $stmt->bindValue(':id', $id, PDO::PARAM_INT);
        if ($comentarioAdmin === '') {
            $stmt->bindValue(':comentario_admin', null, PDO::PARAM_NULL);
        } else {
            $stmt->bindValue(':comentario_admin', $comentarioAdmin, PDO::PARAM_STR);
        }
        $stmt->execute();
    } else {
        $stmt = $conn->prepare("
            UPDATE pago_reportado_app
            SET estado = 'RECHAZADO',
                rechazado_at = NOW(),
                motivo_rechazo = :comentario,
                comentario_admin = :comentario,
                aprobado_at = NULL,
                updated_at = NOW()
            WHERE id = :id
        ");
        $stmt->execute([
            ":id" => $id,
            ":comentario" => $comentarioAdmin,
        ]);
    }

    if ($stmt->rowCount() === 0) {
        respond_error("Reporte no encontrado o sin cambios.", 404);
    }

    respond_success([
        "id" => $id,
        "estado" => $estado,
        "estado_label" => $estado === 'APROBADO' ? 'Aprobado' : 'Rechazado',
        "comentario_admin" => $comentarioAdmin !== '' ? $comentarioAdmin : null,
    ]);
} catch (Exception $e) {
    log_error('actualizar_estado_pago_reportado failed', [
        'id' => $id,
        'estado' => $estado,
        'error' => $e->getMessage(),
    ]);
    respond_error($e->getMessage(), 500);
}