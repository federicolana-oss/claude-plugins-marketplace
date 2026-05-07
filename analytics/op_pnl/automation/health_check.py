"""
health_check.py — Bot diario que valida que el Grid doc está actualizado y manda
Slack DM si algo falla.

Pre-requisitos:
- VPN MELI activa
- pip install requests python-dotenv
- Variables en .env (extras del upload):
    SLACK_WEBHOOK=https://hooks.slack.com/services/...
    NOTIFY_USERS=fedlana
    EXPECTED_AGE_HOURS=26   # alerta si última versión > 26 horas
    EXPECTED_MIN_BYTES=80000  # alerta si tamaño cae bruscamente

Salida:
- 0 → todo OK
- 1 → fallo (envía Slack DM)
"""

import os, sys, json, time
from datetime import datetime, timezone
from pathlib import Path

try:
    import requests
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent / ".env")
except ImportError:
    print("pip install requests python-dotenv", file=sys.stderr); sys.exit(2)

DOC_ID             = os.getenv("DOC_ID",       "01KQZ8ZQHYRPD8ARVFGJ157E9B")
GRID_API_BASE      = os.getenv("GRID_API_BASE", "https://grid.melioffice.com/api/v1")
SLACK_WEBHOOK      = os.getenv("SLACK_WEBHOOK", "")
NOTIFY_USERS       = [u.strip() for u in os.getenv("NOTIFY_USERS", "fedlana").split(",") if u.strip()]
EXPECTED_AGE_HOURS = float(os.getenv("EXPECTED_AGE_HOURS", "26"))
EXPECTED_MIN_BYTES = int(os.getenv("EXPECTED_MIN_BYTES", "80000"))


def get_doc_meta(doc_id: str) -> dict:
    """Pide metadata del doc al Grid. Endpoint puede variar — ajustar si la API real difiere."""
    url = f"{GRID_API_BASE}/docs/{doc_id}"
    r = requests.get(url, timeout=20)
    if r.status_code == 401:
        raise PermissionError("401 · VPN MELI caída")
    if r.status_code == 403:
        raise PermissionError(f"403 · sin permisos sobre doc_id={doc_id}")
    if r.status_code == 404:
        raise FileNotFoundError(f"doc_id={doc_id} no existe")
    r.raise_for_status()
    return r.json()


def notify_slack(msg: str):
    if not SLACK_WEBHOOK:
        print(f"[no-slack] {msg}", file=sys.stderr)
        return
    mention = " ".join(f"<@{u}>" for u in NOTIFY_USERS) if NOTIFY_USERS else ""
    payload = {"text": f"{mention} :rotating_light: *OP P&L Dashboard health check FAIL*\n{msg}"}
    try:
        r = requests.post(SLACK_WEBHOOK, json=payload, timeout=10)
        r.raise_for_status()
    except Exception as e:
        print(f"slack post failed: {e}", file=sys.stderr)


def main():
    fails = []
    try:
        meta = get_doc_meta(DOC_ID)
    except Exception as e:
        notify_slack(f"No pude leer metadata del doc {DOC_ID}: {e}")
        sys.exit(1)

    # 1. Edad de la última versión
    updated_at = meta.get("updated_at") or meta.get("last_modified")
    if updated_at:
        try:
            ts = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
            age_h = (datetime.now(timezone.utc) - ts).total_seconds() / 3600
            if age_h > EXPECTED_AGE_HOURS:
                fails.append(f"Última versión hace {age_h:.1f}h (esperado < {EXPECTED_AGE_HOURS}h)")
        except Exception as e:
            fails.append(f"No pude parsear updated_at='{updated_at}': {e}")
    else:
        fails.append("Metadata sin campo updated_at/last_modified")

    # 2. Tamaño
    size = meta.get("size_bytes") or meta.get("html_size") or 0
    if size and size < EXPECTED_MIN_BYTES:
        fails.append(f"Tamaño {size:,} < esperado {EXPECTED_MIN_BYTES:,} bytes (¿upload truncado?)")

    # 3. Title sanity
    title = (meta.get("title") or "").lower()
    if "online payments" not in title and "op p&l" not in title:
        fails.append(f"Title sospechoso: '{meta.get('title')}'")

    if fails:
        notify_slack("\n".join(f"• {f}" for f in fails))
        print("[FAIL] " + " | ".join(fails))
        sys.exit(1)

    print(f"[OK] doc_id={DOC_ID} updated={updated_at} size={size:,}")
    sys.exit(0)


if __name__ == "__main__":
    main()
