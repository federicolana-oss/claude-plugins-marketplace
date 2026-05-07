"""
grid_upload.py — Sube una nueva versión del HTML al Grid doc.

Uso:
    python grid_upload.py [path/al/dashboard.html]

Si no se pasa argumento, usa HTML_DEFAULT.

Pre-requisitos en la máquina que corre esto:
- VPN corporativa MELI activa (auth se hace por edge IP)
- pip install requests python-dotenv
- Variables en .env:
    DOC_ID=01KQZ8ZQHYRPD8ARVFGJ157E9B
    GRID_API=https://grid.melioffice.com/api/v1/engine/run
    SKILL_VERSION=3.6.2
    DOC_TITLE=OP P&L · Online Payments · Monthly Review
    SHARE_WITH=fedlana

Comportamiento:
- 4 retries con backoff exponencial (2s, 4s, 8s, 16s)
- Distingue 401 (VPN caída) vs 403 (permisos) vs 5xx (engine)
- Imprime "[OK] file_replaced" cuando la API confirma upload exitoso
"""

import os, sys, time, json
from pathlib import Path

try:
    import requests
except ImportError:
    print("ERROR: pip install requests python-dotenv", file=sys.stderr); sys.exit(2)
try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent / ".env")
except ImportError:
    pass

REPO_ROOT      = Path(__file__).resolve().parents[3]
HTML_DEFAULT   = REPO_ROOT / "analytics" / "op_pnl" / "grid" / "op_pnl_dashboard_v16.html"
DOC_ID         = os.getenv("DOC_ID",         "01KQZ8ZQHYRPD8ARVFGJ157E9B")
GRID_API       = os.getenv("GRID_API",       "https://grid.melioffice.com/api/v1/engine/run")
SKILL_VERSION  = os.getenv("SKILL_VERSION",  "3.6.2")
DOC_TITLE      = os.getenv("DOC_TITLE",      "OP P&L · Online Payments · Monthly Review")
SHARE_WITH     = [u.strip() for u in os.getenv("SHARE_WITH", "fedlana").split(",") if u.strip()]
MAX_RETRIES    = int(os.getenv("MAX_RETRIES", "4"))
TIMEOUT_SEC    = int(os.getenv("TIMEOUT_SEC", "60"))


def upload(html_path: Path, doc_id: str | None = None) -> dict:
    """Sube el HTML al Grid. Si doc_id es None, crea doc nuevo y devuelve el doc_id en la respuesta."""
    if not html_path.exists():
        raise FileNotFoundError(f"HTML no encontrado: {html_path}")

    config = {
        "skill_version":       SKILL_VERSION,
        "skip_version_check":  True,
        "title":               DOC_TITLE,
        "share_with":          SHARE_WITH,
    }
    if doc_id:
        config["doc_id"] = doc_id

    last_err = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            with open(html_path, "rb") as fh:
                r = requests.post(
                    GRID_API,
                    files={"file": (html_path.name, fh, "text/html")},
                    data={"config": json.dumps(config)},
                    timeout=TIMEOUT_SEC,
                )
        except requests.exceptions.RequestException as e:
            last_err = f"network: {e}"
            print(f"[retry {attempt}/{MAX_RETRIES}] {last_err}", file=sys.stderr)
            time.sleep(2 ** attempt)
            continue

        if r.status_code == 200:
            try:
                body = r.json()
            except Exception:
                body = {"raw": r.text}
            print(f"[OK] file_replaced · doc_id={body.get('doc_id', doc_id)} · version={body.get('version', '?')}")
            return body

        if r.status_code == 401:
            raise PermissionError(
                "401 unauthorized · VPN MELI no activa o sesión expirada. "
                "Reconectá la VPN y reintentá."
            )
        if r.status_code == 403:
            raise PermissionError(
                f"403 forbidden · Tu usuario no tiene rol editor sobre doc_id={doc_id}. "
                f"El owner debe agregarte como EDITOR (no viewer)."
            )
        if 500 <= r.status_code < 600:
            last_err = f"server {r.status_code}: {r.text[:200]}"
            print(f"[retry {attempt}/{MAX_RETRIES}] {last_err}", file=sys.stderr)
            time.sleep(2 ** attempt)
            continue

        # otros 4xx → no retry
        raise RuntimeError(f"HTTP {r.status_code}: {r.text[:300]}")

    raise RuntimeError(f"agotaron reintentos · último error: {last_err}")


def main():
    html_path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else HTML_DEFAULT
    print(f"--> Uploading {html_path.name} ({html_path.stat().st_size:,} bytes) to doc_id={DOC_ID}")
    upload(html_path, DOC_ID)


if __name__ == "__main__":
    main()
