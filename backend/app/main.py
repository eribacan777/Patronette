"""Punctul de pornire al serverului.

Local:  uvicorn app.main:app --reload
Documentația interactivă a API-ului: http://localhost:8000/docs
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from .config import get_settings
from .db import Base, SessionLocal, engine
from .routers import auth, moderation, posts


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Creează tabelele care lipsesc. (La scară mare: migrări cu Alembic.)
    Base.metadata.create_all(engine)
    yield


app = FastAPI(
    title="Patronette API",
    description="Comunitatea Patronette: postări cu sfaturi, link-uri, poze și tipare.",
    version="1.0.0",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_list,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router)
app.include_router(posts.router)
app.include_router(posts.comments_router)
app.include_router(moderation.router)


@app.get("/health", tags=["sistem"])
def health() -> dict[str, str]:
    """Verifică și conexiunea la baza de date (folosit de serviciul din cloud)."""
    with SessionLocal() as db:
        db.execute(text("SELECT 1"))
    return {"status": "ok"}
