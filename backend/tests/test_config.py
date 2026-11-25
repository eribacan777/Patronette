import pytest
from pydantic import ValidationError

from app.config import Settings


@pytest.mark.parametrize(
    "given",
    [
        "postgresql://u:p@ep-x.eu-central-1.aws.neon.tech/neondb?sslmode=require",
        "postgres://u:p@ep-x.eu-central-1.aws.neon.tech/neondb?sslmode=require",
        "  postgresql+psycopg://u:p@ep-x.eu-central-1.aws.neon.tech/neondb?sslmode=require ",
        "psql 'postgresql://u:p@ep-x.eu-central-1.aws.neon.tech/neondb?sslmode=require'",
        '"postgresql://u:p@ep-x.eu-central-1.aws.neon.tech/neondb?sslmode=require"',
        "DATABASE_URL=postgresql://u:p@ep-x.eu-central-1.aws.neon.tech/neondb?sslmode=require",
    ],
)
def test_adresa_din_neon_se_poate_lipi_direct(given):
    s = Settings(database_url=given, jwt_secret="x" * 40)
    assert s.database_url == (
        "postgresql+psycopg://u:p@ep-x.eu-central-1.aws.neon.tech/neondb?sslmode=require"
    )


def test_adresa_gresita_da_un_mesaj_clar_fara_parola():
    with pytest.raises(ValidationError) as e:
        Settings(database_url="ep-x.neon.tech parola-secreta-123", jwt_secret="x" * 40)
    message = str(e.value)
    assert "postgresql://" in message
    assert "parola-secreta-123" not in message


def test_cheia_jwt_prea_scurta_e_respinsa():
    with pytest.raises(ValidationError):
        Settings(database_url="postgresql://u:p@h/db", jwt_secret="scurta")
