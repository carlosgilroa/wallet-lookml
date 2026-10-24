view: mart_expense_summary {
  sql_table_name: `@{schema_name}.mart_expense_summary` ;;
  description: "Monthly expense summary segmented by accounting tier, category, merchant, and labels. Grain: 1 row per year_month + tier_group + category_name + merchant + labels."

  dimension: expense_summary_pk {
    primary_key: yes
    type: string
    hidden: yes
    description: "Compound primary key: year_month + tier_group + category_name + merchant + labels"
    sql: CONCAT(${TABLE}.year_month, '_', ${TABLE}.tier_group, '_', ${TABLE}.category_name, '_', COALESCE(${TABLE}.merchant, 'none'), '_', COALESCE(${TABLE}.labels, 'none')) ;;
  }

  dimension: month_date {
    type: date
    description: "First day of the expense month (DATE)"
    sql: ${TABLE}.month_date ;;
  }

  dimension: year_month {
    type: string
    description: "Expense calendar month (YYYY-MM)"
    sql: ${TABLE}.year_month ;;
  }

  dimension: year {
    type: number
    description: "Calendar year (INTEGER)"
    sql: ${TABLE}.year ;;
  }

  dimension: month {
    type: number
    description: "Calendar month number (1-12)"
    sql: ${TABLE}.month ;;
  }

  dimension: tier_group {
    type: string
    description: "Two-Tier accounting classification (Tier 1 Operational vs Tier 2 Capital)"
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
    description: "Transaction labels/tags"
    sql: ${TABLE}.labels ;;
  }

  dimension: gross_spent {
    type: number
    description: "Gross expenditure before refunds in COP"
    sql: ${TABLE}.gross_spent ;;
    value_format_name: decimal_2
  }

  dimension: refunds_credit {
    type: number
    description: "Refunds and credits offsetting spend in COP"
    sql: ${TABLE}.refunds_credit ;;
    value_format_name: decimal_2
  }

  dimension: net_spent {
    type: number
    description: "Net expenditure after refunds (gross_spent - refunds_credit) in COP"
    sql: ${TABLE}.net_spent ;;
    value_format_name: decimal_2
  }

  dimension: transaction_count {
    type: number
    description: "Number of expense transactions in this category/month"
    sql: ${TABLE}.transaction_count ;;
  }

  dimension: avg_ticket {
    type: number
    description: "Average expense ticket in COP"
    sql: ${TABLE}.avg_ticket ;;
    value_format_name: decimal_2
  }

  dimension: recommended_budget_cap {
    type: number
    description: "Recommended monthly budget cap for the category in COP"
    sql: ${TABLE}.recommended_budget_cap ;;
    value_format_name: decimal_2
  }

  dimension: budget_variance {
    type: number
    description: "Budget variance (recommended_budget_cap - net_spent) in COP"
    sql: ${TABLE}.budget_variance ;;
    value_format_name: decimal_2
  }

  dimension: budget_utilization_pct {
    type: number
    description: "Percentage of budget cap utilized"
    sql: ${TABLE}.budget_utilization_pct ;;
    value_format_name: decimal_2
  }

  dimension: budget_status {
    type: string
    description: "Budget compliance status (e.g. On Track, Over Budget, Warning)"
    sql: ${TABLE}.budget_status ;;
  }

  # ---------------- MEASURES ----------------

  measure: total_net_spent {
    type: sum
    description: "Total net spend after refunds across selected categories and months in COP"
    sql: ${net_spent} ;;
    value_format_name: decimal_2
  }

  measure: total_gross_spent {
    type: sum
    description: "Total gross spend before refunds in COP"
    sql: ${gross_spent} ;;
    value_format_name: decimal_2
  }

  measure: total_refunds_credit {
    type: sum
    description: "Total refunds and credits in COP"
    sql: ${refunds_credit} ;;
    value_format_name: decimal_2
  }
}
