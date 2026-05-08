-- =============================================================================
-- 10_macro_premises_join.sql
-- Join helper para obtener FX (real + plan) e inflación desde la fuente oficial.
-- Reemplaza el FX promedio derivado de la cross con la macro-premise validada.
--
-- Tabla fuente confirmada por el equipo: WHOWNER.BT_FIN_MACRO_PREMISES
-- =============================================================================

CREATE OR REPLACE TABLE `${PROJECT}.${SBOX_DATASET}.dim_fx_real` AS
SELECT
  SIT_SITE_ID                                        AS site,
  DATE_TRUNC(PERIODO, MONTH)                         AS period_month,
  FX                                                 AS fx_real,
  -- LAG 12 meses para USD CC (constant currency)
  LAG(FX, 12) OVER (PARTITION BY SIT_SITE_ID ORDER BY PERIODO) AS fx_ly,
  INFLATION_RATE_YOY                                 AS inflation_yoy
FROM `meli-bi-data.WHOWNER.BT_FIN_MACRO_PREMISES`
WHERE SIT_SITE_ID IN ('MLA','MLB','MLM','MLC','MCO','MPE','MLU');

CREATE OR REPLACE TABLE `${PROJECT}.${SBOX_DATASET}.dim_fx_plan` AS
SELECT
  SIT_SITE_ID                                        AS site,
  DATE_TRUNC(PERIODO, MONTH)                         AS period_month,
  FX_PLAN                                            AS fx_plan,
  PLAN_VERSION                                       AS plan_version
FROM `meli-bi-data.WHOWNER.BT_FIN_MACRO_PREMISES`
WHERE SIT_SITE_ID IN ('MLA','MLB','MLM','MLC','MCO','MPE','MLU');

-- =============================================================================
-- Conversiones USD / USD CC / Deflated (vista canónica)
-- =============================================================================
CREATE OR REPLACE VIEW `${PROJECT}.${SBOX_DATASET}.fx_lookup` AS
SELECT
  fr.site, fr.period_month,
  fr.fx_real,
  fr.fx_ly,
  fr.inflation_yoy,
  fp.fx_plan,
  -- Factores conceptuales aplicados sobre LC para llegar a cada moneda
  SAFE_DIVIDE(1, fr.fx_real)                                        AS lc_to_usd,
  SAFE_DIVIDE(1, fr.fx_ly)                                          AS lc_to_usd_cc,
  CASE
    WHEN fr.site = 'MLA'
      THEN SAFE_DIVIDE(1, fr.fx_ly) / SAFE_DIVIDE(1 + fr.inflation_yoy, 1)
      ELSE SAFE_DIVIDE(1, fr.fx_ly)   -- otros sites: Deflated == USD CC
  END                                                                AS lc_to_deflated,
  SAFE_DIVIDE(1, fp.fx_plan)                                        AS lc_to_plan_usd
FROM `${PROJECT}.${SBOX_DATASET}.dim_fx_real` fr
LEFT JOIN `${PROJECT}.${SBOX_DATASET}.dim_fx_plan` fp
  USING (site, period_month);

-- =============================================================================
-- Reglas de comparación vs LY (per glosario validado):
--   ALL / Argentina:        Real(N) Deflated / Real(N-1) USD - 1
--   Sites excl. Argentina:  Real LC / Real(N-1) LC - 1
-- vs Plan: Real Deflated / Plan Deflated - 1
-- =============================================================================
