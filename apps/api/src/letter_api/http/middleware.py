import logging
from collections.abc import Awaitable, Callable
from time import monotonic
from typing import cast

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.routing import BaseRoute

logger = logging.getLogger("letter_api.access")

RequestHandler = Callable[[Request], Awaitable[Response]]


def _full_route_template(request: Request, route: BaseRoute | None) -> str:
    template = getattr(route, "path", None)
    if not isinstance(template, str):
        return "unmatched"
    actual_segments = request.url.path.strip("/").split("/")
    template_segments = template.strip("/").split("/")
    prefix_count = max(0, len(actual_segments) - len(template_segments))
    segments = [*actual_segments[:prefix_count], *template_segments]
    return f"/{'/'.join(segment for segment in segments if segment)}"


class OperationalLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(
        self,
        request: Request,
        call_next: RequestHandler,
    ) -> Response:
        started_at = monotonic()
        response = await call_next(request)
        route = cast(BaseRoute | None, request.scope.get("route"))
        route_path = _full_route_template(request, route)
        logger.info(
            "request_complete",
            extra={
                "http_method": request.method,
                "route_template": route_path,
                "status_code": response.status_code,
                "duration_ms": round((monotonic() - started_at) * 1000, 2),
            },
        )
        return response
