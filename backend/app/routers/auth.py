"""Conturi: înregistrare și login cu e-mail și parolă sau cu Google."""

from fastapi import APIRouter, HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy import select

from ..config import get_settings
from ..models import User
from ..schemas import GoogleIn, LoginIn, RegisterIn, TokenOut, UserOut
from ..security import DB, CurrentUser, create_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["conturi"])


def _token_out(user: User) -> TokenOut:
    return TokenOut(
        token=create_token(user),
        user=UserOut(id=user.id, display_name=user.display_name, is_admin=user.is_admin),
    )


def _sync_admin(user: User) -> None:
    """Dreptul de administrare vine din lista ADMIN_EMAILS din setări."""
    user.is_admin = user.email in get_settings().admin_list


@router.post("/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def register(data: RegisterIn, db: DB) -> TokenOut:
    email = data.email.lower()
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(status.HTTP_409_CONFLICT, "Există deja un cont cu acest e-mail.")
    user = User(
        email=email,
        password_hash=hash_password(data.password),
        display_name=data.display_name,
    )
    _sync_admin(user)
    db.add(user)
    db.commit()
    return _token_out(user)


@router.post("/login", response_model=TokenOut)
def login(data: LoginIn, db: DB) -> TokenOut:
    user = db.scalar(select(User).where(User.email == data.email.lower()))
    # Același mesaj pentru e-mail greșit și parolă greșită: nu dezvăluim
    # ce adrese au cont.
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "E-mail sau parolă greșită.")
    _sync_admin(user)
    db.commit()
    return _token_out(user)


def verify_google_token(token: str) -> dict:
    """Verifică semnătura Google și pentru ce aplicație a fost emis tokenul.

    Separată ca să poată fi înlocuită în teste.
    """
    audiences = get_settings().google_audiences
    if not audiences:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Login-ul cu Google nu e configurat.")
    try:
        info = google_id_token.verify_oauth2_token(token, google_requests.Request())
    except ValueError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Tokenul Google nu este valid.")
    if info.get("aud") not in audiences:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Tokenul Google e pentru altă aplicație.")
    return info


@router.post("/google", response_model=TokenOut)
def google(data: GoogleIn, db: DB) -> TokenOut:
    info = verify_google_token(data.id_token)
    if not info.get("email_verified") or not info.get("email"):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Adresa Google nu este verificată.")
    sub, email = info["sub"], info["email"].lower()

    user = db.scalar(select(User).where(User.google_sub == sub))
    if user is None:
        # Același e-mail, deja înregistrat cu parolă: legăm contul de Google.
        # E sigur pentru că Google a confirmat că adresa e a acestei persoane.
        user = db.scalar(select(User).where(User.email == email))
        if user is None:
            name = (info.get("name") or email.split("@")[0]).strip()[:40]
            user = User(email=email, display_name=name if len(name) >= 2 else "Croitoreasă")
            db.add(user)
        user.google_sub = sub
    _sync_admin(user)
    db.commit()
    return _token_out(user)


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser) -> UserOut:
    return UserOut(id=user.id, display_name=user.display_name, is_admin=user.is_admin)
