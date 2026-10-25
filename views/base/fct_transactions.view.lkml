view: fct_transactions {
  sql_table_name: `@{schema_name}.master_records` ;;
  description: "Master transaction ledger (master_records). Grain: 1 row per financial transaction event (id). All amounts are in COP."

  # ---------------- KEYS ----------------

  dimension: transaction_id {
    primary_key: yes
    type: string
    description: "Unique identifier for each transaction event in master_records (column: id)"
    sql: ${TABLE}.id ;;
  }

  dimension: account_id {
    hidden: yes
    type: string
    description: "Foreign key to dim_accounts"
    sql: ${TABLE}.account_id ;;
  }

  dimension: account_name {
    type: string
    description: "Account the transaction was recorded on (e.g. Bancolombia, Nu, Carlos Savings)"
    sql: ${TABLE}.account_name ;;
  }

  dimension: account_class {
    type: string
    description: "Two-Tier classification of the account the transaction was recorded on"
    sql: ${TABLE}.account_class ;;
  }

  dimension: category_id {
    hidden: yes
    type: string
    description: "Foreign key to dim_categories"
    sql: ${TABLE}.category_id ;;
  }

  # Category names are copied onto the ledger at ingestion time and can go stale
  # (e.g. 'Travel' vs 'Travel Transport'). Use dim_categories for category analysis.
  dimension: category_name {
    hidden: yes
    type: string
    description: "Category name as stored on the ledger row at ingestion time. Use Categories > Category Name instead."
    sql: ${TABLE}.category_name ;;
  }

  dimension: category_group {
    hidden: yes
    type: string
    description: "Category group as stored on the ledger row at ingestion time. Use Categories > Category Group instead."
    sql: ${TABLE}.category_group ;;
  }

  # ---------------- TIMEFRAMES ----------------

  dimension_group: transaction {
    type: time
    timeframes: [raw, date, week, month, month_name, quarter, year, day_of_week]
    convert_tz: no
    datatype: date
    sql: CAST(${TABLE}.date AS DATE) ;;
    description: "Transaction date (column: date, YYYY-MM-DD)"
  }

  # ---------------- AMOUNTS & ATTRIBUTES ----------------

  dimension: original_currency {
    type: string
    description: "Currency the transaction was settled in (COP or EUR). Amounts are normalized to COP in Amount COP."
    sql: ${TABLE}.currency ;;
  }

  dimension: amount_original {
    type: number
    description: "Transaction amount in its original settlement currency (column: raw_amount). Signed: expenses negative, income positive."
    sql: ${TABLE}.raw_amount ;;
    value_format_name: decimal_2
  }

  dimension: amount_cop {
    type: number
    description: "Transaction amount in COP (column: amount). Signed: expenses negative, income and refunds positive."
    sql: ${TABLE}.amount ;;
    value_format_name: decimal_0
  }

  dimension: is_transfer {
    type: yesno
    description: "Internal transfer between owned accounts. Transfers are excluded from every spend and income measure."
    sql: ${TABLE}.is_transfer ;;
  }

  dimension: type {
    type: string
    description: "Raw transaction direction: expense, income or transfer"
    sql: ${TABLE}.type ;;
  }

  dimension: nature {
    type: string
    description: "Two-Tier accounting nature: tier1_operational_cost (living expenses), tier2_capital_outlay (sinking funds, investments, big purchases), tier1_operating_income (salary-like income), tier2_capital_inflow (capital or investment inflows), tier2_refund_offset (refunds, which reduce spend) or transfer"
    sql: ${TABLE}.nature ;;
  }

  dimension: tier_group {
    type: string
    description: "Two-Tier group: 'Tier 1: Operational Living', 'Tier 2: Capital & Sinking Funds' or 'Transfer'"
    sql: ${TABLE}.tier_group ;;
  }

  dimension: is_refund {
    type: yesno
    description: "Refund or credit that offsets earlier spend (nature = tier2_refund_offset). Refunds reduce Total Spend; they are not income."
    sql: ${TABLE}.nature = 'tier2_refund_offset' ;;
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

  dimension: note {
    type: string
    description: "Free-text note entered on the transaction"
    sql: ${TABLE}.note ;;
  }

  dimension: record_state {
    type: string
    description: "Bank reconciliation state of the record: cleared or reconciled"
    sql: ${TABLE}.record_state ;;
  }

  dimension: labels {
    type: string
    description: "Display-only list of label names attached to the transaction. Label names can contain commas, so do not split or filter on this; use the Transaction Labels explore for label analysis."
    sql: ${TABLE}.labels ;;
  }

  dimension: transaction_type {
    type: string
    description: "Human-readable Income, Expense, Refund or Transfer classification"
    case: {
      when: {
        sql: ${TABLE}.is_transfer = true OR ${TABLE}.type = 'transfer' ;;
        label: "Transfer"
      }
      when: {
        sql: ${TABLE}.nature = 'tier2_refund_offset' ;;
        label: "Refund"
      }
      when: {
        sql: ${TABLE}.type = 'income' ;;
        label: "Income"
      }
      when: {
        sql: ${TABLE}.type = 'expense' ;;
        label: "Expense"
      }
      else: "Other"
    }
  }

  # ---------------- MEASURES: COUNTS ----------------

  measure: transaction_count {
    type: count
    description: "Number of ledger rows, including transfers and refunds"
    drill_fields: [transaction_id, transaction_date, account_name, merchant, amount_cop]
  }

  measure: expense_count {
    type: count
    description: "Number of expense transactions (excludes transfers and refunds)"
    filters: [is_transfer: "no", type: "expense", nature: "tier1_operational_cost,tier2_capital_outlay"]
    drill_fields: [transaction_id, transaction_date, merchant, amount_cop]
  }

  # ---------------- MEASURES: SPEND (COP) ----------------
  # Spend is always net of refunds, matching mart_monthly_pnl.

  measure: gross_spend_cop {
    type: sum
    description: "Spend before refunds in COP: Tier 1 operational costs + Tier 2 capital outlays, excluding transfers"
    sql: ABS(${TABLE}.amount) ;;
    filters: [is_transfer: "no", nature: "tier1_operational_cost,tier2_capital_outlay"]
    value_format_name: decimal_0
    drill_fields: [transaction_id, transaction_date, merchant, amount_cop]
  }

  measure: total_refunds_cop {
    type: sum
    description: "Refunds and credits in COP that offset earlier spend (nature = tier2_refund_offset)"
    sql: ${TABLE}.amount ;;
    filters: [is_transfer: "no", nature: "tier2_refund_offset"]
    value_format_name: decimal_0
    drill_fields: [transaction_id, transaction_date, merchant, amount_cop]
  }

  measure: total_spend_cop {
    type: number
    description: "DEFAULT spend metric. Total spend in COP net of refunds (Gross Spend - Refunds), excluding transfers. Matches mart_monthly_pnl operational + capital expenses."
    sql: COALESCE(${gross_spend_cop}, 0) - COALESCE(${total_refunds_cop}, 0) ;;
    value_format_name: decimal_0
  }

  measure: tier1_operational_spend_cop {
    type: sum
    description: "Tier 1 living expenses in COP (routine operational burn rate). Refunds are all Tier 2, so Tier 1 gross = net."
    sql: ABS(${TABLE}.amount) ;;
    filters: [is_transfer: "no", nature: "tier1_operational_cost"]
    value_format_name: decimal_0
    drill_fields: [transaction_id, transaction_date, merchant, amount_cop]
  }

  measure: tier2_gross_capital_spend_cop {
    type: sum
    description: "Tier 2 capital outlays in COP before refunds (sinking funds, investments, big purchases)"
    sql: ABS(${TABLE}.amount) ;;
    filters: [is_transfer: "no", nature: "tier2_capital_outlay"]
    value_format_name: decimal_0
    drill_fields: [transaction_id, transaction_date, merchant, amount_cop]
  }

  measure: tier2_capital_spend_cop {
    type: number
    description: "Tier 2 capital spend in COP net of refunds. Matches mart_monthly_pnl capital_expenses."
    sql: COALESCE(${tier2_gross_capital_spend_cop}, 0) - COALESCE(${total_refunds_cop}, 0) ;;
    value_format_name: decimal_0
  }

  measure: average_expense_ticket_cop {
    type: average
    description: "Average size of a single expense transaction in COP (excludes transfers and refunds)"
    sql: ABS(${TABLE}.amount) ;;
    filters: [is_transfer: "no", type: "expense", nature: "tier1_operational_cost,tier2_capital_outlay"]
    value_format_name: decimal_0
  }

  # ---------------- MEASURES: INCOME (COP) ----------------
  # Income excludes refunds (they reduce spend instead).

  measure: operating_income_cop {
    type: sum
    description: "Tier 1 operating income in COP (salary and recurring earned income)"
    sql: ${TABLE}.amount ;;
    filters: [is_transfer: "no", nature: "tier1_operating_income"]
    value_format_name: decimal_0
    drill_fields: [transaction_id, transaction_date, payee, amount_cop]
  }

  measure: capital_inflow_cop {
    type: sum
    description: "Tier 2 capital inflows in COP (investment returns, asset sales, one-off capital income)"
    sql: ${TABLE}.amount ;;
    filters: [is_transfer: "no", nature: "tier2_capital_inflow"]
    value_format_name: decimal_0
    drill_fields: [transaction_id, transaction_date, payee, amount_cop]
  }

  measure: total_income_cop {
    type: number
    description: "DEFAULT income metric. Total income in COP: operating income + capital inflows. Excludes refunds and transfers."
    sql: COALESCE(${operating_income_cop}, 0) + COALESCE(${capital_inflow_cop}, 0) ;;
    value_format_name: decimal_0
  }

  # ---------------- MEASURES: CASHFLOW & SAVINGS ----------------

  measure: net_cash_flow_cop {
    type: number
    description: "Net cash flow in COP across all tiers: Total Income - Total Spend. Matches mart_monthly_pnl net_cashflow."
    sql: ${total_income_cop} - ${total_spend_cop} ;;
    value_format_name: decimal_0
  }

  measure: operating_margin_cop {
    type: number
    description: "Tier 1 operating margin in COP: Operating Income - Tier 1 Operational Spend"
    sql: COALESCE(${operating_income_cop}, 0) - COALESCE(${tier1_operational_spend_cop}, 0) ;;
    value_format_name: decimal_0
  }

  measure: savings_rate_pct {
    type: number
    description: "DEFAULT savings rate. Total savings rate in percent: Net Cash Flow / Total Income * 100. NULL when there is no income."
    sql: ${net_cash_flow_cop} / NULLIF(${total_income_cop}, 0) * 100.0 ;;
    value_format_name: decimal_2
  }

  measure: operating_savings_rate_pct {
    type: number
    description: "Tier 1 operating savings rate in percent: Operating Margin / Operating Income * 100. Use only when the question is about Tier 1 / living expenses. NULL when there is no operating income."
    sql: ${operating_margin_cop} / NULLIF(${operating_income_cop}, 0) * 100.0 ;;
    value_format_name: decimal_2
  }
}
