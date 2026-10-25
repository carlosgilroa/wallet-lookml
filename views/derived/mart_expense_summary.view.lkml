view: mart_expense_summary {
  sql_table_name: `@{schema_name}.mart_expense_summary` ;;
  description: "Monthly spend segmented by accounting tier, category, merchant and labels. Grain: 1 row per year_month + tier_group + category_name + merchant + labels. All amounts in COP. For budget questions use mart_category_budget."

  dimension: expense_summary_pk {
    primary_key: yes
    type: string
    hidden: yes
    description: "Compound primary key: year_month + tier_group + category_name + merchant + labels"
    sql: CONCAT(${TABLE}.year_month, '_', ${TABLE}.tier_group, '_', ${TABLE}.category_name, '_', COALESCE(${TABLE}.merchant, 'none'), '_', COALESCE(${TABLE}.labels, 'none')) ;;
  }

  dimension_group: expense {
    type: time
    timeframes: [month, month_name, quarter, year]
    convert_tz: no
    datatype: date
    description: "Expense month as a date, for month, quarter and year filters (column: month_date)"
    sql: ${TABLE}.month_date ;;
  }

  dimension: year_month {
    type: string
    description: "Expense calendar month (YYYY-MM)"
    sql: ${TABLE}.year_month ;;
  }

  dimension: tier_group {
    type: string
    description: "Two-Tier group: 'Tier 1: Operational Living' or 'Tier 2: Capital & Sinking Funds'"
    sql: ${TABLE}.tier_group ;;
  }

  dimension: category_group {
    type: string
    description: "High-level expense category group"
    sql: ${TABLE}.category_group ;;
  }

  dimension: category_name {
    type: string
    description: "Granular spend category name"
    sql: ${TABLE}.category_name ;;
  }

  dimension: merchant {
    type: string
    description: "Merchant or vendor name"
    sql: ${TABLE}.merchant ;;
  }

  dimension: labels {
    type: string
    description: "Display-only list of label names on the transactions in this row. Label names can contain commas; use the Transaction Labels explore for label analysis."
    sql: ${TABLE}.labels ;;
  }

  dimension: gross_spent {
    type: number
    description: "Spend before refunds for this row in COP"
    sql: ${TABLE}.gross_spent ;;
    value_format_name: decimal_0
  }

  dimension: refunds_credit {
    type: number
    description: "Refunds and credits offsetting spend for this row in COP"
    sql: ${TABLE}.refunds_credit ;;
    value_format_name: decimal_0
  }

  dimension: net_spent {
    type: number
    description: "Spend net of refunds for this row in COP (gross_spent - refunds_credit)"
    sql: ${TABLE}.net_spent ;;
    value_format_name: decimal_0
  }

  dimension: transaction_count {
    type: number
    hidden: yes
    description: "Number of expense and refund transactions in this row. Use the Total Transactions measure."
    sql: ${TABLE}.transaction_count ;;
  }

  dimension: avg_ticket {
    type: number
    description: "Average expense ticket for this row in COP (gross_spent / number of expenses)"
    sql: ${TABLE}.avg_ticket ;;
    value_format_name: decimal_0
  }

  # Budget columns are category-month values repeated on every merchant/label row of that
  # category-month. They must not be summed here; mart_category_budget has them at their own grain.

  dimension: recommended_budget_cap {
    type: number
    description: "P80 monthly budget cap for the row's category in COP (Tier 1 only). Category-month value repeated on every row; do not sum, use mart_category_budget."
    sql: ${TABLE}.recommended_budget_cap ;;
    value_format_name: decimal_0
  }

  dimension: category_month_net_spent {
    type: number
    description: "Net spend of the whole category in this month in COP (Tier 1 only). Category-month value repeated on every row; do not sum."
    sql: ${TABLE}.category_month_net_spent ;;
    value_format_name: decimal_0
  }

  dimension: budget_variance {
    type: number
    description: "Budget cap minus the category's net spend for the month in COP (negative = over budget). Category-month value; do not sum."
    sql: ${TABLE}.budget_variance ;;
    value_format_name: decimal_0
  }

  dimension: budget_utilization_pct {
    type: number
    description: "Category's net spend for the month as a percentage of its budget cap. Category-month value."
    sql: ${TABLE}.budget_utilization_pct ;;
    value_format_name: decimal_2
  }

  dimension: budget_status {
    type: string
    description: "Category-month budget status: 'On Track', 'Exceeded' or 'No Cap (Sinking Fund)' for Tier 2"
    sql: ${TABLE}.budget_status ;;
  }

  # ---------------- MEASURES ----------------

  measure: total_spend_cop {
    type: sum
    description: "DEFAULT spend metric. Spend net of refunds across the selected rows in COP"
    sql: ${net_spent} ;;
    value_format_name: decimal_0
  }

  measure: gross_spend_cop {
    type: sum
    description: "Spend before refunds across the selected rows in COP"
    sql: ${gross_spent} ;;
    value_format_name: decimal_0
  }

  measure: total_refunds_cop {
    type: sum
    description: "Refunds and credits across the selected rows in COP"
    sql: ${refunds_credit} ;;
    value_format_name: decimal_0
  }

  measure: total_transactions {
    type: sum
    description: "Number of expense and refund transactions across the selected rows"
    sql: ${transaction_count} ;;
  }
}
