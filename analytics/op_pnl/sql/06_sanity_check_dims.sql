-- =============================================================================
-- 06_sanity_check_dims.sql
-- Sanity check de catálogos / dimensiones contra las tablas reales.
-- Corré esto en BigQuery y pegame el output (en CSV o lista)
-- así reemplazo los valores mock del dashboard con los reales.
--
-- Ajustá las tablas si difieren:
--   FACT  = SBOX_FINANCEMP.BT_MP_ACQUIRING_CROSS_V3
--   SELLR = meli-bi-data.WHOWNER.DM_SNAP_ACQUIRING_SELLERS
-- =============================================================================

-- 1) Valores únicos de cada dimensión en BT_MP_ACQUIRING_CROSS_V3
WITH base AS (
  SELECT *
  FROM `${PROJECT}.${SBOX_DATASET}.BT_MP_ACQUIRING_CROSS_V3`
  WHERE PERIODO BETWEEN DATE '2025-04-01' AND DATE '2026-04-30'
)
SELECT 'CATEGORIA_PLAN_OP'    AS field, COUNT(DISTINCT CATEGORIA_PLAN_OP)    AS n_distinct, ARRAY_AGG(DISTINCT CATEGORIA_PLAN_OP    IGNORE NULLS LIMIT 50) AS values FROM base
UNION ALL SELECT 'OP_PRODUCT',           COUNT(DISTINCT OP_PRODUCT),           ARRAY_AGG(DISTINCT OP_PRODUCT           IGNORE NULLS LIMIT 50) FROM base
UNION ALL SELECT 'SUBBU',                COUNT(DISTINCT SUBBU),                ARRAY_AGG(DISTINCT SUBBU                IGNORE NULLS LIMIT 50) FROM base
UNION ALL SELECT 'PAY_PM_TYPE_ID_2',     COUNT(DISTINCT PAY_PM_TYPE_ID_2),     ARRAY_AGG(DISTINCT PAY_PM_TYPE_ID_2     IGNORE NULLS LIMIT 50) FROM base
UNION ALL SELECT 'FINANCING_TYPE_3',     COUNT(DISTINCT FINANCING_TYPE_3),     ARRAY_AGG(DISTINCT FINANCING_TYPE_3     IGNORE NULLS LIMIT 80) FROM base
UNION ALL SELECT 'PAY_CCD_ACQUIRER_ID',  COUNT(DISTINCT PAY_CCD_ACQUIRER_ID),  ARRAY_AGG(DISTINCT PAY_CCD_ACQUIRER_ID  IGNORE NULLS LIMIT 50) FROM base
UNION ALL SELECT 'UE_MP_ISSUER_DESC',    COUNT(DISTINCT UE_MP_ISSUER_DESC),    ARRAY_AGG(DISTINCT UE_MP_ISSUER_DESC    IGNORE NULLS LIMIT 200) FROM base
UNION ALL SELECT 'UE_MP_TAG_FUNGIBLE',   COUNT(DISTINCT UE_MP_TAG_FUNGIBLE),   ARRAY_AGG(DISTINCT UE_MP_TAG_FUNGIBLE   IGNORE NULLS LIMIT 20) FROM base
UNION ALL SELECT 'SIT_SITE_ID',          COUNT(DISTINCT SIT_SITE_ID),          ARRAY_AGG(DISTINCT SIT_SITE_ID          IGNORE NULLS LIMIT 20) FROM base
ORDER BY field;

-- =============================================================================
-- 2) Industria (de la tabla de sellers)
-- =============================================================================
SELECT 'MCC_INDUSTRY' AS field,
       COUNT(DISTINCT MCC_INDUSTRY)            AS n_distinct,
       ARRAY_AGG(DISTINCT MCC_INDUSTRY IGNORE NULLS LIMIT 100) AS values
FROM `meli-bi-data.WHOWNER.DM_SNAP_ACQUIRING_SELLERS`
WHERE SNAP_DATE = (SELECT MAX(SNAP_DATE) FROM `meli-bi-data.WHOWNER.DM_SNAP_ACQUIRING_SELLERS`);

-- Si la columna se llama diferente (INDUSTRY, INDUSTRY_DESC, MCC_DESC, etc.):
-- SELECT column_name FROM `meli-bi-data.WHOWNER.INFORMATION_SCHEMA.COLUMNS`
-- WHERE table_name = 'DM_SNAP_ACQUIRING_SELLERS' AND LOWER(column_name) LIKE '%indust%' OR LOWER(column_name) LIKE '%mcc%';

-- =============================================================================
-- 3) Volúmenes de TPV / VC por dimensión para validar que mi mock matchea órdenes
-- de magnitud (compará contra los KPIs del dashboard)
-- =============================================================================
SELECT
  SIT_SITE_ID,
  SUBBU,
  ROUND(SUM(TPV_USD)/1e6, 1) AS tpv_M_USD,
  ROUND(SUM(VC_USD)/1e6,  1) AS vc_M_USD,
  ROUND(SAFE_DIVIDE(SUM(VC_USD), SUM(TPV_USD)), 4) AS vc_pct
FROM `${PROJECT}.${SBOX_DATASET}.BT_MP_ACQUIRING_CROSS_V3`
WHERE PERIODO = DATE '2026-04-01'
GROUP BY 1,2
ORDER BY tpv_M_USD DESC;

-- =============================================================================
-- 4) FX y inflación desde WHOWNER.BT_FIN_MACRO_PREMISES (fuente oficial)
-- =============================================================================
-- Usar esta tabla en lugar de derivar FX desde la cross.
SELECT
  SIT_SITE_ID,
  PERIODO,
  FX,
  FX_PLAN,            -- confirmar nombre exacto de la columna
  INFLATION_RATE_YOY  -- confirmar nombre exacto de la columna
FROM `meli-bi-data.WHOWNER.BT_FIN_MACRO_PREMISES`
WHERE PERIODO BETWEEN DATE '2025-01-01' AND DATE '2026-12-31'
  AND SIT_SITE_ID IN ('MLA','MLB','MLM','MLC','MCO','MPE','MLU')
ORDER BY SIT_SITE_ID, PERIODO;

-- Recordatorio de fórmulas (glosario validado por el equipo):
--   Local Currency (LC)    = valor crudo
--   USD                    = LC / TC_actual
--   USD CC                 = LC / TC_LY (mismo mes año pasado)
--   Deflated MLA           = USD CC / (1 + inflation_AR_YoY)
--   Deflated otros sites   = USD CC
-- Para vs LY:
--   ALL/Argentina:         Real (N) Deflated / Real (N-1) USD - 1
--   Sites excl AR:         Real LC / Real (N-1) LC - 1
-- Para vs Plan:
--   Real Deflated / Plan Deflated - 1
