-- =============================================================================
-- 04_grid_long.sql
-- Capa GRID — UNPIVOT de las métricas a una fila por p_l_line.
-- Esta vista es la que consume el frontend del grid (Tabulator / AG Grid / Looker).
-- =============================================================================

CREATE OR REPLACE VIEW `${PROJECT}.${SBOX_DATASET}.op_pnl__grid_long` AS

WITH base AS (
  SELECT * FROM `${PROJECT}.${SBOX_DATASET}.op_pnl__economics_enriched`
),

unpivoted AS (
  SELECT b.* EXCEPT(
    -- excluyo las columnas que se van a "explotar" para dejar limpio el SELECT
    processing_lc, processing_usd,
    fin_gross_lc, fin_gross_usd,
    fin_cost_lc, fin_cost_usd,
    sales_tax_lc, sales_tax_usd,
    cp_lc, cp_usd, ccff_lc, ccff_usd,
    cbk_lc, cbk_usd, bpp_lc, bpp_usd,
    incentivos_lc, incentivos_usd,
    descuentos_lc, descuentos_usd,
    cupones_lc, cupones_usd,
    other_direct_var_cost_lc, other_direct_var_cost_usd,
    cx_var_lc, cx_var_usd,
    hosting_var_lc, hosting_var_usd,
    com_resellers_lc, com_resellers_usd,
    ntr_lc, ntr_usd, vc_lc, vc_usd, vc_usd_ue, tpv_lc, tpv_usd
  ),
  v.concept,
  v.value_lc,
  v.value_usd,
  v.pct_tpv,
  -- TPV del scope (para el grid)
  b.tpv_lc, b.tpv_usd
  FROM base b
  CROSS JOIN UNNEST([
    STRUCT('TPV'                   AS concept, b.tpv_lc                   AS value_lc, b.tpv_usd                   AS value_usd, CAST(NULL AS FLOAT64) AS pct_tpv),
    STRUCT('Processing'                       , b.processing_lc                       , b.processing_usd                       , b.processing_pct_tpv),
    STRUCT('Financing Gross'                  , b.fin_gross_lc                        , b.fin_gross_usd                        , b.fin_gross_pct_tpv),
    STRUCT('Financing Cost'                   , b.fin_cost_lc                         , b.fin_cost_usd                         , b.fin_cost_pct_tpv),
    STRUCT('Sales Tax'                        , b.sales_tax_lc                        , b.sales_tax_usd                        , b.sales_tax_pct_tpv),
    STRUCT('CP'                               , b.cp_lc                               , b.cp_usd                               , b.cp_pct_tpv),
    STRUCT('CCFF'                             , b.ccff_lc                             , b.ccff_usd                             , b.ccff_pct_tpv),
    STRUCT('NTR'                              , b.ntr_lc                              , b.ntr_usd                              , b.ntr_pct_tpv),
    STRUCT('CBK'                              , b.cbk_lc                              , b.cbk_usd                              , b.cbk_pct_tpv),
    STRUCT('BPP'                              , b.bpp_lc                              , b.bpp_usd                              , b.bpp_pct_tpv),
    STRUCT('Incentivos'                       , b.incentivos_lc                       , b.incentivos_usd                       , b.incentivos_pct_tpv),
    STRUCT('Descuentos'                       , b.descuentos_lc                       , b.descuentos_usd                       , b.descuentos_pct_tpv),
    STRUCT('Cupones'                          , b.cupones_lc                          , b.cupones_usd                          , CAST(NULL AS FLOAT64)),
    STRUCT('Other Direct Var Cost'            , b.other_direct_var_cost_lc            , b.other_direct_var_cost_usd            , b.other_direct_var_pct_tpv),
    STRUCT('CX Var'                           , b.cx_var_lc                           , b.cx_var_usd                           , b.cx_var_pct_tpv),
    STRUCT('Hosting Var'                      , b.hosting_var_lc                      , b.hosting_var_usd                      , b.hosting_var_pct_tpv),
    STRUCT('Com Resellers'                    , b.com_resellers_lc                    , b.com_resellers_usd                    , CAST(NULL AS FLOAT64)),
    STRUCT('VC'                               , b.vc_lc                               , b.vc_usd                               , b.vc_pct_tpv),
    STRUCT('Economic VC'                      , b.vc_lc * 0  /* TODO: lógica real */  , b.vc_usd_ue                            , SAFE_DIVIDE(b.vc_usd_ue, b.tpv_usd))
  ]) AS v
)

SELECT
  u.*,
  m.p_l_block, m.p_l_line, m.m_l1, m.m_l2, m.m_l3, m.m_l4,
  m.line_order, m.sign, m.line_type
FROM unpivoted u
JOIN `${PROJECT}.${SBOX_DATASET}.dim_pnl_mapping` m USING (concept);
