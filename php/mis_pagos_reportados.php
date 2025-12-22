<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once(__DIR__ . "/config/conexion.php");
require_once(__DIR__ . "/helpers.php");

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

function get_user_from_token(PDO $conn, string $token): int {
    $stmt = $conn->prepare("
        SELECT user_id
        FROM menu_login.tokens
        WHERE token = :token
          AND expires_at > NOW()
        LIMIT 1
    ");
    $stmt->execute([":token" => $token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row || !isset($row["user_id"])) {
        respond_error("Token invalido o expirado.", 401);
    }

    return (int)$row["user_id"];
}

function build_evidence_url(?string $path): ?string {
    if (!$path) return null;
    if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
        return $path;
    }
    $clean = ltrim(str_replace('\\', '/', $path), '/');
    return rtrim(api_base_url(), '/') . '/' . $clean;
}

function compute_resumen(array $detalle): array {
    $resumen = [
        "abono_total_base" => null,
        "pagos_total_base" => null,
        "pendiente_total_base" => null,
        "cubre_total_estimado" => null,
    ];

    if (isset($detalle["resumen"]) && is_array($detalle["resumen"])) {
        $res = $detalle["resumen"];
        $resumen["abono_total_base"] = $res["abono_total_base"] ?? null;
        $resumen["pagos_total_base"] = $res["pagos_total_base"] ?? null;
        $resumen["pendiente_total_base"] = $res["pendiente_total_base"] ?? null;
        if ($resumen["pendiente_total_base"] !== null && $resumen["pagos_total_base"] !== null) {
            $resumen["cubre_total_estimado"] = ($resumen["pagos_total_base"] + 0.01) >= $resumen["pendiente_total_base"];
        }
    } else {
        // Fallback calculando desde el detalle
        if (isset($detalle["notificaciones"]) && is_array($detalle["notificaciones"])) {
            $abonoTotal = 0.0;
            foreach ($detalle["notificaciones"] as $n) {
                $abono = (float)($n["abono"] ?? 0);
                $tasa = (float)($n["tasa"] ?? 1);
                $abonoTotal += $abono * ($tasa > 0 ? $tasa : 1);
            }
            $resumen["abono_total_base"] = $abonoTotal;
            $resumen["pagos_total_base"] = $abonoTotal;
        }
    }
    return $resumen;
}

try {
    $conn = ConexionAPI::getInstance();
    ensure_columns($conn);
    $input = json_decode(file_get_contents("php://input"), true) ?? [];
    if (empty($input)) {
        $input = $_POST;
    }

    $token = trim($input["token"] ?? "");
    if ($token === "") {
        respond_error("Token requerido.", 400);
    }
    $userId = get_user_from_token($conn, $token);

    $idInmueble = null;
    if (isset($input["id_inmueble"]) && $input["id_inmueble"] !== "") {
        $idInmueble = (int)$input["id_inmueble"];
    }

    $sql = "
        SELECT id, id_usuario, id_inmueble, id_condominio, fecha_pago, observacion, total_base, moneda_base,
               estado, motivo_rechazo, evidencia_url, evidencia_path, created_at, aprobado_at, rechazado_at, client_uuid, detalle
        FROM pago_reportado_app
        WHERE id_usuario = :usr
    ";
    $params = [":usr" => $userId];
    if ($idInmueble !== null) {
        $sql .= " AND id_inmueble = :inmueble";
        $params[":inmueble"] = $idInmueble;
    }
    $sql .= " ORDER BY created_at DESC LIMIT 100";

    $stmt = $conn->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];

    foreach ($rows as &$r) {
        if (empty($r["evidencia_url"]) && !empty($r["evidencia_path"])) {
            $r["evidencia_url"] = build_evidence_url($r["evidencia_path"]);
        }
        $detalle = [];
        if (!empty($r["detalle"])) {
            $detalle = json_decode($r["detalle"], true) ?? [];
        }
        $resumen = compute_resumen($detalle);
        $r["abono_total_base"] = $resumen["abono_total_base"];
        $r["pagos_total_base"] = $resumen["pagos_total_base"];
        $r["pendiente_total_base"] = $resumen["pendiente_total_base"];
        $r["cubre_total_estimado"] = $resumen["cubre_total_estimado"];
        unset($r["detalle"]);
    }
    unset($r);

    respond_success(["reportes" => $rows]);
} catch (Exception $e) {
    respond_error($e->getMessage(), 500);
}
