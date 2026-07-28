import ast
from pathlib import Path


def test_domain_has_no_framework_imports() -> None:
    domain_root = Path("src/letter_api/domain")
    prohibited = {"fastapi", "pydantic", "sqlalchemy", "starlette"}

    for source_path in domain_root.glob("*.py"):
        tree = ast.parse(source_path.read_text(encoding="utf-8"))
        imports = {
            alias.name.split(".", maxsplit=1)[0]
            for node in ast.walk(tree)
            if isinstance(node, ast.Import)
            for alias in node.names
        }
        imports.update(
            node.module.split(".", maxsplit=1)[0]
            for node in ast.walk(tree)
            if isinstance(node, ast.ImportFrom) and node.module
        )
        assert imports.isdisjoint(prohibited), source_path
