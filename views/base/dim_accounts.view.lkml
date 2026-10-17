view: dim_accounts {
  sql_table_name: `@{schema_name}.dim_accounts` ;;

  dimension: account_id {
    primary_key: yes
    type: string
    description: "Unique surrogate key for the financial account"
    sql: ${TABLE}.account_id ;;
  }

  dimension: account_name {
    type: string
    description: "Descriptive name of the account (e.g. Bancolombia Checking, Nu Savings)"
    sql: ${TABLE}.account_name ;;
    drill_fields: [account_id, institution, account_type]
  }

  dimension: account_type {
    type: string
    description: "Asset or liability classification: Checking, Savings, Credit Card, Investment"
    sql: ${TABLE}.account_type ;;
  }

  dimension: institution {
    type: string
    description: "Financial institution (Bancolombia, Nu Bank, Davivienda, Nequi, RappiCard)"
    sql: ${TABLE}.institution ;;
  }

  dimension: default_currency {
    type: string
    description: "Base currency of the account (COP, EUR, USD)"
    sql: ${TABLE}.currency ;;
  }

  dimension: is_active {
    type: yesno
    description: "Whether the account is currently open and active"
    sql: ${TABLE}.is_active ;;
  }

  measure: count {
    type: count
    description: "Total number of managed financial accounts"
    drill_fields: [account_id, account_name, institution, account_type]
  }
}
