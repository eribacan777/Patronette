"""Comunitatea: postări, poze, tipare, aprecieri și comentarii."""

import json
import re
from typing import Annotated

from fastapi import APIRouter, File, Form, HTTPException, Query, Response, UploadFile, status
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError

from ..config import get_settings
from ..images import prepare_image
from ..models import Block, Comment, Like, Post, User
from ..schemas import (
    AuthorOut,
    CommentIn,
    CommentOut,
    PatternOut,
    PostOut,
    PostPage,
)
from ..security import DB, CurrentUser, OptionalUser

router = APIRouter(prefix="/posts", tags=["postări"])

_GARMENT_ID = re.compile(r"^[a-z][a-z0-9-]{0,39}$")


# ---------------------------------------------------------------- ajutoare


def _blocked_ids(db: DB, user: User | None) -> list[int]:
    if user is None:
        return []
    return list(db.scalars(select(Block.blocked_id).where(Block.blocker_id == user.id)))


def _visible_post(db: DB, post_id: int, user: User | None) -> Post:
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Postarea nu există.")
    is_owner_or_admin = user is not None and (user.id == post.author_id or user.is_admin)
    if post.hidden and not is_owner_or_admin:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Postarea nu există.")
    return post


def posts_out(db: DB, posts: list[Post], user: User | None) -> list[PostOut]:
    """Transformă postările în răspuns, cu numărul de aprecieri și comentarii.

    Numerele se citesc cu două interogări pentru toată pagina, nu câte una
    pe postare.
    """
    ids = [p.id for p in posts]
    if not ids:
        return []
    likes = dict(
        db.execute(
            select(Like.post_id, func.count()).where(Like.post_id.in_(ids)).group_by(Like.post_id)
        ).all()
    )
    comments = dict(
        db.execute(
            select(Comment.post_id, func.count())
            .where(Comment.post_id.in_(ids))
            .group_by(Comment.post_id)
        ).all()
    )
    mine: set[int] = set()
    if user is not None:
        mine = set(
            db.scalars(select(Like.post_id).where(Like.post_id.in_(ids), Like.user_id == user.id))
        )
    return [
        PostOut(
            id=p.id,
            author=AuthorOut(id=p.author.id, display_name=p.author.display_name),
            text=p.text,
            link_url=p.link_url,
            image_url=f"/posts/{p.id}/image" if p.has_image else None,
            pattern=(
                PatternOut(garment_id=p.pattern_garment_id, options=p.pattern_options or {})
                if p.pattern_garment_id
                else None
            ),
            like_count=likes.get(p.id, 0),
            comment_count=comments.get(p.id, 0),
            liked_by_me=p.id in mine,
            can_delete=user is not None and (user.id == p.author_id or user.is_admin),
            hidden=p.hidden,
            created_at=p.created_at,
        )
        for p in posts
    ]


def _clean_link(link: str | None) -> str | None:
    if link is None or not link.strip():
        return None
    link = link.strip()
    if len(link) > 500 or not re.match(r"^https?://[^\s/]+\.[^\s]+$", link):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Link-ul trebuie să înceapă cu http:// sau https://.",
        )
    return link


def _clean_pattern(raw: str | None) -> tuple[str | None, dict | None]:
    if raw is None or not raw.strip():
        return None, None
    try:
        data = json.loads(raw)
        garment_id = data["garment_id"]
        options = data.get("options", {})
        ok = (
            isinstance(garment_id, str)
            and _GARMENT_ID.match(garment_id)
            and isinstance(options, dict)
            and len(options) <= 20
            and all(
                isinstance(k, str) and len(k) <= 40 and isinstance(v, (int, float))
                for k, v in options.items()
            )
        )
    except (ValueError, KeyError, TypeError):
        ok = False
    if not ok:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Tiparul trimis nu e valid.")
    return garment_id, {k: float(v) for k, v in options.items()}


# ---------------------------------------------------------------- postări


@router.get("", response_model=PostPage)
def feed(
    db: DB,
    user: OptionalUser,
    before_id: Annotated[int | None, Query(gt=0)] = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> PostPage:
    """Cele mai noi postări, câte o pagină. Fără cele ascunse și fără cele ale
    persoanelor blocate."""
    q = select(Post).where(Post.hidden.is_(False))
    blocked = _blocked_ids(db, user)
    if blocked:
        q = q.where(Post.author_id.not_in(blocked))
    if before_id is not None:
        q = q.where(Post.id < before_id)
    posts = list(db.scalars(q.order_by(Post.id.desc()).limit(limit + 1)))
    more = len(posts) > limit
    posts = posts[:limit]
    return PostPage(
        posts=posts_out(db, posts, user),
        next_before_id=posts[-1].id if more else None,
    )


@router.post("", response_model=PostOut, status_code=status.HTTP_201_CREATED)
async def create_post(
    db: DB,
    user: CurrentUser,
    text: Annotated[str, Form(max_length=2000)],
    link_url: Annotated[str | None, Form()] = None,
    pattern: Annotated[str | None, Form(description="JSON: {garment_id, options}")] = None,
    image: Annotated[UploadFile | None, File()] = None,
) -> PostOut:
    text = text.strip()
    if not text:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Scrie ceva în postare.")
    garment_id, options = _clean_pattern(pattern)
    post = Post(
        author_id=user.id,
        text=text,
        link_url=_clean_link(link_url),
        pattern_garment_id=garment_id,
        pattern_options=options,
    )
    if image is not None and image.filename:
        post.image = prepare_image(await image.read(), get_settings().max_image_mb)
        post.has_image = True
    db.add(post)
    db.commit()
    db.refresh(post)
    return posts_out(db, [post], user)[0]


@router.get("/{post_id}", response_model=PostOut)
def get_post(post_id: int, db: DB, user: OptionalUser) -> PostOut:
    return posts_out(db, [_visible_post(db, post_id, user)], user)[0]


@router.get("/{post_id}/image")
def get_image(post_id: int, db: DB, user: OptionalUser) -> Response:
    post = _visible_post(db, post_id, user)
    if not post.has_image or post.image is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Postarea nu are poză.")
    # Poza unei postări nu se schimbă niciodată: telefonul o poate păstra.
    return Response(
        post.image,
        media_type="image/jpeg",
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_post(post_id: int, db: DB, user: CurrentUser) -> None:
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Postarea nu există.")
    if post.author_id != user.id and not user.is_admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Poți șterge doar postările tale.")
    db.delete(post)
    db.commit()


# ---------------------------------------------------------------- aprecieri


@router.put("/{post_id}/like", status_code=status.HTTP_204_NO_CONTENT)
def like(post_id: int, db: DB, user: CurrentUser) -> None:
    _visible_post(db, post_id, user)
    db.add(Like(post_id=post_id, user_id=user.id))
    try:
        db.commit()
    except IntegrityError:  # deja apreciată: nu e o eroare
        db.rollback()


@router.delete("/{post_id}/like", status_code=status.HTTP_204_NO_CONTENT)
def unlike(post_id: int, db: DB, user: CurrentUser) -> None:
    db.execute(delete(Like).where(Like.post_id == post_id, Like.user_id == user.id))
    db.commit()


# ---------------------------------------------------------------- comentarii


def _comment_out(c: Comment, user: User | None) -> CommentOut:
    return CommentOut(
        id=c.id,
        author=AuthorOut(id=c.author.id, display_name=c.author.display_name),
        text=c.text,
        created_at=c.created_at,
        can_delete=user is not None and (user.id == c.author_id or user.is_admin),
    )


@router.get("/{post_id}/comments", response_model=list[CommentOut])
def list_comments(post_id: int, db: DB, user: OptionalUser) -> list[CommentOut]:
    _visible_post(db, post_id, user)
    q = select(Comment).where(Comment.post_id == post_id)
    blocked = _blocked_ids(db, user)
    if blocked:
        q = q.where(Comment.author_id.not_in(blocked))
    return [_comment_out(c, user) for c in db.scalars(q.order_by(Comment.id).limit(500))]


@router.post(
    "/{post_id}/comments", response_model=CommentOut, status_code=status.HTTP_201_CREATED
)
def add_comment(post_id: int, data: CommentIn, db: DB, user: CurrentUser) -> CommentOut:
    _visible_post(db, post_id, user)
    text = data.text.strip()
    if not text:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Comentariul e gol.")
    comment = Comment(post_id=post_id, author_id=user.id, text=text)
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return _comment_out(comment, user)


comments_router = APIRouter(prefix="/comments", tags=["postări"])


@comments_router.delete("/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_comment(comment_id: int, db: DB, user: CurrentUser) -> None:
    comment = db.get(Comment, comment_id)
    if comment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Comentariul nu există.")
    if comment.author_id != user.id and not user.is_admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Poți șterge doar comentariile tale.")
    db.delete(comment)
    db.commit()
