from pathlib import Path

from sqlalchemy import Engine, text

from config import DATABASE_DIR, get_engine
from load_raw_data import load_raw_data


EXPECTED_RAW_ROW_COUNTS = {
    "category_translation": 71,
    "customers": 99_441,
    "geolocation": 1_000_163,
    "order_items": 112_650,
    "orders": 99_441,
    "payments": 103_886,
    "products": 32_951,
    "reviews": 99_224,
    "sellers": 3_095,
}

EXPECTED_ANALYTICS_ROW_COUNTS = {
    "products": 32_951,
    "geolocation": 19_015,
    "orders_enriched": 99_441,
    "order_items_enriched": 112_650,
    "order_metrics": 99_441,
}


def execute_sql_file(engine: Engine, filepath: Path) -> None:
    """Execute a SQL file containing PostgreSQL statements."""

    if not filepath.exists():
        raise FileNotFoundError(
            f"SQL file was not found: {filepath}"
        )

    sql = filepath.read_text(encoding="utf-8")

    with engine.begin() as connection:
        connection.exec_driver_sql(sql)


def check_connection(engine: Engine) -> None:
    """Check that PostgreSQL connection works."""

    with engine.connect() as connection:
        database_name = connection.execute(
            text("SELECT current_database();")
        ).scalar_one()

    print(f"Connected to PostgreSQL database: {database_name}")


def validate_row_counts(
    engine: Engine,
    schema: str,
    expected_counts: dict[str, int],
) -> None:
    """Compare actual table or view sizes with expected values."""

    errors: list[str] = []

    with engine.connect() as connection:
        for object_name, expected_count in expected_counts.items():
            query = text(
                f"SELECT COUNT(*) FROM {schema}.{object_name};"
            )

            actual_count = connection.execute(query).scalar_one()

            print(
                f"{schema}.{object_name}: "
                f"{actual_count:,} rows"
            )

            if actual_count != expected_count:
                errors.append(
                    f"{schema}.{object_name}: "
                    f"expected {expected_count:,}, "
                    f"got {actual_count:,}"
                )

    if errors:
        raise ValueError(
            "Row-count validation failed:\n"
            + "\n".join(errors)
        )


def run_pipeline() -> None:
    """Run the complete PostgreSQL data-loading pipeline."""

    engine = get_engine()

    try:
        check_connection(engine)

        print("\n1. Creating schemas...")
        execute_sql_file(
            engine,
            DATABASE_DIR / "01_create_schemas.sql",
        )

        print("\n2. Creating raw tables...")
        execute_sql_file(
            engine,
            DATABASE_DIR / "02_create_raw_tables.sql",
        )

        print("\n3. Loading raw CSV files...")
        load_raw_data(engine)

        print("\n4. Validating raw row counts...")
        validate_row_counts(
            engine=engine,
            schema="raw",
            expected_counts=EXPECTED_RAW_ROW_COUNTS,
        )

        print("\n5. Creating analytics views...")
        execute_sql_file(
            engine,
            DATABASE_DIR / "04_create_analytics_layer.sql",
        )

        print("\n6. Validating analytics row counts...")
        validate_row_counts(
            engine=engine,
            schema="analytics",
            expected_counts=EXPECTED_ANALYTICS_ROW_COUNTS,
        )

        print("\nPipeline completed successfully.")

    finally:
        engine.dispose()


if __name__ == "__main__":
    run_pipeline()