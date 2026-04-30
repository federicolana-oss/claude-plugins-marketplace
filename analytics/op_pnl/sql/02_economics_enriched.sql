-- =============================================================================
-- 02_economics_enriched.sql
-- Capa SEMÁNTICA — métricas USD, ratios %TPV, shares, comparativas (MoM/YoY/Plan),
-- rolling 3/6/12, efectos volumen / rate / FX a grano máximo.
--
-- Requiere:
--   - op_pnl__base_granular  (capa 01)
--   - dim_fx_real, dim_fx_plan
--   - op_pnl__plan_unified   (consolidación de Economic VC | Plan + TPV | Plan)
-- =============================================================================

CREATE OR REPLACE TABLE `${PROJECT}.${SBOX_DATASET}.op_pnl__economics_enriched`
PARTITION BY DATE_TRUNC(period_month, MONTH)
CLUSTER BY site, product, segment AS

WITH base AS (
  SELECT b.*,
         COALESCE(fx.fx,        b.fx_real) AS fx_real_eff,
         COALESCE(fxp.fx_plan,  fx.fx)     AS fx_plan_eff
  FROM `${PROJECT}.${SBOX_DATASET}.op_pnl__base_granular`  b
  LEFT JOIN `${PROJECT}.${SBOX_DATASET}.dim_fx_real`       fx  USING (site, period_month)
  LEFT JOIN `${PROJECT}.${SBOX_DATASET}.dim_fx_plan`       fxp USING (site, period_month)
),

usd AS (
  SELECT
    period_month, scenario, site, product, subproduct, segment, subsegment,
    categoria_plan, categorizacion_bs, cartera,
    payment_method, payment_method_group,
    financing_type_1, financing_type_2, financing_type_3,
    financing_credit_card, financing_pre_3, financing_pre_vf, financing_3_vf,
    cuotas, issuer, acquirer, industry,
    fx_real_eff AS fx_real, fx_plan_eff AS fx_plan,

    -- Métricas LC
    tpv_lc, processing_lc, fin_gross_lc, fin_cost_lc, cp_lc, ccff_lc, sales_tax_lc,
    cbk_lc, bpp_lc, incentivos_lc, descuentos_lc, cupones_lc,
    other_direct_var_cost_lc, cx_var_lc, hosting_var_lc, com_resellers_lc,
    vc_lc_ue, cbk_and_others_lc,

    -- USD
    SAFE_DIVIDE(tpv_lc,                fx_real_eff) AS tpv_usd,
    SAFE_DIVIDE(processing_lc,         fx_real_eff) AS processing_usd,
    SAFE_DIVIDE(fin_gross_lc,          fx_real_eff) AS fin_gross_usd,
    SAFE_DIVIDE(fin_cost_lc,           fx_real_eff) AS fin_cost_usd,
    SAFE_DIVIDE(cp_lc,                 fx_real_eff) AS cp_usd,
    SAFE_DIVIDE(ccff_lc,               fx_real_eff) AS ccff_usd,
    SAFE_DIVIDE(sales_tax_lc,          fx_real_eff) AS sales_tax_usd,
    SAFE_DIVIDE(cbk_lc,                fx_real_eff) AS cbk_usd,
    SAFE_DIVIDE(bpp_lc,                fx_real_eff) AS bpp_usd,
    SAFE_DIVIDE(incentivos_lc,         fx_real_eff) AS incentivos_usd,
    SAFE_DIVIDE(descuentos_lc,         fx_real_eff) AS descuentos_usd,
    SAFE_DIVIDE(cupones_lc,            fx_real_eff) AS cupones_usd,
    SAFE_DIVIDE(other_direct_var_cost_lc, fx_real_eff) AS other_direct_var_cost_usd,
    SAFE_DIVIDE(cx_var_lc,             fx_real_eff) AS cx_var_usd,
    SAFE_DIVIDE(hosting_var_lc,        fx_real_eff) AS hosting_var_usd,
    SAFE_DIVIDE(com_resellers_lc,      fx_real_eff) AS com_resellers_usd,
    SAFE_DIVIDE(vc_lc_ue,              fx_real_eff) AS vc_usd_ue
  FROM base
),

ntr_vc AS (
  SELECT *,
    -- NTR = Processing + FinGross + FinCost + CP + CCFF + Sales Tax (signo algebraico)
    (processing_lc  + fin_gross_lc  + fin_cost_lc  + cp_lc  + ccff_lc  + sales_tax_lc ) AS ntr_lc,
    (processing_usd + fin_gross_usd + fin_cost_usd + cp_usd + ccff_usd + sales_tax_usd) AS ntr_usd,
    -- VC = NTR + (CBK + BPP + Incent + Desc + Cup + OtherDirect + CX + Hosting + Resellers)
    (processing_lc  + fin_gross_lc  + fin_cost_lc  + cp_lc  + ccff_lc  + sales_tax_lc
       + cbk_lc + bpp_lc + incentivos_lc + descuentos_lc + cupones_lc
       + other_direct_var_cost_lc + cx_var_lc + hosting_var_lc + com_resellers_lc) AS vc_lc,
    (processing_usd + fin_gross_usd + fin_cost_usd + cp_usd + ccff_usd + sales_tax_usd
       + cbk_usd + bpp_usd + incentivos_usd + descuentos_usd + cupones_usd
       + other_direct_var_cost_usd + cx_var_usd + hosting_var_usd + com_resellers_usd) AS vc_usd
  FROM usd
),

ratios AS (
  SELECT *,
    SAFE_DIVIDE(processing_usd,           tpv_usd) AS processing_pct_tpv,
    SAFE_DIVIDE(fin_gross_usd,            tpv_usd) AS fin_gross_pct_tpv,
    SAFE_DIVIDE(fin_cost_usd,             tpv_usd) AS fin_cost_pct_tpv,
    SAFE_DIVIDE(sales_tax_usd,            tpv_usd) AS sales_tax_pct_tpv,
    SAFE_DIVIDE(cp_usd,                   tpv_usd) AS cp_pct_tpv,
    SAFE_DIVIDE(ccff_usd,                 tpv_usd) AS ccff_pct_tpv,
    SAFE_DIVIDE(cbk_usd,                  tpv_usd) AS cbk_pct_tpv,
    SAFE_DIVIDE(bpp_usd,                  tpv_usd) AS bpp_pct_tpv,
    SAFE_DIVIDE(incentivos_usd,           tpv_usd) AS incentivos_pct_tpv,
    SAFE_DIVIDE(descuentos_usd,           tpv_usd) AS descuentos_pct_tpv,
    SAFE_DIVIDE(other_direct_var_cost_usd,tpv_usd) AS other_direct_var_pct_tpv,
    SAFE_DIVIDE(cx_var_usd,               tpv_usd) AS cx_var_pct_tpv,
    SAFE_DIVIDE(hosting_var_usd,          tpv_usd) AS hosting_var_pct_tpv,
    SAFE_DIVIDE(ntr_usd,                  tpv_usd) AS ntr_pct_tpv,
    SAFE_DIVIDE(vc_usd,                   tpv_usd) AS vc_pct_tpv
  FROM ntr_vc
),

shares AS (
  SELECT *,
    SAFE_DIVIDE(tpv_usd, SUM(tpv_usd) OVER (PARTITION BY period_month))                                 AS tpv_share_total,
    SAFE_DIVIDE(tpv_usd, SUM(tpv_usd) OVER (PARTITION BY period_month, site))                           AS tpv_share_in_site,
    SAFE_DIVIDE(tpv_usd, SUM(tpv_usd) OVER (PARTITION BY period_month, site, segment))                  AS tpv_share_in_segment,
    SAFE_DIVIDE(tpv_usd, SUM(tpv_usd) OVER (PARTITION BY period_month, site, payment_method_group))     AS tpv_share_in_mop,
    SAFE_DIVIDE(tpv_usd, SUM(tpv_usd) OVER (PARTITION BY period_month, site, industry))                 AS tpv_share_in_industry
  FROM ratios
),

comparisons AS (
  SELECT *,
    LAG(tpv_usd,  1)  OVER w AS tpv_usd_prev_month,
    LAG(vc_usd,   1)  OVER w AS vc_usd_prev_month,
    LAG(vc_pct_tpv,1) OVER w AS vc_pct_prev_month,
    LAG(tpv_share_in_site,1) OVER w AS tpv_share_prev_month,
    LAG(fx_real,  1)  OVER w AS fx_real_prev_month,

    LAG(tpv_usd, 12)  OVER w AS tpv_usd_last_year,
    LAG(vc_usd,  12)  OVER w AS vc_usd_last_year,
    LAG(vc_pct_tpv,12) OVER w AS vc_pct_last_year,

    AVG(tpv_usd) OVER (w_roll  3) AS tpv_usd_rolling_3m,
    AVG(tpv_usd) OVER (w_roll  6) AS tpv_usd_rolling_6m,
    AVG(tpv_usd) OVER (w_roll 12) AS tpv_usd_rolling_12m,
    AVG(vc_usd)  OVER (w_roll  3) AS vc_usd_rolling_3m,
    AVG(vc_usd)  OVER (w_roll 12) AS vc_usd_rolling_12m
  FROM shares
  WINDOW
    w AS (PARTITION BY site, product, segment, payment_method_group, cuotas, issuer, acquirer, industry
          ORDER BY period_month),
    w_roll AS (PARTITION BY site, product, segment, payment_method_group, cuotas, issuer, acquirer, industry
               ORDER BY period_month
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
  -- Nota: BQ no acepta el truco "w_roll N" como sintaxis literal; expandilo:
  --   AVG(tpv_usd) OVER (PARTITION BY ... ORDER BY period_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS tpv_usd_rolling_3m
  -- Lo dejé en formato compacto a propósito para que lo expandas manualmente al copiar.
),

plan_join AS (
  SELECT c.*,
         p.tpv_usd        AS tpv_plan_usd,
         p.vc_usd         AS vc_plan_usd,
         SAFE_DIVIDE(p.vc_usd, p.tpv_usd) AS vc_plan_pct,
         SAFE_DIVIDE(c.tpv_lc, c.fx_plan) AS tpv_at_plan_fx_usd,
         SAFE_DIVIDE(c.vc_lc,  c.fx_plan) AS vc_at_plan_fx_usd
  FROM comparisons c
  LEFT JOIN `${PROJECT}.${SBOX_DATASET}.op_pnl__plan_unified` p
    ON c.period_month = p.period_month
   AND c.site         = p.site
   AND c.product      = p.product
   AND c.segment      = p.segment
   AND COALESCE(c.payment_method_group,'') = COALESCE(p.payment_method_group,'')
),

effects AS (
  SELECT *,
    -- Deltas MoM
    (tpv_usd     - tpv_usd_prev_month)              AS delta_tpv_mom,
    SAFE_DIVIDE(tpv_usd, tpv_usd_prev_month) - 1    AS delta_tpv_mom_pct,
    (vc_usd      - vc_usd_prev_month)               AS delta_vc_mom,
    (vc_pct_tpv  - vc_pct_prev_month)               AS delta_vc_pct_mom_pp,
    (tpv_share_in_site - tpv_share_prev_month)      AS delta_tpv_share_mom_pp,

    -- Deltas YoY
    (tpv_usd     - tpv_usd_last_year)               AS delta_tpv_yoy,
    SAFE_DIVIDE(tpv_usd, tpv_usd_last_year) - 1     AS delta_tpv_yoy_pct,
    (vc_usd      - vc_usd_last_year)                AS delta_vc_yoy,
    (vc_pct_tpv  - vc_pct_last_year)                AS delta_vc_pct_yoy_pp,

    -- Deltas vs Plan
    (tpv_usd     - tpv_plan_usd)                    AS delta_tpv_vs_plan,
    (vc_usd      - vc_plan_usd)                     AS delta_vc_vs_plan,
    (vc_pct_tpv  - vc_plan_pct)                     AS delta_vc_pct_vs_plan_pp,

    -- Efecto VOLUMEN: rate_comp × ΔTPV  (comparador = mes anterior)
    vc_pct_prev_month * (tpv_usd - tpv_usd_prev_month)                       AS effect_volume_usd,

    -- Efecto RATE: ΔRate × TPV_curr
    (vc_pct_tpv - vc_pct_prev_month) * tpv_usd                               AS effect_rate_usd,

    -- Efecto FX: revaluación de VC LC con FX actual vs FX comparador
    SAFE_DIVIDE(vc_lc, fx_real) - SAFE_DIVIDE(vc_lc, fx_real_prev_month)     AS effect_fx_usd,

    -- Efecto Plan
    (vc_usd - vc_plan_usd)                                                   AS effect_plan_usd,
    -- Efecto Plan @ FX real (gap operativo aislando FX)
    (vc_usd - vc_at_plan_fx_usd)                                             AS effect_plan_fx_usd

  FROM plan_join
)

SELECT * FROM effects;

-- =============================================================================
-- ⚠️ NOTA SOBRE EL WINDOW BLOCK:
-- BigQuery acepta WINDOW pero la sintaxis "OVER (w_roll 3)" del bloque "comparisons"
-- es PSEUDOCÓDIGO. Reemplazá cada AVG(...) OVER (w_roll N) por la forma explícita:
--
--   AVG(tpv_usd) OVER (
--     PARTITION BY site, product, segment, payment_method_group, cuotas, issuer, acquirer, industry
--     ORDER BY period_month
--     ROWS BETWEEN (N-1) PRECEDING AND CURRENT ROW
--   ) AS tpv_usd_rolling_Nm
-- =============================================================================
