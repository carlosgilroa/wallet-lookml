view: mart_monthly_pnl {
  sql_table_name: `@{schema_name}.mart_monthly_pnl` ;;
  description: "Pre-aggregated monthly Two-Tier P&L mart. Grain: 1 row per calendar month (year_month). All amounts in COP; spend is net of refunds and income excludes refunds."

  dimension: year_month {
    primary_key: yes
    type: string
    description: "Calendar month in YYYY-MM format (primary grain of monthly P&L)"
    sql: ${TABLE}.year_month ;;
  }

  dimension_group: pnl {
    type: time
    timeframes: [month, month_name, quarter, year]
    convert_tz: no
    datatype: date
    description: "P&L month as a date, for month, quarter and year filters (e.g. 'last 3 months', 'this year')"
    sql: CAST(CONCAT(${TABLE}.year_month, '-01') AS DATE) ;;
  }

  # ---------------- SINGLE-MONTH VALUES ----------------
  # Use the measures below to aggregate across months; these are the per-month values.

  dimension: operating_income {
    type: number
    description: "Tier 1 operating income for the month in COP"
    sql: ${TABLE}.operating_income ;;
    value_format_name: decimal_0
  }

  dimension: operational_expenses {
    type: number
    description: "Tier 1 operational living expenses for the month in COP"
    sql: ${TABLE}.operational_expenses ;;
    value_format_name: decimal_0
  }

  dimension: operating_margin {
    type: number
    description: "Tier 1 operating margin for the month in COP (operating_income - operational_expenses)"
    sql: ${TABLE}.operating_margin ;;
    value_format_name: decimal_0
  }

  dimension: capital_income {
    type: number
    description: "Tier 2 capital inflows for the month in COP"
    sql: ${TABLE}.capital_income ;;
    value_format_name: decimal_0
  }

  dimension: capital_expenses {
    type: number
    description: "Tier 2 capital spend for the month in COP, net of refunds (capital outlays - refunds)"
    sql: ${TABLE}.capital_expenses ;;
    value_format_name: decimal_0
  }

  dimension: total_income {
    type: number
    description: "Total income for the month in COP (operating_income + capital_income)"
    sql: ${TABLE}.total_income ;;
    value_format_name: decimal_0
  }

  dimension: total_expenses {
    type: number
    description: "Total spend for the month in COP, net of refunds (operational_expenses + capital_expenses)"
    sql: ${TABLE}.total_expenses ;;
    value_format_name: decimal_0
  }

  dimension: net_cashflow {
    type: number
    description: "Net cashflow for the month across all tiers in COP (total_income - total_expenses)"
    sql: ${TABLE}.net_cashflow ;;
    value_format_name: decimal_0
  }

  dimension: monthly_savings_rate_pct {
    type: number
    description: "Total savings rate for this single month in percent (net_cashflow / total_income * 100). NULL when the month had no income. Use the Savings Rate measure for multi-month periods."
    sql: ${TABLE}.total_savings_rate_pct ;;
    value_format_name: decimal_2
  }

  dimension: monthly_operating_savings_rate_pct {
    type: number
    description: "Tier 1 operating savings rate for this single month in percent (operating_margin / operating_income * 100). NULL when the month had no operating income."
    sql: ${TABLE}.savings_rate_pct ;;
    value_format_name: decimal_2
  }

  dimension: transaction_count {
    type: number
    hidden: yes
    description: "Number of P&L transactions in the month (excludes transfers). Use the Total Transactions measure."
    sql: ${TABLE}.transaction_count ;;
  }

  # ---------------- MEASURES ----------------

  measure: total_operating_income {
    type: sum
    description: "Tier 1 operating income across the selected months in COP"
    sql: ${operating_income} ;;
    value_format_name: decimal_0
  }

  measure: total_operational_expenses {
    type: sum
    description: "Tier 1 operational expenses across the selected months in COP"
    sql: ${operational_expenses} ;;
    value_format_name: decimal_0
  }

  measure: total_operating_margin {
    type: sum
    description: "Tier 1 operating margin across the selected months in COP"
    sql: ${operating_margin} ;;
    value_format_name: decimal_0
  }

  measure: total_capital_income {
    type: sum
    description: "Tier 2 capital inflows across the selected months in COP"
    sql: ${capital_income} ;;
    value_format_name: decimal_0
  }

  measure: total_capital_expenses {
    type: sum
    description: "Tier 2 capital spend net of refunds across the selected months in COP"
    sql: ${capital_expenses} ;;
    value_format_name: decimal_0
  }

  measure: total_income_cop {
    type: sum
    description: "DEFAULT income metric. Total income across the selected months in COP (operating + capital, excludes refunds)"
    sql: ${total_income} ;;
    value_format_name: decimal_0
  }

  measure: total_spend_cop {
    type: sum
    description: "DEFAULT spend metric. Total spend net of refunds across the selected months in COP (operational + capital)"
    sql: ${total_expenses} ;;
    value_format_name: decimal_0
  }

  measure: total_net_cashflow {
    type: sum
    description: "Cumulative net cashflow across the selected months in COP"
    sql: ${net_cashflow} ;;
    value_format_name: decimal_0
  }

  measure: savings_rate_pct {
    type: number
    description: "DEFAULT savings rate. Total savings rate in percent over the selected months: SUM(net_cashflow) / SUM(total_income) * 100. NULL when there is no income."
    sql: ${total_net_cashflow} / NULLIF(${total_income_cop}, 0) * 100.0 ;;
    value_format_name: decimal_2
  }

  measure: operating_savings_rate_pct {
    type: number
    description: "Tier 1 operating savings rate in percent over the selected months: SUM(operating_margin) / SUM(operating_income) * 100. Use only when the question is about Tier 1 / living expenses."
    sql: ${total_operating_margin} / NULLIF(${total_operating_income}, 0) * 100.0 ;;
    value_format_name: decimal_2
  }

  measure: total_transactions {
    type: sum
    description: "Number of P&L transactions across the selected months (excludes transfers)"
    sql: ${transaction_count} ;;
  }
}
