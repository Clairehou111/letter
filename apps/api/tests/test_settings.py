import pytest
from pydantic import ValidationError

from letter_api.core.settings import Settings


def test_invalid_api_prefix_fails_without_echoing_secret_values() -> None:
    with pytest.raises(ValidationError) as error:
        Settings(api_prefix="not/a/prefix")

    assert "not/a/prefix" not in str(error.value)
