from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel

from letter_api.application.get_service_status import get_service_status

router = APIRouter(tags=["operations"])


class StatusResponse(BaseModel):
    status: Literal["ok"]
    service: str
    api_version: str


@router.get("/status", response_model=StatusResponse, operation_id="getStatus")
def get_status() -> StatusResponse:
    status = get_service_status()
    return StatusResponse(
        status=status.status,
        service=status.service,
        api_version=status.api_version,
    )
