view: pdt_category_mom_velocity {
  description: "LookML Persistent Derived Table (PDT) tracking monthly category spend acceleration and 3-month rolling averages. Grain: 1 row per year_month + category_id."
  derived_table: {
    sql:
      WITH monthly_category_spend AS (
        SELECT
          SUBSTR(CAST(t.date AS VARCHAR), 1, 7) AS year_month,
          t.category_id,
          COALESCE(c.category_name, t.category_name) AS category_name,
          COALESCE(c.category_group, t.category_group) AS category_group,
          COALESCE(c.cardinality, 'unclassified') AS cardinality,
          COUNT(*) AS transaction_count,
          SUM(ABS(t.amount)) AS monthly_spend_cop
        FROM `@{schema_name}.master_records` t
        LEFT JOIN `@{schema_name}.dim_categories` c
          ON t.category_id = c.category_id
        WHERE t.is_transfer = FALSE
          AND t.type = 'expense'
        GROUP BY 1, 2, 3, 4, 5
      )
      SELECT
        CONCAT(year_month, '_', category_id) AS velocity_key,
        year_month,
        category_id,
        category_name,
        category_group,
        cardinality,
        transaction_count,
        monthly_spend_cop,
        LAG(monthly_spend_cop) OVER (
          PARTITION BY category_id
          ORDER BY year_month
        ) AS prev_month_spend_cop,
        monthly_spend_cop - LAG(monthly_spend_cop) OVER (
          PARTITION BY category_id
          ORDER BY year_month
        ) AS mom_delta_cop,
        ROUND(
          (monthly_spend_cop - LAG(monthly_spend_cop) OVER (PARTITION BY category_id ORDER BY year_month))
          / NULLIF(LAG(monthly_spend_cop) OVER (PARTITION BY category_id ORDER BY year_month), 0) * 100.0,
          2
        ) AS mom_growth_pct,
        ROUND(
          AVG(monthly_spend_cop) OVER (
            PARTITION BY category_id
            ORDER BY year_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
          ),
          2
        ) AS rolling_3m_avg_spend_cop
      FROM monthly_category_spend ;;
    datagroup_trigger: wallet_daily_datagroup
    indexes: ["year_month", "category_id"]
  }

  dimension: velocity_key {
    primary_key: yes
    type: string
    hidden: yes
    description: "Composite primary key (year_month + category_id)"
    sql: ${TABLE}.velocity_key ;;
  }

  dimension: year_month {
    type: string
    description: "Calendar month (YYYY-MM)"
    sql: ${TABLE}.year_month ;;
  }

  dimension: category_id {
    type: string
    description: "Category surrogate key"
    sql: ${TABLE}.category_id ;;
  }

  dimension: category_name {
    type: string
    description: "Granular spend category name"
    sql: ${TABLE}.category_name ;;
  }

  dimension: category_group {
    type: string
    description: "High-level category group"
    sql: ${TABLE}.category_group ;;
  }

  dimension: cardinality {
    type: string
    description: "Spending priority classification: must, need, or want"
    sql: ${TABLE}.cardinality ;;
  }

  dimension: transaction_count {
    type: number
    description: "Number of expense transactions in the month for this category"
    sql: ${TABLE}.transaction_count ;;
  }

  dimension: monthly_spend_cop {
    type: number
    description: "Monthly category spend in COP"
    sql: ${TABLE}.monthly_spend_cop ;;
    value_format_name: decimal_2
  }

  dimension: prev_month_spend_cop {
    type: number
    description: "Prior month spend in COP computed via LAG() window function"
    sql: ${TABLE}.prev_month_spend_cop ;;
    value_format_name: decimal_2
  }

  dimension: mom_delta_cop {
    type: number
    description: "Month-over-month spend change in COP (monthly_spend_cop - prev_month_spend_cop)"
    sql: ${TABLE}.mom_delta_cop ;;
    value_format_name: decimal_2
  }

  dimension: mom_growth_pct {
    type: number
    description: "Month-over-month spend acceleration percentage"
    sql: ${TABLE}.mom_growth_pct ;;
    value_format_name: decimal_2
  }

  dimension: rolling_3m_avg_spend_cop {
    type: number
    description: "Trailing 3-month rolling average spend in COP computed via window frame ROWS BETWEEN 2 PRECEDING AND CURRENT ROW"
    sql: ${TABLE}.rolling_3m_avg_spend_cop ;;
    value_format_name: decimal_2
  }

  measure: total_monthly_spend_cop {
    type: sum
    description: "Sum of monthly category spend in COP"
    sql: ${monthly_spend_cop} ;;
    value_format_name: decimal_2
  }

  measure: max_mom_delta_cop {
    type: max
    description: "Largest month-over-month spend increase in COP"
    sql: ${mom_delta_cop} ;;
    value_format_name: decimal_2
  }

  measure: average_rolling_3m_spend_cop {
    type: average
    description: "Average 3-month rolling category spend in COP"
    sql: ${rolling_3m_avg_spend_cop} ;;
    value_format_name: decimal_2
  }
}
