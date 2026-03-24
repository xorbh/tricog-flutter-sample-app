# CardioScan Backend Server — Specification

## Overview

- **Framework**: FastAPI (Python 3.12)
- **Database**: PostgreSQL on Neon
- **Object Storage**: Tigris (S3-compatible) on Fly.io
- **Auth**: Clerk JWT verification
- **Deployment**: Fly.io
- **Infrastructure**: Terraform

---

## 1. Database Schema

### Table: `user_profiles`

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Internal PK |
| `clerk_user_id` | `TEXT` | `NOT NULL UNIQUE` | From Clerk JWT `sub` claim |
| `name` | `TEXT` | `NOT NULL` | Patient full name |
| `date_of_birth` | `DATE` | `NOT NULL` | Age computed dynamically |
| `gender` | `TEXT` | `NOT NULL CHECK (gender IN ('Male','Female','Other'))` | |
| `medical_conditions` | `JSONB` | `NOT NULL DEFAULT '[]'::jsonb` | Array of strings |
| `medications` | `TEXT` | `NULL` | Free-text |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | |

**Indexes:**
- `UNIQUE INDEX ix_user_profiles_clerk_user_id ON user_profiles (clerk_user_id)`

---

### Table: `ecg_records`

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Internal PK |
| `clerk_user_id` | `TEXT` | `NOT NULL` | Tenant isolation key |
| `patient_name` | `TEXT` | `NOT NULL` | Snapshot at recording time |
| `patient_age` | `INTEGER` | `NOT NULL CHECK (patient_age >= 0)` | Snapshot at recording time |
| `patient_gender` | `TEXT` | `NOT NULL` | Snapshot at recording time |
| `recorded_at` | `TIMESTAMPTZ` | `NOT NULL` | Client-provided capture timestamp |
| `ecg_data_key` | `TEXT` | `NOT NULL` | Tigris object key: `ecg/{clerk_user_id}/{uuid}.json` |
| `interpretation` | `TEXT` | `NOT NULL` | e.g. "Normal Sinus Rhythm" |
| `severity` | `TEXT` | `NOT NULL CHECK (severity IN ('normal','warning','critical'))` | |
| `heart_rate` | `INTEGER` | `NOT NULL CHECK (heart_rate > 0)` | BPM |
| `findings` | `JSONB` | `NOT NULL DEFAULT '[]'::jsonb` | Array of finding strings |
| `doctor_notes` | `TEXT` | `NULL` | Editable after creation |
| `symptoms` | `JSONB` | `NOT NULL DEFAULT '[]'::jsonb` | Array of symptom strings |
| `symptom_note` | `TEXT` | `NULL` | Free-text symptom note |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Server-side insert timestamp |

**Indexes:**
- `INDEX ix_ecg_records_user_time ON ecg_records (clerk_user_id, recorded_at DESC)` — primary list query
- `INDEX ix_ecg_records_user_severity ON ecg_records (clerk_user_id, severity)` — stats/filtering
- `INDEX ix_ecg_records_user_heart_rate ON ecg_records (clerk_user_id, recorded_at, heart_rate)` — trends

---

### Tigris/S3 Object Layout

- **Bucket**: `cardioscan-ecg-data`
- **Key pattern**: `ecg/{clerk_user_id}/{ecg_record_uuid}.json`
- **Body**: JSON array of 2500 floats (250 Hz × 10s)
- **Size**: ~30-50 KB per recording

---

## 2. API Endpoints

All endpoints except `/health` require `Authorization: Bearer <clerk_jwt>`. The JWT `sub` claim is used as `clerk_user_id` for tenant isolation.

**Base path**: `/api/v1`

### 2.1 Health

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/health` | None | `{"status": "ok"}` — Fly.io health check |

### 2.2 User Profile

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/profile` | Get current user's profile (404 if none) |
| `PUT` | `/api/v1/profile` | Create or replace profile (upsert) |

**PUT request body:**
```json
{
  "name": "Sarah Johnson",
  "date_of_birth": "1980-01-15",
  "gender": "Female",
  "medical_conditions": ["Hypertension", "High Cholesterol"],
  "medications": "Lisinopril 10mg"
}
```

**GET response:**
```json
{
  "id": "uuid",
  "name": "Sarah Johnson",
  "date_of_birth": "1980-01-15",
  "age": 46,
  "gender": "Female",
  "medical_conditions": ["Hypertension", "High Cholesterol"],
  "medications": "Lisinopril 10mg",
  "created_at": "2026-03-01T10:00:00Z",
  "updated_at": "2026-03-20T14:30:00Z"
}
```

### 2.3 ECG Interpretation (Stateless)

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/v1/interpret` | Run interpretation on raw ECG data. Does NOT save. |

**Request:**
```json
{
  "ecg_data": [0.01, 0.03, ...],
  "ecg_type": "normal"
}
```

`ecg_type`: `"normal"` | `"tachycardia"` | `"bradycardia"` | `"afib"` | `"st_elevation"` | `"pvc"`

**Response:**
```json
{
  "diagnosis": "Normal Sinus Rhythm",
  "severity": "normal",
  "heart_rate": 72,
  "details": "The ECG shows a normal sinus rhythm with regular rate and rhythm.",
  "findings": [
    "Regular R-R intervals",
    "Normal P wave morphology",
    "Normal PR interval (120-200ms)",
    "Narrow QRS complex (<120ms)",
    "Normal ST segment",
    "Normal T wave morphology"
  ]
}
```

### 2.4 ECG Records CRUD

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/v1/ecg-records` | Create record (uploads waveform to Tigris, metadata to Postgres) |
| `GET` | `/api/v1/ecg-records` | List records with cursor pagination and severity filter |
| `GET` | `/api/v1/ecg-records/{id}` | Get single record with full detail |
| `GET` | `/api/v1/ecg-records/{id}/waveform` | Get raw waveform data (fetched from Tigris) |
| `PATCH` | `/api/v1/ecg-records/{id}` | Update doctor_notes |
| `DELETE` | `/api/v1/ecg-records/{id}` | Delete record + waveform from Tigris |

**POST request** (create):
```json
{
  "patient_name": "Sarah Johnson",
  "patient_age": 46,
  "patient_gender": "Female",
  "recorded_at": "2026-03-24T10:30:00Z",
  "ecg_data": [0.01, 0.03, ...],
  "interpretation": "Normal Sinus Rhythm",
  "severity": "normal",
  "heart_rate": 72,
  "findings": ["Regular R-R intervals", "Normal P wave morphology"],
  "symptoms": ["Routine Check"],
  "symptom_note": null
}
```

**POST response** (201): Full record object with `ecg_data_key` (no raw `ecg_data`).

**GET list** query params:
- `limit` (int, default 20, max 100)
- `cursor` (string, optional — `recorded_at` ISO timestamp of last item)
- `severity` (string, optional — `"normal"` | `"warning"` | `"critical"`)

**GET list response:**
```json
{
  "items": [...],
  "next_cursor": "2026-03-20T08:00:00Z",
  "has_more": true
}
```

**PATCH request** (update notes):
```json
{
  "doctor_notes": "Patient advised to follow up in 2 weeks."
}
```

### 2.5 Analytics

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/stats` | Aggregate counts by severity |
| `GET` | `/api/v1/trends?range=month` | Heart rate data points for charting |

**Stats response:**
```json
{
  "total": 25,
  "normal": 15,
  "warning": 7,
  "critical": 3
}
```

**Trends response** (`range`: `"week"` | `"month"` | `"quarter"` | `"all"`):
```json
{
  "data_points": [
    {"recorded_at": "2026-03-01T08:00:00Z", "heart_rate": 72, "severity": "normal"},
    {"recorded_at": "2026-03-05T14:00:00Z", "heart_rate": 125, "severity": "warning"}
  ],
  "summary": {
    "avg_heart_rate": 82,
    "min_heart_rate": 48,
    "max_heart_rate": 125,
    "count": 12
  }
}
```

### 2.6 Report Generation

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/ecg-records/{id}/report` | Generate shareable text report |

**Response:**
```json
{
  "report_text": "CARDIOSCAN ECG REPORT\n==============================\n..."
}
```

---

## 3. Project Structure

```
cardioscan-backend/
├── alembic/
│   ├── versions/
│   │   └── 001_initial_schema.py
│   ├── env.py
│   └── alembic.ini
├── app/
│   ├── __init__.py
│   ├── main.py                       # FastAPI app, CORS, routers, lifespan
│   ├── config.py                     # pydantic-settings: DATABASE_URL, S3, CLERK_*
│   ├── dependencies.py               # get_db_session, get_current_user, get_s3_client
│   ├── auth.py                       # Clerk JWKS fetch, JWT verify, extract sub
│   ├── database.py                   # SQLAlchemy async engine + session
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user_profile.py           # SQLAlchemy model
│   │   └── ecg_record.py             # SQLAlchemy model
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── user_profile.py           # Pydantic schemas
│   │   ├── ecg_record.py             # Pydantic schemas
│   │   ├── interpretation.py         # Pydantic schemas
│   │   ├── stats.py                  # Pydantic schemas
│   │   └── report.py                 # Pydantic schemas
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── health.py                 # GET /health
│   │   ├── profile.py                # GET/PUT /api/v1/profile
│   │   ├── ecg_records.py            # CRUD + waveform + report
│   │   ├── interpretation.py         # POST /api/v1/interpret
│   │   └── analytics.py             # GET /api/v1/stats, trends
│   └── services/
│       ├── __init__.py
│       ├── interpretation.py         # Python port of InterpretationService
│       ├── report.py                 # Python port of ReportService
│       └── storage.py               # Tigris/S3 upload/download/delete
├── scripts/
│   └── seed.py                       # Generate 20 sample ECG records
├── terraform/
│   ├── main.tf                       # Fly.io app, Neon DB, Tigris bucket
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── Dockerfile
├── fly.toml
├── pyproject.toml
├── requirements.txt
└── README.md
```

---

## 4. Terraform Resources

| Resource | Provider | Purpose |
|---|---|---|
| `fly_app.cardioscan_api` | `fly-apps/fly` | Fly.io application |
| `neon_project.cardioscan` | `kislerdm/neon` | Neon Postgres project |
| `neon_database.cardioscan` | `kislerdm/neon` | Database instance |
| `neon_role.app_user` | `kislerdm/neon` | App database role |
| `null_resource.tigris_bucket` | hashicorp/null | Tigris bucket via `fly storage create` |

**Fly.io Secrets** (set via Terraform `null_resource`):
- `DATABASE_URL` — Neon connection string
- `AWS_ACCESS_KEY_ID` — Tigris credentials
- `AWS_SECRET_ACCESS_KEY` — Tigris credentials
- `AWS_ENDPOINT_URL_S3` — `https://fly.storage.tigris.dev`
- `BUCKET_NAME` — `cardioscan-ecg-data`
- `CLERK_SECRET_KEY` — `sk_test_...`
- `CLERK_FRONTEND_API_URL` — `https://romantic-herring-93.clerk.accounts.dev`
- `CLERK_PUBLISHABLE_KEY` — `pk_test_...`

---

## 5. Auth Flow

1. Flutter app authenticates via Clerk SDK (email+password or phone OTP)
2. Clerk returns a JWT
3. Flutter sends JWT as `Authorization: Bearer <token>` on every API call
4. FastAPI middleware:
   - Fetches JWKS from `https://romantic-herring-93.clerk.accounts.dev/.well-known/jwks.json` (cached)
   - Verifies JWT signature (RS256), expiry, issuer
   - Extracts `sub` claim as `clerk_user_id`
   - All DB queries filter by `clerk_user_id`

---

## 6. Sample Data (Seed Script)

Creates a test user profile and 20 ECG records spanning 6 weeks:

**Test User:**
- Name: Alex Rivera
- DOB: 1982-09-14 (age 43)
- Gender: Male
- Conditions: Hypertension, High Cholesterol
- Medications: Lisinopril 10mg, Atorvastatin 20mg
- `clerk_user_id`: `seed_user_test`

**20 ECG Records:**

| # | Day Offset | Type | Severity | HR | Symptoms | Doctor Notes |
|---|---|---|---|---|---|---|
| 1 | -42 | Normal | normal | 72 | Routine Check | — |
| 2 | -40 | Normal | normal | 68 | Routine Check | — |
| 3 | -37 | Tachycardia | warning | 118 | Palpitations | — |
| 4 | -35 | Normal | normal | 75 | Routine Check | "Looking good, continue monitoring" |
| 5 | -33 | Bradycardia | warning | 48 | Fatigue, Dizziness | — |
| 6 | -30 | Normal | normal | 70 | Routine Check | — |
| 7 | -28 | AFib | critical | 92 | Chest Pain, Palpitations, SOB | "Referred to cardiology" |
| 8 | -26 | Normal | normal | 78 | Routine Check | — |
| 9 | -24 | Normal | normal | 65 | Routine Check | — |
| 10 | -21 | ST Elevation | critical | 80 | Chest Pain, SOB | "ER visit, troponins negative" |
| 11 | -19 | Normal | normal | 71 | Routine Check | — |
| 12 | -17 | Tachycardia | warning | 130 | Palpitations, Fatigue | Note: "Just finished exercising" |
| 13 | -14 | AFib | critical | 105 | Palpitations, Dizziness, SOB | "Started anticoagulation" |
| 14 | -12 | Normal | normal | 74 | Routine Check | — |
| 15 | -10 | PVC | warning | 75 | Palpitations | Note: "Felt skipped beats" |
| 16 | -8 | Normal | normal | 69 | Routine Check | "Stable rhythm, continue meds" |
| 17 | -6 | Bradycardia | warning | 52 | Fatigue | Note: "Woke up feeling off" |
| 18 | -4 | AFib | critical | 98 | Chest Pain, Palpitations | — |
| 19 | -2 | Normal | normal | 73 | Routine Check | — |
| 20 | -1 | ST Elevation | critical | 82 | Chest Pain, SOB, Dizziness | "Urgent: referred for catheterization" |

**Distribution**: 10 normal (50%), 5 warning (25%), 5 critical (25%)

The seed script:
- Generates waveform data using a Python port of the Flutter ECG simulator
- Uploads each waveform to Tigris
- Inserts metadata into Postgres
- Is idempotent (deletes existing seed data before inserting)

---

## 7. Key Dependencies

```
fastapi>=0.115
uvicorn[standard]>=0.30
sqlalchemy[asyncio]>=2.0
asyncpg>=0.30
alembic>=1.14
boto3>=1.35
pyjwt[crypto]>=2.9
httpx>=0.28
pydantic-settings>=2.6
python-multipart>=0.0.12
```

---

## 8. Implementation Order

1. **Terraform** — Provision Fly app, Neon DB, Tigris bucket
2. **Database** — SQLAlchemy models, Alembic migration
3. **Auth** — Clerk JWT verification
4. **Profile endpoints** — GET/PUT profile
5. **Storage service** — Tigris upload/download/delete
6. **Interpretation service** — Python port of the algo
7. **ECG record endpoints** — CRUD + waveform + report
8. **Analytics endpoints** — Stats + trends
9. **Seed script** — Generate sample data
10. **Dockerfile + fly.toml** — Deploy to Fly.io
