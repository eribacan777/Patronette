"""Colecții de postări salvate, ca boardurile de pe Pinterest.

O colecție publică apare pe profil și o poate deschide oricine; una privată
o vede doar proprietara (pentru ceilalți, nici nu există).
"""

from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError

from ..models import Collection, CollectionItem, Post, User
from ..schemas import CollectionDetailOut, CollectionIn, CollectionOut, CollectionUpdateIn
from ..security import DB, CurrentUser, OptionalUser
from .posts import _visible_post, author_out, posts_out

router = APIRouter(tags=["colecții"])

MAX_COLLECTIONS = 100


def _collections_out(
    db: DB, collections: list[Collection], post_id: int | None = None
) -> list[CollectionOut]:
    ids = [c.id for c in collections]
    if not ids:
        return []
    counts = dict(
        db.execute(
            select(CollectionItem.collection_id, func.count())
            .join(Post, Post.id == CollectionItem.post_id)
            .where(CollectionItem.collection_id.in_(ids), Post.hidden.is_(False))
            .group_by(CollectionItem.collection_id)
        ).all()
    )
    # Coperta: poza celei mai recent salvate postări cu poză.
    covers: dict[int, int] = {}
    for cid, pid in db.execute(
        select(CollectionItem.collection_id, CollectionItem.post_id)
        .join(Post, Post.id == CollectionItem.post_id)
        .where(
            CollectionItem.collection_id.in_(ids),
            Post.has_image.is_(True),
            Post.hidden.is_(False),
        )
        .order_by(CollectionItem.added_at.desc())
    ).all():
        covers.setdefault(cid, pid)
    containing: set[int] = set()
    if post_id is not None:
        containing = set(
            db.scalars(
                select(CollectionItem.collection_id).where(
                    CollectionItem.collection_id.in_(ids), CollectionItem.post_id == post_id
                )
            )
        )
    owners = {u.id: u for u in db.scalars(select(User).where(User.id.in_({c.owner_id for c in collections})))}
    return [
        CollectionOut(
            id=c.id,
            owner=author_out(owners[c.owner_id]),
            name=c.name,
            is_public=c.is_public,
            item_count=counts.get(c.id, 0),
            cover_url=f"/posts/{covers[c.id]}/image" if c.id in covers else None,
            contains_post=(c.id in containing) if post_id is not None else None,
        )
        for c in collections
    ]


def _own(db: DB, collection_id: int, me: User) -> Collection:
    c = db.get(Collection, collection_id)
    if c is None or c.owner_id != me.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Colecția nu există.")
    return c


def _commit_name(db: DB) -> None:
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Ai deja o colecție cu acest nume.")


# ---------------------------------------------------------------- colecțiile mele


@router.get("/me/collections", response_model=list[CollectionOut])
def my_collections(
    db: DB,
    me: CurrentUser,
    post_id: Annotated[int | None, Query(description="Arată și dacă postarea e în fiecare")] = None,
) -> list[CollectionOut]:
    rows = list(
        db.scalars(
            select(Collection).where(Collection.owner_id == me.id).order_by(Collection.name)
        )
    )
    return _collections_out(db, rows, post_id)


@router.post("/me/collections", response_model=CollectionOut, status_code=status.HTTP_201_CREATED)
def create_collection(data: CollectionIn, db: DB, me: CurrentUser) -> CollectionOut:
    total = db.scalar(select(func.count()).where(Collection.owner_id == me.id)) or 0
    if total >= MAX_COLLECTIONS:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, f"Poți avea cel mult {MAX_COLLECTIONS} colecții."
        )
    c = Collection(owner_id=me.id, name=data.name, is_public=data.is_public)
    db.add(c)
    _commit_name(db)
    db.refresh(c)
    return _collections_out(db, [c])[0]


@router.patch("/collections/{collection_id}", response_model=CollectionOut)
def update_collection(
    collection_id: int, data: CollectionUpdateIn, db: DB, me: CurrentUser
) -> CollectionOut:
    c = _own(db, collection_id, me)
    if data.name is not None:
        c.name = data.name
    if data.is_public is not None:
        c.is_public = data.is_public
    _commit_name(db)
    return _collections_out(db, [c])[0]


@router.delete("/collections/{collection_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_collection(collection_id: int, db: DB, me: CurrentUser) -> None:
    db.delete(_own(db, collection_id, me))
    db.commit()


@router.put(
    "/collections/{collection_id}/posts/{post_id}", status_code=status.HTTP_204_NO_CONTENT
)
def save_post(collection_id: int, post_id: int, db: DB, me: CurrentUser) -> None:
    _own(db, collection_id, me)
    _visible_post(db, post_id, me)
    db.add(CollectionItem(collection_id=collection_id, post_id=post_id))
    try:
        db.commit()
    except IntegrityError:  # era deja salvată acolo
        db.rollback()


@router.delete(
    "/collections/{collection_id}/posts/{post_id}", status_code=status.HTTP_204_NO_CONTENT
)
def unsave_post(collection_id: int, post_id: int, db: DB, me: CurrentUser) -> None:
    _own(db, collection_id, me)
    db.execute(
        delete(CollectionItem).where(
            CollectionItem.collection_id == collection_id, CollectionItem.post_id == post_id
        )
    )
    db.commit()


# ---------------------------------------------------------------- ce văd ceilalți


@router.get("/users/{user_id}/collections", response_model=list[CollectionOut])
def user_collections(user_id: int, db: DB, me: OptionalUser) -> list[CollectionOut]:
    if db.get(User, user_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Profilul nu există.")
    q = select(Collection).where(Collection.owner_id == user_id)
    if me is None or me.id != user_id:
        q = q.where(Collection.is_public.is_(True))
    return _collections_out(db, list(db.scalars(q.order_by(Collection.name))))


@router.get("/collections/{collection_id}", response_model=CollectionDetailOut)
def get_collection(collection_id: int, db: DB, me: OptionalUser) -> CollectionDetailOut:
    c = db.get(Collection, collection_id)
    if c is None or (not c.is_public and (me is None or me.id != c.owner_id)):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Colecția nu există.")
    posts = list(
        db.scalars(
            select(Post)
            .join(CollectionItem, CollectionItem.post_id == Post.id)
            .where(CollectionItem.collection_id == c.id, Post.hidden.is_(False))
            .order_by(CollectionItem.added_at.desc())
            .limit(300)
        )
    )
    return CollectionDetailOut(
        collection=_collections_out(db, [c])[0], posts=posts_out(db, posts, me)
    )
