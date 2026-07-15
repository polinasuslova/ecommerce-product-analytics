from pathlib import Path
import os

from dotenv import load_dotenv
from sqlalchemy import create_engine


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data" / "raw"
DATABASE_DIR = PROJECT_ROOT / "database"

load_dotenv(PROJECT_ROOT / ".env")


def get_engine():
    host = os.getenv("DB_HOST")
    port = os.getenv("DB_PORT")
    database = os.getenv("DB_NAME")
    user = os.getenv("DB_USER")
    password = os.getenv("DB_PASSWORD")

    missing = []

    variables = {
        "DB_HOST": host,
        "DB_PORT": port,
        "DB_NAME": database,
        "DB_USER": user,
        "DB_PASSWORD": password,
    }

    for name, value in variables.items():
        if not value:
            missing.append(name)

    if missing:
        raise ValueError(
            f"Missing environment variables: {', '.join(missing)}"
        )

    return create_engine(
        f"postgresql+psycopg2://{user}:{password}"
        f"@{host}:{port}/{database}"
    )