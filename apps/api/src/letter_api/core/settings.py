from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="LETTER_",
        extra="ignore",
        hide_input_in_errors=True,
    )

    app_name: str = "Letter API"
    environment: Literal["development", "test", "production"] = "development"
    api_prefix: str = Field(default="/v1", pattern=r"^/[a-z0-9]+$")
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"


@lru_cache
def get_settings() -> Settings:
    return Settings()
