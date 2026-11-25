from app.routers import auth as auth_router
from conftest import auth, register


def test_inregistrare_si_login(client):
    user = register(client, "Ana@Exemplu.ro", "Ana")
    r = client.post("/auth/login", json={"email": "ana@exemplu.ro", "password": "parola-buna"})
    assert r.status_code == 200
    assert r.json()["user"]["display_name"] == "Ana"
    me = client.get("/auth/me", headers=auth(user))
    assert me.json()["id"] == user["id"]


def test_parola_gresita_si_email_dublu(client):
    register(client, "ana@exemplu.ro")
    bad = client.post("/auth/login", json={"email": "ana@exemplu.ro", "password": "alta-parola"})
    assert bad.status_code == 401
    unknown = client.post("/auth/login", json={"email": "nimeni@exemplu.ro", "password": "x" * 8})
    # Același mesaj: nu aflăm dacă adresa are cont.
    assert unknown.json()["detail"] == bad.json()["detail"]
    dup = client.post(
        "/auth/register",
        json={"email": "ana@exemplu.ro", "password": "parola-buna", "display_name": "Ana"},
    )
    assert dup.status_code == 409


def test_parola_prea_scurta(client):
    r = client.post(
        "/auth/register", json={"email": "a@b.ro", "password": "scurt", "display_name": "Ana"}
    )
    assert r.status_code == 422


def test_parola_nu_se_pastreaza_in_clar(client):
    from app.db import SessionLocal
    from app.models import User

    register(client, "ana@exemplu.ro")
    with SessionLocal() as db:
        user = db.query(User).one()
        assert "parola-buna" not in user.password_hash
        assert user.password_hash.startswith("$argon2")


def test_token_invalid(client):
    r = client.get("/auth/me", headers={"Authorization": "Bearer nu-e-un-token"})
    assert r.status_code == 401


def test_administratoarea_vine_din_setari(client):
    admin = register(client, "admin@exemplu.ro", "Admin")
    assert client.get("/auth/me", headers=auth(admin)).json()["is_admin"] is True
    user = register(client, "ana@exemplu.ro")
    assert client.get("/auth/me", headers=auth(user)).json()["is_admin"] is False


def test_login_google_creeaza_si_leaga_contul(client, monkeypatch):
    monkeypatch.setattr(
        auth_router,
        "verify_google_token",
        lambda token: {
            "sub": "google-123",
            "email": "ana@exemplu.ro",
            "email_verified": True,
            "name": "Ana Google",
        },
    )
    # Exista deja un cont cu parolă pe același e-mail: se leagă, nu se dublează.
    first = register(client, "ana@exemplu.ro", "Ana")
    r = client.post("/auth/google", json={"id_token": "orice"})
    assert r.status_code == 200
    assert r.json()["user"]["id"] == first["id"]
    # A doua oară se găsește după contul Google.
    again = client.post("/auth/google", json={"id_token": "orice"})
    assert again.json()["user"]["id"] == first["id"]


def test_login_google_respinge_email_neverificat(client, monkeypatch):
    monkeypatch.setattr(
        auth_router,
        "verify_google_token",
        lambda token: {"sub": "g", "email": "x@y.ro", "email_verified": False},
    )
    assert client.post("/auth/google", json={"id_token": "orice"}).status_code == 401
