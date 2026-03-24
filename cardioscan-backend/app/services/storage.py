import json
from io import BytesIO

from ..config import settings


def upload_ecg_data(s3_client, key: str, data: list[float]) -> None:
    body = json.dumps(data).encode()
    s3_client.put_object(
        Bucket=settings.bucket_name,
        Key=key,
        Body=body,
        ContentType="application/json",
    )


def download_ecg_data(s3_client, key: str) -> list[float]:
    response = s3_client.get_object(Bucket=settings.bucket_name, Key=key)
    body = response["Body"].read()
    return json.loads(body)


def delete_ecg_data(s3_client, key: str) -> None:
    s3_client.delete_object(Bucket=settings.bucket_name, Key=key)
