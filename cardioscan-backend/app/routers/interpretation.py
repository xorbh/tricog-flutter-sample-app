from fastapi import APIRouter

from ..dependencies import CurrentUser
from ..schemas.interpretation import InterpretRequest, InterpretResponse
from ..services.interpretation import analyze

router = APIRouter(prefix="/api/v1")


@router.post("/interpret", response_model=InterpretResponse)
async def interpret_ecg(user_id: CurrentUser, body: InterpretRequest):
    result = await analyze(body.ecg_data, body.ecg_type)
    return InterpretResponse(
        diagnosis=result.diagnosis,
        severity=result.severity,
        heart_rate=result.heart_rate,
        details=result.details,
        findings=result.findings,
    )
