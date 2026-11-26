"""Pregătirea pozelor încărcate: verificare, micșorare, ștergerea datelor EXIF."""

import io

from fastapi import HTTPException, status
from PIL import Image, ImageOps, UnidentifiedImageError

MAX_SIDE = 1280  # px, latura cea mai lungă
JPEG_QUALITY = 82


def prepare_image(raw: bytes, max_mb: int) -> bytes:
    """Întoarce poza ca JPEG micșorat.

    Poza se redesenează de la zero, așa că datele EXIF (inclusiv locația GPS
    a telefonului) nu ajung pe server.
    """
    if len(raw) > max_mb * 1024 * 1024:
        raise HTTPException(
            status.HTTP_413_CONTENT_TOO_LARGE, f"Poza e mai mare de {max_mb} MB."
        )
    try:
        img = Image.open(io.BytesIO(raw))
        img.load()
    except (UnidentifiedImageError, OSError):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Fișierul nu este o poză.")

    img = ImageOps.exif_transpose(img)  # pozele de pe telefon rămân drepte
    if img.mode not in ("RGB", "L"):
        background = Image.new("RGB", img.size, "white")
        if img.mode in ("RGBA", "LA"):
            background.paste(img, mask=img.getchannel("A"))
        else:
            background.paste(img.convert("RGB"))
        img = background
    img.thumbnail((MAX_SIDE, MAX_SIDE))

    out = io.BytesIO()
    img.convert("RGB").save(out, "JPEG", quality=JPEG_QUALITY, optimize=True)
    return out.getvalue()


AVATAR_SIDE = 512  # px


def prepare_avatar(raw: bytes, max_mb: int) -> bytes:
    """Poza de profil: decupată pătrat din centru și micșorată la 512 px."""
    img = Image.open(io.BytesIO(prepare_image(raw, max_mb)))
    side = min(img.size)
    left, top = (img.width - side) // 2, (img.height - side) // 2
    img = img.crop((left, top, left + side, top + side))
    img.thumbnail((AVATAR_SIDE, AVATAR_SIDE))
    out = io.BytesIO()
    img.save(out, "JPEG", quality=JPEG_QUALITY, optimize=True)
    return out.getvalue()
