from letter_api import __version__
from letter_api.domain.service_status import ServiceStatus


def get_service_status() -> ServiceStatus:
    return ServiceStatus(
        status="ok",
        service="letter-api",
        api_version=__version__,
    )
