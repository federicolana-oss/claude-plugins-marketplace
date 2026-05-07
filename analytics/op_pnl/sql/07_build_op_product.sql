-- =============================================================================
-- 07_build_op_product.sql
-- Lógica real para construir el campo OP_PRODUCT (post-CASE) y el roll-up de
-- métricas P&L Online Payments. Basado en la query de referencia compartida.
--
-- Salida: una fila por (PERIODO, SIT_SITE_ID, SUBBU, OP_PRODUCT, SUBSEGMENT_SEL,
-- PAY_PM_TYPE_ID_2, FINANCING_TYPE_3, INSTALLMENTS, CONCEPTO, VALOR)
--
-- Reemplazá ${PROJECT}, ${SBOX_DATASET} con tus valores.
-- Ajustá el filtro de SIT_SITE_ID o quitalo para multi-país.
-- =============================================================================

WITH base AS (
  SELECT
    PERIODO,
    SIT_SITE_ID,
    SUBBU,

    -- ============================================================
    -- OP_PRODUCT post-CASE: combina OP_PRODUCT raw + CATEGORIA_PLAN_OP
    --                       + SUBSEGMENT_SEL para producir 12 buckets
    -- ============================================================
    CASE
      WHEN SUBBU = "ONLINE PAYMENTS" THEN
        CASE
          -- Big Sellers · Farming
          WHEN UPPER(OP_PRODUCT) IN ('COW','API','TELEVENTAS','PAYMENT ADDITION','WALLET BUTTON','OTHER','WALLET CONNECT','CAIXA','CORONA VOUCHER','WHATSAPP')
            AND CATEGORIA_PLAN_OP IN ("BS Farming","BS Farming LC","BS Farming Midtail","BS Farming Corps")
            AND SUBSEGMENT_SEL = "BIG SELLERS"
          THEN "BS_Farming"

          -- Big Sellers · Hunting
          WHEN UPPER(OP_PRODUCT) IN ('COW','API','TELEVENTAS','PAYMENT ADDITION','WALLET BUTTON','OTHER','WALLET CONNECT','CAIXA','CORONA VOUCHER','WHATSAPP')
            AND CATEGORIA_PLAN_OP IN ("BS Hunting","BS Hunting LC","BS Hunting Midtail")
            AND SUBSEGMENT_SEL = "BIG SELLERS"
          THEN "BS_Hunting"

          -- Big Sellers · Sin Tag (cae en Longtail / SMB / sin clasificar)
          WHEN UPPER(OP_PRODUCT) IN ('COW','API','TELEVENTAS','PAYMENT ADDITION','WALLET BUTTON','OTHER','WALLET CONNECT','CAIXA','CORONA VOUCHER','WHATSAPP')
            AND SUBSEGMENT_SEL = "BIG SELLERS"
          THEN "BS_Sin Tag"

          -- SMB · Checkout
          WHEN UPPER(OP_PRODUCT) IN ('COW','API','TELEVENTAS','PAYMENT ADDITION','WALLET BUTTON','OTHER','WALLET CONNECT','CAIXA','CORONA VOUCHER','WHATSAPP')
            AND SUBSEGMENT_SEL = "SMB"
          THEN "SMB_CHECKOUT"

          -- SMB · Others (no checkout, no link)
          WHEN UPPER(OP_PRODUCT) NOT IN ('COW','API','TELEVENTAS','PAYMENT ADDITION','WALLET BUTTON','OTHER','WALLET CONNECT','CAIXA','CORONA VOUCHER','WHATSAPP','LINK')
            AND SUBSEGMENT_SEL = "SMB"
          THEN "SMB_Others"

          -- Longtail · Checkout
          WHEN UPPER(OP_PRODUCT) IN ('COW','API','TELEVENTAS','PAYMENT ADDITION','WALLET BUTTON','OTHER','WALLET CONNECT','CAIXA','CORONA VOUCHER','WHATSAPP')
            AND SUBSEGMENT_SEL = "LONGTAIL"
          THEN "LT_CHECKOUT"

          -- Longtail · Others
          WHEN UPPER(OP_PRODUCT) NOT IN ('COW','API','TELEVENTAS','PAYMENT ADDITION','WALLET BUTTON','OTHER','WALLET CONNECT','CAIXA','CORONA VOUCHER','WHATSAPP','LINK')
            AND SUBSEGMENT_SEL = "LONGTAIL"
          THEN "LT_Others"

          -- Link de Pago por subsegmento
          WHEN UPPER(OP_PRODUCT) = 'LINK' AND SUBSEGMENT_SEL = "LONGTAIL"    THEN "LT_LINK"
          WHEN UPPER(OP_PRODUCT) = 'LINK' AND SUBSEGMENT_SEL = "SMB"         THEN "SMB_LINK"
          WHEN UPPER(OP_PRODUCT) = 'LINK' AND SUBSEGMENT_SEL = "BIG SELLERS" THEN "BS_LINK"
        END

      WHEN UPPER(OP_PRODUCT) = 'TTP' THEN 'TTP'
      ELSE "NA"
    END AS OP_PRODUCT,

    SUBSEGMENT_SEL,
    CAST(NULL AS STRING) AS FINANCING_TYPE_3,   -- TODO: confirmar fórmula con el equipo
    CAST(NULL AS STRING) AS PAY_PM_TYPE_ID_2,
    CAST(NULL AS INT64)  AS installments,

    -- ============================================================
    -- MÉTRICAS P&L (sumadas)
    -- ============================================================
    SUM(CASE WHEN tpv_flag = 1 THEN TPV ELSE 0 END) AS TPV,

    -- VC = NTR + var costs (la suma algebraica completa)
    SUM(
      COALESCE(PROCESSING_FEE,0)
      + COALESCE(UE_MP_SPREAD_MARK_UP_AMT_LC,0)
      + COALESCE(FINANCING_GROSS,0)
      + COALESCE(UE_MP_FINANCING_COST_FTP_AMT_LC,0)
      + COALESCE(COLLECTION_COST,0)
      + COALESCE(SALES_TAXES,0)
      + COALESCE(UE_MP_COSTO_PLAZO_FTP_AMT_LC,0)
      + COALESCE(UE_MP_FEE_RIESGO_AMT_LC,0)
      + COALESCE(CHARGEBACKS_SIN_PREVISION,0)
      + COALESCE(BPP,0)
      + COALESCE(INCENTIVOS_SELLERS,0)
      + COALESCE(BONIFICACIONES_SELLERS,0)
      + COALESCE(UE_MP_CUPONES_SELLER_AMT_LC,0)
      + COALESCE(DESCUENTOS,0)*0           -- excluido (regla del modelo)
      + COALESCE(DESCUENTOS_PAYERS,0)*0    -- excluido
      + COALESCE(OTHER_DIRECT_VAR_COST,0)
      + COALESCE(UE_MP_MNG_TLM_AMT_LC,0)
      + COALESCE(CX_VAR,0)
      + COALESCE(HOSTING_VAR,0)
      + COALESCE(FRD_PREV,0)
      + CASE WHEN SUBBU = "POINT" THEN 0 ELSE COALESCE(COMISIONES_RESELLER,0) END
    ) AS VC,

    SUM(COALESCE(PROCESSING_FEE,0) + COALESCE(UE_MP_SPREAD_MARK_UP_AMT_LC,0)) AS Processing,
    SUM(COALESCE(FINANCING_GROSS,0))                                          AS FINANCING_GROSS,
    SUM(COALESCE(UE_MP_FINANCING_COST_FTP_AMT_LC,0)
        + COALESCE(UE_MP_COSTO_PLAZO_FTP_AMT_LC,0)
        + COALESCE(UE_MP_FEE_RIESGO_AMT_LC,0))                                AS FINANCING_COST,
    SUM(COALESCE(COLLECTION_COST,0))                                          AS COLL_FEES,
    SUM(COALESCE(SALES_TAXES,0))                                              AS SALES_TAXES,
    SUM(COALESCE(CHARGEBACKS_SIN_PREVISION,0)
        + COALESCE(BPP,0)
        + COALESCE(UE_MP_MNG_TLM_AMT_LC,0)
        + COALESCE(INCENTIVOS_SELLERS,0)
        + COALESCE(BONIFICACIONES_SELLERS,0)
        + COALESCE(UE_MP_CUPONES_SELLER_AMT_LC,0)
        + COALESCE(DESCUENTOS,0)*0
        + COALESCE(DESCUENTOS_PAYERS,0)*0
        + COALESCE(OTHER_DIRECT_VAR_COST,0)
        + COALESCE(CX_VAR,0)
        + COALESCE(HOSTING_VAR,0)
        + COALESCE(FRD_PREV,0)
        + CASE WHEN SUBBU = "POINT" THEN 0 ELSE COALESCE(COMISIONES_RESELLER,0) END) AS OTHERS

  FROM `${PROJECT}.${SBOX_DATASET}.BT_MP_ACQUIRING_CROSS`     -- ← versión raw (no V3 si la cross materializada cambia)
  WHERE TPV_SEGMENT_ID NOT IN ('Point Device Sale')          -- ← excluye Point físico
    -- AND SIT_SITE_ID IN ('MLA','MLB','MLM','MLC','MCO','MPE','MLU')   -- opcional: multi-país
    AND PERIODO BETWEEN DATE '2025-04-01' AND DATE '2026-04-30'
  GROUP BY ALL
)

SELECT *
FROM base
UNPIVOT (valor FOR concepto IN (
  TPV,
  VC,
  Processing,
  FINANCING_GROSS,
  COLL_FEES,
  FINANCING_COST,
  SALES_TAXES,
  OTHERS
))
ORDER BY PERIODO, SIT_SITE_ID, OP_PRODUCT, concepto;
