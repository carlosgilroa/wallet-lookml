view: fct_transactions {
  sql_table_name: `@{schema_name}.master_records` ;;
  description: "Master multi-currency transaction ledger (master_records). Grain: 1 row per financial transaction event (id)."

  # ---------------- KEYS ----------------

  dimension: transaction_id {
    primary_key: yes
    type: string
    description: "Unique identifier for each transaction event in master_records (column: id)"
    sql: ${TABLE}.id ;;
  }

  dimension: account_id {
    type: string
    description: "Foreign key to dim_accounts"
    sql: ${TABLE}.account_id ;;
  }

  dimension: account_name {
    type: string
    description: "Account name on the transaction ledger"
    sql: ${TABLE}.account_name ;;
  }

  dimension: account_class {
    type: string
    description: "Classification of the account on the transaction record"
    sql: ${TABLE}.account_class ;;
  }

  dimension: category_id {
    type: string
    description: "Foreign key to dim_categories"
    sql: ${TABLE}.category_id ;;
  }

  dimension: category_name {
    type: string
    description: "Granular category name on the transaction record"
    sql: ${TABLE}.category_name ;;
  }

  dimension: category_group {
    type: string
    description: "High-level category group on the transaction record"
    sql: ${TABLE}.category_group ;;
  }

  # ---------------- TIMEFRAMES ----------------

  dimension_group: transaction {
    type: time
    timeframes: [raw, time, date, week, month, quarter, year]
    datatype: date
    sql: CAST(${TABLE}.date AS DATE) ;;
    description: "Transaction execution date (stored as YYYY-MM-DD in column: date)"
  }

  # ---------------- RAW AMOUNTS & ATTRIBUTES ----------------

  dimension: original_currency {
    type: string
    description: "Settlement currency code (COP, EUR, USD)"
    sql: ${TABLE}.currency ;;
  }

  dimension: amount_original {
    type: number
    description: "Raw transaction amount in native currency (column: raw_amount)"
    sql: ${TABLE}.raw_amount ;;
    value_format_name: decimal_2
  }

  dimension: amount_cop {
    type: number
    description: "Normalized transaction amount in Colombian Pesos (COP, column: amount)"
    sql: ${TABLE}.amount ;;
    value_format_name: decimal_2
  }

  dimension: amount_usd {
    type: number
    description: "Transaction amount normalized to COP/USD in master_records (column: amount)"
    sql: ${TABLE}.amount ;;
    value_format_name: usd
  }

  dimension: is_transfer {
    type: yesno
    description: "Indicates internal transfer between owned accounts (excluded from P&L)"
    sql: ${TABLE}.is_transfer ;;
  }

  dimension: type {
    type: string
    description: "Transaction direction type in master_records: expense, income, or transfer"
    sql: ${TABLE}.type ;;
  }

  dimension: nature {
    type: string
    description: "Two-Tier accounting nature: tier1_operational_cost, tier2_capital_outlay, tier1_operating_income, tier2_capital_inflow, tier2_refund_offset, or transfer"
    sql: ${TABLE}.nature ;;
  }

  dimension: tier_group {
    type: string
    description: "Two-Tier accounting group classification (Tier 1 vs Tier 2)"
    sql: ${TABLE}.tier_group ;;
  }

  dimension: merchant {
    type: string
    description: "Cleaned merchant or vendor name"
    sql: ${TABLE}.merchant ;;
  }

  dimension: payee {
    type: string
    description: "Counterparty or payee name"
    sql: ${TABLE}.payee ;;
  }

  dimension: labels {
    type: string
    description: "Comma-separated labels attached to the transaction"
    sql: ${TABLE}.labels ;;
  }

  dimension: transaction_type {
    type: string
    description: "Human-readable Income, Expense, or Transfer classification"
    case: {
      when: {
        sql: ${TABLE}.is_transfer = true ;;
        label: "Transfer"
      }
      when: {
        sql: ${TABLE}.type = 'income' ;;
        label: "Income"
      }
      when: {
        sql: ${TABLE}.type = 'expense' ;;
        label: "Expense"
      }
      else: "Neutral"
    }
  }

  # ---------------- MEASURES ----------------

  measure: transaction_count {
    type: count
    description: "Total number of recorded transactions in master_records"
    drill_fields: [transaction_id, account_name, category_name, amount_cop]
  }

  measure: total_spend_cop {
    type: sum
    description: "Total cash outflow in COP (excluding transfers)"
    sql: ABS(${TABLE}.amount) ;;
    filters: [is_transfer: "no", type: "expense"]
    value_format_name: decimal_2
  }

  measure: total_spend_usd {
    type: sum
    description: "Total cash outflow (excluding transfers) from master_records"
    sql: ABS(${TABLE}.amount) ;;
    filters: [is_transfer: "no", type: "expense"]
    value_format_name: usd
    drill_fields: [transaction_id, category_name, amount_cop]
  }

  measure: total_income_cop {
    type: sum
    description: "Total cash inflow in COP (excluding transfers)"
    sql: ${TABLE}.amount ;;
    filters: [is_transfer: "no", type: "income"]
    value_format_name: decimal_2
  }

  measure: total_income_usd {
    type: sum
    description: "Total cash inflow (excluding transfers) from master_records"
    sql: ${TABLE}.amount ;;
    filters: [is_transfer: "no", type: "income"]
    value_format_name: usd
    drill_fields: [transaction_id, category_name, amount_cop]
  }

  measure: net_cash_flow_usd {
    type: number
    description: "Net cash flow (Total Income - Total Spend)"
    sql: ${total_income_usd} - ${total_spend_usd} ;;
    value_format_name: usd
  }

  measure: tier1_operational_spend_usd {
    type: sum
    description: "Two-Tier Accounting: Essential routine living burn rate (Tier 1 operational costs)"
    sql: ABS(${TABLE}.amount) ;;
    filters: [is_transfer: "no", type: "expense", nature: "tier1_operational_cost"]
    value_format_name: usd
  }

  measure: tier2_sinking_fund_spend_usd {
    type: sum
    description: "Two-Tier Accounting: Capital outlays, sinking funds, and investments (Tier 2)"
    sql: ABS(${TABLE}.amount) ;;
    filters: [is_transfer: "no", type: "expense", nature: "tier2_capital_outlay"]
    value_format_name: usd
  }

  measure: savings_rate_percentage {
    type: number
    description: "Percentage of total income retained after expenses ((total_income - total_spend) / NULLIF(total_income, 0) * 100)"
    sql: (${total_income_usd} - ${total_spend_usd}) / NULLIF(${total_income_usd}, 0) * 100 ;;
    value_format_name: decimal_2
  }

  measure: average_expense_ticket_usd {
    type: average
    description: "Average expense ticket size"
    sql: ABS(${TABLE}.amount) ;;
    filters: [is_transfer: "no", type: "expense"]
    value_format_name: usd
  }
}
