-- =============================================================================
-- 05_grid_export_json.sql
-- Query final que exporta el grid en formato JSON-friendly para el HTML.
--
-- Cómo usarlo:
--   1) Pegá esta query en BQ console.
--   2) Ajustá los filtros en el WHERE (period_month, sites, etc.).
--   3) Ejecutá y descargá el resultado como JSON (Save Results > JSON).
--   4) Reemplazá el contenido de   analytics/op_pnl/grid/data/grid_data.json
-- =============================================================================

WITH grid AS (
  SELECT
    -- Identificación
    FORMAT_DATE('%Y-%m', period_month) AS period,
    site, product, segment, industry,
    payment_method_group,
    cuotas, issuer, acquirer,
    p_l_block, p_l_line, m_l1, m_l2, m_l3, m_l4, line_order,

    -- Valores
    ROUND(value_usd, 0)              AS value_usd,
    ROUND(tpv_usd,   0)              AS tpv_usd,
    ROUND(pct_tpv,   4)              AS pct_tpv,
    ROUND(tpv_share_in_site, 4)      AS tpv_share,
    ROUND(vc_pct_tpv, 4)             AS vc_pct,

    -- MoM
    ROUND(delta_tpv_mom, 0)          AS delta_tpv_mom,
    ROUND(delta_tpv_mom_pct, 4)      AS delta_tpv_mom_pct,
    ROUND(delta_vc_mom, 0)           AS delta_vc_mom,
    ROUND(delta_vc_pct_mom_pp, 4)    AS delta_vc_pct_mom_pp,

    -- YoY
    ROUND(delta_tpv_yoy, 0)          AS delta_tpv_yoy,
    ROUND(delta_vc_yoy, 0)           AS delta_vc_yoy,

    -- Plan
    ROUND(tpv_plan_usd, 0)           AS tpv_plan_usd,
    ROUND(vc_plan_usd, 0)            AS vc_plan_usd,
    ROUND(delta_vc_vs_plan, 0)       AS delta_vc_vs_plan,

    -- Efectos
    ROUND(effect_volume_usd, 0)      AS effect_volume,
    ROUND(effect_rate_usd, 0)        AS effect_rate,
    ROUND(effect_fx_usd, 0)          AS effect_fx,
    ROUND(effect_plan_usd, 0)        AS effect_plan
  FROM `${PROJECT}.${SBOX_DATASET}.op_pnl__grid_long`
  WHERE period_month = DATE '2026-04-01'
    AND scenario = 'real'
)

SELECT * FROM grid
ORDER BY site, product, segment, line_order;
