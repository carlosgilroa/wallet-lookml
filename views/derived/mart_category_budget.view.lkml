view: mart_category_budget {
  sql_table_name: `@{schema_name}.mart_category_budget` ;;
  description: "Tier 1 category budget tracking. Grain: 1 row per year_month + category_group + category_name. Compares net spend with a recommended cap (P80 of the category's last 6 completed months). All amounts in COP."

  dimension: category_budget_pk {
    primary_key: yes
    type: string
    hidden: yes
    description: "Compound primary key: year_month + category_group + category_name"
    sql: CONCAT(${TABLE}.year_month, '_', ${TABLE}.category_group, '_', ${TABLE}.category_name) ;;
  }

  dimension_group: budget {
    type: time
    timeframes: [month, month_name, quarter, year]
    convert_tz: no
    datatype: date
    description: "Budget month as a date (column: month_date)"
    sql: ${TABLE}.month_date ;;
  }

  dimension: year_month {
    type: string
    description: "Budget calendar month (YYYY-MM)"
    sql: ${TABLE}.year_month ;;
  }

  dimension: category_group {
    type: string
    description: "High-level category group"
    sql: ${TABLE}.category_group ;;
  }

  dimension: category_name {
    type: string
    description: "Granular Tier 1 spend category"
    sql: ${TABLE}.category_name ;;
  }

  dimension: net_spent {
    type: number
    description: "Category spend for the month net of refunds in COP"
    sql: ${TABLE}.net_spent ;;
    value_format_name: decimal_0
  }

  dimension: recommended_budget_cap {
    type: number
    description: "Recommended monthly budget cap for the category in COP (P80 of the last 6 completed months, rounded to the nearest 100)"
    sql: ${TABLE}.recommended_budget_cap ;;
    value_format_name: decimal_0
  }

  dimension: budget_variance {
    type: number
    description: "Budget cap minus net spend for the month in COP (negative = over budget)"
    sql: ${TABLE}.budget_variance ;;
    value_format_name: decimal_0
  }

  dimension: budget_utilization_pct {
    type: number
    description: "Net spend as a percentage of the budget cap"
    sql: ${TABLE}.budget_utilization_pct ;;
    value_format_name: decimal_2
  }

  dimension: budget_status {
    type: string
    description: "'On Track' (spend <= cap) or 'Exceeded' (spend > cap)"
    sql: ${TABLE}.budget_status ;;
  }

  dimension: is_over_budget {
    type: yesno
    description: "Whether the category spent more than its cap this month"
    sql: ${TABLE}.budget_status = 'Exceeded' ;;
  }

  measure: total_spend_cop {
    type: sum
    description: "Tier 1 spend net of refunds across the selected categories and months in COP"
    sql: ${net_spent} ;;
    value_format_name: decimal_0
  }

  measure: total_budget_cap_cop {
    type: sum
    description: "Sum of budget caps across the selected categories and months in COP"
    sql: ${recommended_budget_cap} ;;
    value_format_name: decimal_0
  }

  measure: total_budget_variance_cop {
    type: number
    description: "Total budget cap minus total spend in COP (negative = over budget overall)"
    sql: ${total_budget_cap_cop} - ${total_spend_cop} ;;
    value_format_name: decimal_0
  }

  measure: overall_budget_utilization_pct {
    type: number
    description: "Total spend as a percentage of total budget cap"
    sql: ${total_spend_cop} / NULLIF(${total_budget_cap_cop}, 0) * 100.0 ;;
    value_format_name: decimal_2
  }

  measure: categories_over_budget {
    type: count
    description: "Number of category-months whose spend exceeded the cap"
    filters: [is_over_budget: "yes"]
    drill_fields: [year_month, category_name, net_spent, recommended_budget_cap, budget_variance]
  }

  measure: category_month_count {
    type: count
    description: "Number of category-months with Tier 1 spend"
  }
}
