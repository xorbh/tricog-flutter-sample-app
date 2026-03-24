from typing import Annotated

import boto3
from fastapi import Depends, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession

from .auth import verify_clerk_token
from .config import settings
from .database import async_session


async def get_db() -> AsyncSession:
    async with async_session() as session:
        yield session


def get_s3_client():
    return boto3.client(
        "s3",
        aws_access_key_id=settings.aws_access_key_id,
        aws_secret_access_key=settings.aws_secret_access_key,
        endpoint_url=settings.aws_endpoint_url_s3,
    )


async def get_current_user(authorization: Annotated[str | None, Header()] = None) -> str:
    """Extract and verify the Clerk user ID from the Authorization header."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")

    token = authorization.removeprefix("Bearer ")
    try:
        payload = verify_clerk_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    clerk_user_id = payload.get("sub")
    if not clerk_user_id:
        raise HTTPException(status_code=401, detail="Invalid token: missing sub claim")

    return clerk_user_id


DB = Annotated[AsyncSession, Depends(get_db)]
CurrentUser = Annotated[str, Depends(get_current_user)]
S3Client = Annotated[object, Depends(get_s3_client)]
