<?php
header("Content-Type: application/json; charset=UTF-8");

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

function build_evidence_url(?string $path): ?string {
    if (!$path) return null;
    $normalized = trim(str_replace('\\', '/', $path));
    if ($normalized === '') return null;
    if (str_starts_with($normalized, 'http://') || str_starts_with($normalized, 'https://')) {
        return $normalized;
    }

    $uploadsPos = strpos(strtolower($normalized), '/uploads/');
    if ($uploadsPos !== false) {
        $normalized = substr($normalized, $uploadsPos + 1);
    }

    $normalized = ltrim($normalized, '/');
    if (str_starts_with($normalized, 'condominio/movil/')) {
        $normalized = substr($normalized, strlen('condominio/movil/'));
    } elseif (str_starts_with($normalized, 'movil/')) {
        $normalized = substr($normalized, strlen('movil/'));
    }

    if ($normalized === '') {
        return null;
    }
    return rtrim(api_base_url(), '/') . '/' . $normalized;
}

function extract_detail_evidence_url(array $detalle): ?string {
    $directUrlKeys = ['evidencia_url', 'comprobante_url', 'archivo_url', 'url_comprobante', 'url'];
    foreach ($directUrlKeys as $key) {
        $value = trim((string)($detalle[$key] ?? ''));
        if ($value !== '' && strtolower($value) !== 'null') {
            return build_evidence_url($value);
        }
    }

    $pathKeys = ['evidencia_path', 'comprobante_path', 'archivo_path', 'ruta_comprobante', 'path'];
    foreach ($pathKeys as $key) {
        $value = trim((string)($detalle[$key] ?? ''));
        if ($value !== '' && strtolower($value) !== 'null') {
            return build_evidence_url($value);
        }
    }

    $nestedKeys = ['comprobante', 'evidencia', 'archivo'];
    foreach ($nestedKeys as $nested) {
        if (!isset($detalle[$nested]) || !is_array($detalle[$nested])) {
            continue;
        }
        $nestedMatch = extract_detail_evidence_url($detalle[$nested]);
        if ($nestedMatch !== null) {
            return $nestedMatch;
        }
    }

    return null;
}

function find_evidence_by_client_uuid(?string $clientUuid): ?string {
    $uuid = trim((string)$clientUuid);
    if ($uuid === '' || !preg_match('/^[a-f0-9-]{8,64}$/i', $uuid)) {
        return null;
    }
    $files = glob(__DIR__ . '/uploads/evidencias/' . $uuid . '.*');
    if (!$files) {
        return null;
    }
    sort($files);
    foreach ($files as $file) {
        if (is_file($file)) {
            return build_evidence_url($file);
        }
    }
    return null;
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

function estado_label(string $estado): string {
    $normalized = strtoupper(trim($estado));
    if ($normalized === 'APROBADO') {
        return 'Aprobado';
    }
    if ($normalized === 'RECHAZADO') {
        return 'Rechazado';
    }
    return 'En revision';
}

function build_timeline(array $row): array {
    $timeline = [];
    $createdAt = $row['created_at'] ?? null;
    if ($createdAt) {
        $timeline[] = [
            'key' => 'enviado',
            'label' => 'Enviado',
            'at' => $createdAt,
        ];
        $timeline[] = [
            'key' => 'en_revision',
            'label' => 'En revision',
            'at' => $createdAt,
        ];
    }

    $estado = strtoupper(trim((string)($row['estado'] ?? '')));
    if ($estado === 'APROBADO' && !empty($row['aprobado_at'])) {
        $timeline[] = [
            'key' => 'aprobado',
            'label' => 'Aprobado',
            'at' => $row['aprobado_at'],
        ];
    } elseif ($estado === 'RECHAZADO' && !empty($row['rechazado_at'])) {
        $timeline[] = [
            'key' => 'rechazado',
            'label' => 'Rechazado',
            'at' => $row['rechazado_at'],
        ];
    }
    return $timeline;
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
    $userId = resolve_user_id_from_token($conn, $token);

    $idInmueble = null;
    if (isset($input["id_inmueble"]) && $input["id_inmueble"] !== "") {
        $idInmueble = (int)$input["id_inmueble"];
    }

    $sql = "
        SELECT id, id_usuario, id_inmueble, id_condominio, fecha_pago, observacion, total_base, moneda_base,
               estado, motivo_rechazo, comentario_admin, evidencia_url, evidencia_path, created_at, aprobado_at, rechazado_at, client_uuid, detalle
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
        if (strtolower(trim((string)($r["evidencia_url"] ?? ''))) === 'null') {
            $r["evidencia_url"] = null;
        }
        $detalle = [];
        if (!empty($r["detalle"])) {
            $detalle = json_decode($r["detalle"], true) ?? [];
        }

        if (empty($r["evidencia_url"]) && !empty($r["evidencia_path"])) {
            $r["evidencia_url"] = build_evidence_url($r["evidencia_path"]);
        }
        if (empty($r["evidencia_url"]) && !empty($detalle)) {
            $r["evidencia_url"] = extract_detail_evidence_url($detalle);
        }
        if (empty($r["evidencia_url"])) {
            $r["evidencia_url"] = find_evidence_by_client_uuid($r["client_uuid"] ?? null);
        }

        $comentarioAdmin = trim((string)($r["comentario_admin"] ?? ''));
        $motivoRechazo = trim((string)($r["motivo_rechazo"] ?? ''));
        if ($comentarioAdmin === '' && $motivoRechazo !== '') {
            $comentarioAdmin = $motivoRechazo;
        }
        if ($motivoRechazo === '' && strtoupper((string)($r["estado"] ?? '')) === 'RECHAZADO' && $comentarioAdmin !== '') {
            $motivoRechazo = $comentarioAdmin;
        }
        $r["comentario_admin"] = $comentarioAdmin !== '' ? $comentarioAdmin : null;
        $r["motivo_rechazo"] = $motivoRechazo !== '' ? $motivoRechazo : null;
        $r["estado_label"] = estado_label((string)($r["estado"] ?? ''));
        $r["timeline"] = build_timeline($r);

        $resumen = compute_resumen($detalle);
        $r["abono_total_base"] = $resumen["abono_total_base"];
        $r["pagos_total_base"] = $resumen["pagos_total_base"];
        $r["pendiente_total_base"] = $resumen["pendiente_total_base"];
        $r["cubre_total_estimado"] = $resumen["cubre_total_estimado"];
        unset($r["detalle"]);
    }
    unset($r);

    respond_success(["reportes" => $rows]);
} catch (Throwable $e) {
    log_error('mis_pagos_reportados failed', [
        'error' => $e->getMessage(),
    ]);
    $lower = strtolower($e->getMessage());
    $status = (strpos($lower, 'token') !== false) ? 401 : 500;
    respond_error($e->getMessage(), $status);
}
