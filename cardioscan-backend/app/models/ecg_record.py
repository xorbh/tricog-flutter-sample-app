import uuid
from datetime import datetime

from sqlalchemy import DateTime, Index, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from ..database import Base


class ECGRecord(Base):
    __tablename__ = "ecg_records"

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True, default=uuid.uuid4, server_default=func.gen_random_uuid()
    )
    clerk_user_id: Mapped[str] = mapped_column(String, nullable=False)
    patient_name: Mapped[str] = mapped_column(Text, nullable=False)
    patient_age: Mapped[int] = mapped_column(Integer, nullable=False)
    patient_gender: Mapped[str] = mapped_column(String, nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ecg_data_key: Mapped[str] = mapped_column(Text, nullable=False)
    interpretation: Mapped[str] = mapped_column(Text, nullable=False)
    severity: Mapped[str] = mapped_column(String, nullable=False)
    heart_rate: Mapped[int] = mapped_column(Integer, nullable=False)
    findings: Mapped[list] = mapped_column(JSONB, nullable=False, server_default="[]")
    doctor_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    symptoms: Mapped[list] = mapped_column(JSONB, nullable=False, server_default="[]")
    symptom_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    __table_args__ = (
        Index("ix_ecg_records_user_time", "clerk_user_id", recorded_at.desc()),
        Index("ix_ecg_records_user_severity", "clerk_user_id", "severity"),
        Index("ix_ecg_records_user_heart_rate", "clerk_user_id", "recorded_at", "heart_rate"),
    )
