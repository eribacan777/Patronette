from conftest import auth, jpeg_bytes, new_post, register


def _collection(client, user, name, public=False):
    r = client.post(
        "/me/collections", headers=auth(user), json={"name": name, "is_public": public}
    )
    assert r.status_code == 201, r.text
    return r.json()


def test_salvarea_unei_postari_intr_o_colectie(client):
    ana = register(client, "ana@exemplu.ro", "Ana")
    maria = register(client, "maria@exemplu.ro", "Maria")
    post = new_post(
        client, maria, files={"image": ("r.jpg", jpeg_bytes((800, 600)), "image/jpeg")}
    )
    rochii = _collection(client, ana, "Rochii de vară", public=True)

    assert client.put(
        f"/collections/{rochii['id']}/posts/{post['id']}", headers=auth(ana)
    ).status_code == 204
    # A doua oară nu o dublează.
    client.put(f"/collections/{rochii['id']}/posts/{post['id']}", headers=auth(ana))

    seen = client.get(f"/posts/{post['id']}", headers=auth(ana)).json()
    assert seen["saved_by_me"] is True
    assert client.get(f"/posts/{post['id']}", headers=auth(maria)).json()["saved_by_me"] is False

    mine = client.get("/me/collections", params={"post_id": post["id"]}, headers=auth(ana)).json()
    assert mine[0]["item_count"] == 1
    assert mine[0]["contains_post"] is True
    assert mine[0]["cover_url"] == f"/posts/{post['id']}/image"

    detail = client.get(f"/collections/{rochii['id']}").json()
    assert [p["id"] for p in detail["posts"]] == [post["id"]]
    assert detail["collection"]["owner"]["display_name"] == "Ana"

    client.delete(f"/collections/{rochii['id']}/posts/{post['id']}", headers=auth(ana))
    assert client.get(f"/posts/{post['id']}", headers=auth(ana)).json()["saved_by_me"] is False


def test_colectiile_private_nu_le_vede_nimeni_altcineva(client):
    ana = register(client, "ana@exemplu.ro", "Ana")
    maria = register(client, "maria@exemplu.ro", "Maria")
    publica = _collection(client, ana, "Idei", public=True)
    privata = _collection(client, ana, "Cadouri secrete")

    vazute = client.get(f"/users/{ana['id']}/collections", headers=auth(maria)).json()
    assert [c["name"] for c in vazute] == ["Idei"]
    toate = client.get(f"/users/{ana['id']}/collections", headers=auth(ana)).json()
    assert sorted(c["name"] for c in toate) == ["Cadouri secrete", "Idei"]

    assert client.get(f"/collections/{privata['id']}", headers=auth(maria)).status_code == 404
    assert client.get(f"/collections/{privata['id']}").status_code == 404
    assert client.get(f"/collections/{privata['id']}", headers=auth(ana)).status_code == 200
    assert client.get(f"/collections/{publica['id']}").status_code == 200


def test_doar_proprietara_modifica_colectia(client):
    ana = register(client, "ana@exemplu.ro", "Ana")
    maria = register(client, "maria@exemplu.ro", "Maria")
    c = _collection(client, ana, "Idei")
    post = new_post(client, maria)
    assert client.put(
        f"/collections/{c['id']}/posts/{post['id']}", headers=auth(maria)
    ).status_code == 404
    assert client.patch(
        f"/collections/{c['id']}", headers=auth(maria), json={"name": "Ale mele"}
    ).status_code == 404
    assert client.delete(f"/collections/{c['id']}", headers=auth(maria)).status_code == 404


def test_redenumire_vizibilitate_si_nume_dublu(client):
    ana = register(client, "ana@exemplu.ro", "Ana")
    c = _collection(client, ana, "Idei")
    _collection(client, ana, "Tipare")
    r = client.patch(f"/collections/{c['id']}", headers=auth(ana), json={"name": "Idei noi", "is_public": True})
    assert r.json()["name"] == "Idei noi" and r.json()["is_public"] is True
    dup = client.post("/me/collections", headers=auth(ana), json={"name": "Tipare"})
    assert dup.status_code == 409
    assert client.post("/me/collections", headers=auth(ana), json={"name": "   "}).status_code == 422


def test_stergerea_postarii_o_scoate_din_colectii(client):
    ana = register(client, "ana@exemplu.ro", "Ana")
    maria = register(client, "maria@exemplu.ro", "Maria")
    c = _collection(client, ana, "Idei")
    post = new_post(client, maria)
    client.put(f"/collections/{c['id']}/posts/{post['id']}", headers=auth(ana))
    client.delete(f"/posts/{post['id']}", headers=auth(maria))
    assert client.get("/me/collections", headers=auth(ana)).json()[0]["item_count"] == 0
    # Ștergerea colecției nu șterge postările din ea.
    other = new_post(client, maria)
    client.put(f"/collections/{c['id']}/posts/{other['id']}", headers=auth(ana))
    assert client.delete(f"/collections/{c['id']}", headers=auth(ana)).status_code == 204
    assert client.get(f"/posts/{other['id']}").status_code == 200
