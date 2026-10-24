connection: "@{connection_name}"

include: "/views/**/*.view.lkml"
include: "/tests/**/*.lkml"

# ---------------- CACHING POLICY (DATAGROUPS) ----------------

datagroup: wallet_daily_datagroup {
  sql_trigger: SELECT MAX(date) FROM `@{schema_name}.master_records` ;;
  max_cache_age: "24 hours"
  description: "Triggers daily when new bank transactions or TRM updates are ingested into the lakehouse"
}

persist_with: wallet_daily_datagroup

# ---------------- EXPLORES & SEMANTIC JOINS ----------------

explore: fct_transactions {
  label: "Personal Finance & Cash Flow Ledger (Silver)"
  description: "Transaction-level ledger (master_records) joined with conformal dimensional tables (dim_accounts, dim_categories, dim_fx_rates)"

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
    sql_on: ${fct_transactions.transaction_raw} = ${dim_fx_rates.fx_raw} ;;
  }
}

explore: dim_labels {
  label: "Transaction Labels & Project Tagging (Silver)"
  description: "Conformed label catalog with cumulative inflows, outflows, and net balances per tag"
}

explore: mart_monthly_pnl {
  label: "Monthly P&L & Two-Tier Cashflow Summary (Gold)"
  description: "Executive monthly Profit & Loss mart with Tier 1 operational vs Tier 2 capital breakdowns and dynamic multi-period savings rate"
}

explore: mart_expense_summary {
  label: "Monthly Category Expense & Budget Variance Mart (Gold)"
  description: "Pre-aggregated monthly category and merchant spend with budget caps, variances, and utilization status"
}

explore: pdt_category_mom_velocity {
  label: "Category MoM Spend Velocity & 3M Rolling Average (PDT)"
  description: "Window-function Persistent Derived Table tracking month-over-month spend acceleration and 3-month moving averages per category"
}
