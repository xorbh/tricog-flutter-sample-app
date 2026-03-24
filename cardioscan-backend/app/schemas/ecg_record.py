from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class ECGRecordCreate(BaseModel):
    patient_name: str
    patient_age: int
    patient_gender: str
    recorded_at: datetime
    ecg_data: list[float]
    interpretation: str
    severity: str
    heart_rate: int
    findings: list[str]
    symptoms: list[str] = []
    symptom_note: str | None = None


class ECGRecordUpdate(BaseModel):
    doctor_notes: str | None = None


class ECGRecordListItem(BaseModel):
    id: UUID
    patient_name: str
    patient_age: int
    patient_gender: str
    recorded_at: datetime
    interpretation: str
    severity: str
    heart_rate: int
    findings: list[str]
    symptoms: list[str]
    symptom_note: str | None
    doctor_notes: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class ECGRecordDetail(ECGRecordListItem):
    ecg_data_key: str


class ECGRecordListResponse(BaseModel):
    items: list[ECGRecordListItem]
    next_cursor: str | None
    has_more: bool


class WaveformResponse(BaseModel):
    ecg_data: list[float]
