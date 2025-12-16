<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once(__DIR__ . "/config/conexion.php");
require_once(__DIR__ . "/helpers.php");

$conn = ConexionAPI::getInstance();
$input = json_decode(file_get_contents("php://input"), true) ?? [];
$token = trim($input["token"] ?? "");

if ($token === "") {
    respond_error("Token requerido.", 400);
}

try {
    $userId = get_user_id_from_token($conn, $token);
    $inmuebles = fetch_inmuebles($conn, $userId);

    if (empty($inmuebles)) {
        respond_success(["inmuebles" => []]);
    }

    $inmueblesConDeuda = enrich_with_cxc($conn, $inmuebles);
    respond_success(["inmuebles" => $inmueblesConDeuda]);
} catch (Exception $e) {
    file_put_contents(
        __DIR__ . "/debug_error.txt",
        "ERROR mis_inmuebles: " . $e->getMessage()
    );
    respond_error("Error consultando inmuebles.", 500);
}

function get_user_id_from_token(PDO $conn, string $token): int
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
        throw new Exception("Token invalido o expirado.");
    }

    return (int)$row["user_id"];
}

function fetch_inmuebles(PDO $conn, int $userId): array
{
    // Igual que la web: inmuebles vinculados directamente o via propietario_inmueble
    $sql = "
        SELECT DISTINCT
            i.id_inmueble,
            i.id_condominio,
            i.id_usuario,
            i.alicuota,
            i.estado,
            c.nombre AS condominio_nombre,
            i.torre,
            i.piso,
            i.identificacion,
            i.manzana,
            i.calle,
            i.avenida,
            i.tipo,
            i.correlativo
        FROM public.inmueble i
        LEFT JOIN public.condominio c
            ON c.id_condominio = i.id_condominio
        LEFT JOIN public.propietario_inmueble pi 
            ON pi.id_inmueble = i.id_inmueble
        WHERE i.id_usuario = :id_usuario
           OR pi.id_usuario = :id_usuario
        ORDER BY i.id_inmueble ASC
    ";

    $stmt = $conn->prepare($sql);
    $stmt->execute([":id_usuario" => $userId]);
    return $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
}

function enrich_with_cxc(PDO $conn, array $inmuebles): array
{
    $ids = array_column($inmuebles, "id_inmueble");
    if (empty($ids)) {
        return $inmuebles;
    }

    $placeholders = implode(",", array_fill(0, count($ids), "?"));
    $sql = "
        SELECT 
            nc.id_notificacion,
            nc.id_inmueble,
            nc.fecha_emision,
            nc.descripcion,
            nc.monto_total,
            nc.monto_pagado,
            nc.estado,
            nc.token,
            rc.token AS token_recibo,
            m.codigo AS moneda
        FROM notificacion_cobro nc
        LEFT JOIN moneda m ON nc.id_moneda = m.id_moneda
        LEFT JOIN recibo_destino_fondos rdf ON rdf.id_notificacion = nc.id_notificacion
        LEFT JOIN recibo_cabecera rc ON rdf.id_recibo = rc.id_recibo
        WHERE nc.id_inmueble IN ($placeholders)
    ";

    $stmt = $conn->prepare($sql);
    $stmt->execute($ids);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];

    // Acumulador por inmueble
    $map = [];
    foreach ($inmuebles as $inmueble) {
        $id = $inmueble["id_inmueble"];
        $map[$id] = array_merge($inmueble, [
            "deuda_actual" => 0.0,
            "proxima_fecha_pago" => null,
            "pagos" => [],
        ]);
    }

    foreach ($rows as $row) {
        $id = $row["id_inmueble"];
        if (!isset($map[$id])) {
            continue;
        }

        $estado = strtolower(trim($row["estado"] ?? ""));
        $montoTotal = (float)($row["monto_total"] ?? 0);
        $montoPagado = (float)($row["monto_pagado"] ?? 0);
        $pendiente = max($montoTotal - $montoPagado, 0);
        $fecha = $row["fecha_emision"] ?? null;

        if ($estado !== "pagada") {
            $map[$id]["deuda_actual"] += $pendiente;
            if ($fecha) {
                $actual = $map[$id]["proxima_fecha_pago"];
                if ($actual === null || strtotime($fecha) < strtotime($actual)) {
                    $map[$id]["proxima_fecha_pago"] = $fecha;
                }
            }
        }

        $pagoMonto = $estado === "pagada"
            ? ($montoPagado > 0 ? $montoPagado : $montoTotal)
            : ($pendiente > 0 ? $pendiente : $montoTotal);

        $map[$id]["pagos"][] = [
            "id_pago" => $row["id_notificacion"] ?? null,
            "descripcion" => $row["descripcion"] ?? "Notificacion",
            "fecha" => $fecha ?? "",
            "monto" => number_format($pagoMonto, 2, ".", ""),
            "estado" => $row["estado"] ?? "",
            "moneda" => $row["moneda"] ?? "",
            "token" => $row["token"] ?? "",
            "documento_url" => build_document_url($row),
            "notificacion_url" => build_document_url($row),
            "recibo_url" => build_recibo_url($row),
        ];
    }

    // Ordenar pagos y preparar salida
    $result = [];
    foreach ($inmuebles as $inmueble) {
        $id = $inmueble["id_inmueble"];
        $item = $map[$id];

        usort($item["pagos"], function ($a, $b) {
            return strcmp($b["fecha"], $a["fecha"]);
        });
        $item["pagos"] = array_slice($item["pagos"], 0, 10);

        $item["deuda_actual"] = number_format((float)$item["deuda_actual"], 2, ".", "");
        $item["proxima_fecha_pago"] = $item["proxima_fecha_pago"] ?? "";
        $result[] = $item;
    }

    return $result;
}

function base_host(): string
{
    $host = $_SERVER["HTTP_HOST"] ?? "rhodiumdev.com";
    $scheme = (!empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off") ? "https" : "http";
    return $scheme . "://" . rtrim($host, "/");
}

function base_sys(): string
{
    return base_host() . "/condominio/sys";
}

function build_document_url(array $row): string
{
    $token = $row["token"] ?? "";
    if ($token) {
        return base_sys() . "/generar_notificacion.php?token=" . urlencode((string)$token);
    }
    $id = $row["id_notificacion"] ?? null;
    if ($id) {
        return base_sys() . "/generar_notificacion.php?id_notificacion=" . urlencode((string)$id);
    }
    return "";
}

function build_recibo_url(array $row): string
{
    $tokenRecibo = $row["token_recibo"] ?? "";
    if ($tokenRecibo) {
        return base_sys() . "/generar_recibo.php?token=" . urlencode((string)$tokenRecibo);
    }
    $id = $row["id_notificacion"] ?? null;
    if ($id) {
        return base_sys() . "/generar_recibo.php?id_notificacion=" . urlencode((string)$id);
    }
    return "";
}
