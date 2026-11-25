# Imaginea serverului pentru cloud (de exemplu Render). Baza de date PostgreSQL
# e separată și vine prin variabila DATABASE_URL.
FROM python:3.13-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# Serviciul de cloud dă portul prin variabila PORT.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
