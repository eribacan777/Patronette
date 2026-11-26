"""Profiluri (descriere, poză), urmărire și colecții de postări salvate.

Revision ID: 0002
Revises: 0001
Create Date: 2026-11-26
"""

import sqlalchemy as sa
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # server_default: conturile existente primesc o descriere goală.
    op.add_column("users", sa.Column("bio", sa.String(300), nullable=False, server_default=""))
    op.add_column("users", sa.Column("avatar", sa.LargeBinary(), nullable=True))
    op.add_column(
        "users", sa.Column("avatar_version", sa.Integer(), nullable=False, server_default="0")
    )

    op.create_table(
        "follows",
        sa.Column(
            "follower_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "followed_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_follows_followed_id", "follows", ["followed_id"])

    op.create_table(
        "collections",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "owner_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(60), nullable=False),
        sa.Column("is_public", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("owner_id", "name"),
    )
    op.create_index("ix_collections_owner_id", "collections", ["owner_id"])

    op.create_table(
        "collection_items",
        sa.Column(
            "collection_id", sa.Integer(),
            sa.ForeignKey("collections.id", ondelete="CASCADE"), primary_key=True,
        ),
        sa.Column(
            "post_id", sa.Integer(), sa.ForeignKey("posts.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("added_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_collection_items_post_id", "collection_items", ["post_id"])


def downgrade() -> None:
    op.drop_table("collection_items")
    op.drop_table("collections")
    op.drop_table("follows")
    op.drop_column("users", "avatar_version")
    op.drop_column("users", "avatar")
    op.drop_column("users", "bio")
