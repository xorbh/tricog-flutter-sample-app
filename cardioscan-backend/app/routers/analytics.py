from datetime import datetime, timedelta

from fastapi import APIRouter, Query
from sqlalchemy import func, select

from ..dependencies import DB, CurrentUser
from ..models.ecg_record import ECGRecord
from ..schemas.stats import StatsResponse, TrendDataPoint, TrendSummary, TrendsResponse

router = APIRouter(prefix="/api/v1")


@router.get("/stats", response_model=StatsResponse)
async def get_stats(db: DB, user_id: CurrentUser):
    base = select(func.count()).where(ECGRecord.clerk_user_id == user_id)

    total = (await db.execute(base)).scalar() or 0
    normal = (
        await db.execute(base.where(ECGRecord.severity == "normal"))
    ).scalar() or 0
    warning = (
        await db.execute(base.where(ECGRecord.severity == "warning"))
    ).scalar() or 0
    critical = (
        await db.execute(base.where(ECGRecord.severity == "critical"))
    ).scalar() or 0

    return StatsResponse(total=total, normal=normal, warning=warning, critical=critical)


@router.get("/trends", response_model=TrendsResponse)
async def get_trends(
    db: DB,
    user_id: CurrentUser,
    range: str = Query(..., pattern="^(week|month|quarter|all)$"),
):
    now = datetime.now()
    start = {
        "week": now - timedelta(days=7),
        "month": now - timedelta(days=30),
        "quarter": now - timedelta(days=90),
        "all": datetime(2000, 1, 1),
    }[range]

    query = (
        select(ECGRecord.recorded_at, ECGRecord.heart_rate, ECGRecord.severity)
        .where(ECGRecord.clerk_user_id == user_id)
        .where(ECGRecord.recorded_at >= start)
        .where(ECGRecord.recorded_at <= now)
        .order_by(ECGRecord.recorded_at.asc())
    )

    result = await db.execute(query)
    rows = result.all()

    data_points = [
        TrendDataPoint(recorded_at=r.recorded_at, heart_rate=r.heart_rate, severity=r.severity)
        for r in rows
    ]

    if data_points:
        hrs = [d.heart_rate for d in data_points]
        summary = TrendSummary(
            avg_heart_rate=round(sum(hrs) / len(hrs)),
            min_heart_rate=min(hrs),
            max_heart_rate=max(hrs),
            count=len(hrs),
        )
    else:
        summary = TrendSummary(avg_heart_rate=0, min_heart_rate=0, max_heart_rate=0, count=0)

    return TrendsResponse(data_points=data_points, summary=summary)
