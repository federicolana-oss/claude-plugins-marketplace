"""
data_audit.py — Auditoría de fuentes de datos del dashboard OP P&L.
Lista métrica por métrica si está conectada a fuente real o usa mock.
Genera reporte legible que se puede pegar en el commit message o issue.

Uso:
    python data_audit.py
"""
import sys, re, json
from pathlib import Path

REPO_ROOT     = Path(__file__).resolve().parents[3]
HTML_DEFAULT  = REPO_ROOT / "analytics" / "op_pnl" / "grid" / "op_pnl_dashboard_v20.html"

REPORT = []

def section(title): REPORT.append(f"\n{'='*68}\n{title}\n{'='*68}")
def line(label, status, detail=""):
    icon = {"REAL":"✅","PARTIAL":"⚠️","MOCK":"❌"}[status]
    REPORT.append(f"  {icon} {label:<32} {status:<8} {detail}")


def main():
    html = HTML_DEFAULT.read_text(encoding="utf-8")
    section("AUDITORÍA DE DATOS · OP P&L Dashboard")
    REPORT.append(f"\nArchivo: {HTML_DEFAULT.name}")
    REPORT.append(f"Tamaño:  {HTML_DEFAULT.stat().st_size:,} bytes\n")

    # Plan v3
    section("PLAN 2026 (CSV de Finanzas Acquiring · Aj FTP)")
    if "const PLAN_2026" in html and '"tpv_usd"' in html:
        line("Plan TPV / VC mensual", "REAL",
             "embebido como JSON · 420 buckets · 12 meses · 7 sites")
    else:
        line("Plan TPV / VC mensual", "MOCK", "PLAN_2026 no encontrado")

    # Real (current month TPV/VC)
    section("REAL · Métricas del mes (TPV, VC, ratios componentes)")
    if "mulberry32" in html and "function tpvTotalAt" in html:
        line("TPV mensual por site", "MOCK",
             "generado con mulberry32 + factores hardcoded SITE_W")
        line("VC mensual por site",  "MOCK",
             "vc_pct = baseVcPct + siteAdj + noise")
        line("Ratios componentes (Processing, Fin Net, etc.)", "MOCK",
             "buildRatios() con valores fijos + ruido")

    # FX / Inflación
    section("FX / INFLACIÓN")
    if "SITE_INFL" in html and "WHOWNER.BT_FIN_MACRO_PREMISES" in html:
        line("FX real / FX plan",  "MOCK",
             "factores hardcoded; SQL listo en sql/10_macro_premises_join.sql para conectar a WHOWNER.BT_FIN_MACRO_PREMISES")
        line("Inflation YoY MLA",  "MOCK",
             "hardcoded 0.60 · necesita columna real de macro premises")
    else:
        line("FX / Inflación", "MOCK", "factores hardcoded sin documentar")

    # YoY
    section("CÁLCULOS YoY")
    if "function tpvSiteTrendV11" in html:
        line("TPV YoY % MLA",      "PARTIAL",
             "fórmula correcta (USD CC Deflated) · datos input mock")
        line("TPV YoY % otros",    "PARTIAL",
             "fórmula correcta (LC nativa proxy) · datos input mock")
    else:
        line("TPV YoY %", "MOCK", "sin lógica YoY")

    # Industrias
    section("INDUSTRIAS (Heatmap BS)")
    if "INDUSTRY_BASE_SHARE" in html:
        line("Share por industria", "MOCK",
             "hardcoded; SQL listo en sql/08_industrias.sql para WHOWNER.DM_SNAP_ACQUIRING_SELLERS")
        line("VC% por industria",   "MOCK",
             "vcByIndustry() factor hardcoded")

    # BS Movement
    section("BIG SELLERS · Top 100 Movement (STAY/NEW/EXIT)")
    if "function bsmMockSite" in html:
        line("STAY / NEW / EXIT counts",     "MOCK",
             "función bsmMockSite genera datos · SQL listo en sql/09_farming_hunting.sql")
        line("Quality Spread (VC% NEW − VC% EXIT)", "MOCK",
             "calculated sobre data mock")

    # Filtros (estructura, no data)
    section("FILTROS / DIMENSIONES (estructura)")
    line("OP_PRODUCT post-CASE",    "REAL",
         "valores y mapping de la query del repo big-sellers-hub")
    line("CATEGORIA_PLAN_OP",       "REAL",
         "valores reales de la tabla")
    line("Industrias (taxonomía)",  "REAL",
         "INDUSTRY_GROUP × VERTICAL del CASE oficial")
    line("Sites · Segmentos",       "REAL",  "catálogos completos")
    line("Adquirentes · Emisores",  "PARTIAL",
         "lista LATAM razonable; necesita DISTINCT real para confirmar")

    # Resumen
    section("RESUMEN")
    REPORT.append("""
  REAL = mapeos / catálogos / Plan v3 (CSV)
  PARTIAL = lógica correcta, datos input mock
  MOCK = totalmente generado por seeds JS — necesita pipeline BQ

  Para tener números 100% reales necesito:
    1. Output del SQL sql/05_grid_export_json.sql contra
       SBOX_FINANCEMP.BT_MP_ACQUIRING_CROSS_V3  →  reemplaza mock TPV/VC
    2. Output de sql/10_macro_premises_join.sql contra
       WHOWNER.BT_FIN_MACRO_PREMISES  →  reemplaza FX/Inflation hardcoded
    3. Output de sql/08_industrias.sql contra
       WHOWNER.DM_SNAP_ACQUIRING_SELLERS  →  reemplaza shares industria
    4. Output de sql/09_farming_hunting.sql  →  reemplaza BS Movement mock

  Alternativa: subir HTML de un Grid existente con números reales
  (como hiciste con Acquiring KPI Evolution) y los extraigo / cross-checkeo.
""")

    print("\n".join(REPORT))
    # Save report to file
    out = REPO_ROOT / "analytics" / "op_pnl" / "automation" / "audit_report.txt"
    out.write_text("\n".join(REPORT))
    print(f"\nReporte guardado en: {out}")


if __name__ == "__main__":
    main()
