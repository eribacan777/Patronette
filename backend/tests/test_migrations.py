from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy import inspect, text

from app.db import Base, engine
from app.migrate import alembic_config, run_migrations
from conftest import drop_everything


def test_migrarile_dau_exact_tabelele_din_cod():
    with engine.connect() as conn:
        diff = compare_metadata(MigrationContext.configure(conn), Base.metadata)
    assert diff == [], diff


def _upgrade_to(rev: str) -> None:
    cfg = alembic_config()
    with engine.begin() as conn:
        cfg.attributes["connection"] = conn
        command.upgrade(cfg, rev)


def _old_data() -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users (email, display_name, is_admin, created_at) "
                "VALUES ('ana@exemplu.ro', 'Ana', false, now())"
            )
        )


def test_baza_veche_din_neon_fara_versiune_se_actualizeaza():
    # Așa arată baza din cloud: tabelele de la lansare, fără alembic_version.
    drop_everything()
    _upgrade_to("0001")
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE alembic_version"))
    _old_data()

    run_migrations()

    tables = set(inspect(engine).get_table_names())
    assert {"follows", "collections", "collection_items"} <= tables
    with engine.connect() as conn:
        bio, version = conn.execute(text("SELECT bio, avatar_version FROM users")).one()
    assert (bio, version) == ("", 0)  # contul vechi a rămas, cu valori implicite


def test_a_doua_pornire_nu_schimba_nimic():
    run_migrations()
    run_migrations()
    with engine.connect() as conn:
        assert conn.execute(text("SELECT version_num FROM alembic_version")).scalar() == "0002"
