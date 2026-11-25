"""Moderare: raportare, blocare și panoul administratoarelor.

Google Play cere ca aplicațiile în care postează utilizatorii să permită
raportarea conținutului și blocarea persoanelor.
"""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import delete, func, select, update
from sqlalchemy.exc import IntegrityError

from ..config import get_settings
from ..models import Block, Post, Report, User
from ..schemas import ReportedPostOut, ReportIn
from ..security import DB, AdminUser, CurrentUser
from .posts import posts_out

router = APIRouter(tags=["moderare"])


@router.post("/posts/{post_id}/report", status_code=status.HTTP_204_NO_CONTENT)
def report_post(post_id: int, data: ReportIn, db: DB, user: CurrentUser) -> None:
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Postarea nu există.")
    db.add(Report(post_id=post_id, reporter_id=user.id, reason=data.reason.strip()))
    try:
        db.commit()
    except IntegrityError:  # a mai raportat-o o dată
        db.rollback()
        return
    open_reports = db.scalar(
        select(func.count()).where(Report.post_id == post_id, Report.resolved.is_(False))
    )
    # Prea multe raportări: postarea dispare până o verifică o administratoare.
    if open_reports >= get_settings().reports_to_hide:
        post.hidden = True
        db.commit()


@router.put("/users/{user_id}/block", status_code=status.HTTP_204_NO_CONTENT)
def block_user(user_id: int, db: DB, user: CurrentUser) -> None:
    if user_id == user.id:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Nu te poți bloca singură.")
    if db.get(User, user_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Utilizatorul nu există.")
    db.add(Block(blocker_id=user.id, blocked_id=user_id))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()


@router.delete("/users/{user_id}/block", status_code=status.HTTP_204_NO_CONTENT)
def unblock_user(user_id: int, db: DB, user: CurrentUser) -> None:
    db.execute(delete(Block).where(Block.blocker_id == user.id, Block.blocked_id == user_id))
    db.commit()


# ---------------------------------------------------------------- administrare


@router.get("/admin/reports", response_model=list[ReportedPostOut])
def reported_posts(db: DB, admin: AdminUser) -> list[ReportedPostOut]:
    """Postările cu raportări nerezolvate, cele mai raportate primele."""
    rows = db.execute(
        select(Report.post_id, func.count(), func.array_agg(Report.reason))
        .where(Report.resolved.is_(False))
        .group_by(Report.post_id)
        .order_by(func.count().desc())
        .limit(100)
    ).all()
    posts = {p.id: p for p in db.scalars(select(Post).where(Post.id.in_([r[0] for r in rows])))}
    outs = {o.id: o for o in posts_out(db, list(posts.values()), admin)}
    return [
        ReportedPostOut(post=outs[pid], report_count=count, reasons=list(reasons))
        for pid, count, reasons in rows
        if pid in outs
    ]


def _resolve(db: DB, post_id: int, hidden: bool) -> None:
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Postarea nu există.")
    post.hidden = hidden
    db.execute(update(Report).where(Report.post_id == post_id).values(resolved=True))
    db.commit()


@router.post("/admin/posts/{post_id}/hide", status_code=status.HTTP_204_NO_CONTENT)
def hide_post(post_id: int, db: DB, admin: AdminUser) -> None:
    _resolve(db, post_id, hidden=True)


@router.post("/admin/posts/{post_id}/restore", status_code=status.HTTP_204_NO_CONTENT)
def restore_post(post_id: int, db: DB, admin: AdminUser) -> None:
    """Raportările erau nejustificate: postarea revine în listă."""
    _resolve(db, post_id, hidden=False)
