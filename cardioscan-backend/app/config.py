from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    aws_access_key_id: str
    aws_secret_access_key: str
    aws_endpoint_url_s3: str = "https://fly.storage.tigris.dev"
    bucket_name: str = "cardioscan-ecg-data"
    clerk_secret_key: str
    clerk_frontend_api_url: str
    clerk_publishable_key: str

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
