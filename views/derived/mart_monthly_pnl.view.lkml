view: mart_monthly_pnl {
  sql_table_name: `@{schema_name}.mart_monthly_pnl` ;;

  dimension: year_month {
    primary_key: yes
    type: string
    description: "Calendar month in YYYY-MM format (primary grain of monthly P&L)"
    sql: ${TABLE}.year_month ;;
  }

  dimension: operating_income {
    type: number
    description: "Monthly Tier 1 operating income in COP"
    sql: ${TABLE}.operating_income ;;
    value_format_name: decimal_2
  }

  dimension: operational_expenses {
    type: number
    description: "Monthly Tier 1 routine operational living expenses in COP"
    sql: ${TABLE}.operational_expenses ;;
    value_format_name: decimal_2
  }

  dimension: operating_margin {
    type: number
    description: "Monthly operating margin (operating_income - operational_expenses) in COP"
    sql: ${TABLE}.operating_margin ;;
    value_format_name: decimal_2
  }

  dimension: capital_income {
    type: number
    description: "Monthly Tier 2 capital inflows and investment returns in COP"
    sql: ${TABLE}.capital_income ;;
    value_format_name: decimal_2
  }

  dimension: capital_expenses {
    type: number
    description: "Monthly Tier 2 capital outlays, sinking funds, and irregular investments in COP"
    sql: ${TABLE}.capital_expenses ;;
    value_format_name: decimal_2
  }

  dimension: net_cashflow {
    type: number
    description: "Reconciled monthly net cashflow across all tiers in COP"
    sql: ${TABLE}.net_cashflow ;;
    value_format_name: decimal_2
  }

  dimension: savings_rate_pct {
    type: number
    description: "Single-month savings rate percentage in mart_monthly_pnl"
    sql: ${TABLE}.savings_rate_pct ;;
    value_format_name: decimal_2
  }

  dimension: transaction_count {
    type: number
    description: "Total reconciled transactions in the month"
    sql: ${TABLE}.transaction_count ;;
  }

  # ---------------- DYNAMIC MULTI-PERIOD MEASURES ----------------

  measure: total_operating_income {
    type: sum
    description: "Total operating income across selected months in COP"
    sql: ${operating_income} ;;
    value_format_name: decimal_2
  }

  measure: total_operational_expenses {
    type: sum
    description: "Total Tier 1 operational expenses across selected months in COP"
    sql: ${operational_expenses} ;;
    value_format_name: decimal_2
  }

  measure: total_capital_expenses {
    type: sum
    description: "Total Tier 2 capital outlays across selected months in COP"
    sql: ${capital_expenses} ;;
    value_format_name: decimal_2
  }

  measure: total_net_cashflow {
    type: sum
    description: "Cumulative net cashflow across selected months in COP"
    sql: ${net_cashflow} ;;
    value_format_name: decimal_2
  }

  measure: period_savings_rate_pct {
    type: number
    description: "True multi-month savings rate percentage (SUM(net_cashflow) / NULLIF(SUM(operating_income), 0) * 100) avoiding Simpson's paradox"
    sql: ${total_net_cashflow} / NULLIF(${total_operating_income}, 0) * 100.0 ;;
    value_format_name: decimal_2
  }
}
