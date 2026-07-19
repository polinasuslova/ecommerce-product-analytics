from collections.abc import Mapping
from pathlib import Path
import sys

import pandas as pd
from sqlalchemy import Engine


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DASHBOARD_DATA_DIR = PROJECT_ROOT / "dashboard" / "data"

if str(PROJECT_ROOT) not in sys.path:
    sys.path.append(str(PROJECT_ROOT))

from etl.config import get_engine


DASHBOARD_QUERIES: Mapping[str, str] = {
    "executive_metrics": """
        SELECT
            ROUND(
                SUM(order_items_value)::NUMERIC, 2
            ) AS gmv,

            COUNT(DISTINCT order_id)
                AS delivered_orders,

            COUNT(DISTINCT customer_unique_id)
                AS unique_customers,

            ROUND(
                (
                    SUM(order_items_value)
                    / NULLIF(
                        COUNT(DISTINCT order_id), 0
                    )
                )::NUMERIC, 2
            ) AS average_order_value,

            ROUND(
                AVG(average_review_score)::NUMERIC, 2
            ) AS average_review_score,

            ROUND(
                (
                    AVG(is_delayed::INTEGER) * 100
                )::NUMERIC, 2
            ) AS delayed_order_rate_percent,

            ROUND(
                AVG(delivery_time_days)::NUMERIC, 2
            ) AS average_delivery_time_days

        FROM analytics.order_metrics

        WHERE order_status = 'delivered';
    """,

    "monthly_metrics": """
        SELECT
            DATE_TRUNC(
                'month',
                order_purchase_timestamp
            )::DATE AS month,

            ROUND(
                SUM(order_items_value)::NUMERIC, 2
            ) AS gmv,

            COUNT(DISTINCT order_id)
                AS delivered_orders,

            COUNT(DISTINCT customer_unique_id)
                AS active_customers,

            ROUND(
                (
                    SUM(order_items_value)
                    / NULLIF(
                        COUNT(DISTINCT order_id), 0
                    )
                )::NUMERIC, 2
            ) AS average_order_value,

            ROUND(
                AVG(average_review_score)::NUMERIC, 2
            ) AS average_review_score,

            ROUND(
                (
                    AVG(is_delayed::INTEGER) * 100
                )::NUMERIC, 2
            ) AS delayed_order_rate_percent,

            ROUND(
                AVG(delivery_time_days)::NUMERIC, 2
            ) AS average_delivery_time_days

        FROM analytics.order_metrics

        WHERE order_status = 'delivered'

        GROUP BY
            DATE_TRUNC(
                'month',
                order_purchase_timestamp
            )

        ORDER BY
            month;
    """,

    "delivery_metrics": """
        SELECT
            DATE_TRUNC(
                'month',
                order_purchase_timestamp
            )::DATE AS month,

            is_delayed,

            COUNT(DISTINCT order_id)
                AS delivered_orders,

            ROUND(
                AVG(delivery_time_days)::NUMERIC,
                2
            ) AS average_delivery_time_days,

            ROUND(
                PERCENTILE_CONT(0.5)
                WITHIN GROUP (
                    ORDER BY delivery_time_days
                )::NUMERIC,
                2
            ) AS median_delivery_time_days,

            ROUND(
                AVG(delivery_delay_days)::NUMERIC,
                2
            ) AS average_delivery_delay_days,

            ROUND(
                AVG(average_review_score)::NUMERIC,
                2
            ) AS average_review_score,

            ROUND(
                (
                    AVG(
                        CASE
                            WHEN average_review_score <= 2
                            THEN 1.0
                            ELSE 0.0
                        END
                    ) * 100
                )::NUMERIC,
                2
            ) AS low_review_rate_percent

        FROM analytics.order_metrics

        WHERE order_status = 'delivered'

        GROUP BY
            DATE_TRUNC(
                'month',
                order_purchase_timestamp
            ),
            is_delayed

        ORDER BY
            month,
            is_delayed;
    """,

    "category_metrics": """
        WITH order_category_metrics AS (
            SELECT
                oi.order_id,

                oi.product_category_name_english
                    AS product_category,

                COUNT(*)
                    AS items_count,

                SUM(oi.price)
                    AS products_value,

                SUM(oi.freight_value)
                    AS freight_value,

                AVG(oi.price)
                    AS average_item_price,

                AVG(oi.freight_value)
                    AS average_freight_value,

                MAX(om.average_review_score)
                    AS average_review_score

            FROM analytics.order_items_enriched AS oi

            INNER JOIN analytics.order_metrics AS om
                ON oi.order_id = om.order_id

            WHERE om.order_status = 'delivered'

            GROUP BY
                oi.order_id,
                oi.product_category_name_english
        )

        SELECT
            product_category,

            COUNT(DISTINCT order_id)
                AS delivered_orders,

            SUM(items_count)
                AS items_sold,

            ROUND(
                SUM(products_value)::NUMERIC,
                2
            ) AS products_value,

            ROUND(
                SUM(freight_value)::NUMERIC,
                2
            ) AS freight_value,

            ROUND(
                AVG(average_item_price)::NUMERIC,
                2
            ) AS average_item_price,

            ROUND(
                AVG(average_freight_value)::NUMERIC,
                2
            ) AS average_freight_value,

            ROUND(
                AVG(average_review_score)::NUMERIC,
                2
            ) AS average_review_score

        FROM order_category_metrics

        GROUP BY
            product_category

        ORDER BY
            products_value DESC;
    """,

    "state_metrics": """
        SELECT
            customer_state,

            COUNT(DISTINCT order_id)
                AS delivered_orders,

            COUNT(DISTINCT customer_unique_id)
                AS unique_customers,

            ROUND(
                SUM(order_items_value)::NUMERIC,
                2
            ) AS gmv,

            ROUND(
                (
                    SUM(order_items_value)
                    / NULLIF(
                        COUNT(DISTINCT order_id),
                        0
                    )
                )::NUMERIC,
                2
            ) AS average_order_value,

            ROUND(
                AVG(delivery_time_days)::NUMERIC,
                2
            ) AS average_delivery_time_days,

            ROUND(
                (
                    AVG(is_delayed::INTEGER)
                    * 100
                )::NUMERIC,
                2
            ) AS delayed_order_rate_percent,

            ROUND(
                AVG(average_review_score)::NUMERIC,
                2
            ) AS average_review_score

        FROM analytics.order_metrics

        WHERE order_status = 'delivered'

        GROUP BY
            customer_state

        ORDER BY
            gmv DESC;
    """,

    "customer_metrics": """
        WITH delivered_orders AS (
            SELECT
                order_id,
                customer_unique_id,
                order_purchase_timestamp,

                DATE_TRUNC(
                    'month',
                    order_purchase_timestamp
                )::DATE AS month,

                order_items_value

            FROM analytics.order_metrics

            WHERE order_status = 'delivered'
            AND customer_unique_id IS NOT NULL
        ),

        customer_first_orders AS (
            SELECT
                customer_unique_id,

                MIN(month)
                    AS first_order_month

            FROM delivered_orders

            GROUP BY
                customer_unique_id
        ),

        monthly_customer_activity AS (
            SELECT
                orders.month,
                orders.customer_unique_id,
                first_orders.first_order_month,

                COUNT(DISTINCT orders.order_id)
                    AS customer_orders,

                SUM(orders.order_items_value)
                    AS customer_gmv

            FROM delivered_orders AS orders

            INNER JOIN customer_first_orders AS first_orders
                ON orders.customer_unique_id
                    = first_orders.customer_unique_id

            GROUP BY
                orders.month,
                orders.customer_unique_id,
                first_orders.first_order_month
        )

        SELECT
            month,

            COUNT(*)
                AS active_customers,

            COUNT(*) FILTER (
                WHERE month = first_order_month
            ) AS new_customers,

            COUNT(*) FILTER (
                WHERE month > first_order_month
            ) AS repeat_customers,

            ROUND(
                (
                    COUNT(*) FILTER (
                        WHERE month > first_order_month
                    )::NUMERIC
                    / NULLIF(
                        COUNT(*),
                        0
                    )
                    * 100
                ),
                2
            ) AS repeat_customer_share_percent,

            SUM(customer_orders)
                AS delivered_orders,

            ROUND(
                SUM(customer_gmv)::NUMERIC,
                2
            ) AS gmv,

            ROUND(
                (
                    SUM(customer_orders)::NUMERIC
                    / NULLIF(
                        COUNT(*),
                        0
                    )
                ),
                3
            ) AS orders_per_active_customer

        FROM monthly_customer_activity

        GROUP BY
            month

        ORDER BY
            month;
    """,

    "cohort_retention": """
        WITH delivered_orders AS (
            SELECT
                customer_unique_id,

                DATE_TRUNC(
                    'month',
                    order_purchase_timestamp
                )::DATE AS activity_month

            FROM analytics.order_metrics

            WHERE order_status = 'delivered'
        ),

        customer_cohorts AS (
            SELECT
                customer_unique_id,

                MIN(activity_month)
                    AS cohort_month

            FROM delivered_orders

            GROUP BY
                customer_unique_id
        ),

        cohort_activity AS (
            SELECT DISTINCT
                orders.customer_unique_id,
                cohorts.cohort_month,
                orders.activity_month,

                (
                    EXTRACT(
                        YEAR FROM AGE(
                            orders.activity_month,
                            cohorts.cohort_month
                        )
                    ) * 12
                    +
                    EXTRACT(
                        MONTH FROM AGE(
                            orders.activity_month,
                            cohorts.cohort_month
                        )
                    )
                )::INTEGER AS cohort_index

            FROM delivered_orders AS orders

            INNER JOIN customer_cohorts AS cohorts
                ON orders.customer_unique_id
                    = cohorts.customer_unique_id
        ),

        cohort_sizes AS (
            SELECT
                cohort_month,

                COUNT(DISTINCT customer_unique_id)
                    AS cohort_size

            FROM customer_cohorts

            GROUP BY
                cohort_month
        )

        SELECT
            activity.cohort_month,
            activity.cohort_index,

            COUNT(
                DISTINCT activity.customer_unique_id
            ) AS active_customers,

            sizes.cohort_size,

            ROUND(
                (
                    COUNT(
                        DISTINCT activity.customer_unique_id
                    )::NUMERIC
                    / NULLIF(
                        sizes.cohort_size,
                        0
                    )
                    * 100
                ),
                3
            ) AS retention_rate_percent

        FROM cohort_activity AS activity

        INNER JOIN cohort_sizes AS sizes
            ON activity.cohort_month
                = sizes.cohort_month

        GROUP BY
            activity.cohort_month,
            activity.cohort_index,
            sizes.cohort_size

        ORDER BY
            activity.cohort_month,
            activity.cohort_index;
    """,

    "rfm_segments": """
        WITH customer_metrics AS (
            SELECT
                customer_unique_id,

                MAX(
                    order_purchase_timestamp
                ) AS last_order_timestamp,

                COUNT(DISTINCT order_id)
                    AS frequency,

                SUM(order_items_value)
                    AS monetary

            FROM analytics.order_metrics

            WHERE order_status = 'delivered'

            GROUP BY
                customer_unique_id
        ),

        reference_date AS (
            SELECT
                MAX(order_purchase_timestamp)
                    + INTERVAL '1 day'
                    AS analysis_date

            FROM analytics.order_metrics

            WHERE order_status = 'delivered'
        ),

        rfm_values AS (
            SELECT
                metrics.customer_unique_id,

                (
                    reference.analysis_date::DATE
                    - metrics.last_order_timestamp::DATE
                ) AS recency,

                metrics.frequency,
                metrics.monetary

            FROM customer_metrics AS metrics

            CROSS JOIN reference_date AS reference
        ),

        rfm_scores AS (
            SELECT
                customer_unique_id,
                recency,
                frequency,
                monetary,

                5 - NTILE(4) OVER (
                    ORDER BY recency
                ) AS recency_score,

                CASE
                    WHEN frequency = 1
                        THEN 1

                    WHEN frequency = 2
                        THEN 2

                    WHEN frequency = 3
                        THEN 3

                    ELSE 4
                END AS frequency_score,

                NTILE(4) OVER (
                    ORDER BY monetary
                ) AS monetary_score

            FROM rfm_values
        ),

        segmented_customers AS (
            SELECT
                customer_unique_id,
                recency,
                frequency,
                monetary,
                recency_score,
                frequency_score,
                monetary_score,

                CASE
                    WHEN recency_score = 4
                        AND frequency_score >= 3
                        AND monetary_score >= 3
                        THEN 'Champions'

                    WHEN recency_score >= 3
                        AND frequency_score >= 2
                        AND monetary_score >= 2
                        THEN 'Loyal Customers'

                    WHEN recency_score = 4
                        AND frequency_score = 1
                        THEN 'New Customers'

                    WHEN recency_score >= 3
                        AND monetary_score >= 3
                        THEN 'High-Value Recent'

                    WHEN recency_score <= 2
                        AND frequency_score >= 2
                        THEN 'At Risk'

                    WHEN recency_score = 1
                        AND frequency_score = 1
                        THEN 'Lost Customers'

                    ELSE 'Regular Customers'
                END AS rfm_segment

            FROM rfm_scores
        )

        SELECT
            rfm_segment,

            COUNT(*)
                AS customers_count,

            ROUND(
                (
                    COUNT(*)::NUMERIC
                    / SUM(COUNT(*)) OVER ()
                    * 100
                ),
                2
            ) AS customer_share_percent,

            ROUND(
                SUM(monetary)::NUMERIC,
                2
            ) AS monetary_value,

            ROUND(
                (
                    SUM(monetary)
                    / SUM(SUM(monetary)) OVER ()
                    * 100
                )::NUMERIC,
                2
            ) AS monetary_share_percent,

            ROUND(
                AVG(recency)::NUMERIC,
                2
            ) AS average_recency_days,

            ROUND(
                AVG(frequency)::NUMERIC,
                3
            ) AS average_frequency,

            ROUND(
                AVG(monetary)::NUMERIC,
                2
            ) AS average_monetary_value

        FROM segmented_customers

        GROUP BY
            rfm_segment

        ORDER BY
            monetary_value DESC;
    """,
}


def export_query_to_csv(
    engine: Engine,
    dataset_name: str,
    query: str,
) -> None:
    dataframe = pd.read_sql(
        query,
        engine,
    )

    output_path = (
        DASHBOARD_DATA_DIR
        / f"{dataset_name}.csv"
    )

    dataframe.to_csv(
        output_path,
        index=False,
    )

    print(
        f"Exported {dataset_name}: "
        f"{len(dataframe):,} rows "
        f"to {output_path}"
    )


def export_dashboard_data() -> None:
    DASHBOARD_DATA_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    engine = get_engine()

    try:
        for dataset_name, query in (
            DASHBOARD_QUERIES.items()
        ):
            export_query_to_csv(
                engine=engine,
                dataset_name=dataset_name,
                query=query,
            )

    finally:
        engine.dispose()

    print("Dashboard data export completed.")


if __name__ == "__main__":
    export_dashboard_data()
