"""Initial schema

Revision ID: 001
Revises:
Create Date: 2026-03-24

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_profiles",
        sa.Column("id", sa.UUID(), server_default=sa.text("gen_random_uuid()"), primary_key=True),
        sa.Column("clerk_user_id", sa.String(), nullable=False, unique=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("date_of_birth", sa.Date(), nullable=False),
        sa.Column("gender", sa.String(), nullable=False),
        sa.Column("medical_conditions", JSONB(), nullable=False, server_default="[]"),
        sa.Column("medications", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_user_profiles_clerk_user_id", "user_profiles", ["clerk_user_id"], unique=True)

    op.create_table(
        "ecg_records",
        sa.Column("id", sa.UUID(), server_default=sa.text("gen_random_uuid()"), primary_key=True),
        sa.Column("clerk_user_id", sa.String(), nullable=False),
        sa.Column("patient_name", sa.Text(), nullable=False),
        sa.Column("patient_age", sa.Integer(), nullable=False),
        sa.Column("patient_gender", sa.String(), nullable=False),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ecg_data_key", sa.Text(), nullable=False),
        sa.Column("interpretation", sa.Text(), nullable=False),
        sa.Column("severity", sa.String(), nullable=False),
        sa.Column("heart_rate", sa.Integer(), nullable=False),
        sa.Column("findings", JSONB(), nullable=False, server_default="[]"),
        sa.Column("doctor_notes", sa.Text(), nullable=True),
        sa.Column("symptoms", JSONB(), nullable=False, server_default="[]"),
        sa.Column("symptom_note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.CheckConstraint("severity IN ('normal', 'warning', 'critical')", name="ck_ecg_severity"),
        sa.CheckConstraint("heart_rate > 0", name="ck_ecg_heart_rate"),
        sa.CheckConstraint("patient_age >= 0", name="ck_ecg_patient_age"),
    )
    op.create_index("ix_ecg_records_user_time", "ecg_records", ["clerk_user_id", sa.text("recorded_at DESC")])
    op.create_index("ix_ecg_records_user_severity", "ecg_records", ["clerk_user_id", "severity"])
    op.create_index("ix_ecg_records_user_heart_rate", "ecg_records", ["clerk_user_id", "recorded_at", "heart_rate"])


def downgrade() -> None:
    op.drop_table("ecg_records")
    op.drop_table("user_profiles")
