"""Aduce baza de date la ultima versiune, la pornirea serverului."""

from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import inspect

from .db import engine

_ROOT = Path(__file__).resolve().parents[1]


def alembic_config() -> Config:
    cfg = Config(str(_ROOT / "alembic.ini"))
    cfg.set_main_option("script_location", str(_ROOT / "migrations"))
    return cfg


def run_migrations() -> None:
    cfg = alembic_config()
    with engine.begin() as conn:
        cfg.attributes["connection"] = conn
        tables = set(inspect(conn).get_table_names())
        # Baza din Neon a fost creată înainte de migrări, cu structura din
        # 0001: o marcăm ca atare, apoi aplicăm doar ce e nou.
        if "alembic_version" not in tables and "users" in tables:
            command.stamp(cfg, "0001")
        command.upgrade(cfg, "head")
