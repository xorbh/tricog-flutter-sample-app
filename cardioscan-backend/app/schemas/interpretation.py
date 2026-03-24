from pydantic import BaseModel


class InterpretRequest(BaseModel):
    ecg_data: list[float]
    ecg_type: str


class InterpretResponse(BaseModel):
    diagnosis: str
    severity: str
    heart_rate: int
    details: str
    findings: list[str]
