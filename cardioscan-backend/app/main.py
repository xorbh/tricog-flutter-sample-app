from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routers import analytics, ecg_records, health, interpretation, profile


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield


app = FastAPI(title="CardioScan API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(profile.router)
app.include_router(interpretation.router)
app.include_router(ecg_records.router)
app.include_router(analytics.router)
