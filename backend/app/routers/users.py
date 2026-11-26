"""Profiluri ca pe Instagram: poză, descriere, postări, urmăritori."""

from typing import Annotated

from fastapi import APIRouter, File, HTTPException, Query, Response, UploadFile, status
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError

from ..config import get_settings
from ..images import prepare_avatar
from ..models import Block, Follow, Post, User
from ..schemas import AuthorOut, PostPage, ProfileOut, ProfileUpdateIn
from ..security import DB, CurrentUser, OptionalUser
from .posts import author_out, posts_out

router = APIRouter(tags=["profiluri"])


def _user_or_404(db: DB, user_id: int) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Profilul nu există.")
    return user


def profile_out(db: DB, user: User, me: User | None) -> ProfileOut:
    def count(q) -> int:
        return db.scalar(select(func.count()).select_from(q.subquery())) or 0

    is_me = me is not None and me.id == user.id
    return ProfileOut(
        id=user.id,
        display_name=user.display_name,
        bio=user.bio,
        avatar_url=author_out(user).avatar_url,
        post_count=count(
            select(Post.id).where(Post.author_id == user.id, Post.hidden.is_(False))
        ),
        follower_count=count(select(Follow.follower_id).where(Follow.followed_id == user.id)),
        following_count=count(select(Follow.followed_id).where(Follow.follower_id == user.id)),
        followed_by_me=me is not None
        and not is_me
        and db.get(Follow, (me.id, user.id)) is not None,
        blocked_by_me=me is not None
        and not is_me
        and db.get(Block, (me.id, user.id)) is not None,
        is_me=is_me,
    )


# ---------------------------------------------------------------- profilul meu


@router.patch("/me", response_model=ProfileOut)
def update_me(data: ProfileUpdateIn, db: DB, me: CurrentUser) -> ProfileOut:
    if data.display_name is not None:
        me.display_name = data.display_name
    if data.bio is not None:
        me.bio = data.bio.strip()
    db.commit()
    return profile_out(db, me, me)


@router.put("/me/avatar", response_model=ProfileOut)
async def set_avatar(
    db: DB, me: CurrentUser, image: Annotated[UploadFile, File()]
) -> ProfileOut:
    me.avatar = prepare_avatar(await image.read(), get_settings().max_image_mb)
    me.avatar_version += 1
    db.commit()
    return profile_out(db, me, me)


@router.delete("/me/avatar", response_model=ProfileOut)
def delete_avatar(db: DB, me: CurrentUser) -> ProfileOut:
    me.avatar = None
    me.avatar_version = 0
    db.commit()
    return profile_out(db, me, me)


# ---------------------------------------------------------------- profiluri


@router.get("/users/{user_id}", response_model=ProfileOut)
def get_profile(user_id: int, db: DB, me: OptionalUser) -> ProfileOut:
    return profile_out(db, _user_or_404(db, user_id), me)


@router.get("/users/{user_id}/avatar")
def get_avatar(user_id: int, db: DB) -> Response:
    user = _user_or_404(db, user_id)
    if user.avatar is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Profilul nu are poză.")
    # Adresa conține versiunea pozei, deci telefonul o poate păstra mult.
    return Response(
        user.avatar,
        media_type="image/jpeg",
        headers={"Cache-Control": "public, max-age=604800"},
    )


@router.get("/users/{user_id}/posts", response_model=PostPage)
def user_posts(
    user_id: int,
    db: DB,
    me: OptionalUser,
    before_id: Annotated[int | None, Query(gt=0)] = None,
    limit: Annotated[int, Query(ge=1, le=60)] = 30,
) -> PostPage:
    user = _user_or_404(db, user_id)
    if me is not None and db.get(Block, (me.id, user.id)) is not None:
        return PostPage(posts=[], next_before_id=None)
    q = select(Post).where(Post.author_id == user.id)
    # Autoarea își vede și postările ascunse după raportări.
    if me is None or (me.id != user.id and not me.is_admin):
        q = q.where(Post.hidden.is_(False))
    if before_id is not None:
        q = q.where(Post.id < before_id)
    posts = list(db.scalars(q.order_by(Post.id.desc()).limit(limit + 1)))
    more = len(posts) > limit
    posts = posts[:limit]
    return PostPage(posts=posts_out(db, posts, me), next_before_id=posts[-1].id if more else None)


# ---------------------------------------------------------------- urmărire


@router.put("/users/{user_id}/follow", response_model=ProfileOut)
def follow(user_id: int, db: DB, me: CurrentUser) -> ProfileOut:
    user = _user_or_404(db, user_id)
    if user.id == me.id:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Nu te poți urmări singură.")
    db.add(Follow(follower_id=me.id, followed_id=user.id))
    try:
        db.commit()
    except IntegrityError:  # o urmărea deja
        db.rollback()
    return profile_out(db, user, me)


@router.delete("/users/{user_id}/follow", response_model=ProfileOut)
def unfollow(user_id: int, db: DB, me: CurrentUser) -> ProfileOut:
    user = _user_or_404(db, user_id)
    db.execute(delete(Follow).where(Follow.follower_id == me.id, Follow.followed_id == user.id))
    db.commit()
    return profile_out(db, user, me)


def _people(db: DB, q) -> list[AuthorOut]:
    return [author_out(u) for u in db.scalars(q.order_by(User.display_name).limit(500))]


@router.get("/users/{user_id}/followers", response_model=list[AuthorOut])
def followers(user_id: int, db: DB) -> list[AuthorOut]:
    _user_or_404(db, user_id)
    return _people(
        db,
        select(User).join(Follow, Follow.follower_id == User.id).where(Follow.followed_id == user_id),
    )


@router.get("/users/{user_id}/following", response_model=list[AuthorOut])
def following(user_id: int, db: DB) -> list[AuthorOut]:
    _user_or_404(db, user_id)
    return _people(
        db,
        select(User).join(Follow, Follow.followed_id == User.id).where(Follow.follower_id == user_id),
    )
