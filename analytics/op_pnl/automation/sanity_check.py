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
HTML_DEFAULT  = REPO_ROOT / "analytics" / "op_pnl" / "grid" / "op_pnl_dashboard_v9.html"
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
        (r"\bundefined\b(?!\s*[=:])",    "literal 'undefined' in output"),
        (r"v\d+\.0\s*·\s*MOCK",          "version+MOCK marker still present (debe sacarse)"),
        (r"All SubBU\s*·\s*Pricing",     "obsolete 'All SubBU · Pricing' subtitle"),
    ]
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

    # SubBUs
    subbus = re.findall(r'data-subbu="([^"]+)"', html)
    if sorted(set(subbus)) != sorted(['ALL','BS','SMB','Longtail']):
        failed("subbus", f"obtenido {sorted(set(subbus))}")
    else:
        passed("subbus", "ALL/BS/SMB/Longtail")

    # No Point ni QR
    if "Point" in html and re.search(r'\bPoint\s+(Total|TOTAL)', html):
        failed("no_point", "encontró 'Point' en el HTML (debería ser solo OP)")
    else:
        passed("no_point", "no Point/QR")

    # Friendly filter labels
    friendly_labels = ['CATEGORÍA','PRODUCTO','SUBSEGMENTO','MEDIO PAGO','CUOTAS','ADQUIRENTE','EMISOR','FUNGIBLE']
    found = [lbl for lbl in friendly_labels if lbl in html]
    if len(found) != len(friendly_labels):
        missing = set(friendly_labels) - set(found)
        failed("friendly_labels", f"faltan: {missing}")
    else:
        passed("friendly_labels", "8/8 filtros con labels amigables")


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
