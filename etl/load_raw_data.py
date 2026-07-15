from collections.abc import Mapping
from pathlib import Path

import pandas as pd
from sqlalchemy import Engine, text

from config import DATA_DIR


TABLE_CONFIG: Mapping[str, dict[str, object]] = {
    "category_translation": {
        "filename": "product_category_name_translation.csv",
        "columns": [
            "product_category_name",
            "product_category_name_english",
        ],
    },
    "customers": {
        "filename": "olist_customers_dataset.csv",
        "columns": [
            "customer_id",
            "customer_unique_id",
            "customer_zip_code_prefix",
            "customer_city",
            "customer_state",
        ],
    },
    "sellers": {
        "filename": "olist_sellers_dataset.csv",
        "columns": [
            "seller_id",
            "seller_zip_code_prefix",
            "seller_city",
            "seller_state",
        ],
    },
    "products": {
        "filename": "olist_products_dataset.csv",
        "columns": [
            "product_id",
            "product_category_name",
            "product_name_lenght",
            "product_description_lenght",
            "product_photos_qty",
            "product_weight_g",
            "product_length_cm",
            "product_height_cm",
            "product_width_cm",
        ],
    },
    "orders": {
        "filename": "olist_orders_dataset.csv",
        "columns": [
            "order_id",
            "customer_id",
            "order_status",
            "order_purchase_timestamp",
            "order_approved_at",
            "order_delivered_carrier_date",
            "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ],
        "date_columns": [
            "order_purchase_timestamp",
            "order_approved_at",
            "order_delivered_carrier_date",
            "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ],
    },
    "order_items": {
        "filename": "olist_order_items_dataset.csv",
        "columns": [
            "order_id",
            "order_item_id",
            "product_id",
            "seller_id",
            "shipping_limit_date",
            "price",
            "freight_value",
        ],
        "date_columns": [
            "shipping_limit_date",
        ],
    },
    "payments": {
        "filename": "olist_order_payments_dataset.csv",
        "columns": [
            "order_id",
            "payment_sequential",
            "payment_type",
            "payment_installments",
            "payment_value",
        ],
    },
    "reviews": {
        "filename": "olist_order_reviews_dataset.csv",
        "columns": [
            "review_id",
            "order_id",
            "review_score",
            "review_comment_title",
            "review_comment_message",
            "review_creation_date",
            "review_answer_timestamp",
        ],
        "date_columns": [
            "review_creation_date",
            "review_answer_timestamp",
        ],
    },
    "geolocation": {
        "filename": "olist_geolocation_dataset.csv",
        "columns": [
            "geolocation_zip_code_prefix",
            "geolocation_lat",
            "geolocation_lng",
            "geolocation_city",
            "geolocation_state",
        ],
    },
}


def validate_file_columns(
    dataframe: pd.DataFrame,
    expected_columns: list[str],
    filename: str,
) -> None:
    """Check that CSV columns exactly match the expected structure."""

    actual_columns = dataframe.columns.tolist()

    if actual_columns != expected_columns:
        raise ValueError(
            f"Unexpected columns in {filename}.\n"
            f"Expected: {expected_columns}\n"
            f"Actual: {actual_columns}"
        )


def read_csv_file(
    filepath: Path,
    expected_columns: list[str],
    date_columns: list[str] | None = None,
) -> pd.DataFrame:
    """Read and validate one source CSV file."""

    if not filepath.exists():
        raise FileNotFoundError(
            f"Dataset file was not found: {filepath}"
        )

    dataframe = pd.read_csv(
        filepath,
        encoding="utf-8",
        quotechar='"',
        low_memory=False,
    )

    validate_file_columns(
        dataframe=dataframe,
        expected_columns=expected_columns,
        filename=filepath.name,
    )

    text_columns = dataframe.select_dtypes(include="object").columns

    for column in text_columns:
        dataframe[column] = dataframe[column].replace(
            r"^\s*$",
            pd.NA,
            regex=True,
        )

    if date_columns:
        for column in date_columns:
            dataframe[column] = pd.to_datetime(
                dataframe[column],
                errors="raise",
            )

    return dataframe


def truncate_raw_tables(engine: Engine) -> None:
    """Remove current raw data before a reproducible reload."""

    statement = text(
        """
        TRUNCATE TABLE
            raw.reviews,
            raw.payments,
            raw.order_items,
            raw.orders,
            raw.products,
            raw.sellers,
            raw.customers,
            raw.category_translation,
            raw.geolocation
        RESTART IDENTITY CASCADE;
        """
    )

    with engine.begin() as connection:
        connection.execute(statement)


def load_dataframe(
    dataframe: pd.DataFrame,
    table_name: str,
    engine: Engine,
) -> None:
    """Append a dataframe to an existing PostgreSQL table."""

    dataframe.to_sql(
        name=table_name,
        con=engine,
        schema="raw",
        if_exists="append",
        index=False,
        chunksize=5_000,
        method="multi",
    )


def load_raw_data(engine: Engine) -> None:
    """Load all Olist CSV files into the raw PostgreSQL schema."""

    truncate_raw_tables(engine)

    for table_name, table_config in TABLE_CONFIG.items():
        filename = str(table_config["filename"])
        expected_columns = list(table_config["columns"])
        date_columns = table_config.get("date_columns")

        filepath = DATA_DIR / filename

        print(f"Loading raw.{table_name} from {filename}...")

        dataframe = read_csv_file(
            filepath=filepath,
            expected_columns=expected_columns,
            date_columns=list(date_columns) if date_columns else None,
        )

        load_dataframe(
            dataframe=dataframe,
            table_name=table_name,
            engine=engine,
        )

        print(
            f"Loaded {len(dataframe):,} rows "
            f"into raw.{table_name}."
        )