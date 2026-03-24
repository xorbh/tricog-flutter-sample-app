from datetime import datetime

from pydantic import BaseModel


class StatsResponse(BaseModel):
    total: int
    normal: int
    warning: int
    critical: int


class TrendDataPoint(BaseModel):
    recorded_at: datetime
    heart_rate: int
    severity: str


class TrendSummary(BaseModel):
    avg_heart_rate: int
    min_heart_rate: int
    max_heart_rate: int
    count: int


class TrendsResponse(BaseModel):
    data_points: list[TrendDataPoint]
    summary: TrendSummary
