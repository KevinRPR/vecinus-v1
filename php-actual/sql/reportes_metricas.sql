-- Base SQL for report metrics (API metricas_reportes.php)
-- Replace :from_date, :to_date, and condo placeholders when executing manually.

-- 1) Serie diaria (reportes por dia + estados)
WITH series AS (
    SELECT generate_series(:from_date::date, :to_date::date, interval '1 day')::date AS day
),
base AS (
    SELECT DATE(created_at) AS day, estado
    FROM pago_reportado_app
    WHERE id_condominio IN (:condo_0, :condo_1)
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
ORDER BY s.day ASC;

-- 2) Resumen agregado + promedio de revision (solo reportes finalizados)
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
WHERE id_condominio IN (:condo_0, :condo_1)
  AND DATE(created_at) BETWEEN :from_date::date AND :to_date::date;
