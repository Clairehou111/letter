from logging.config import fileConfig

from alembic import context

from letter_api.persistence.metadata import metadata

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    if not url:
        raise RuntimeError("Set sqlalchemy.url before running migrations")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    raise RuntimeError(
        "Online migrations are not configured until an operational schema is approved"
    )


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
