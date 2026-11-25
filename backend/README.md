# Serverul Patronette (comunitatea)

API REST în **Python + FastAPI**, cu baza de date principală **PostgreSQL**.
Aplicația Flutter îl folosește pentru comunitate: conturi, postări cu sfaturi,
link-uri, poze și tipare, aprecieri, comentarii și moderare.

```
Aplicația Flutter ──HTTPS + token JWT──▶ FastAPI ──SQL──▶ PostgreSQL
```

## Pornire locală

Ai nevoie de Python 3.12+ și de un PostgreSQL. Pe calculatorul nostru,
PostgreSQL e portabil, în `D:\Postgres`, iar scriptul îl pornește singur:

```powershell
powershell -ExecutionPolicy Bypass -File backend\porneste-server.ps1
```

Pe alt calculator: copiază `.env.example` ca `.env`, completează valorile,
apoi:

```bash
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt
.venv/Scripts/python -m uvicorn app.main:app --reload
```

Documentația interactivă a API-ului (Swagger): <http://localhost:8000/docs>.

## Teste

```bash
.venv/Scripts/python -m pytest
```

Testele rulează pe baza separată `patronette_test` (`TEST_DATABASE_URL`) și o
golesc la fiecare test. Verifică login-ul (inclusiv cu Google), postările,
pozele (micșorate, fără GPS), paginarea, aprecierile, comentariile,
raportarea, blocarea și panoul administratoarelor.

## Structură

| Fișier | Ce face |
|---|---|
| `app/main.py` | Pornește aplicația, leagă rutele, creează tabelele |
| `app/config.py` | Setările din `.env` / variabile de mediu |
| `app/db.py` | Conexiunea la PostgreSQL (SQLAlchemy) |
| `app/models.py` | Tabelele: users, posts, comments, likes, reports, blocks |
| `app/schemas.py` | Forma datelor din API (Pydantic) |
| `app/security.py` | Parole Argon2, tokenuri JWT, utilizatorul curent |
| `app/images.py` | Poze: verificare, micșorare la 1280 px, fără EXIF |
| `app/routers/` | Rutele: `auth`, `posts`, `moderation` |

## Baza de date

| Tabel | Conține |
|---|---|
| `users` | e-mail, parolă criptată sau cont Google, nume afișat, administratoare |
| `posts` | text, link, poză (JPEG micșorat), tipar (model + setări), ascunsă |
| `comments` | textul comentariului, autoarea, postarea |
| `likes` | cine a apreciat ce (cheie dublă: postare + utilizator) |
| `reports` | raportările; 3 raportări ascund automat postarea |
| `blocks` | cine pe cine a blocat |

Măsurile corpului **nu** ajung pe server: rămân pe telefon. Un tipar
distribuit conține doar modelul și setările, iar cine îl deschide îl vede pe
măsurile ei.

## Securitate

- Parolele se păstrează doar criptate, cu Argon2id.
- Login-ul dă un token JWT semnat, valabil 30 de zile.
- Tokenul Google se verifică la Google și trebuie emis pentru aplicația noastră.
- Pozele se redesenează, deci locația GPS din fotografie se pierde.
- Link-urile acceptate sunt doar `http://` și `https://`.
- Administratoarele vin din lista `ADMIN_EMAILS`, nu din aplicație.
