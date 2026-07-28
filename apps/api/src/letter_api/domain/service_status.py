from dataclasses import dataclass
from typing import Literal


@dataclass(frozen=True, slots=True)
class ServiceStatus:
    status: Literal["ok"]
    service: str
    api_version: str
