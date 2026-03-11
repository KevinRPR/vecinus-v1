<?php
@session_start();
require_once("core/PDO.class.php");

$conn = DB::getInstance();

// Seguridad básica: validar id_inmueble
$id_inmueble = isset($_POST['id_inmueble']) && ctype_digit($_POST['id_inmueble'])
    ? (int)$_POST['id_inmueble']
    : 0;
if ($id_inmueble === 0) {
    echo json_encode(["data" => []]);
    exit;
}

// DataTables parámetros básicos
$start  = $_POST['start'] ?? 0;
$length = $_POST['length'] ?? 10;
$search = $_POST['search']['value'] ?? '';
$orderCol = $_POST['order'][0]['column'] ?? 0;
$orderDir = $_POST['order'][0]['dir'] ?? 'asc';

// Columnas disponibles (ajusta según tus headers)
$cols = [
    "nc.id_notificacion",
    "nc.fecha_emision",
    "nc.descripcion",
    "m.codigo",
    "nc.monto_total",
    "nc.monto_pagado",
    "(nc.monto_total - nc.monto_pagado) AS monto_x_pagar",
    "nc.estado"
];

// Orden dinámico
$orderBy = $cols[$orderCol] ?? "nc.fecha_emision";
$orderDir = strtoupper($orderDir) === "DESC" ? "DESC" : "ASC";

// --- Consulta principal con token de notificación y token de recibo ---
$sql = "
    SELECT 
   nc.id_notificacion,
   nc.fecha_emision,
   nc.descripcion,
   m.codigo AS moneda_notificacion,
   nc.monto_total,
   nc.monto_pagado,
   (nc.monto_total - nc.monto_pagado) AS monto_x_pagar,
   nc.estado,
   nc.token,
   rc.token AS token_recibo,
   0 AS envios_count   -- valor fijo
FROM notificacion_cobro nc
INNER JOIN moneda m ON nc.id_moneda = m.id_moneda
LEFT JOIN recibo_destino_fondos rdf ON rdf.id_notificacion = nc.id_notificacion
LEFT JOIN recibo_cabecera rc ON rdf.id_recibo = rc.id_recibo
WHERE nc.id_inmueble = :id_inmueble

";

// Filtro por búsqueda
$params = [":id_inmueble" => $id_inmueble];
if ($search !== '') {
    $sql .= " AND (CAST(nc.id_notificacion AS TEXT) ILIKE :s
                   OR nc.descripcion ILIKE :s
                   OR m.codigo ILIKE :s)";
    $params[":s"] = "%$search%";
}

// Conteo total
$stmtTotal = $conn->prepare("SELECT COUNT(*) FROM ($sql) t");
$stmtTotal->execute($params);
$recordsFiltered = (int)$stmtTotal->fetchColumn();

// Agregar orden, limit y offset
$sql .= " ORDER BY $orderBy $orderDir LIMIT :l OFFSET :o";
$stmt = $conn->prepare($sql);
foreach ($params as $k => $v) $stmt->bindValue($k, $v);
$stmt->bindValue(":l", (int)$length, PDO::PARAM_INT);
$stmt->bindValue(":o", (int)$start, PDO::PARAM_INT);
$stmt->execute();
$data = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Conteo total sin filtros
$stmtAll = $conn->prepare("SELECT COUNT(*) FROM notificacion_cobro WHERE id_inmueble = :id_inmueble");
$stmtAll->execute([":id_inmueble" => $id_inmueble]);
$recordsTotal = (int)$stmtAll->fetchColumn();

// Respuesta DataTables
echo json_encode([
    "draw" => (int)($_POST['draw'] ?? 0),
    "recordsTotal" => $recordsTotal,
    "recordsFiltered" => $recordsFiltered,
    "data" => $data
]);
