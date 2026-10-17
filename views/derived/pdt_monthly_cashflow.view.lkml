view: pdt_monthly_cashflow {
  derived_table: {
    sql:
      SELECT
        DATE_TRUNC(t.transaction_date, MONTH) AS month_date,
        COUNT(DISTINCT t.transaction_id) AS total_transactions,
        SUM(CASE WHEN t.is_transfer = FALSE AND t.amount_usd > 0 THEN t.amount_usd ELSE 0 END) AS monthly_income_usd,
        SUM(CASE WHEN t.is_transfer = FALSE AND t.amount_usd < 0 THEN ABS(t.amount_usd) ELSE 0 END) AS monthly_spend_usd,
        SUM(CASE WHEN t.is_transfer = FALSE AND t.amount_usd < 0 AND c.accounting_tier = 1 THEN ABS(t.amount_usd) ELSE 0 END) AS tier1_spend_usd,
        SUM(CASE WHEN t.is_transfer = FALSE AND t.amount_usd < 0 AND c.accounting_tier = 2 THEN ABS(t.amount_usd) ELSE 0 END) AS tier2_spend_usd
      FROM `@{schema_name}.fct_transactions` t
      LEFT JOIN `@{schema_name}.dim_categories` c ON t.category_id = c.category_id
      GROUP BY 1 ;;
    datagroup_trigger: wallet_daily_datagroup
    indexes: ["month_date"]
  }

  dimension: month_date {
    primary_key: yes
    type: date
    description: "First day of the aggregated calendar month"
    sql: ${TABLE}.month_date ;;
  }

  dimension: total_transactions {
    type: number
    sql: ${TABLE}.total_transactions ;;
  }

  dimension: monthly_income_usd {
    type: number
    sql: ${TABLE}.monthly_income_usd ;;
    value_format_name: usd
  }

  dimension: monthly_spend_usd {
    type: number
    sql: ${TABLE}.monthly_spend_usd ;;
    value_format_name: usd
  }

  dimension: tier1_spend_usd {
    type: number
    sql: ${TABLE}.tier1_spend_usd ;;
    value_format_name: usd
  }

  dimension: tier2_spend_usd {
    type: number
    sql: ${TABLE}.tier2_spend_usd ;;
    value_format_name: usd
  }

  measure: total_monthly_burn_usd {
    type: sum
    description: "Sum of monthly spend from pre-aggregated PDT"
    sql: ${monthly_spend_usd} ;;
    value_format_name: usd
  }

  measure: total_monthly_income_usd {
    type: sum
    description: "Sum of monthly income from pre-aggregated PDT"
    sql: ${monthly_income_usd} ;;
    value_format_name: usd
  }

  measure: average_monthly_burn_rate {
    type: average
    description: "Average monthly burn rate across the selected timeframe"
    sql: ${monthly_spend_usd} ;;
    value_format_name: usd
  }
}
