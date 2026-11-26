"""Forma datelor care intră și ies din API (validate de Pydantic)."""

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=2, max_length=40)

    @field_validator("display_name")
    @classmethod
    def _strip(cls, v: str) -> str:
        v = " ".join(v.split())
        if len(v) < 2:
            raise ValueError("Numele trebuie să aibă cel puțin 2 caractere")
        return v


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class GoogleIn(BaseModel):
    id_token: str


class UserOut(BaseModel):
    id: int
    display_name: str
    is_admin: bool = False


class TokenOut(BaseModel):
    token: str
    user: UserOut


class AuthorOut(BaseModel):
    id: int
    display_name: str
    avatar_url: str | None = None


class PatternOut(BaseModel):
    garment_id: str
    options: dict[str, float]


class PostOut(BaseModel):
    id: int
    author: AuthorOut
    text: str
    link_url: str | None
    image_url: str | None
    pattern: PatternOut | None
    like_count: int
    comment_count: int
    liked_by_me: bool
    # Salvată în cel puțin una dintre colecțiile mele.
    saved_by_me: bool = False
    can_delete: bool
    hidden: bool
    created_at: datetime


class PostPage(BaseModel):
    posts: list[PostOut]
    # Trimis înapoi ca `before_id` pentru pagina următoare; null = gata.
    next_before_id: int | None


class CommentIn(BaseModel):
    text: str = Field(min_length=1, max_length=1000)


class CommentOut(BaseModel):
    id: int
    author: AuthorOut
    text: str
    created_at: datetime
    can_delete: bool


class ReportIn(BaseModel):
    reason: str = Field(min_length=3, max_length=300)


class ReportedPostOut(BaseModel):
    post: PostOut
    report_count: int
    reasons: list[str]


# ---------------------------------------------------------------- profiluri


def _clean_name(v: str) -> str:
    v = " ".join(v.split())
    if len(v) < 2:
        raise ValueError("Numele trebuie să aibă cel puțin 2 caractere")
    return v


class ProfileOut(BaseModel):
    id: int
    display_name: str
    bio: str
    avatar_url: str | None
    post_count: int
    follower_count: int
    following_count: int
    followed_by_me: bool
    blocked_by_me: bool
    is_me: bool


class ProfileUpdateIn(BaseModel):
    display_name: str | None = Field(default=None, min_length=2, max_length=40)
    bio: str | None = Field(default=None, max_length=300)

    @field_validator("display_name")
    @classmethod
    def _name(cls, v: str | None) -> str | None:
        return None if v is None else _clean_name(v)


# ---------------------------------------------------------------- colecții


def _clean_collection_name(v: str) -> str:
    v = " ".join(v.split())
    if not v:
        raise ValueError("Dă un nume colecției")
    return v


class CollectionIn(BaseModel):
    name: str = Field(min_length=1, max_length=60)
    is_public: bool = False

    @field_validator("name")
    @classmethod
    def _strip(cls, v: str) -> str:
        return _clean_collection_name(v)


class CollectionUpdateIn(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=60)
    is_public: bool | None = None

    @field_validator("name")
    @classmethod
    def _strip(cls, v: str | None) -> str | None:
        return None if v is None else _clean_collection_name(v)


class CollectionOut(BaseModel):
    id: int
    owner: AuthorOut
    name: str
    is_public: bool
    item_count: int
    cover_url: str | None
    # Doar când lista e cerută pentru o anumită postare (?post_id=).
    contains_post: bool | None = None


class CollectionDetailOut(BaseModel):
    collection: CollectionOut
    posts: list[PostOut]
