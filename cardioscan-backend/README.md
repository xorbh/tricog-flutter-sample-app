# CardioScan Backend

FastAPI server for the CardioScan ECG interpretation app.

## Stack

- **FastAPI** + **uvicorn** — async Python API
- **PostgreSQL** (Neon) — metadata storage
- **Tigris** (S3-compatible) — ECG waveform storage
- **Clerk** — JWT authentication
- **Fly.io** — deployment

## Local Development

```bash
# Install dependencies
pip install -e .

# Copy env vars
cp .env.example .env
# Edit .env with your credentials

# Run migrations
DATABASE_URL=... alembic -c alembic/alembic.ini upgrade head

# Seed sample data
python -m scripts.seed

# Run the server
uvicorn app.main:app --reload --port 8080
```

## Deploy

```bash
# 1. Provision Neon DB
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply

# 2. Create Fly app + Tigris
fly apps create cardioscan-api
fly storage create --name cardioscan-ecg-data --app cardioscan-api

# 3. Set secrets
fly secrets set -a cardioscan-api \
  DATABASE_URL="$(terraform output -raw database_url)" \
  CLERK_SECRET_KEY="sk_test_..." \
  CLERK_FRONTEND_API_URL="https://romantic-herring-93.clerk.accounts.dev" \
  CLERK_PUBLISHABLE_KEY="pk_test_..."

# 4. Deploy
fly deploy

# 5. Run migrations
fly ssh console -a cardioscan-api -C "alembic -c alembic/alembic.ini upgrade head"

# 6. Seed data (optional)
fly ssh console -a cardioscan-api -C "python -m scripts.seed"
```

## API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/api/v1/profile` | Get user profile |
| PUT | `/api/v1/profile` | Create/update profile |
| POST | `/api/v1/interpret` | Run ECG interpretation |
| POST | `/api/v1/ecg-records` | Create ECG record |
| GET | `/api/v1/ecg-records` | List records (paginated) |
| GET | `/api/v1/ecg-records/{id}` | Get record detail |
| GET | `/api/v1/ecg-records/{id}/waveform` | Get raw ECG data |
| PATCH | `/api/v1/ecg-records/{id}` | Update doctor notes |
| DELETE | `/api/v1/ecg-records/{id}` | Delete record |
| GET | `/api/v1/ecg-records/{id}/report` | Generate text report |
| GET | `/api/v1/stats` | Severity counts |
| GET | `/api/v1/trends?range=month` | Heart rate trend data |
