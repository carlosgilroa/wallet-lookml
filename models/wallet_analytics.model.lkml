connection: "@{connection_name}"

include: "/views/**/*.view.lkml"
include: "/tests/**/*.lkml"

# ---------------- CACHING POLICY (DATAGROUPS) ----------------

datagroup: wallet_daily_datagroup {
  sql_trigger: SELECT MAX(transaction_date) FROM `@{schema_name}.fct_transactions` ;;
  max_cache_age: "24 hours"
  description: "Triggers daily when new bank transactions or TRM updates are ingested into BigQuery"
}

persist_with: wallet_daily_datagroup

# ---------------- EXPLORES & SEMANTIC JOINS ----------------

explore: fct_transactions {
  label: "Personal Finance & Cash Flow Ledger"
  description: "Multi-currency financial transactions with Two-Tier accounting and BigQuery integration"

  join: dim_accounts {
    view_label: "Accounts"
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_transactions.account_id} = ${dim_accounts.account_id} ;;
  }

  join: dim_categories {
    view_label: "Categories"
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_transactions.category_id} = ${dim_categories.category_id} ;;
  }

  join: dim_fx_rates {
    view_label: "FX Rates"
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_transactions.transaction_date} = ${dim_fx_rates.fx_date}
      AND ${fct_transactions.original_currency} = ${dim_fx_rates.base_currency} ;;
  }
}

explore: pdt_monthly_cashflow {
  label: "Monthly Run-Rate & Liquidity Summary (PDT)"
  description: "Pre-aggregated monthly performance metrics cached in BigQuery for sub-second dashboard latency"
}
