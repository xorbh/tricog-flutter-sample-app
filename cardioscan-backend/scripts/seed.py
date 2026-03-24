"""Seed script: generates 20 sample ECG records with realistic data."""

import asyncio
import json
import math
import os
import random
import uuid
from datetime import date, datetime, timedelta

import boto3
from sqlalchemy import delete, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

# ---------------------------------------------------------------------------
# ECG Simulator (Python port of Flutter ECGSimulator)
# ---------------------------------------------------------------------------

SAMPLE_RATE = 250
DURATION_SECONDS = 10
TOTAL_SAMPLES = SAMPLE_RATE * DURATION_SECONDS


def _gaussian(t: float, center: float, sigma: float, amplitude: float) -> float:
    exponent = -((t - center) ** 2) / (2 * sigma**2)
    return amplitude * math.exp(exponent)


def _generate_pqrst(cycle_length: float, afib: bool = False, st_elevation: bool = False) -> list[float]:
    samples = round(cycle_length * SAMPLE_RATE)
    data = []
    for i in range(samples):
        t = i / SAMPLE_RATE
        value = 0.0

        if not afib:
            value += _gaussian(t, cycle_length * 0.12, 0.04, 0.15)
        else:
            value += 0.05 * math.sin(2 * math.pi * (random.random() * 8 + 4) * t)
            value += 0.03 * math.sin(2 * math.pi * (random.random() * 12 + 6) * t)

        value += _gaussian(t, cycle_length * 0.22, 0.008, -0.10)
        value += _gaussian(t, cycle_length * 0.25, 0.012, 1.2)
        value += _gaussian(t, cycle_length * 0.28, 0.008, -0.20)

        if st_elevation:
            value += _gaussian(t, cycle_length * 0.35, 0.06, 0.35)

        value += _gaussian(t, cycle_length * 0.45, 0.06, 0.30)
        value += (random.random() - 0.5) * 0.03

        data.append(round(value, 4))
    return data


def generate_normal(heart_rate: int = 72) -> list[float]:
    cycle_length = 60.0 / heart_rate
    data = []
    while len(data) < TOTAL_SAMPLES:
        data.extend(_generate_pqrst(cycle_length))
    return data[:TOTAL_SAMPLES]


def generate_tachycardia(heart_rate: int = 120) -> list[float]:
    return generate_normal(heart_rate)


def generate_bradycardia(heart_rate: int = 48) -> list[float]:
    return generate_normal(heart_rate)


def generate_afib() -> list[float]:
    data = []
    while len(data) < TOTAL_SAMPLES:
        cycle_length = 0.5 + random.random() * 0.6
        data.extend(_generate_pqrst(cycle_length, afib=True))
    return data[:TOTAL_SAMPLES]


def generate_st_elevation(heart_rate: int = 80) -> list[float]:
    cycle_length = 60.0 / heart_rate
    data = []
    while len(data) < TOTAL_SAMPLES:
        data.extend(_generate_pqrst(cycle_length, st_elevation=True))
    return data[:TOTAL_SAMPLES]


def generate_pvc(heart_rate: int = 75) -> list[float]:
    cycle_length = 60.0 / heart_rate
    data = []
    beat = 0
    while len(data) < TOTAL_SAMPLES:
        beat += 1
        if beat % 4 == 0:
            samples = round(cycle_length * SAMPLE_RATE)
            pvc = []
            for i in range(samples):
                t = i / SAMPLE_RATE
                v = 0.0
                v += _gaussian(t, cycle_length * 0.20, 0.025, -1.5)
                v += _gaussian(t, cycle_length * 0.28, 0.020, 0.8)
                v += _gaussian(t, cycle_length * 0.45, 0.06, -0.25)
                v += (random.random() - 0.5) * 0.03
                pvc.append(round(v, 4))
            data.extend(pvc)
        else:
            data.extend(_generate_pqrst(cycle_length))
    return data[:TOTAL_SAMPLES]


# ---------------------------------------------------------------------------
# Seed Data Definition
# ---------------------------------------------------------------------------

SEED_USER_ID = "seed_user_test"

SEED_PROFILE = {
    "name": "Alex Rivera",
    "date_of_birth": date(1982, 9, 14),
    "gender": "Male",
    "medical_conditions": ["Hypertension", "High Cholesterol"],
    "medications": "Lisinopril 10mg, Atorvastatin 20mg",
}

SEED_RECORDS = [
    {"day": -42, "type": "normal", "hr": 72, "symptoms": ["Routine Check"], "note": None, "doc": None},
    {"day": -40, "type": "normal", "hr": 68, "symptoms": ["Routine Check"], "note": None, "doc": None},
    {"day": -37, "type": "tachycardia", "hr": 118, "symptoms": ["Palpitations"], "note": None, "doc": None},
    {"day": -35, "type": "normal", "hr": 75, "symptoms": ["Routine Check"], "note": None, "doc": "Looking good, continue monitoring"},
    {"day": -33, "type": "bradycardia", "hr": 48, "symptoms": ["Fatigue", "Dizziness"], "note": None, "doc": None},
    {"day": -30, "type": "normal", "hr": 70, "symptoms": ["Routine Check"], "note": None, "doc": None},
    {"day": -28, "type": "afib", "hr": 92, "symptoms": ["Chest Pain", "Palpitations", "Shortness of Breath"], "note": None, "doc": "Referred to cardiology"},
    {"day": -26, "type": "normal", "hr": 78, "symptoms": ["Routine Check"], "note": None, "doc": None},
    {"day": -24, "type": "normal", "hr": 65, "symptoms": ["Routine Check"], "note": None, "doc": None},
    {"day": -21, "type": "st_elevation", "hr": 80, "symptoms": ["Chest Pain", "Shortness of Breath"], "note": None, "doc": "ER visit, troponins negative, follow up"},
    {"day": -19, "type": "normal", "hr": 71, "symptoms": ["Routine Check"], "note": None, "doc": None},
    {"day": -17, "type": "tachycardia", "hr": 130, "symptoms": ["Palpitations", "Fatigue"], "note": "Just finished exercising", "doc": None},
    {"day": -14, "type": "afib", "hr": 105, "symptoms": ["Palpitations", "Dizziness", "Shortness of Breath"], "note": None, "doc": "Started on anticoagulation therapy"},
    {"day": -12, "type": "normal", "hr": 74, "symptoms": ["Routine Check"], "note": None, "doc": None},
    {"day": -10, "type": "pvc", "hr": 75, "symptoms": ["Palpitations"], "note": "Felt skipped beats", "doc": None},
    {"day": -8, "type": "normal", "hr": 69, "symptoms": ["Routine Check"], "note": None, "doc": "Stable rhythm, continue meds"},
    {"day": -6, "type": "bradycardia", "hr": 52, "symptoms": ["Fatigue"], "note": "Woke up feeling off", "doc": None},
    {"day": -4, "type": "afib", "hr": 98, "symptoms": ["Chest Pain", "Palpitations"], "note": None, "doc": None},
    {"day": -2, "type": "normal", "hr": 73, "symptoms": ["Routine Check"], "note": None, "doc": None},
    {"day": -1, "type": "st_elevation", "hr": 82, "symptoms": ["Chest Pain", "Shortness of Breath", "Dizziness"], "note": None, "doc": "Urgent: referred for catheterization"},
]

INTERPRETATION_MAP = {
    "normal": ("Normal Sinus Rhythm", "normal", ["Regular R-R intervals", "Normal P wave morphology", "Normal PR interval (120-200ms)", "Narrow QRS complex (<120ms)", "Normal ST segment", "Normal T wave morphology"]),
    "tachycardia": ("Sinus Tachycardia", "warning", ["Elevated heart rate (>100 BPM)", "Regular R-R intervals", "Normal P wave before each QRS", "Narrow QRS complex", "Consider causes: fever, anxiety, dehydration, anemia"]),
    "bradycardia": ("Sinus Bradycardia", "warning", ["Low heart rate (<60 BPM)", "Regular R-R intervals", "Normal P wave morphology", "Normal PR interval", "May be normal in athletes or during sleep"]),
    "afib": ("Atrial Fibrillation", "critical", ["Irregularly irregular R-R intervals", "Absence of distinct P waves", "Fibrillatory baseline", "Variable ventricular rate", "URGENT: Assess stroke risk (CHA2DS2-VASc)", "Consider anticoagulation therapy"]),
    "st_elevation": ("ST Segment Elevation", "critical", ["ST segment elevation >1mm", "Possible acute myocardial injury", "URGENT: Rule out STEMI", "Immediate cardiology consultation recommended", "Consider emergent catheterization"]),
    "pvc": ("Premature Ventricular Contractions", "warning", ["Premature wide QRS complexes", "No preceding P wave for PVC beats", "Compensatory pause after PVCs", "Underlying rhythm appears sinus", "Monitor for frequency and symptoms"]),
}

GENERATORS = {
    "normal": generate_normal,
    "tachycardia": generate_tachycardia,
    "bradycardia": generate_bradycardia,
    "afib": generate_afib,
    "st_elevation": generate_st_elevation,
    "pvc": generate_pvc,
}

# Hours of day for natural distribution
HOURS = [7, 8, 9, 10, 11, 14, 15, 16, 17, 18, 19, 20]


async def seed():
    db_url = os.environ["DATABASE_URL"]
    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql+asyncpg://", 1)
    elif db_url.startswith("postgresql://"):
        db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
    db_url = db_url.replace("sslmode=require", "ssl=require").replace("&channel_binding=require", "")

    engine = create_async_engine(db_url)
    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    s3 = boto3.client(
        "s3",
        aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
        endpoint_url=os.environ.get("AWS_ENDPOINT_URL_S3", "https://fly.storage.tigris.dev"),
    )
    bucket = os.environ.get("BUCKET_NAME", "cardioscan-ecg-data")

    async with session_factory() as db:
        # Clean existing seed data
        await db.execute(text("DELETE FROM ecg_records WHERE clerk_user_id = :uid"), {"uid": SEED_USER_ID})
        await db.execute(text("DELETE FROM user_profiles WHERE clerk_user_id = :uid"), {"uid": SEED_USER_ID})
        await db.commit()

        # Create profile
        profile_id = uuid.uuid4()
        await db.execute(
            text("""
                INSERT INTO user_profiles (id, clerk_user_id, name, date_of_birth, gender, medical_conditions, medications, created_at, updated_at)
                VALUES (:id, :uid, :name, :dob, :gender, :conditions, :meds, now(), now())
            """),
            {
                "id": str(profile_id),
                "uid": SEED_USER_ID,
                "name": SEED_PROFILE["name"],
                "dob": SEED_PROFILE["date_of_birth"],
                "gender": SEED_PROFILE["gender"],
                "conditions": json.dumps(SEED_PROFILE["medical_conditions"]),
                "meds": SEED_PROFILE["medications"],
            },
        )

        now = datetime.now()
        for i, rec in enumerate(SEED_RECORDS):
            record_id = uuid.uuid4()
            ecg_type = rec["type"]
            hr = rec["hr"]

            # Generate waveform
            gen_fn = GENERATORS[ecg_type]
            if ecg_type in ("normal", "tachycardia", "bradycardia", "st_elevation", "pvc"):
                ecg_data = gen_fn(heart_rate=hr)
            else:
                ecg_data = gen_fn()

            # Upload to S3
            key = f"ecg/{SEED_USER_ID}/{record_id}.json"
            s3.put_object(
                Bucket=bucket,
                Key=key,
                Body=json.dumps(ecg_data).encode(),
                ContentType="application/json",
            )

            # Interpretation
            interp_name, severity, findings = INTERPRETATION_MAP[ecg_type]
            recorded_at = now + timedelta(days=rec["day"], hours=random.choice(HOURS), minutes=random.randint(0, 59))

            # Compute age at recording
            dob = SEED_PROFILE["date_of_birth"]
            age = recorded_at.year - dob.year
            if (recorded_at.month, recorded_at.day) < (dob.month, dob.day):
                age -= 1

            await db.execute(
                text("""
                    INSERT INTO ecg_records (
                        id, clerk_user_id, patient_name, patient_age, patient_gender,
                        recorded_at, ecg_data_key, interpretation, severity, heart_rate,
                        findings, doctor_notes, symptoms, symptom_note, created_at
                    ) VALUES (
                        :id, :uid, :name, :age, :gender,
                        :recorded_at, :key, :interp, :severity, :hr,
                        :findings, :doc, :symptoms, :note, now()
                    )
                """),
                {
                    "id": str(record_id),
                    "uid": SEED_USER_ID,
                    "name": SEED_PROFILE["name"],
                    "age": age,
                    "gender": SEED_PROFILE["gender"],
                    "recorded_at": recorded_at,
                    "key": key,
                    "interp": interp_name,
                    "severity": severity,
                    "hr": hr,
                    "findings": json.dumps(findings),
                    "doc": rec["doc"],
                    "symptoms": json.dumps(rec["symptoms"]),
                    "note": rec["note"],
                },
            )
            print(f"  [{i+1}/20] {interp_name} ({severity}) - {hr} BPM - {recorded_at.date()}")

        await db.commit()

    await engine.dispose()
    print("\nSeed complete: 1 profile + 20 ECG records created.")


if __name__ == "__main__":
    asyncio.run(seed())
