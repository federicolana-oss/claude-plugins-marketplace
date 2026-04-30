-- =============================================================================
-- 01_base_granular.sql
-- Capa BASE (Bronze/Silver) — 1 fila por combinación de dimensiones operativas
-- + period_month + scenario, con métricas en LC.
-- Fuente: SBOX_FINANCEMP.BT_MP_ACQUIRING_CROSS_V3
--
-- Reemplazá ${PROJECT}, ${SBOX_DATASET}, ${RAW_TABLE} antes de ejecutar.
--   ${PROJECT}        = tu GCP project
--   ${SBOX_DATASET}   = sbox_financemp
--   ${RAW_TABLE}      = BT_MP_ACQUIRING_CROSS_V3
-- =============================================================================

CREATE OR REPLACE TABLE `${PROJECT}.${SBOX_DATASET}.op_pnl__base_granular`
PARTITION BY DATE_TRUNC(period_month, MONTH)
CLUSTER BY site, product, segment, payment_method_group AS
SELECT
  -- Tiempo
  DATE_TRUNC(SAFE_CAST(PERIODO AS DATE), MONTH)                AS period_month,
  'real'                                                       AS scenario,

  -- Geografía / Producto
  UPPER(TRIM(SITE))                                            AS site,
  TRIM(PRODUCTO)                                               AS product,
  CAST(NULL AS STRING)                                         AS subproduct,    -- mapear si existe
  TRIM(SEGMENTO)                                               AS segment,
  TRIM(`SUB SEGMENTO`)                                         AS subsegment,
  TRIM(`CATEGORIA PLAN`)                                       AS categoria_plan,
  TRIM(`CATEGORIZACIÓN BS`)                                    AS categorizacion_bs,
  CAST(NULL AS STRING)                                         AS cartera,       -- agregar si la tabla la trae

  -- Pago
  CAST(NULL AS STRING)                                         AS payment_method,
  CAST(NULL AS STRING)                                         AS payment_method_group,
  TRIM(`FINANCING 1`)                                          AS financing_type_1,
  TRIM(`FINANCING 2`)                                          AS financing_type_2,
  TRIM(`FINANCING 3`)                                          AS financing_type_3,
  TRIM(`FINANCING CREDIT CARD`)                                AS financing_credit_card,
  TRIM(`FINANCING PRE 3`)                                      AS financing_pre_3,
  TRIM(`FINANCING PRE VF`)                                     AS financing_pre_vf,
  TRIM(`FINANCING 3 VF`)                                       AS financing_3_vf,
  CAST(CUOTAS AS STRING)                                       AS cuotas,
  CAST(NULL AS STRING)                                         AS issuer,
  CAST(NULL AS STRING)                                         AS acquirer,
  CAST(NULL AS STRING)                                         AS industry,

  -- Métricas LC (sumadas a ese grano)
  SUM(SAFE_CAST(TPV_LC                AS NUMERIC))             AS tpv_lc,
  SUM(SAFE_CAST(PROCESSING            AS NUMERIC))             AS processing_lc,
  SUM(SAFE_CAST(`FIN GROSS`           AS NUMERIC))             AS fin_gross_lc,
  SUM(SAFE_CAST(`FIN COST`            AS NUMERIC))             AS fin_cost_lc,
  SUM(SAFE_CAST(CP                    AS NUMERIC))             AS cp_lc,
  SUM(SAFE_CAST(CCFF                  AS NUMERIC))             AS ccff_lc,
  SUM(SAFE_CAST(`SALES TAX`           AS NUMERIC))             AS sales_tax_lc,
  SUM(SAFE_CAST(CBK                   AS NUMERIC))             AS cbk_lc,
  SUM(SAFE_CAST(BPP                   AS NUMERIC))             AS bpp_lc,
  SUM(SAFE_CAST(INCENTIVOS            AS NUMERIC))             AS incentivos_lc,
  SUM(SAFE_CAST(DESCUENTOS            AS NUMERIC))             AS descuentos_lc,
  SUM(SAFE_CAST(CUPONES               AS NUMERIC))             AS cupones_lc,
  SUM(SAFE_CAST(`OTHER DIRECT VAR COST` AS NUMERIC))           AS other_direct_var_cost_lc,
  SUM(SAFE_CAST(`CX VAR`              AS NUMERIC))             AS cx_var_lc,
  SUM(SAFE_CAST(`HOSTING VAR`         AS NUMERIC))             AS hosting_var_lc,
  SUM(SAFE_CAST(`COM RESELLERS`       AS NUMERIC))             AS com_resellers_lc,
  SUM(SAFE_CAST(`NTR LC`              AS NUMERIC))             AS ntr_lc_src,        -- para reconciliación
  SUM(SAFE_CAST(`VC LC`               AS NUMERIC))             AS vc_lc_src,         -- para reconciliación
  SUM(SAFE_CAST(`VC_LC UE`            AS NUMERIC))             AS vc_lc_ue,
  SUM(SAFE_CAST(`CBK & Others`        AS NUMERIC))             AS cbk_and_others_lc,

  -- FX promedio del período (validar con MacroPremises)
  ANY_VALUE(SAFE_CAST(FX AS NUMERIC))                          AS fx_real,

  -- Trazabilidad
  CURRENT_TIMESTAMP()                                          AS refresh_date,
  '${RAW_TABLE}'                                               AS source_table,
  TO_HEX(SHA256(CONCATENADO))                                  AS source_row_hash
FROM `${PROJECT}.${SBOX_DATASET}.${RAW_TABLE}`
WHERE PERIODO IS NOT NULL
GROUP BY ALL;

-- Validaciones
-- 1. Cierre vs origen
-- SELECT period_month, ROUND(SUM(tpv_lc),2) AS tpv FROM `${PROJECT}.${SBOX_DATASET}.op_pnl__base_granular` GROUP BY 1 ORDER BY 1;
-- 2. Sanidad de signos
-- SELECT MIN(processing_lc), MAX(fin_cost_lc), MIN(cbk_lc) FROM `${PROJECT}.${SBOX_DATASET}.op_pnl__base_granular`;
