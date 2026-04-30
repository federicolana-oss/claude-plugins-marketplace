-- =============================================================================
-- 03_effects_mix.sql
-- Efecto MIX por dimensión, calculado al nivel de agregación INMEDIATAMENTE
-- INFERIOR al subtotal donde se quiere mostrar (anti doble conteo).
--
-- Patrón: para mostrar mix por <dim_mix> dentro del scope <dim_scope>:
--   1) Calcular share y rate por (period, dim_scope, dim_mix) en t y t-1
--   2) effect_mix = Σ (share_curr - share_comp) × rate_comp × tpv_total_curr_scope
-- =============================================================================

-- Ejemplo 1: efecto MIX por CUOTAS dentro de site × product
CREATE OR REPLACE TABLE `${PROJECT}.${SBOX_DATASET}.op_pnl__effect_mix_cuotas`
PARTITION BY DATE_TRUNC(period_month, MONTH)
CLUSTER BY site, product AS

WITH agg AS (
  SELECT period_month, site, product, cuotas,
         SUM(tpv_usd) AS tpv_usd,
         SUM(vc_usd)  AS vc_usd
  FROM `${PROJECT}.${SBOX_DATASET}.op_pnl__economics_enriched`
  WHERE scenario = 'real'
  GROUP BY 1,2,3,4
),
shares AS (
  SELECT *,
    SAFE_DIVIDE(tpv_usd, SUM(tpv_usd) OVER (PARTITION BY period_month, site, product)) AS share,
    SAFE_DIVIDE(vc_usd,  tpv_usd)                                                       AS rate,
    SUM(tpv_usd) OVER (PARTITION BY period_month, site, product)                        AS tpv_scope
  FROM agg
),
joined AS (
  SELECT a.period_month, a.site, a.product, a.cuotas,
         a.share AS share_curr, a.rate AS rate_curr, a.tpv_scope,
         b.share AS share_comp, b.rate AS rate_comp
  FROM shares a
  LEFT JOIN shares b
    ON a.site=b.site AND a.product=b.product AND a.cuotas=b.cuotas
   AND b.period_month = DATE_SUB(a.period_month, INTERVAL 1 MONTH)
)
SELECT period_month, site, product,
       SUM((share_curr - COALESCE(share_comp,0)) * COALESCE(rate_comp, 0)) * ANY_VALUE(tpv_scope)
         AS effect_mix_cuotas_usd
FROM joined
GROUP BY 1,2,3;

-- Ejemplo 2: efecto MIX por PAYMENT_METHOD_GROUP dentro de site × product
CREATE OR REPLACE TABLE `${PROJECT}.${SBOX_DATASET}.op_pnl__effect_mix_mop`
PARTITION BY DATE_TRUNC(period_month, MONTH)
CLUSTER BY site, product AS
WITH agg AS (
  SELECT period_month, site, product, payment_method_group AS mop,
         SUM(tpv_usd) AS tpv_usd, SUM(vc_usd) AS vc_usd
  FROM `${PROJECT}.${SBOX_DATASET}.op_pnl__economics_enriched`
  WHERE scenario = 'real'
  GROUP BY 1,2,3,4
),
shares AS (
  SELECT *,
    SAFE_DIVIDE(tpv_usd, SUM(tpv_usd) OVER (PARTITION BY period_month, site, product)) AS share,
    SAFE_DIVIDE(vc_usd, tpv_usd) AS rate,
    SUM(tpv_usd) OVER (PARTITION BY period_month, site, product) AS tpv_scope
  FROM agg
),
joined AS (
  SELECT a.period_month, a.site, a.product, a.mop,
         a.share AS share_curr, a.rate AS rate_curr, a.tpv_scope,
         b.share AS share_comp, b.rate AS rate_comp
  FROM shares a
  LEFT JOIN shares b
    ON a.site=b.site AND a.product=b.product AND a.mop=b.mop
   AND b.period_month = DATE_SUB(a.period_month, INTERVAL 1 MONTH)
)
SELECT period_month, site, product,
       SUM((share_curr - COALESCE(share_comp,0)) * COALESCE(rate_comp,0)) * ANY_VALUE(tpv_scope)
         AS effect_mix_mop_usd
FROM joined
GROUP BY 1,2,3;

-- Repetir el patrón para: industry, segment, issuer, acquirer.
-- Recomendación: macro-izar con un script Python o dbt macro para no duplicar SQL.
