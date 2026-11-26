"""Testele rulează pe baza `patronette_test` (TEST_DATABASE_URL din .env),
niciodată pe baza aplicației. Fiecare test pornește cu tabelele goale."""

import io
import os
from pathlib import Path

import pytest
from dotenv import dotenv_values  # vine odată cu uvicorn[standard]

_env = dotenv_values(Path(__file__).parents[1] / ".env")
os.environ["DATABASE_URL"] = os.environ.get("TEST_DATABASE_URL") or _env["TEST_DATABASE_URL"]
os.environ.setdefault("JWT_SECRET", _env.get("JWT_SECRET") or "x" * 40)
os.environ["ADMIN_EMAILS"] = "admin@exemplu.ro"
os.environ["GOOGLE_CLIENT_IDS"] = "client-de-test.apps.googleusercontent.com"
os.environ["REPORTS_TO_HIDE"] = "3"

from fastapi.testclient import TestClient  # noqa: E402
from PIL import Image  # noqa: E402

from sqlalchemy import text  # noqa: E402

from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.migrate import run_migrations  # noqa: E402

assert "patronette_test" in str(engine.url), "testele trebuie să ruleze pe baza de test"


def drop_everything():
    Base.metadata.drop_all(engine)
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS alembic_version"))


@pytest.fixture(autouse=True)
def clean_db():
    # Baza de test se construiește prin migrări, exact ca în cloud.
    drop_everything()
    run_migrations()
    yield


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def register(client, email: str, name: str = "Ana") -> dict:
    r = client.post(
        "/auth/register", json={"email": email, "password": "parola-buna", "display_name": name}
    )
    assert r.status_code == 201, r.text
    data = r.json()
    return {"Authorization": f"Bearer {data['token']}", "id": data["user"]["id"]}


def auth(user: dict) -> dict:
    return {"Authorization": user["Authorization"]}


def jpeg_bytes(size=(3000, 2000), exif_gps=False) -> bytes:
    img = Image.new("RGB", size, (200, 120, 130))
    out = io.BytesIO()
    if exif_gps:
        exif = Image.Exif()
        exif[0x8825] = {2: (45.0, 45.0, 0.0)}  # GPSInfo: latitudine
        img.save(out, "JPEG", exif=exif)
    else:
        img.save(out, "JPEG")
    return out.getvalue()


def new_post(client, user: dict, text="Sfat: călcați rezervele", **extra) -> dict:
    files = extra.pop("files", None)
    r = client.post("/posts", headers=auth(user), data={"text": text, **extra}, files=files)
    assert r.status_code == 201, r.text
    return r.json()
