<?php
session_start();
require_once 'core/PDO.class.php';

header('Content-Type: application/json');
$id_inmueble=8;
try {
    $conn = DB::getInstance();
    if (!$conn) {
        throw new Exception('No se pudo conectar a la base de datos.');
    }


    $sql = "SELECT c.id_moneda
            FROM condominio c
            JOIN inmueble i ON i.id_condominio = c.id_condominio
            WHERE i.id_inmueble = :id_inmueble";
    $moneda_base_id = $conn->single($sql, ['id_inmueble' => $id_inmueble]) ?: 0;
    if (!$moneda_base_id) {
        throw new Exception('No se encontró la moneda base para el inmueble.');
    }

    $sql_credito = "SELECT 
                        m.id_moneda,
                        m.codigo AS moneda,
                        SUM(c.monto) AS saldo_credito
                    FROM credito_a_favor c
                    INNER JOIN moneda m ON c.id_moneda = m.id_moneda
                    WHERE c.id_inmueble = :id_inmueble
                      AND c.estado = 'activo'
                    GROUP BY m.id_moneda, m.codigo
                    HAVING SUM(c.monto) > 0
                    ORDER BY m.codigo";
    $stmt_credito = $conn->prepare($sql_credito);
    $stmt_credito->execute(['id_inmueble' => $id_inmueble]);
    $creditos = $stmt_credito->fetchAll(PDO::FETCH_ASSOC);

    foreach ($creditos as &$credito) {
        $id_moneda = (int)$credito['id_moneda'];
        $credito['tasa'] = ($id_moneda === $moneda_base_id) ? 1 : (
            $conn->prepare("SELECT tasa FROM tipo_cambio 
                            WHERE id_moneda_origen = :o AND id_moneda_destino = :d 
                            ORDER BY fecha_vigencia DESC LIMIT 1")
                 ->execute([':o' => $id_moneda, ':d' => $moneda_base_id])
                 ->fetchColumn() ?: 1
        );
    }
    unset($credito);

    echo json_encode([
        'status' => 'success',
        'creditos' => $creditos
    ]);
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>