from fastapi import FastAPI

from letter_api import __version__
from letter_api.core.settings import Settings, get_settings
from letter_api.http.middleware import OperationalLoggingMiddleware
from letter_api.http.routes.health import router as health_router
from letter_api.http.routes.status import router as status_router


def create_app(settings: Settings | None = None) -> FastAPI:
    resolved_settings = settings or get_settings()
    app = FastAPI(
        title=resolved_settings.app_name,
        version=__version__,
        description=(
            "Operational API for Letter. Readable health records remain on-device."
        ),
    )
    app.state.settings = resolved_settings
    app.add_middleware(OperationalLoggingMiddleware)
    app.include_router(health_router)
    app.include_router(status_router, prefix=resolved_settings.api_prefix)
    return app
