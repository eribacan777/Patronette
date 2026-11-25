import io
import json

from PIL import Image

from conftest import auth, jpeg_bytes, new_post, register


def test_cititul_merge_fara_cont_postarea_cere_cont(client):
    assert client.get("/posts").status_code == 200
    r = client.post("/posts", data={"text": "Salut"})
    assert r.status_code == 401


def test_postare_cu_link_si_tipar(client):
    ana = register(client, "ana@exemplu.ro")
    pattern = {"garment_id": "fusta-dreapta", "options": {"lungime": 60, "largime": 4}}
    post = new_post(
        client,
        ana,
        text="Fusta mea preferată",
        link_url="https://exemplu.ro/idee",
        pattern=json.dumps(pattern),
    )
    assert post["link_url"] == "https://exemplu.ro/idee"
    assert post["pattern"] == {"garment_id": "fusta-dreapta", "options": {"lungime": 60.0, "largime": 4.0}}
    assert post["author"]["display_name"] == "Ana"
    assert post["can_delete"] is True


def test_link_si_tipar_invalide_sunt_respinse(client):
    ana = register(client, "ana@exemplu.ro")
    bad_link = client.post(
        "/posts", headers=auth(ana), data={"text": "x", "link_url": "javascript:alert(1)"}
    )
    assert bad_link.status_code == 422
    bad_pattern = client.post(
        "/posts", headers=auth(ana), data={"text": "x", "pattern": '{"garment_id": "../../etc"}'}
    )
    assert bad_pattern.status_code == 422
    empty = client.post("/posts", headers=auth(ana), data={"text": "   "})
    assert empty.status_code == 422


def test_poza_e_micsorata_si_fara_gps(client):
    ana = register(client, "ana@exemplu.ro")
    post = new_post(
        client, ana, files={"image": ("rochie.jpg", jpeg_bytes(exif_gps=True), "image/jpeg")}
    )
    assert post["image_url"] == f"/posts/{post['id']}/image"
    r = client.get(post["image_url"])
    assert r.headers["content-type"] == "image/jpeg"
    img = Image.open(io.BytesIO(r.content))
    assert max(img.size) == 1280
    assert 0x8825 not in img.getexif()  # fără GPSInfo


def test_fisier_care_nu_e_poza(client):
    ana = register(client, "ana@exemplu.ro")
    r = client.post(
        "/posts",
        headers=auth(ana),
        data={"text": "x"},
        files={"image": ("virus.jpg", b"nu sunt o poza", "image/jpeg")},
    )
    assert r.status_code == 422


def test_paginare_de_la_cele_mai_noi(client):
    ana = register(client, "ana@exemplu.ro")
    ids = [new_post(client, ana, text=f"postarea {i}")["id"] for i in range(5)]
    page1 = client.get("/posts", params={"limit": 2}).json()
    assert [p["id"] for p in page1["posts"]] == ids[::-1][:2]
    page2 = client.get("/posts", params={"limit": 2, "before_id": page1["next_before_id"]}).json()
    assert [p["id"] for p in page2["posts"]] == ids[::-1][2:4]
    page3 = client.get("/posts", params={"limit": 2, "before_id": page2["next_before_id"]}).json()
    assert [p["id"] for p in page3["posts"]] == ids[:1]
    assert page3["next_before_id"] is None


def test_aprecieri_si_comentarii(client):
    ana = register(client, "ana@exemplu.ro", "Ana")
    maria = register(client, "maria@exemplu.ro", "Maria")
    post = new_post(client, ana)

    assert client.put(f"/posts/{post['id']}/like", headers=auth(maria)).status_code == 204
    # A doua apreciere nu se numără de două ori.
    client.put(f"/posts/{post['id']}/like", headers=auth(maria))
    seen = client.get(f"/posts/{post['id']}", headers=auth(maria)).json()
    assert seen["like_count"] == 1 and seen["liked_by_me"] is True

    c = client.post(
        f"/posts/{post['id']}/comments", headers=auth(maria), json={"text": "Superb!"}
    )
    assert c.status_code == 201
    comments = client.get(f"/posts/{post['id']}/comments").json()
    assert [x["text"] for x in comments] == ["Superb!"]
    assert client.get(f"/posts/{post['id']}").json()["comment_count"] == 1

    client.delete(f"/posts/{post['id']}/like", headers=auth(maria))
    assert client.get(f"/posts/{post['id']}").json()["like_count"] == 0


def test_doar_autoarea_sterge(client):
    ana = register(client, "ana@exemplu.ro")
    maria = register(client, "maria@exemplu.ro")
    post = new_post(client, ana)
    assert client.delete(f"/posts/{post['id']}", headers=auth(maria)).status_code == 403
    comment = client.post(
        f"/posts/{post['id']}/comments", headers=auth(ana), json={"text": "notă"}
    ).json()
    assert client.delete(f"/comments/{comment['id']}", headers=auth(maria)).status_code == 403
    assert client.delete(f"/posts/{post['id']}", headers=auth(ana)).status_code == 204
    assert client.get(f"/posts/{post['id']}").status_code == 404
