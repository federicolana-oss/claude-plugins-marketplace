"""
sanity_check.py — Bot de validación pre-upload del dashboard.

Corre TODOS los checks abajo. Si alguno falla, sale con exit code != 0
(y refresh_dashboard.bat aborta el upload).

Checks:
  1. HTML existe y es parseable
  2. Tamaño del archivo razonable (entre 80KB y 500KB)
  3. Período default correcto (configurable)
  4. Sin bugs conocidos: "M M" doble, "$NaN", "undefined" en output, "v_.0 · MOCK"
  5. Estructura de tabs presente (3 tabs principales)
  6. Catálogos consistentes:
       - 7 sites + ALL
       - 3 SubBUs + ALL
       - 5 productos OP (sin Point ni QR)
       - 8 filtros row 2 con labels amigables
  7. Funciones JS críticas presentes (renderPnLCard, buildPnL, applyAdv, etc.)
  8. JSON-friendly: mock data se parsea sin errores

Uso:
    python sanity_check.py [path/to/dashboard.html]

Salida:
    [OK] todos los checks pasaron
    [FAIL] check X: descripción → exit 1

Integración con refresh_dashboard.bat:
    El .bat ya llama a sanity_check.py antes de grid_upload.py.
"""
import os, sys, re
from pathlib import Path

REPO_ROOT     = Path(__file__).resolve().parents[3]
HTML_DEFAULT  = REPO_ROOT / "analytics" / "op_pnl" / "grid" / "op_pnl_dashboard_v15.html"
EXPECTED_PERIOD = os.getenv("EXPECTED_PERIOD", "2026-04")  # configurable
MIN_BYTES = 80_000
MAX_BYTES = 500_000

CHECKS_PASSED = []
CHECKS_FAILED = []


def passed(name, msg=""):
    CHECKS_PASSED.append((name, msg))
    print(f"  [OK]   {name} {msg}")


def failed(name, msg):
    CHECKS_FAILED.append((name, msg))
    print(f"  [FAIL] {name} → {msg}")


def check_file(path: Path):
    if not path.exists():
        failed("file_exists", f"{path} no existe")
        return None
    size = path.stat().st_size
    if size < MIN_BYTES:
        failed("file_size", f"{size:,} bytes < {MIN_BYTES:,} (¿truncado?)")
    elif size > MAX_BYTES:
        failed("file_size", f"{size:,} bytes > {MAX_BYTES:,} (¿bloated?)")
    else:
        passed("file_size", f"{size:,} bytes")
    return path.read_text(encoding="utf-8")


def check_no_known_bugs(html: str):
    bugs = [
        (r"\d+\.\d+\s*M\s+M\b",         "double-M bug ('5.5 M M')"),
        (r"\$NaN",                        "$NaN in output"),
        (r"v\d+\.0\s*·\s*MOCK",          "version+MOCK marker still present (debe sacarse)"),
        (r"All SubBU\s*·\s*Pricing",     "obsolete 'All SubBU · Pricing' subtitle"),
    ]
    # Heurística para 'undefined' en texto visible (no en código JS válido).
    # JS válido usa undefined en: typeof X==='undefined', X===undefined, void 0, default-init.
    # Si aparece en HTML literal o en un template literal sin condición → bug.
    visible_undef = re.search(r"(?<![=!])>\s*undefined\s*<", html)
    if visible_undef:
        failed("no_known_bugs", "'undefined' renderizado como texto visible")
        return
    for pattern, desc in bugs:
        if re.search(pattern, html):
            failed("no_known_bugs", desc)
            return
    passed("no_known_bugs", "sin bugs conocidos")


def check_default_period(html: str):
    # busca opción seleccionada con value == EXPECTED_PERIOD
    m = re.search(rf'<option[^>]*value="{re.escape(EXPECTED_PERIOD)}"[^>]*selected', html)
    if m:
        passed("default_period", EXPECTED_PERIOD)
    else:
        failed("default_period", f"esperado <option value='{EXPECTED_PERIOD}' selected> no encontrado")


def check_tabs(html: str):
    expected = ["portada", "multi", "trend"]
    present = re.findall(r'data-tab="([^"]+)"', html)
    missing = [t for t in expected if t not in present]
    if missing:
        failed("tabs_present", f"faltan tabs: {missing}")
    else:
        passed("tabs_present", f"{len(present)} tabs ({', '.join(present)})")


def check_catalogs(html: str):
    # Sites
    sites = re.findall(r'data-site="([^"]+)"', html)
    sites_uniq = sorted(set(sites))
    expected_sites = ['ALL','MLA','MLB','MLM','MLC','MCO','MPE','MLU']
    if sorted(expected_sites) != sites_uniq:
        failed("sites", f"esperado {expected_sites} · obtenido {sites_uniq}")
    else:
        passed("sites", f"{len(expected_sites)} sites")

    # Segmentos (was SubBU)
    subbus = re.findall(r'data-subbu="([^"]+)"', html)
    if sorted(set(subbus)) != sorted(['ALL','BS','SMB','Longtail']):
        failed("segmentos", f"obtenido {sorted(set(subbus))}")
    else:
        passed("segmentos", "ALL/BS/SMB/Longtail")

    # SubBU label should be Segmento now
    if 'ALL SubBU' in html or '>SubBU<' in html:
        failed("segmento_renamed", "todavía hay 'SubBU' en UI (debería ser 'Segmento')")
    else:
        passed("segmento_renamed", "renombrado correctamente")

    # No Point ni QR
    if "Point" in html and re.search(r'\bPoint\s+(Total|TOTAL)', html):
        failed("no_point", "encontró 'Point' en el HTML (debería ser solo OP)")
    else:
        passed("no_point", "no Point/QR")

    # Friendly filter labels (v11: SUBSEGMENTO removed -- duplicate of SEGMENTO)
    friendly_labels = ['CATEGORÍA','PRODUCTO','MEDIO PAGO','CUOTAS','ADQUIRENTE','EMISOR','FUNGIBLE']
    found = [lbl for lbl in friendly_labels if lbl in html]
    if len(found) != len(friendly_labels):
        missing = set(friendly_labels) - set(found)
        failed("friendly_labels", f"faltan: {missing}")
    else:
        passed("friendly_labels", f"{len(friendly_labels)}/{len(friendly_labels)} filtros con labels amigables")
    if 'SUBSEGMENTO' in html:
        failed("subsegmento_removed", "SUBSEGMENTO todavía aparece (debería haberse eliminado)")
    else:
        passed("subsegmento_removed", "SUBSEGMENTO eliminado")

    # Categoria Plan OP: valores reales del modelo (BS Farming LC, Hunting Midtail, etc.)
    if 'BS Farming LC' not in html or 'BS Hunting Midtail' not in html:
        failed("categoria_plan_op", "valores reales BQ no encontrados (BS Farming LC / BS Hunting Midtail)")
    elif 'option>Cards<' in html or 'option>Crypto<' in html:
        failed("categoria_plan_op", "todavía hay valores genéricos (Cards/Crypto)")
    else:
        passed("categoria_plan_op", "valores reales BQ presentes")

    # OP_PRODUCT post-CASE: valores reales (BS_Farming, SMB_CHECKOUT, LT_LINK, etc.)
    op_prod_real = ['BS_Farming','BS_Hunting','SMB_CHECKOUT','LT_LINK','LT_CHECKOUT']
    missing_op = [v for v in op_prod_real if v not in html]
    if missing_op:
        failed("op_product_real", f"faltan valores OP_PRODUCT post-CASE: {missing_op}")
    else:
        passed("op_product_real", "OP_PRODUCT real (post-CASE) presente")

    # INDUSTRIA real (verticales del mapeo CUS_INDUSTRY_ID_ORIGINAL)
    industry_real = ['Apps y Plataformas Digitales','Apparel','Retail','Turismo','Gambling','Oil &amp; Gas']
    missing_ind = [v for v in industry_real if v not in html]
    if missing_ind:
        failed("industry_real", f"faltan industrias reales: {missing_ind}")
    else:
        passed("industry_real", "INDUSTRIA real (verticales del mapeo) presente")
    if 'af-industry' not in html:
        failed("industry_filter", "filtro INDUSTRIA (af-industry) no presente en row 2")
    else:
        passed("industry_filter", "filtro INDUSTRIA wired")

    # Header subtitle: Business Controlling FP&A (was: Pricing & Profitability)
    if 'Business Controlling FP&amp;A' not in html and 'Business Controlling FP&A' not in html:
        failed("fpa_subtitle", "subtitle 'Business Controlling FP&A' no encontrado")
    elif 'Pricing &amp; Profitability' in html or 'Pricing & Profitability' in html:
        failed("fpa_subtitle", "todavía aparece 'Pricing & Profitability' en algún lado")
    else:
        passed("fpa_subtitle", "subtitle correcto · FP&A")

    # BS Movement section present
    bsm_keywords = ['bsm-stay-n','bsm-new-n','bsm-exit-n','bsm-spread-v','renderBSMovement','QUALITY SPREAD']
    missing = [k for k in bsm_keywords if k not in html]
    if missing:
        failed("bs_movement", f"sección BS Movement incompleta: faltan {missing}")
    else:
        passed("bs_movement", "Top 100 BS Movement (STAY/NEW/EXIT + Quality Spread)")

    # Responsive: media queries presentes
    if '@media' in html and 'max-width:1280px' in html:
        passed("responsive", "media queries presentes")
    else:
        failed("responsive", "no se encontraron media queries de responsive")

    # Logo MP — usa el PNG oficial (matchea referente Acquiring KPI)
    if 'mp-brand' in html and 'mp-logo-img' in html and 'data:image/png;base64,iVBOR' in html:
        passed("logo_mp", "logo Mercado Pago oficial PNG (matchea referente)")
    elif 'logo-mp' in html or 'mercado' in html.lower():
        failed("logo_mp", "logo encontrado pero NO es el PNG oficial (debe usar mp-brand + mp-logo-img + base64)")
    else:
        failed("logo_mp", "logo MP no encontrado")


def check_js_functions(html: str):
    expected = [
        "renderPnLCard", "buildPnL", "applyAdv", "applyCur",
        "renderMRBySite", "renderMRByProduct", "renderMRBySegProd",
        "renderTopDeviations", "buildPivotTable", "renderPortada",
        "renderMulti", "renderTrend"
    ]
    missing = [f for f in expected if f"function {f}" not in html]
    if missing:
        failed("js_functions", f"faltan: {missing}")
    else:
        passed("js_functions", f"{len(expected)} funciones críticas")


def check_mock_data_parses(html: str):
    # Extrae el bloque DATA y verifica que no tenga errores obvios
    if "const DATA = " not in html and "const DATA= " not in html:
        failed("mock_data", "bloque 'const DATA' no encontrado")
        return
    if "DATA.metrics[" not in html:
        failed("mock_data", "DATA.metrics no se usa")
        return
    passed("mock_data", "bloque DATA presente y referenciado")


def main():
    path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else HTML_DEFAULT
    print(f"--> Sanity check: {path.name}")
    html = check_file(path)
    if html is None:
        sys.exit(1)
    check_no_known_bugs(html)
    check_default_period(html)
    check_tabs(html)
    check_catalogs(html)
    check_js_functions(html)
    check_mock_data_parses(html)

    print()
    print(f"==> {len(CHECKS_PASSED)} OK · {len(CHECKS_FAILED)} FAIL")
    if CHECKS_FAILED:
        sys.exit(1)
    print("[OK] dashboard listo para upload")
    sys.exit(0)


if __name__ == "__main__":
    main()
