view: pdt_category_mom_velocity {
  description: "Persistent Derived Table tracking monthly category spend (net of refunds), month-over-month change and 3-month rolling averages. Grain: 1 row per year_month + category_id, with a row for every calendar month from the category's first spend onwards (0 when nothing was spent). All amounts in COP."
  derived_table: {
    sql:
      WITH category_spend AS (
        SELECT
          SUBSTR(CAST(t.date AS STRING), 1, 7) AS year_month,
          t.category_id,
          COUNT(CASE WHEN t.nature <> 'tier2_refund_offset' THEN 1 END) AS transaction_count,
          SUM(CASE WHEN t.nature = 'tier2_refund_offset' THEN -t.amount ELSE ABS(t.amount) END) AS monthly_spend_cop
        FROM `@{schema_name}.master_records` t
        WHERE t.is_transfer = FALSE
          AND t.nature IN ('tier1_operational_cost', 'tier2_capital_outlay', 'tier2_refund_offset')
        GROUP BY 1, 2
      ),
      -- Calendar spine: every month present in the ledger, so LAG() always compares with the previous calendar month
      months AS (
        SELECT DISTINCT SUBSTR(CAST(date AS STRING), 1, 7) AS year_month
        FROM `@{schema_name}.master_records`
      ),
      category_first_month AS (
        SELECT category_id, MIN(year_month) AS first_month
        FROM category_spend
        GROUP BY 1
      ),
      monthly_category_spend AS (
        SELECT
          m.year_month,
          f.category_id,
          COALESCE(s.transaction_count, 0) AS transaction_count,
          COALESCE(s.monthly_spend_cop, 0) AS monthly_spend_cop
        FROM category_first_month f
        CROSS JOIN months m
        LEFT JOIN category_spend s
          ON s.category_id = f.category_id
          AND s.year_month = m.year_month
        WHERE m.year_month >= f.first_month
      ),
      with_lag AS (
        SELECT
          mcs.*,
          LAG(mcs.monthly_spend_cop) OVER (PARTITION BY mcs.category_id ORDER BY mcs.year_month) AS prev_month_spend_cop
        FROM monthly_category_spend mcs
      )
      SELECT
        CONCAT(w.year_month, '_', w.category_id) AS velocity_key,
        w.year_month,
        w.category_id,
        c.category_name,
        c.category_group,
        CASE WHEN c.cardinality IS NULL OR c.cardinality = 'none' THEN 'unclassified' ELSE c.cardinality END AS cardinality,
        w.transaction_count,
        w.monthly_spend_cop,
        w.prev_month_spend_cop,
        w.monthly_spend_cop - w.prev_month_spend_cop AS mom_delta_cop,
        ROUND((w.monthly_spend_cop - w.prev_month_spend_cop) / NULLIF(w.prev_month_spend_cop, 0) * 100.0, 2) AS mom_growth_pct,
        ROUND(
          AVG(w.monthly_spend_cop) OVER (
            PARTITION BY w.category_id
            ORDER BY w.year_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
          ),
          2
        ) AS rolling_3m_avg_spend_cop
      FROM with_lag w
      LEFT JOIN `@{schema_name}.dim_categories` c
        ON w.category_id = c.category_id ;;
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

  dimension_group: velocity {
    type: time
    timeframes: [month, month_name, quarter, year]
    convert_tz: no
    datatype: date
    description: "Velocity month as a date, for month, quarter and year filters"
    sql: CAST(CONCAT(${TABLE}.year_month, '-01') AS DATE) ;;
  }

  dimension: category_id {
    type: string
    hidden: yes
    description: "Category surrogate key"
    sql: ${TABLE}.category_id ;;
  }

  dimension: category_name {
    type: string
    description: "Granular spend category name (from dim_categories)"
    sql: ${TABLE}.category_name ;;
  }

  dimension: category_group {
    type: string
    description: "High-level category group (from dim_categories)"
    sql: ${TABLE}.category_group ;;
  }

  dimension: cardinality {
    type: string
    description: "Spending priority classification: must, need, want or unclassified"
    sql: ${TABLE}.cardinality ;;
  }

  dimension: transaction_count {
    type: number
    description: "Number of expense transactions in the month for this category (0 for months without spend)"
    sql: ${TABLE}.transaction_count ;;
  }

  dimension: monthly_spend_cop {
    type: number
    description: "Category spend for the month net of refunds in COP (0 when nothing was spent)"
    sql: ${TABLE}.monthly_spend_cop ;;
    value_format_name: decimal_0
  }

  dimension: prev_month_spend_cop {
    type: number
    description: "Category spend in the previous calendar month in COP (NULL for the category's first month)"
    sql: ${TABLE}.prev_month_spend_cop ;;
    value_format_name: decimal_0
  }

  dimension: mom_delta_cop {
    type: number
    description: "Month-over-month spend change in COP (monthly_spend_cop - prev_month_spend_cop)"
    sql: ${TABLE}.mom_delta_cop ;;
    value_format_name: decimal_0
  }

  dimension: mom_growth_pct {
    type: number
    description: "Month-over-month spend change in percent vs the previous calendar month (NULL when the previous month had no spend)"
    sql: ${TABLE}.mom_growth_pct ;;
    value_format_name: decimal_2
  }

  dimension: rolling_3m_avg_spend_cop {
    type: number
    description: "Average category spend over the current and two previous calendar months in COP (months without spend count as 0)"
    sql: ${TABLE}.rolling_3m_avg_spend_cop ;;
    value_format_name: decimal_0
  }

  measure: total_monthly_spend_cop {
    type: sum
    description: "Sum of monthly category spend net of refunds in COP"
    sql: ${monthly_spend_cop} ;;
    value_format_name: decimal_0
  }

  measure: max_mom_delta_cop {
    type: max
    description: "Largest month-over-month spend increase in COP"
    sql: ${mom_delta_cop} ;;
    value_format_name: decimal_0
  }

  measure: average_rolling_3m_spend_cop {
    type: average
    description: "Average 3-month rolling category spend in COP"
    sql: ${rolling_3m_avg_spend_cop} ;;
    value_format_name: decimal_0
  }
}
