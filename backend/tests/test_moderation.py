from conftest import auth, new_post, register


def _report(client, user, post_id, reason="conținut nepotrivit"):
    r = client.post(f"/posts/{post_id}/report", headers=auth(user), json={"reason": reason})
    assert r.status_code == 204


def test_trei_raportari_ascund_postarea(client):
    ana = register(client, "ana@exemplu.ro")
    post = new_post(client, ana, text="spam")
    reporters = [register(client, f"r{i}@exemplu.ro", f"R{i}") for i in range(3)]

    _report(client, reporters[0], post["id"])
    # Aceeași persoană nu poate raporta de două ori.
    _report(client, reporters[0], post["id"])
    _report(client, reporters[1], post["id"])
    assert len(client.get("/posts").json()["posts"]) == 1

    _report(client, reporters[2], post["id"])
    assert client.get("/posts").json()["posts"] == []
    # Autoarea încă își vede postarea, ca să știe ce s-a întâmplat.
    assert client.get(f"/posts/{post['id']}", headers=auth(ana)).json()["hidden"] is True


def test_blocarea_ascunde_postarile_si_comentariile(client):
    ana = register(client, "ana@exemplu.ro")
    troll = register(client, "troll@exemplu.ro", "Troll")
    post = new_post(client, ana)
    new_post(client, troll, text="ceva urât")
    client.post(f"/posts/{post['id']}/comments", headers=auth(troll), json={"text": "urât"})

    assert client.put(f"/users/{troll['id']}/block", headers=auth(ana)).status_code == 204
    feed = client.get("/posts", headers=auth(ana)).json()["posts"]
    assert [p["author"]["display_name"] for p in feed] == ["Ana"]
    assert client.get(f"/posts/{post['id']}/comments", headers=auth(ana)).json() == []
    # Ceilalți încă văd totul.
    assert len(client.get("/posts").json()["posts"]) == 2

    client.delete(f"/users/{troll['id']}/block", headers=auth(ana))
    assert len(client.get("/posts", headers=auth(ana)).json()["posts"]) == 2


def test_panoul_administratoarei(client):
    ana = register(client, "ana@exemplu.ro")
    maria = register(client, "maria@exemplu.ro")
    admin = register(client, "admin@exemplu.ro", "Admin")
    post = new_post(client, ana, text="ofertă suspectă")
    _report(client, maria, post["id"], "reclamă")

    assert client.get("/admin/reports", headers=auth(maria)).status_code == 403
    reports = client.get("/admin/reports", headers=auth(admin)).json()
    assert reports[0]["post"]["id"] == post["id"]
    assert reports[0]["reasons"] == ["reclamă"]

    assert client.post(f"/admin/posts/{post['id']}/hide", headers=auth(admin)).status_code == 204
    assert client.get("/posts").json()["posts"] == []
    assert client.get("/admin/reports", headers=auth(admin)).json() == []

    client.post(f"/admin/posts/{post['id']}/restore", headers=auth(admin))
    assert len(client.get("/posts").json()["posts"]) == 1
    # Administratoarea poate șterge orice postare.
    assert client.delete(f"/posts/{post['id']}", headers=auth(admin)).status_code == 204


def test_nu_te_poti_bloca_singura(client):
    ana = register(client, "ana@exemplu.ro")
    assert client.put(f"/users/{ana['id']}/block", headers=auth(ana)).status_code == 422
