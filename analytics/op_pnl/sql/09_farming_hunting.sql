-- ─────────────────────────────────────────────────────────────────────────────
-- FARMING & HUNTING · Big Sellers Online Payments
-- ─────────────────────────────────────────────────────────────────────────────
-- Clasifica los sellers del Top 100 (por TPV LC, ranking por país) en 3 buckets:
--   FARMING : seller que estuvo en Top 100 en period_actual Y en period_anterior
--   HUNTING : seller nuevo en Top 100 (no estaba en period_anterior)
--   DROP    : seller que estaba en Top 100 en period_anterior y ya no
--
-- Output por SIT_SITE_ID + bucket: cantidad de sellers, TPV USD, VC%.
-- Granularidad de seller disponible cambiando el GROUP BY al final.
--
-- USO:
--   Reemplazá @current_period y @prev_period por los YYYYMM target.
--   Ej: 202604 (abril 2026) y 202603 (marzo 2026).
-- ─────────────────────────────────────────────────────────────────────────────

DECLARE current_period INT64 DEFAULT 202604;
DECLARE prev_period    INT64 DEFAULT 202603;

WITH
-- Ranking por seller dentro de cada (site, periodo) — base para Top 100
ranking_per_period AS (
  SELECT
    PERIODO,
    SIT_SITE_ID,
    COLLECTOR_GROUP,
    RANK() OVER (
      PARTITION BY SIT_SITE_ID, PERIODO
      ORDER BY SUM(TPV_LC) DESC
    ) AS RANKING
  FROM `meli-bi-data.WHOWNER.DM_SNAP_ACQUIRING_SELLERS`
  WHERE SUBSEGMENT_SEL = 'BIG SELLERS'
    AND PERIODO IN (current_period, prev_period)
  GROUP BY PERIODO, SIT_SITE_ID, COLLECTOR_GROUP
),
top100 AS (
  SELECT PERIODO, SIT_SITE_ID, COLLECTOR_GROUP, RANKING
  FROM ranking_per_period
  WHERE RANKING <= 100
),

-- Métricas por seller en Online Payments
seller_metrics AS (
  SELECT
    PERIODO,
    SIT_SITE_ID,
    COLLECTOR_GROUP,
    SUM(COALESCE(TPV_USD,    0)) AS tpv_usd,
    SUM(COALESCE(VC_USD_FTP, 0)) AS vc_usd
  FROM `meli-bi-data.WHOWNER.DM_SNAP_ACQUIRING_SELLERS`
  WHERE SUBSEGMENT_SEL = 'BIG SELLERS'
    AND UE_MP_SUBBU_MANAGERIAL = 'ONLINE PAYMENTS'
    AND PERIODO IN (current_period, prev_period)
  GROUP BY PERIODO, SIT_SITE_ID, COLLECTOR_GROUP
),

-- Cruce: ¿estuvo cada seller en Top 100 de cada periodo?
classification AS (
  SELECT
    COALESCE(c.SIT_SITE_ID, p.SIT_SITE_ID)         AS SIT_SITE_ID,
    COALESCE(c.COLLECTOR_GROUP, p.COLLECTOR_GROUP) AS COLLECTOR_GROUP,
    c.RANKING AS rank_actual,
    p.RANKING AS rank_anterior,
    CASE
      WHEN c.RANKING IS NOT NULL AND p.RANKING IS NOT NULL THEN 'FARMING'
      WHEN c.RANKING IS NOT NULL AND p.RANKING IS NULL     THEN 'HUNTING'
      WHEN c.RANKING IS NULL     AND p.RANKING IS NOT NULL THEN 'DROP'
    END AS bucket
  FROM (SELECT * FROM top100 WHERE PERIODO = current_period) c
  FULL OUTER JOIN (SELECT * FROM top100 WHERE PERIODO = prev_period) p
    ON c.SIT_SITE_ID = p.SIT_SITE_ID
   AND c.COLLECTOR_GROUP = p.COLLECTOR_GROUP
)

-- Resumen por site × bucket (cambiá GROUP BY para granularidad seller)
SELECT
  cl.SIT_SITE_ID,
  cl.bucket,
  COUNT(DISTINCT cl.COLLECTOR_GROUP)              AS sellers,
  ROUND(SUM(COALESCE(m_actual.tpv_usd, m_prev.tpv_usd))/1e6, 2) AS tpv_musd,
  ROUND(SAFE_DIVIDE(
    SUM(COALESCE(m_actual.vc_usd, m_prev.vc_usd)),
    SUM(COALESCE(m_actual.tpv_usd, m_prev.tpv_usd))
  ) * 100, 3) AS vc_pct
FROM classification cl
LEFT JOIN seller_metrics m_actual
  ON m_actual.PERIODO = current_period
 AND m_actual.SIT_SITE_ID = cl.SIT_SITE_ID
 AND m_actual.COLLECTOR_GROUP = cl.COLLECTOR_GROUP
LEFT JOIN seller_metrics m_prev
  ON m_prev.PERIODO = prev_period
 AND m_prev.SIT_SITE_ID = cl.SIT_SITE_ID
 AND m_prev.COLLECTOR_GROUP = cl.COLLECTOR_GROUP
WHERE cl.bucket IS NOT NULL
GROUP BY cl.SIT_SITE_ID, cl.bucket
ORDER BY cl.SIT_SITE_ID, cl.bucket;
