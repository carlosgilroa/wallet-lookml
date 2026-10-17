view: fct_transactions {
  sql_table_name: `@{schema_name}.fct_transactions` ;;

  # ---------------- KEYS ----------------

  dimension: transaction_id {
    primary_key: yes
    type: string
    description: "Unique identifier for each transaction event (UUID / Hash)"
    sql: ${TABLE}.transaction_id ;;
  }

  dimension: account_id {
    type: string
    hidden: yes
    description: "Foreign key to dim_accounts"
    sql: ${TABLE}.account_id ;;
  }

  dimension: category_id {
    type: string
    hidden: yes
    description: "Foreign key to dim_categories"
    sql: ${TABLE}.category_id ;;
  }

  # ---------------- TIMEFRAMES ----------------

  dimension_group: transaction {
    type: time
    timeframes: [raw, time, date, week, month, quarter, year]
    datatype: date
    sql: ${TABLE}.transaction_date ;;
    description: "Event execution date"
  }

  # ---------------- RAW AMOUNTS & ATTRIBUTES ----------------

  dimension: original_currency {
    type: string
    description: "Original settlement currency (COP, EUR, USD)"
    sql: ${TABLE}.currency ;;
  }

  dimension: amount_original {
    type: number
    description: "Raw transaction amount in native currency"
    sql: ${TABLE}.amount_original ;;
    value_format_name: decimal_2
  }

  dimension: amount_usd {
    type: number
    description: "Normalized transaction amount in USD using daily TRM rate"
    sql: ${TABLE}.amount_usd ;;
    value_format_name: usd
  }

  dimension: amount_cop {
    type: number
    description: "Normalized transaction amount in Colombian Pesos (COP)"
    sql: ${TABLE}.amount_cop ;;
    value_format_name: usd_0
  }

  dimension: is_transfer {
    type: yesno
    description: "Indicates internal transfer between owned accounts (excluded from P&L)"
    sql: ${TABLE}.is_transfer ;;
  }

  dimension: transaction_type {
    type: string
    description: "Income, Expense, or Transfer"
    case: {
      when: {
        sql: ${is_transfer} = true ;;
        label: "Transfer"
      }
      when: {
        sql: ${amount_usd} > 0 ;;
        label: "Income"
      }
      when: {
        sql: ${amount_usd} < 0 ;;
        label: "Expense"
      }
      else: "Neutral"
    }
  }

  # ---------------- MEASURES ----------------

  measure: transaction_count {
    type: count
    description: "Total number of recorded transactions"
    drill_fields: [transaction_id, transaction_date, dim_accounts.account_name, dim_categories.category_name, amount_usd]
  }

  measure: total_spend_usd {
    type: sum
    description: "Total cash outflow in USD (excluding transfers)"
    sql: ABS(${amount_usd}) ;;
    filters: [is_transfer: "no", amount_usd: "<0"]
    value_format_name: usd
    drill_fields: [transaction_id, transaction_date, dim_categories.category_name, amount_usd]
  }

  measure: total_income_usd {
    type: sum
    description: "Total cash inflow in USD (excluding transfers)"
    sql: ${amount_usd} ;;
    filters: [is_transfer: "no", amount_usd: ">0"]
    value_format_name: usd
    drill_fields: [transaction_id, transaction_date, dim_categories.category_name, amount_usd]
  }

  measure: net_cash_flow_usd {
    type: number
    description: "Net cash flow (Total Income - Total Spend) in USD"
    sql: ${total_income_usd} - ${total_spend_usd} ;;
    value_format_name: usd
  }

  measure: tier1_operational_spend_usd {
    type: sum
    description: "Two-Tier Accounting: Essential routine living burn rate (Tier 1)"
    sql: ABS(${amount_usd}) ;;
    filters: [is_transfer: "no", amount_usd: "<0", dim_categories.accounting_tier: "1"]
    value_format_name: usd
  }

  measure: tier2_sinking_fund_spend_usd {
    type: sum
    description: "Two-Tier Accounting: Capital sinking funds and investments (Tier 2)"
    sql: ABS(${amount_usd}) ;;
    filters: [is_transfer: "no", amount_usd: "<0", dim_categories.accounting_tier: "2"]
    value_format_name: usd
  }

  measure: savings_rate_percentage {
    type: number
    description: "Percentage of total income retained or allocated to Tier 2 capital funds"
    sql: SAFE_DIVIDE(${net_cash_flow_usd}, ${total_income_usd}) ;;
    value_format_name: percent_2
  }

  measure: average_expense_ticket_usd {
    type: average
    description: "Average expense ticket size in USD"
    sql: ABS(${amount_usd}) ;;
    filters: [is_transfer: "no", amount_usd: "<0"]
    value_format_name: usd
  }
}
