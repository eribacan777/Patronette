import io

from PIL import Image

from conftest import auth, jpeg_bytes, new_post, register


def test_profilul_arata_numarul_de_postari_si_urmaritori(client):
    ana = register(client, "ana@exemplu.ro", "Ana")
    maria = register(client, "maria@exemplu.ro", "Maria")
    new_post(client, ana)
    new_post(client, ana)

    p = client.get(f"/users/{ana['id']}", headers=auth(maria)).json()
    assert p["display_name"] == "Ana"
    assert p["post_count"] == 2
    assert p["follower_count"] == 0
    assert p["is_me"] is False and p["followed_by_me"] is False
    assert client.get(f"/users/{ana['id']}", headers=auth(ana)).json()["is_me"] is True


def test_editarea_profilului(client):
    ana = register(client, "ana@exemplu.ro", "Ana")
    r = client.patch(
        "/me", headers=auth(ana), json={"display_name": "  Ana   Pop ", "bio": "Cos rochii de vară."}
    )
    assert r.status_code == 200
    assert r.json()["display_name"] == "Ana Pop"
    assert r.json()["bio"] == "Cos rochii de vară."
    assert client.patch("/me", headers=auth(ana), json={"bio": "x" * 301}).status_code == 422


def test_poza_de_profil_e_patrata_si_se_schimba_adresa(client):
    ana = register(client, "ana@exemplu.ro")
    r = client.put(
        "/me/avatar",
        headers=auth(ana),
        files={"image": ("eu.jpg", jpeg_bytes((1600, 900), exif_gps=True), "image/jpeg")},
    )
    first = r.json()["avatar_url"]
    assert first.startswith(f"/users/{ana['id']}/avatar?v=")
    img = Image.open(io.BytesIO(client.get(first).content))
    assert img.size == (512, 512)
    assert 0x8825 not in img.getexif()

    second = client.put(
        "/me/avatar", headers=auth(ana), files={"image": ("b.jpg", jpeg_bytes(), "image/jpeg")}
    ).json()["avatar_url"]
    assert second != first  # adresa nouă: telefonul nu arată poza veche din cache
    # Poza apare și la postări.
    post = new_post(client, ana)
    assert post["author"]["avatar_url"] == second

    gone = client.delete("/me/avatar", headers=auth(ana)).json()
    assert gone["avatar_url"] is None


def test_urmarirea_si_lista_doar_cu_cei_urmariti(client):
    ana = register(client, "ana@exemplu.ro", "Ana")
    maria = register(client, "maria@exemplu.ro", "Maria")
    ioana = register(client, "ioana@exemplu.ro", "Ioana")
    new_post(client, maria, text="de la Maria")
    new_post(client, ioana, text="de la Ioana")

    r = client.put(f"/users/{maria['id']}/follow", headers=auth(ana))
    assert r.json()["followed_by_me"] is True and r.json()["follower_count"] == 1
    client.put(f"/users/{maria['id']}/follow", headers=auth(ana))  # de două ori: tot 1
    assert client.get(f"/users/{maria['id']}").json()["follower_count"] == 1
    assert client.get(f"/users/{ana['id']}").json()["following_count"] == 1

    feed = client.get("/posts", params={"following": True}, headers=auth(ana)).json()["posts"]
    assert [p["text"] for p in feed] == ["de la Maria"]
    assert client.get("/posts", params={"following": True}).status_code == 401

    names = [u["display_name"] for u in client.get(f"/users/{maria['id']}/followers").json()]
    assert names == ["Ana"]
    following = client.get(f"/users/{ana['id']}/following").json()
    assert [u["display_name"] for u in following] == ["Maria"]

    r = client.delete(f"/users/{maria['id']}/follow", headers=auth(ana))
    assert r.json()["followed_by_me"] is False and r.json()["follower_count"] == 0
    assert client.put(f"/users/{ana['id']}/follow", headers=auth(ana)).status_code == 422


def test_postarile_unui_profil(client):
    ana = register(client, "ana@exemplu.ro", "Ana")
    maria = register(client, "maria@exemplu.ro", "Maria")
    ids = [new_post(client, ana, text=f"p{i}")["id"] for i in range(3)]
    new_post(client, maria, text="alta")
    page = client.get(f"/users/{ana['id']}/posts", params={"limit": 2}).json()
    assert [p["id"] for p in page["posts"]] == ids[::-1][:2]
    assert page["next_before_id"] == ids[1]

    # Cine a blocat-o nu-i mai vede postările nici pe profil.
    client.put(f"/users/{ana['id']}/block", headers=auth(maria))
    blocked = client.get(f"/users/{ana['id']}", headers=auth(maria)).json()
    assert blocked["blocked_by_me"] is True
    assert client.get(f"/users/{ana['id']}/posts", headers=auth(maria)).json()["posts"] == []


def test_profil_inexistent(client):
    assert client.get("/users/9999").status_code == 404
