-- ─────────────────────────────────────────────────────────────────────────────
-- INDUSTRIAS · Big Sellers Online Payments
-- ─────────────────────────────────────────────────────────────────────────────
-- Agrega VC%, TPV y cantidad de sellers por:
--   INDUSTRY_GROUP : agrupación macro (Commerce, Apps, Recaudos, Ocio,
--                    Oil & Gas, Gambling, Venta Directa, Otros)
--   VERTICAL       : verticales más finas dentro de cada grupo
--                    (Apparel, Retail, Home, Salud, Turismo, etc.)
--
-- La clasificación viene de mapeos custom sobre CUS_INDUSTRY_ID_ORIGINAL.
-- El mapeo está documentado en build_html.py del repo big-sellers-hub.
--
-- Filtros estándar:
--   - SUBSEGMENT_SEL = 'BIG SELLERS'
--   - UE_MP_SUBBU_MANAGERIAL = 'ONLINE PAYMENTS'
--   - Solo Top 100 (RANKING_SELLERS <= 100) por país y período
--
-- USO:
--   Reemplazá @current_period por el YYYYMM target. Ej: 202604.
-- ─────────────────────────────────────────────────────────────────────────────

DECLARE current_period INT64 DEFAULT 202604;

WITH
-- Ranking por TPV LC dentro de cada (site, periodo) — para identificar Top 100
ranked AS (
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
    AND PERIODO = current_period
  GROUP BY PERIODO, SIT_SITE_ID, COLLECTOR_GROUP
),

-- Métricas por seller con clasificación industria/vertical
seller_industry AS (
  SELECT
    s.PERIODO,
    s.SIT_SITE_ID,
    s.COLLECTOR_GROUP,
    -- INDUSTRY_GROUP (8 buckets macro)
    CASE
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN (
        'Alimentos','Alimentos y bebidas','Alimentos y Bebidas','Juguetes','Bijouteria',
        'Librería','Librería y Juguetería & Mascotas','Librería y Juguetería & Mascota',
        'Consumo Masivo / Higiene / Limpieza','Hogar y decoración','Hogar / Construcción',
        'Electro y Electronicos','Electro y Electrónicos','Textiles','Tecnología',
        'Luxury Goods & Jewelry','Supermercados','Cosmetics','Retail','Retails / Hipermercados',
        'Home & Deco','Apparel','Moda/Fashion','Moda / Fashion','Cosméticos e Beleza','Home',
        'Farmacias y Perfumerías','Farmacias Perfumerias & Estetica','Farmacias, Perfumerías & Estética',
        'Indumentaria','Restaurantes','Restaurantes / Pubs','Gastronomía','Belleza y cuidado personal',
        'Deportes','Editoriales','Herramientas','Arte'
      ) THEN 'Commerce'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN (
        'Apps y Plataformas Digitales','PSP - Xborders','Fintech','Software','Internet','Suscripciones'
      ) THEN 'Apps'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Gambling') THEN 'Gambling'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN (
        'Turismo','Entretenimientos y Espectáculos /Música','Entretenimiento','Wine and Spirits',
        'Gaming','Leisure, Travel & Tourism','Leisure Travel & Tourism','Moda'
      ) THEN 'Ocio'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Oil & Gas') THEN 'Oil & Gas'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN (
        'Gobierno & Serv. Publico','Gobierno & Serv. Público','Gobierno & Serv. Públicos','Gobierno',
        'Utilities','Energía','Educación','Educacion','Educación / Capacitación',
        'Automotriz y Autopartes','Autos, Motos & Náutica','Salud / Obras Sociales / Laboratorios','Salud',
        'Estética y cuidado de la salud','Servicios Financieros y Bancarios','Seguros',
        'Servicios Empresariales & Personales','Clubes, Outdoors & Gimnasios','Construcción',
        'Logística','Transporte urbano','Transporte','Seguridad','Inmobiliario',
        'Comunicaciones','Laboratorios','Telecomunicaciones'
      ) THEN 'Recaudos'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Venta Directa') THEN 'Venta Directa'
      ELSE 'Otros'
    END AS INDUSTRY_GROUP,
    -- VERTICAL (granularidad fina dentro de cada grupo)
    CASE
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Alimentos','Alimentos y bebidas','Alimentos y Bebidas','Restaurantes','Restaurantes / Pubs','Gastronomía') THEN 'Alimentos y Bebidas'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Apparel','Moda/Fashion','Moda / Fashion','Indumentaria','Bijouteria','Textiles','Luxury Goods & Jewelry','Belleza y cuidado personal','Cosméticos e Beleza','Moda','Deportes') THEN 'Apparel'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Apps y Plataformas Digitales','PSP - Xborders','Fintech','Software','Internet','Suscripciones') THEN 'Apps y Plataformas Digitales'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL = 'Automotriz y Autopartes' THEN 'Autos, Motos & Náutica'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Electro y Electronicos','Electro y Electrónicos','Tecnología') THEN 'Electro'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Entretenimientos y Espectáculos /Música','Entretenimiento','Wine and Spirits','Gaming','Arte') THEN 'Entretenimiento'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Farmacias y Perfumerías','Farmacias Perfumerias & Estetica','Farmacias, Perfumerías & Estética','Estética y cuidado de la salud') THEN 'Farmacias, Perfumerías & Estética'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Gobierno & Serv. Publico','Gobierno & Serv. Público','Gobierno & Serv. Públicos','Gobierno') THEN 'Gobierno'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Home','Home & Deco','Hogar y decoración','Hogar / Construcción') THEN 'Home'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Consumo Masivo / Higiene / Limpieza','Supermercados','Retail','Retails / Hipermercados','Cosmetics','Juguetes','Librería','Librería y Juguetería & Mascotas','Librería y Juguetería & Mascota','Editoriales','Herramientas') THEN 'Retail'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Salud / Obras Sociales / Laboratorios','Salud','Laboratorios') THEN 'Salud'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL = 'Oil & Gas' THEN 'Oil & Gas'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Turismo','Leisure, Travel & Tourism','Leisure Travel & Tourism') THEN 'Turismo'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Educación','Educacion','Educación / Capacitación') THEN 'Educación'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Utilities','Energía','Comunicaciones','Telecomunicaciones') THEN 'Utilities'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL = 'Servicios Financieros y Bancarios' THEN 'Servicios Financieros'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL = 'Venta Directa' THEN 'Venta Directa'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL = 'Gambling' THEN 'Gambling'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL = 'Seguros' THEN 'Seguros'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Servicios Empresariales & Personales','Seguridad','Inmobiliario') THEN 'Servicios Empresariales'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL = 'Clubes, Outdoors & Gimnasios' THEN 'Clubes & Gimnasios'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL = 'Construcción' THEN 'Construcción'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL = 'Logística' THEN 'Logística'
      WHEN s.CUS_INDUSTRY_ID_ORIGINAL IN ('Transporte urbano','Transporte') THEN 'Transporte'
      ELSE 'Otros'
    END AS VERTICAL,
    SUM(COALESCE(s.TPV_USD,    0)) AS tpv_usd,
    SUM(COALESCE(s.VC_USD_FTP, 0)) AS vc_usd
  FROM `meli-bi-data.WHOWNER.DM_SNAP_ACQUIRING_SELLERS` s
  WHERE s.SUBSEGMENT_SEL = 'BIG SELLERS'
    AND s.UE_MP_SUBBU_MANAGERIAL = 'ONLINE PAYMENTS'
    AND s.PERIODO = current_period
  GROUP BY s.PERIODO, s.SIT_SITE_ID, s.COLLECTOR_GROUP, s.CUS_INDUSTRY_ID_ORIGINAL
),

-- Filtrar solo Top 100
top100_industry AS (
  SELECT si.*, r.RANKING
  FROM seller_industry si
  JOIN ranked r
    ON r.PERIODO = si.PERIODO
   AND r.SIT_SITE_ID = si.SIT_SITE_ID
   AND r.COLLECTOR_GROUP = si.COLLECTOR_GROUP
  WHERE r.RANKING <= 100
)

-- Output: por site × INDUSTRY_GROUP × VERTICAL.
-- Para vista solo INDUSTRY_GROUP, comentá la línea del VERTICAL en SELECT y GROUP BY.
SELECT
  SIT_SITE_ID,
  INDUSTRY_GROUP,
  VERTICAL,
  COUNT(DISTINCT COLLECTOR_GROUP) AS sellers_top100,
  ROUND(SUM(tpv_usd)/1e6, 2)      AS tpv_musd,
  ROUND(SUM(vc_usd) /1e6, 3)      AS vc_musd,
  ROUND(SAFE_DIVIDE(SUM(vc_usd), SUM(tpv_usd))*100, 3) AS vc_pct,
  ROUND(SUM(tpv_usd) / SUM(SUM(tpv_usd)) OVER (PARTITION BY SIT_SITE_ID) * 100, 1) AS tpv_share_site_pct
FROM top100_industry
GROUP BY SIT_SITE_ID, INDUSTRY_GROUP, VERTICAL
ORDER BY SIT_SITE_ID, tpv_musd DESC;
