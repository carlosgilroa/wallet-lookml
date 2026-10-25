view: dim_accounts {
  sql_table_name: `@{schema_name}.dim_accounts` ;;
  description: "Conformed financial accounts dimension from BudgetBakers. Grain: 1 row per financial account (account_id)."

  dimension: account_id {
    primary_key: yes
    type: string
    description: "Unique surrogate key for the financial account from BudgetBakers"
    sql: ${TABLE}.account_id ;;
  }

  dimension: account_name {
    type: string
    description: "Descriptive name of the account (e.g. Bancolombia, Nu, Ahorro)"
    sql: ${TABLE}.account_name ;;
    drill_fields: [account_id, account_type, currency]
  }

  dimension: account_type {
    type: string
    description: "Account classification from BudgetBakers (e.g. General, SavingAccount, CreditCard, Loan)"
    sql: ${TABLE}.account_type ;;
  }

  dimension: currency {
    type: string
    description: "Base currency of the account (COP, EUR, USD)"
    sql: ${TABLE}.currency ;;
  }

  dimension: is_active {
    type: yesno
    description: "Whether the account is currently open and active (not archived)"
    sql: ${TABLE}.is_active ;;
  }

  dimension: archived {
    type: yesno
    description: "Whether the account has been archived"
    sql: ${TABLE}.archived ;;
  }

  dimension: exclude_from_stats {
    type: yesno
    description: "Whether the account is excluded from aggregate statistics"
    sql: ${TABLE}.exclude_from_stats ;;
  }

  dimension: is_bank_sync {
    type: yesno
    description: "Whether the account is automatically synchronized with a bank"
    sql: ${TABLE}.is_bank_sync ;;
  }

  dimension: is_investment_account {
    type: yesno
    description: "Whether the account is an investment portfolio or asset account"
    sql: ${TABLE}.is_investment_account ;;
  }

  dimension: current_balance {
    type: number
    description: "Current balance in the account's own currency (see Currency). Do not add across currencies; use Current Balance COP."
    sql: ${TABLE}.current_balance ;;
    value_format_name: decimal_2
  }

  dimension: current_balance_cop {
    type: number
    description: "Current balance converted to COP with the latest available FX rate (equal to current_balance for COP accounts)"
    sql: ${TABLE}.current_balance_cop ;;
    value_format_name: decimal_0
  }

  dimension: credit_limit {
    type: number
    description: "Total credit limit for credit card accounts (all credit cards are COP-denominated)"
    sql: ${TABLE}.credit_limit ;;
    value_format_name: decimal_2
  }

  dimension: available_credit {
    type: number
    description: "Remaining available credit on credit card accounts"
    sql: ${TABLE}.available_credit ;;
    value_format_name: decimal_2
  }

  dimension: credit_balance {
    type: number
    description: "Current utilized credit balance on credit card accounts"
    sql: ${TABLE}.credit_balance ;;
    value_format_name: decimal_2
  }

  dimension: record_count {
    type: number
    description: "Total number of historical transactions recorded in this account"
    sql: ${TABLE}.record_count ;;
  }

  measure: count {
    type: count
    description: "Total number of financial accounts (including archived)"
    drill_fields: [account_id, account_name, account_type, currency, is_active, current_balance]
  }

  measure: active_accounts_count {
    type: count
    description: "Total number of currently active (non-archived) financial accounts"
    filters: [is_active: "yes"]
    drill_fields: [account_id, account_name, account_type, currency, current_balance]
  }

  measure: total_current_balance_cop {
    type: sum
    description: "Sum of current balances across active accounts in COP (foreign-currency accounts converted at the latest FX rate). Loan and credit card balances are included with their sign."
    sql: ${current_balance_cop} ;;
    filters: [is_active: "yes"]
    value_format_name: decimal_0
  }

  measure: total_credit_limit {
    type: sum
    description: "Total credit limit across active credit cards in COP"
    sql: ${credit_limit} ;;
    filters: [is_active: "yes"]
    value_format_name: decimal_2
  }

  measure: total_available_credit {
    type: sum
    description: "Total available credit remaining across active credit cards in COP"
    sql: ${available_credit} ;;
    filters: [is_active: "yes"]
    value_format_name: decimal_2
  }
}
