-- =============================================================================
-- 00_dim_pnl_mapping.sql
-- Catálogo de líneas P&L con jerarquía managerial M L1..M L4 + orden financiero.
-- Reemplazá ${PROJECT} y ${SBOX_DATASET} con tus valores antes de ejecutar.
-- =============================================================================

CREATE OR REPLACE TABLE `${PROJECT}.${SBOX_DATASET}.dim_pnl_mapping` AS
WITH src AS (
  SELECT * FROM UNNEST([
    -- concept,                    p_l_block,               p_l_line,                m_l1,                  m_l2,                m_l3,                m_l4,                  sign,  line_type,     line_order
    STRUCT('TPV'                  AS concept, 'TPV'                AS p_l_block, 'TPV'                  AS p_l_line, 'TPV'                AS m_l1, 'TPV'              AS m_l2, 'TPV'              AS m_l3, 'TPV'                AS m_l4,  1 AS sign, 'TPV'         AS line_type,  1 AS line_order),
    STRUCT('Processing'           , 'Product Monetization', 'Processing Fees'      , 'Net Revenue'        , 'Product Monetiz.' , 'Processing'       , 'Processing Fees'    ,  1     , 'REVENUE'                ,  3),
    STRUCT('Financing Gross'      , 'Net Monetization'    , 'Financing Gross'      , 'Net Revenue'        , 'Net Monetiz.'     , 'Financing'        , 'Fin Gross'          ,  1     , 'REVENUE'                ,  5),
    STRUCT('Financing Cost'       , 'Net Monetization'    , 'Financing Cost'       , 'Net Revenue'        , 'Net Monetiz.'     , 'Financing'        , 'Fin Cost'           , -1     , 'COST'                   ,  6),
    STRUCT('Sales Tax'            , 'Net Monetization'    , 'Sales Tax'            , 'Net Revenue'        , 'Net Monetiz.'     , 'Tax'              , 'Sales Tax'          , -1     , 'TAX'                    ,  7),
    STRUCT('CP'                   , 'Variable Contribution','Collection Fees'      , 'VC'                 , 'Var. Costs'       , 'Collection'       , 'CP'                 , -1     , 'COST'                   ,  9),
    STRUCT('CCFF'                 , 'Variable Contribution','CCFF'                 , 'VC'                 , 'Var. Costs'       , 'Financing'        , 'CCFF'               , -1     , 'COST'                   , 10),
    STRUCT('NTR'                  , 'Net Monetization'    , 'NTR'                  , 'Net Revenue'        , 'NTR'              , 'NTR'              , 'NTR'                ,  1     , 'CALCULATED'             ,  8),
    STRUCT('CBK'                  , 'Variable Contribution','Chargebacks'          , 'VC'                 , 'Var. Costs'       , 'Risk'             , 'Chargebacks'        , -1     , 'CHARGEBACK'             , 11),
    STRUCT('BPP'                  , 'Variable Contribution','BPP'                  , 'VC'                 , 'Var. Costs'       , 'Risk'             , 'BPP'                , -1     , 'COST'                   , 12),
    STRUCT('Incentivos'           , 'Variable Contribution','Incentivos'           , 'VC'                 , 'Var. Costs'       , 'Commercial'       , 'Incentivos'         , -1     , 'INCENTIVE'              , 13),
    STRUCT('Descuentos'           , 'Variable Contribution','Descuentos'           , 'VC'                 , 'Var. Costs'       , 'Commercial'       , 'Descuentos'         , -1     , 'INCENTIVE'              , 14),
    STRUCT('Cupones'              , 'Variable Contribution','Cupones'              , 'VC'                 , 'Var. Costs'       , 'Commercial'       , 'Cupones'            , -1     , 'INCENTIVE'              , 15),
    STRUCT('Other Direct Var Cost', 'Variable Contribution','Other Direct Var Cost', 'VC'                 , 'Var. Costs'       , 'Other'            , 'Other Direct'       , -1     , 'COST'                   , 16),
    STRUCT('CX Var'               , 'Variable Contribution','CX Variable'          , 'VC'                 , 'Var. Costs'       , 'Operations'       , 'CX'                 , -1     , 'OPEX'                   , 17),
    STRUCT('Hosting Var'          , 'Variable Contribution','Hosting Variable'     , 'VC'                 , 'Var. Costs'       , 'Operations'       , 'Hosting'            , -1     , 'OPEX'                   , 18),
    STRUCT('Com Resellers'        , 'Variable Contribution','Comisiones Resellers' , 'VC'                 , 'Var. Costs'       , 'Commercial'       , 'Resellers'          , -1     , 'COST'                   , 19),
    STRUCT('VC'                   , 'Variable Contribution','VC'                   , 'VC'                 , 'VC'               , 'VC'               , 'VC'                 ,  1     , 'CALCULATED'             , 20),
    STRUCT('Economic VC'          , 'Economic VC'         , 'Economic VC'          , 'Economic VC'        , 'Economic VC'      , 'Economic VC'      , 'Economic VC'        ,  1     , 'CALCULATED'             , 21)
  ])
)
SELECT * FROM src;

-- Validaciones rápidas
-- SELECT line_type, COUNT(*) FROM `${PROJECT}.${SBOX_DATASET}.dim_pnl_mapping` GROUP BY 1 ORDER BY 1;
