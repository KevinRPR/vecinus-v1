<?php
header("Content-Type: application/json; charset=UTF-8");

require_once(__DIR__ . "/config/conexion.php");
require_once(__DIR__ . "/helpers.php");

apply_cors();
handle_preflight();

function parse_iso_date(?string $raw): ?DateTimeImmutable {
    if ($raw === null) return null;
    $value = trim($raw);
    if ($value === '') return null;
    $dt = DateTimeImmutable::createFromFormat('Y-m-d', $value);
    if ($dt instanceof DateTimeImmutable) {
        return $dt;
    }
    return null;
}

function parse_input_payload(): array {
    $input = json_decode(file_get_contents("php://input"), true) ?? [];
    if (empty($input)) {
        $input = $_POST;
    }
    return is_array($input) ? $input : [];
}

function find_user_condominios(PDO $conn, int $userId): array {
    $stmt = $conn->prepare("
        SELECT DISTINCT i.id_condominio
        FROM public.inmueble i
        LEFT JOIN public.propietario_inmueble pi ON pi.id_inmueble = i.id_inmueble
        WHERE i.id_usuario = :usr OR pi.id_usuario = :usr
        ORDER BY i.id_condominio
    ");
    $stmt->execute([':usr' => $userId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $ids = [];
    foreach ($rows as $row) {
        $id = (int)($row['id_condominio'] ?? 0);
        if ($id > 0) {
            $ids[] = $id;
        }
    }
    return array_values(array_unique($ids));
}

function build_condominio_filter(array $ids, string $prefix = 'condo'): array {
    $params = [];
    $parts = [];
    foreach (array_values($ids) as $idx => $id) {
        $key = ':' . $prefix . '_' . $idx;
        $parts[] = $key;
        $params[$key] = (int)$id;
    }
    if (empty($parts)) {
        return ['1 = 0', []];
    }
    return ['id_condominio IN (' . implode(', ', $parts) . ')', $params];
}

try {
    $conn = ConexionAPI::getInstance();
    $input = parse_input_payload();

    $token = trim((string)($input['token'] ?? ''));
    if ($token === '') {
        respond_error('Token requerido.', 400);
    }

    $userId = resolve_user_id_from_token($conn, $token);
    $accessible = find_user_condominios($conn, $userId);
    if (empty($accessible)) {
        respond_success([
            'from' => null,
            'to' => null,
            'id_condominio' => null,
            'series' => [],
            'summary' => [
                'total_reportes' => 0,
                'aprobados' => 0,
                'rechazados' => 0,
                'en_revision' => 0,
                'promedio_revision_minutos' => 0.0,
            ],
        ]);
    }

    $today = new DateTimeImmutable('today');
    $defaultFrom = $today->sub(new DateInterval('P29D'));
    $from = parse_iso_date((string)($input['from'] ?? '')) ?? $defaultFrom;
    $to = parse_iso_date((string)($input['to'] ?? '')) ?? $today;

    if ($from > $to) {
        respond_error('Rango invalido: from no puede ser mayor que to.', 400);
    }

    $maxRangeDays = 366;
    if ((int)$to->diff($from)->format('%a') > $maxRangeDays) {
        respond_error('Rango muy amplio. Usa un maximo de 366 dias.', 400);
    }

    $requestedCondo = isset($input['id_condominio']) ? (int)$input['id_condominio'] : 0;
    $scopeCondominios = $accessible;
    if ($requestedCondo > 0) {
        if (!in_array($requestedCondo, $accessible, true)) {
            respond_error('No tienes permisos para consultar ese condominio.', 403);
        }
        $scopeCondominios = [$requestedCondo];
    }

    [$condWhere, $condParams] = build_condominio_filter($scopeCondominios);

    $seriesSql = "
        WITH series AS (
            SELECT generate_series(:from_date::date, :to_date::date, interval '1 day')::date AS day
        ),
        base AS (
            SELECT
                DATE(created_at) AS day,
                estado
            FROM pago_reportado_app
            WHERE {$condWhere}
              AND DATE(created_at) BETWEEN :from_date::date AND :to_date::date
        )
        SELECT
            s.day::text AS fecha,
            COALESCE(COUNT(b.day), 0)::int AS total,
            COALESCE(COUNT(*) FILTER (WHERE b.estado = 'APROBADO'), 0)::int AS aprobados,
            COALESCE(COUNT(*) FILTER (WHERE b.estado = 'RECHAZADO'), 0)::int AS rechazados,
            COALESCE(COUNT(*) FILTER (WHERE b.estado = 'EN_PROCESO'), 0)::int AS en_revision
        FROM series s
        LEFT JOIN base b ON b.day = s.day
        GROUP BY s.day
        ORDER BY s.day ASC
    ";

    $summarySql = "
        SELECT
            COUNT(*)::int AS total_reportes,
            COALESCE(COUNT(*) FILTER (WHERE estado = 'APROBADO'), 0)::int AS aprobados,
            COALESCE(COUNT(*) FILTER (WHERE estado = 'RECHAZADO'), 0)::int AS rechazados,
            COALESCE(COUNT(*) FILTER (WHERE estado = 'EN_PROCESO'), 0)::int AS en_revision,
            COALESCE(
                AVG(
                    EXTRACT(EPOCH FROM (COALESCE(aprobado_at, rechazado_at) - created_at)) / 60.0
                ) FILTER (
                    WHERE estado IN ('APROBADO', 'RECHAZADO')
                      AND COALESCE(aprobado_at, rechazado_at) IS NOT NULL
                ),
                0
            )::numeric(12,2) AS promedio_revision_minutos
        FROM pago_reportado_app
        WHERE {$condWhere}
          AND DATE(created_at) BETWEEN :from_date::date AND :to_date::date
    ";

    $queryParams = array_merge([
        ':from_date' => $from->format('Y-m-d'),
        ':to_date' => $to->format('Y-m-d'),
    ], $condParams);

    $seriesStmt = $conn->prepare($seriesSql);
    $seriesStmt->execute($queryParams);
    $series = $seriesStmt->fetchAll(PDO::FETCH_ASSOC) ?: [];

    $summaryStmt = $conn->prepare($summarySql);
    $summaryStmt->execute($queryParams);
    $summary = $summaryStmt->fetch(PDO::FETCH_ASSOC) ?: [
        'total_reportes' => 0,
        'aprobados' => 0,
        'rechazados' => 0,
        'en_revision' => 0,
        'promedio_revision_minutos' => 0,
    ];

    respond_success([
        'from' => $from->format('Y-m-d'),
        'to' => $to->format('Y-m-d'),
        'id_condominio' => $requestedCondo > 0 ? $requestedCondo : null,
        'condominios' => $scopeCondominios,
        'series' => $series,
        'summary' => [
            'total_reportes' => (int)($summary['total_reportes'] ?? 0),
            'aprobados' => (int)($summary['aprobados'] ?? 0),
            'rechazados' => (int)($summary['rechazados'] ?? 0),
            'en_revision' => (int)($summary['en_revision'] ?? 0),
            'promedio_revision_minutos' => (float)($summary['promedio_revision_minutos'] ?? 0),
        ],
    ]);
} catch (Exception $e) {
    log_error('metricas_reportes failed', [
        'error' => $e->getMessage(),
    ]);
    $lower = strtolower($e->getMessage());
    $status = (strpos($lower, 'token') !== false) ? 401 : 500;
    respond_error($e->getMessage(), $status);
}