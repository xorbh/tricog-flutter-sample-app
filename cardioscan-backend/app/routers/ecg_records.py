import uuid
from datetime import datetime

from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from ..dependencies import DB, CurrentUser, S3Client
from ..models.ecg_record import ECGRecord
from ..models.user_profile import UserProfile
from ..schemas.ecg_record import (
    ECGRecordCreate,
    ECGRecordDetail,
    ECGRecordListItem,
    ECGRecordListResponse,
    ECGRecordUpdate,
    WaveformResponse,
)
from ..schemas.report import ReportResponse
from ..services.report import generate_text_report
from ..services.storage import delete_ecg_data, download_ecg_data, upload_ecg_data

router = APIRouter(prefix="/api/v1")


@router.post("/ecg-records", response_model=ECGRecordDetail, status_code=201)
async def create_record(
    db: DB, user_id: CurrentUser, s3: S3Client, body: ECGRecordCreate
):
    record_id = uuid.uuid4()
    ecg_data_key = f"ecg/{user_id}/{record_id}.json"

    upload_ecg_data(s3, ecg_data_key, body.ecg_data)

    record = ECGRecord(
        id=record_id,
        clerk_user_id=user_id,
        patient_name=body.patient_name,
        patient_age=body.patient_age,
        patient_gender=body.patient_gender,
        recorded_at=body.recorded_at,
        ecg_data_key=ecg_data_key,
        interpretation=body.interpretation,
        severity=body.severity,
        heart_rate=body.heart_rate,
        findings=body.findings,
        symptoms=body.symptoms,
        symptom_note=body.symptom_note,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return record


@router.get("/ecg-records", response_model=ECGRecordListResponse)
async def list_records(
    db: DB,
    user_id: CurrentUser,
    limit: int = 20,
    cursor: str | None = None,
    severity: str | None = None,
):
    limit = min(limit, 100)
    query = select(ECGRecord).where(ECGRecord.clerk_user_id == user_id)

    if severity:
        query = query.where(ECGRecord.severity == severity)
    if cursor:
        cursor_dt = datetime.fromisoformat(cursor)
        query = query.where(ECGRecord.recorded_at < cursor_dt)

    query = query.order_by(ECGRecord.recorded_at.desc()).limit(limit + 1)
    result = await db.execute(query)
    records = list(result.scalars().all())

    has_more = len(records) > limit
    if has_more:
        records = records[:limit]

    next_cursor = records[-1].recorded_at.isoformat() if has_more and records else None

    return ECGRecordListResponse(
        items=[ECGRecordListItem.model_validate(r) for r in records],
        next_cursor=next_cursor,
        has_more=has_more,
    )


@router.get("/ecg-records/{record_id}", response_model=ECGRecordDetail)
async def get_record(db: DB, user_id: CurrentUser, record_id: uuid.UUID):
    record = await _get_user_record(db, user_id, record_id)
    return record


@router.get("/ecg-records/{record_id}/waveform", response_model=WaveformResponse)
async def get_waveform(
    db: DB, user_id: CurrentUser, s3: S3Client, record_id: uuid.UUID
):
    record = await _get_user_record(db, user_id, record_id)
    ecg_data = download_ecg_data(s3, record.ecg_data_key)
    return WaveformResponse(ecg_data=ecg_data)


@router.patch("/ecg-records/{record_id}", response_model=ECGRecordDetail)
async def update_record(
    db: DB, user_id: CurrentUser, record_id: uuid.UUID, body: ECGRecordUpdate
):
    record = await _get_user_record(db, user_id, record_id)
    if body.doctor_notes is not None:
        record.doctor_notes = body.doctor_notes
    await db.commit()
    await db.refresh(record)
    return record


@router.delete("/ecg-records/{record_id}", status_code=204)
async def delete_record(
    db: DB, user_id: CurrentUser, s3: S3Client, record_id: uuid.UUID
):
    record = await _get_user_record(db, user_id, record_id)
    delete_ecg_data(s3, record.ecg_data_key)
    await db.delete(record)
    await db.commit()


@router.get("/ecg-records/{record_id}/report", response_model=ReportResponse)
async def get_report(db: DB, user_id: CurrentUser, record_id: uuid.UUID):
    record = await _get_user_record(db, user_id, record_id)
    result = await db.execute(
        select(UserProfile).where(UserProfile.clerk_user_id == user_id)
    )
    profile = result.scalar_one_or_none()
    report_text = generate_text_report(record, profile)
    return ReportResponse(report_text=report_text)


async def _get_user_record(
    db: DB, user_id: str, record_id: uuid.UUID
) -> ECGRecord:
    result = await db.execute(
        select(ECGRecord).where(
            ECGRecord.id == record_id, ECGRecord.clerk_user_id == user_id
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=404, detail="Record not found")
    return record
