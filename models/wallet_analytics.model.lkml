connection: "@{connection_name}"

include: "/views/**/*.view.lkml"
include: "/tests/**/*.lkml"

# All amounts in this model are in COP. Default metric names are shared across explores:
#   total_spend_cop    = spend net of refunds, excluding transfers
#   total_income_cop   = operating income + capital inflows (refunds excluded)
#   savings_rate_pct   = (income - spend) / income, all tiers
#   operating_savings_rate_pct = Tier 1 margin / Tier 1 income

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
  description: "Transaction-level ledger for any question that needs individual transactions, merchants, payees, accounts, categories or day-level dates. Spend is net of refunds."

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

explore: transaction_labels {
  from: bridge_transaction_labels
  view_name: bridge_transaction_labels
  label: "Transaction Labels & Project Tagging (Silver)"
  description: "Spend and income by label (trips, projects, owners). Each transaction counts once per label it carries, so summing across labels can double count multi-label transactions."

  join: fct_transactions {
    type: inner
    relationship: many_to_one
    sql_on: ${bridge_transaction_labels.transaction_id} = ${fct_transactions.transaction_id} ;;
  }

  join: dim_labels {
    view_label: "Labels"
    type: inner
    relationship: many_to_one
    sql_on: ${bridge_transaction_labels.label_id} = ${dim_labels.label_id} ;;
  }

  join: dim_categories {
    view_label: "Categories"
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_transactions.category_id} = ${dim_categories.category_id} ;;
  }
}

explore: dim_labels {
  label: "Label Catalog (Silver)"
  description: "Label catalog with lifetime inflows, outflows and net balance per label. For spend by label over a period, use Transaction Labels."
}

explore: dim_accounts {
  label: "Accounts & Balances (Silver)"
  description: "Current balances (in COP), credit limits and available credit per account"
}

explore: mart_monthly_pnl {
  label: "Monthly P&L & Two-Tier Cashflow Summary (Gold)"
  description: "Monthly income, spend, net cashflow and savings rate, split into Tier 1 (operational) and Tier 2 (capital). Fastest source for month, quarter and year totals."
}

explore: mart_expense_summary {
  label: "Monthly Category & Merchant Spend (Gold)"
  description: "Pre-aggregated monthly spend by tier, category, merchant and labels, net of refunds"
}

explore: mart_category_budget {
  label: "Tier 1 Category Budgets (Gold)"
  description: "Monthly Tier 1 category spend vs recommended budget caps: over or under budget, variance and utilization"
}

explore: pdt_category_mom_velocity {
  label: "Category MoM Spend Velocity & 3M Rolling Average (PDT)"
  description: "Month-over-month spend change and 3-month rolling average per category, computed against the previous calendar month"
}
