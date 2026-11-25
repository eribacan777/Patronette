"""Setările serverului, citite din variabile de mediu sau din fișierul .env.

Nicio parolă nu stă în cod: local vin din `backend/.env` (ignorat de git),
iar în cloud din variabilele de mediu ale serviciului.
"""

from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # postgresql+psycopg://utilizator:parola@gazda:5432/baza
    database_url: str

    # Cheia cu care se semnează tokenurile de login (JWT). Lungă și secretă.
    jwt_secret: str
    jwt_days: int = 30

    # ID-urile de client OAuth Google acceptate (Android, iOS, web),
    # separate prin virgulă. Gol = login cu Google dezactivat.
    google_client_ids: str = ""

    # Adresele de e-mail care primesc drept de administrare (moderare).
    admin_emails: str = ""

    # De pe ce site-uri poate fi apelat API-ul din browser (varianta web).
    cors_origins: str = "*"

    # O postare cu atâtea raportări diferite se ascunde până o verifică
    # o administratoare.
    reports_to_hide: int = 3

    max_image_mb: int = 8

    @field_validator("jwt_secret")
    @classmethod
    def _secret_is_long(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError("JWT_SECRET trebuie să aibă cel puțin 32 de caractere")
        return v

    @staticmethod
    def _split(value: str) -> list[str]:
        return [x.strip() for x in value.split(",") if x.strip()]

    @property
    def google_audiences(self) -> list[str]:
        return self._split(self.google_client_ids)

    @property
    def admin_list(self) -> set[str]:
        return {e.lower() for e in self._split(self.admin_emails)}

    @property
    def cors_list(self) -> list[str]:
        return self._split(self.cors_origins) or ["*"]


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
