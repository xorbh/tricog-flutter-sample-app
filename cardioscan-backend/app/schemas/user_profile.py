from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel


class ProfileCreate(BaseModel):
    name: str
    date_of_birth: date
    gender: str
    medical_conditions: list[str] = []
    medications: str | None = None


class ProfileResponse(BaseModel):
    id: UUID
    name: str
    date_of_birth: date
    age: int
    gender: str
    medical_conditions: list[str]
    medications: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
