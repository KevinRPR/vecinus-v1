<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once(__DIR__ . "/config/conexion.php");
require_once(__DIR__ . "/helpers.php");

function assert_required(array $data, array $keys): void
{
    foreach ($keys as $k) {
        if (!isset($data[$k]) || (is_string($data[$k]) && trim($data[$k]) === "")) {
            respond_error("Falta el campo requerido: {$k}", 400);
        }
    }
}

function get_user_from_token(PDO $conn, string $token): int
{
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

function get_inmueble(PDO $conn, int $userId, int $idInmueble): array
{
    $stmt = $conn->prepare("
        SELECT i.id_inmueble, i.id_condominio, c.id_moneda AS id_moneda_base
        FROM public.inmueble i
        JOIN public.condominio c ON c.id_condominio = i.id_condominio
        LEFT JOIN public.propietario_inmueble pi ON pi.id_inmueble = i.id_inmueble
        WHERE i.id_inmueble = :id
          AND (i.id_usuario = :usr OR pi.id_usuario = :usr)
        LIMIT 1
    ");
    $stmt->execute([":id" => $idInmueble, ":usr" => $userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond_error("Inmueble no encontrado para el usuario.", 404);
    }
    return $row;
}

function get_tasa(PDO $conn, int $origen, int $destino): float
{
    if ($origen === $destino) {
        return 1.0;
    }
    $stmt = $conn->prepare("
        SELECT tasa
        FROM tipo_cambio
        WHERE id_moneda_origen = :o AND id_moneda_destino = :d
        ORDER BY fecha_vigencia DESC
        LIMIT 1
    ");
    $stmt->execute([":o" => $origen, ":d" => $destino]);
    $tasa = (float)($stmt->fetchColumn() ?: 0);
    return $tasa > 0 ? $tasa : 1.0;
}

function fetch_cuentas(PDO $conn, int $idCondo, int $idMonedaBase): array
{
    $stmt = $conn->prepare("
        SELECT c.id_cuenta, c.nombre, c.tipo, c.banco, m.codigo AS moneda, m.id_moneda
             , c.numero_cuenta_cliente, c.codigo_banco, c.titular, c.rif, c.celular
        FROM cuenta c
        JOIN moneda m ON c.id_moneda = m.id_moneda
        WHERE c.id_condominio = :id
        ORDER BY c.banco, c.nombre
    ");
    $stmt->execute([":id" => $idCondo]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    foreach ($rows as &$r) {
        $r["tasa"] = get_tasa($conn, (int)$r["id_moneda"], $idMonedaBase);
    }
    unset($r);
    return $rows;
}

function fetch_creditos(PDO $conn, int $idInmueble, int $idMonedaBase): array
{
    $sql = "
        SELECT m.id_moneda, m.codigo AS moneda, SUM(c.monto) AS saldo_credito
        FROM credito_a_favor c
        JOIN moneda m ON c.id_moneda = m.id_moneda
        WHERE c.id_inmueble = :id
          AND c.estado = 'activo'
        GROUP BY m.id_moneda, m.codigo
        HAVING SUM(c.monto) > 0
        ORDER BY m.codigo
    ";
    $stmt = $conn->prepare($sql);
    $stmt->execute([":id" => $idInmueble]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    foreach ($rows as &$r) {
        $r["tasa"] = get_tasa($conn, (int)$r["id_moneda"], $idMonedaBase);
    }
    unset($r);
    return $rows;
}

function fetch_pendientes(PDO $conn, int $idInmueble, int $idMonedaBase): array
{
    $sql = "
        SELECT 
            n.id_notificacion,
            n.descripcion,
            n.fecha_emision,
            n.id_moneda,
            m.codigo AS codigo_moneda,
            n.monto_total,
            n.monto_pagado,
            COALESCE(n.monto_x_pagar, n.monto_total - n.monto_pagado) AS monto_x_pagar
        FROM notificacion_cobro n
        JOIN moneda m ON n.id_moneda = m.id_moneda
        WHERE n.id_inmueble = :id
          AND COALESCE(n.monto_x_pagar, n.monto_total - n.monto_pagado) > 0
          AND LOWER(n.estado) <> 'pagada'
    ";
    $stmt = $conn->prepare($sql);
    $stmt->execute([":id" => $idInmueble]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    foreach ($rows as &$r) {
        $r["tasa"] = get_tasa($conn, (int)$r["id_moneda"], $idMonedaBase);
        $r["monto_x_pagar"] = (float)$r["monto_x_pagar"];
    }
    unset($r);
    return $rows;
}

function ensure_tables(PDO $conn): void
{
    $conn->exec("
        CREATE TABLE IF NOT EXISTS pago_reportado_app (
            id SERIAL PRIMARY KEY,
            id_usuario INT NOT NULL,
            id_inmueble INT NOT NULL,
            id_condominio INT NOT NULL,
            fecha_pago DATE NOT NULL,
            observacion TEXT,
            total_base NUMERIC(18,2) NOT NULL,
            moneda_base INT NOT NULL,
            detalle JSONB NOT NULL,
            created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
        );
    ");
}

function ensure_columns(PDO $conn): void
{
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

function uuidv4(): string
{
    $data = random_bytes(16);
    $data[6] = chr((ord($data[6]) & 0x0f) | 0x40);
    $data[8] = chr((ord($data[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}

function evidence_directory(): string
{
    $dir = __DIR__ . '/uploads/evidencias';
    if (!is_dir($dir)) {
        mkdir($dir, 0775, true);
    }
    return $dir;
}

function build_public_url(string $path): string
{
    if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
        return $path;
    }
    $base = api_base_url();
    $clean = ltrim(str_replace('\\', '/', $path), '/');
    return rtrim($base, '/') . '/' . $clean;
}

function save_evidence_file(string $clientUuid, string $rawBase64, string $ext): array
{
    $allowed = ['jpg', 'jpeg', 'png', 'pdf'];
    $ext = strtolower($ext);
    if (!in_array($ext, $allowed, true)) {
        throw new Exception('Extension de comprobante no permitida.');
    }

    $cleanData = preg_replace('/^data:[^;]+;base64,/', '', $rawBase64);
    $binary = base64_decode($cleanData);
    if ($binary === false) {
        throw new Exception('Comprobante invalido.');
    }

    $dir = evidence_directory();
    $filename = $clientUuid . '.' . $ext;
    $path = $dir . '/' . $filename;
    file_put_contents($path, $binary);

    $relative = 'uploads/evidencias/' . $filename;
    return [$path, build_public_url($relative)];
}

try {
    $conn = ConexionAPI::getInstance();
    $input = json_decode(file_get_contents("php://input"), true) ?? [];
    if (empty($input)) {
        $input = $_POST;
    }

    $accion = strtolower(trim($input["accion"] ?? "preparar"));
    $token = trim($input["token"] ?? "");
    if ($token === "") {
        respond_error("Token requerido.", 400);
    }

    $userId = get_user_from_token($conn, $token);
    ensure_tables($conn);
    ensure_columns($conn);

    if ($accion === "preparar") {
        assert_required($input, ["id_inmueble"]);
        $idInmueble = (int)$input["id_inmueble"];
        $inmueble = get_inmueble($conn, $userId, $idInmueble);
        $idCondo = (int)$inmueble["id_condominio"];
        $idMonedaBase = (int)$inmueble["id_moneda_base"];

        $cuentas = fetch_cuentas($conn, $idCondo, $idMonedaBase);
        $creditos = fetch_creditos($conn, $idInmueble, $idMonedaBase);
        $pendientes = fetch_pendientes($conn, $idInmueble, $idMonedaBase);

        respond_success([
            "moneda_base" => $idMonedaBase,
            "cuentas" => $cuentas,
            "creditos" => $creditos,
            "pendientes" => $pendientes,
        ]);
    } elseif ($accion === "enviar") {
        assert_required($input, ["id_inmueble", "fecha_pago", "notificaciones", "pagos"]);
        $idInmueble = (int)$input["id_inmueble"];
        $inmueble = get_inmueble($conn, $userId, $idInmueble);
        $idCondo = (int)$inmueble["id_condominio"];
        $idMonedaBase = (int)$inmueble["id_moneda_base"];

        $fechaPago = $input["fecha_pago"];
        $observacion = trim($input["observacion"] ?? "");
        $notificaciones = is_string($input["notificaciones"])
            ? json_decode($input["notificaciones"], true)
            : $input["notificaciones"];
        $pagos = is_string($input["pagos"])
            ? json_decode($input["pagos"], true)
            : $input["pagos"];
        $clientUuid = trim($input["client_uuid"] ?? "");
        $clientUuidGenerated = false;
        if ($clientUuid === "") {
            $clientUuid = uuidv4();
            $clientUuidGenerated = true;
        }

        if (!is_array($notificaciones) || empty($notificaciones)) {
            respond_error("Debe incluir al menos una notificacion a pagar.", 400);
        }
        if (!is_array($pagos) || empty($pagos)) {
            respond_error("Debe incluir al menos un metodo de pago.", 400);
        }

        // Idempotencia
        $stmtDup = $conn->prepare("
            SELECT id, estado, created_at, client_uuid, evidencia_url, motivo_rechazo
            FROM pago_reportado_app
            WHERE client_uuid = :uuid
            LIMIT 1
        ");
        $stmtDup->execute([":uuid" => $clientUuid]);
        $dupRow = $stmtDup->fetch(PDO::FETCH_ASSOC);
        if ($dupRow) {
            respond_success([
                "duplicado" => true,
                "id" => (int)$dupRow["id"],
                "estado" => $dupRow["estado"],
                "created_at" => $dupRow["created_at"],
                "client_uuid" => $dupRow["client_uuid"],
                "evidencia_url" => $dupRow["evidencia_url"] ?? null,
                "motivo_rechazo" => $dupRow["motivo_rechazo"] ?? null,
            ]);
        }

        $pendientes = fetch_pendientes($conn, $idInmueble, $idMonedaBase);
        $pendMap = [];
        foreach ($pendientes as $p) {
            $pendMap[$p["id_notificacion"]] = $p;
        }

        $totalAbonosBase = 0;
        $totalPendienteBase = 0;
        foreach ($notificaciones as $n) {
            $idNotif = (int)($n["id_notificacion"] ?? 0);
            $abono = (float)($n["abono"] ?? 0);
            if ($idNotif <= 0 || $abono <= 0) {
                respond_error("Datos de notificacion invalidos.", 400);
            }
            if (!isset($pendMap[$idNotif])) {
                respond_error("La notificacion {$idNotif} no pertenece al inmueble o no tiene saldo.", 400);
            }
            if ($abono - $pendMap[$idNotif]["monto_x_pagar"] > 0.01) {
                respond_error("El abono supera el saldo pendiente de la notificacion {$idNotif}.", 400);
            }
            $tasaNotif = get_tasa($conn, (int)$pendMap[$idNotif]["id_moneda"], $idMonedaBase);
            $totalPendienteBase += $pendMap[$idNotif]["monto_x_pagar"] * $tasaNotif;
            $tasa = (float)($n["tasa"] ?? $tasaNotif);
            if ($tasa <= 0) $tasa = 1;
            $totalAbonosBase += $abono * $tasa;
        }

        $totalPagosBase = 0;
        foreach ($pagos as $p) {
            $monto = (float)($p["monto"] ?? 0);
            $idMon = (int)($p["id_moneda"] ?? 0);
            if ($monto <= 0 || $idMon <= 0) {
                respond_error("Los metodos de pago deben tener monto y moneda.", 400);
            }
            $tasa = (float)($p["tasa"] ?? get_tasa($conn, $idMon, $idMonedaBase));
            if ($tasa <= 0) $tasa = 1;
            $totalPagosBase += $monto * $tasa;
        }

        $comprobanteBase64 = $input["comprobante_base64"] ?? null;
        $comprobanteExt = trim($input["comprobante_ext"] ?? "");
        $evidPath = null;
        $evidUrl = null;
        if ($comprobanteBase64 && $comprobanteExt !== "") {
            [$evidPath, $evidUrl] = save_evidence_file($clientUuid, $comprobanteBase64, $comprobanteExt);
        }

        ensure_tables($conn);

        $stmt = $conn->prepare("
            INSERT INTO pago_reportado_app
            (id_usuario, id_inmueble, id_condominio, fecha_pago, observacion, total_base, moneda_base, detalle, estado, client_uuid, ip, user_agent, evidencia_path, evidencia_url, updated_at)
            VALUES (:usr, :inm, :condo, :fecha, :obs, :total_base, :moneda_base, :detalle::jsonb, 'EN_PROCESO', :client_uuid, :ip, :ua, :evid_path, :evid_url, NOW())
            RETURNING id, created_at, estado, client_uuid, evidencia_url
        ");

        $resumen = [
            "pendiente_total_base" => $totalPendienteBase,
            "abono_total_base" => $totalAbonosBase,
            "pagos_total_base" => $totalPagosBase,
            "count_notificaciones" => count($notificaciones),
            "count_pagos" => count($pagos),
        ];

        $det = [
            "notificaciones" => $notificaciones,
            "pagos" => $pagos,
            "observacion" => $observacion,
            "resumen" => $resumen,
        ];

        $stmt->execute([
            ":usr" => $userId,
            ":inm" => $idInmueble,
            ":condo" => $idCondo,
            ":fecha" => $fechaPago,
            ":obs" => $observacion,
            ":total_base" => $totalPagosBase,
            ":moneda_base" => $idMonedaBase,
            ":detalle" => json_encode($det),
            ":client_uuid" => $clientUuid,
            ":ip" => $_SERVER["REMOTE_ADDR"] ?? null,
            ":ua" => $_SERVER["HTTP_USER_AGENT"] ?? null,
            ":evid_path" => $evidPath,
            ":evid_url" => $evidUrl,
        ]);

        $inserted = $stmt->fetch(PDO::FETCH_ASSOC);
        $cubreTotal = ($totalPagosBase + 0.01) >= $totalPendienteBase;

        respond_success([
            "message" => "Pago reportado para validacion.",
            "total_base" => $totalPagosBase,
            "moneda_base" => $idMonedaBase,
            "id" => (int)$inserted["id"],
            "estado" => $inserted["estado"],
            "created_at" => $inserted["created_at"],
            "client_uuid" => $inserted["client_uuid"],
            "evidencia_url" => $inserted["evidencia_url"],
            "client_uuid_generado" => $clientUuidGenerated,
            "cubre_total_estimado" => $cubreTotal,
        ]);
    } else {
        respond_error("Accion no soportada.", 400);
    }
} catch (Exception $e) {
    respond_error($e->getMessage(), 500);
}
