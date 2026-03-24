from datetime import datetime

from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from ..dependencies import DB, CurrentUser
from ..models.user_profile import UserProfile
from ..schemas.user_profile import ProfileCreate, ProfileResponse

router = APIRouter(prefix="/api/v1")


def _profile_to_response(profile: UserProfile) -> ProfileResponse:
    today = datetime.now().date()
    age = today.year - profile.date_of_birth.year
    if (today.month, today.day) < (profile.date_of_birth.month, profile.date_of_birth.day):
        age -= 1
    return ProfileResponse(
        id=profile.id,
        name=profile.name,
        date_of_birth=profile.date_of_birth,
        age=age,
        gender=profile.gender,
        medical_conditions=profile.medical_conditions,
        medications=profile.medications,
        created_at=profile.created_at,
        updated_at=profile.updated_at,
    )


@router.get("/profile", response_model=ProfileResponse)
async def get_profile(db: DB, user_id: CurrentUser):
    result = await db.execute(
        select(UserProfile).where(UserProfile.clerk_user_id == user_id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return _profile_to_response(profile)


@router.put("/profile", response_model=ProfileResponse)
async def upsert_profile(db: DB, user_id: CurrentUser, body: ProfileCreate):
    result = await db.execute(
        select(UserProfile).where(UserProfile.clerk_user_id == user_id)
    )
    profile = result.scalar_one_or_none()

    now = datetime.now()
    if profile:
        profile.name = body.name
        profile.date_of_birth = body.date_of_birth
        profile.gender = body.gender
        profile.medical_conditions = body.medical_conditions
        profile.medications = body.medications
        profile.updated_at = now
    else:
        profile = UserProfile(
            clerk_user_id=user_id,
            name=body.name,
            date_of_birth=body.date_of_birth,
            gender=body.gender,
            medical_conditions=body.medical_conditions,
            medications=body.medications,
            created_at=now,
            updated_at=now,
        )
        db.add(profile)

    await db.commit()
    await db.refresh(profile)
    return _profile_to_response(profile)
