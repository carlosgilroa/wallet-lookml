# Wallet LookML — Enterprise Semantic Modeling Layer

[![LookML Validation](https://github.com/carlosgilroa/wallet-lookml/actions/workflows/lookml_lint.yml/badge.svg)](https://github.com/carlosgilroa/wallet-lookml/actions)
[![LookML Engine](https://img.shields.io/badge/Language-LookML-blue.svg)](https://cloud.google.com/looker/docs/what-is-lookml)
[![Warehouse](https://img.shields.io/badge/Warehouse-Google_BigQuery_%7C_DuckDB-669DF6.svg)](https://cloud.google.com/bigquery)
[![Architecture](https://img.shields.io/badge/Pattern-Medallion_Lakehouse-orange.svg)](https://en.wikipedia.org/wiki/Databricks#Medallion_architecture)

A production-grade, Git-versioned **LookML semantic modeling repository** for the [Wallet Personal Finance Automation Lake](https://github.com/carlosgilroa/wallet). This project bridges a multi-currency Medallion data lakehouse (`silver/` and `gold/` Parquet tables) with enterprise-grade metric governance, Persistent Derived Tables (PDTs), and symmetric aggregate explorations.

---

## 1. Architectural Motivation & Problem Statement

### The Anti-Pattern: Ad-Hoc Dashboard Calculations
In traditional Business Intelligence tools (e.g. basic Looker Studio or Power BI reports), metric formulas are defined individually inside charts and widgets. This leads to:
1. **Metric Drift**: Different dashboards calculate "Monthly Net Cash Flow" or "Operational Burn Rate" using inconsistent filters.
2. **SQL Fanout Errors**: Joining fact tables (`1:N`) to dimensional tables multiplies amounts unless complex deduplication logic is manually written in raw SQL.
3. **Dashboard Latency**: Heavy multi-table aggregations scan gigabytes of data on every refresh.

### The Solution: LookML Centralized Semantic Layer
LookML decouples **SQL business logic** from **visual presentation**. By centralizing dimensions, measures, and join relationships in Git:
* Every downstream dashboard, user query, or automated assistant consumes the **exact same vetted business logic**.
* Looker's query generator automatically generates **Symmetric Aggregates** (using primary keys and `relationship: many_to_one`) to prevent fanout bugs mathematically.
* Caching and materialization policies are governed via declarative **Datagroups** and **Persistent Derived Tables (PDTs)**.

---

## 2. System Architecture & Information Flow

```mermaid
flowchart TD
    subgraph DataLake ["1. Upstream Medallion Lakehouse (wallet_lake)"]
        FCT[("master_records<br/>Multi-Currency Ledger")]
        ACC[("dim_accounts<br/>Checking, Savings, Credit")]
        CAT[("dim_categories<br/>Category Hierarchy & Cardinality")]
        LBL[("dim_labels<br/>Transaction Tags & Cashflows")]
        FX[("fx_rates<br/>Daily USD/EUR/COP/GBP")]
        MARTS[("Gold Marts<br/>mart_monthly_pnl & mart_expense_summary")]
    end

    subgraph SemanticLayer ["2. LookML Semantic Modeling Layer (wallet-lookml)"]
        MOD["wallet_analytics.model.lkml<br/>Datagroup & Explores"]
        V_FCT["fct_transactions.view.lkml"]
        V_DIMS["dim_accounts / dim_categories / dim_labels / dim_fx_rates"]
        V_MARTS["mart_monthly_pnl / mart_expense_summary"]
        PDT["pdt_category_mom_velocity.view.lkml<br/>Window-Function PDT (LAG & 3M Rolling)"]
    end

    subgraph Operations ["3. Downstream Analytics & Applications"]
        EXPLORE["Self-Service Explores<br/>Field Picker & Drill-Downs"]
        DASH["Enterprise Dashboards<br/>Sub-Second Mart & PDT Latency"]
        AI["AI Data Agent & RAG<br/>Vetted Semantic Context"]
    end

    FCT & ACC & CAT & LBL & FX & MARTS --> SemanticLayer
    MOD --> V_FCT & V_DIMS & V_MARTS & PDT
    SemanticLayer --> Operations
```

---

## 3. Key LookML Design Patterns Implemented

### A. Symmetric Aggregates & Fanout Protection
In `models/wallet_analytics.model.lkml`, dimensional relationships are declared with explicit cardinality across the `transactions`, `monthly_pnl`, and `category_velocity` explores:

```lookml
explore: transactions {
  from: fct_transactions
  view_name: fct_transactions
  label: "Personal Finance & Cash Flow Ledger"

  join: dim_accounts {
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_transactions.account_id} = ${dim_accounts.account_id} ;;
  }

  join: dim_categories {
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_transactions.category_id} = ${dim_categories.category_id} ;;
  }
}
```
Because `transaction_id`, `account_id`, `category_id`, and `label_id` are flagged with `primary_key: yes`, Looker calculates accurate sums regardless of join fanouts.

### B. Two-Tier Accounting Metric Governance
All amounts are in **COP**. The same default metric names exist in every explore that can answer the question, and `scripts/reconcile_metrics.py` proves they return the same numbers:

| Metric | Definition |
| :--- | :--- |
| `total_spend_cop` | **Default spend.** Tier 1 operational costs + Tier 2 capital outlays, **net of refunds**, excluding transfers |
| `gross_spend_cop` / `total_refunds_cop` | Spend before refunds, and the refunds (`nature = tier2_refund_offset`) that offset it |
| `tier1_operational_spend_cop` | Tier 1 living expenses (`nature = tier1_operational_cost`) |
| `tier2_capital_spend_cop` | Tier 2 capital outlays net of refunds |
| `total_income_cop` | **Default income.** Operating income + capital inflows. Refunds are **not** income |
| `net_cash_flow_cop` | `total_income_cop - total_spend_cop` |
| `savings_rate_pct` | **Default savings rate.** Net cash flow / total income × 100 (all tiers) |
| `operating_savings_rate_pct` | Tier 1 savings rate: (operating income − Tier 1 spend) / operating income × 100 |

```lookml
measure: total_spend_cop {
  type: number
  sql: COALESCE(${gross_spend_cop}, 0) - COALESCE(${total_refunds_cop}, 0) ;;
}

measure: savings_rate_pct {
  type: number
  sql: ${net_cash_flow_cop} / NULLIF(${total_income_cop}, 0) * 100.0 ;;
}
```

### C. Explores
| Explore | Use it for |
| :--- | :--- |
| `fct_transactions` | Transaction-level questions: merchants, payees, accounts, categories, day-level dates |
| `transaction_labels` | Spend by label (trips, projects) through `bridge_transaction_labels`; multi-label transactions count once per label |
| `dim_accounts` | Balances (`total_current_balance_cop`, converted at the latest FX rate), credit limits |
| `mart_monthly_pnl` | Monthly / quarterly / yearly income, spend, cashflow and savings rate |
| `mart_expense_summary` | Monthly spend by tier, category, merchant and labels |
| `mart_category_budget` | Tier 1 category spend vs P80 budget caps (one row per category-month) |
| `pdt_category_mom_velocity` | Month-over-month change and 3-month rolling average per category, on a calendar-month spine so gaps compare against 0, not an older month |

### D. Dialect
The connection is BigQuery, and the local agent runs the same SQL on DuckDB. Derived-table SQL sticks to syntax both engines accept (`CAST(... AS STRING)`, `SUBSTR`, `CONCAT`, window functions).

---

## 4. Repository Structure

```text
wallet-lookml/
├── .github/
│   └── workflows/
│       └── lookml_lint.yml                     # Automated CI/CD syntax and linting pipeline
├── manifest.lkml                               # Project manifest, global constants, and schema names
├── models/
│   └── wallet_analytics.model.lkml             # Connection, datagroups, explores, and joins
├── views/
│   ├── base/                                   # Silver layer physical table bindings
│   │   ├── bridge_transaction_labels.view.lkml # Transaction ↔ label bridge (1 row per transaction + label)
│   │   ├── dim_accounts.view.lkml              # Conformed accounts dimension with COP balances
│   │   ├── dim_categories.view.lkml            # Conformed categories dimension & hierarchy
│   │   ├── dim_labels.view.lkml                # Conformed labels/tags dimension
│   │   ├── dim_fx_rates.view.lkml              # Daily multi-currency FX rates
│   │   └── fct_transactions.view.lkml          # Master transaction ledger (master_records)
│   └── derived/                                # Gold Marts & Persistent Derived Tables (PDTs)
│       ├── mart_category_budget.view.lkml      # Tier 1 category-month spend vs budget caps
│       ├── mart_monthly_pnl.view.lkml          # Monthly Two-Tier P&L Gold mart
│       ├── mart_expense_summary.view.lkml      # Monthly category / merchant / label spend mart
│       └── pdt_category_mom_velocity.view.lkml # Window-function MoM category spend velocity PDT
├── tests/
│   └── data_tests.lkml                         # Native LookML test blocks
├── scripts/
│   ├── validate_lookml.py                      # LookML parser + DuckDB EXPLAIN validator, then runs reconciliation
│   └── reconcile_metrics.py                    # Compiles measures to SQL and checks explores agree
├── requirements.txt                            # Dependencies (`lkml`, `duckdb`)
└── README.md
```

---

## 5. Local Validation & CI/CD Testing

The project uses the open-source Python parser [`lkml`](https://github.com/joshtemple/lkml) plus **DuckDB `EXPLAIN` verification** to validate all LookML views, primary keys, and derived table SQL against the physical Parquet schemas:

```bash
# 1. Install validation dependencies
pip install -r requirements.txt

# 2. Run the automated LookML & DuckDB EXPLAIN validator
python scripts/validate_lookml.py
```

Output (abridged):
```text
Validating 13 LookML file(s) across project...
  [PASS] manifest.lkml
  ...
  [EXPLAIN PASS] Derived table 'pdt_category_mom_velocity' compiled cleanly against DuckDB.
All 13 LookML files parsed and validated successfully!

Reconciling LookML metrics across explores...
  [PASS] fct_transactions.total_spend_cop = mart_monthly_pnl.total_spend_cop (10 months)
  [PASS] fct_transactions.total_income_cop = mart_monthly_pnl.total_income_cop (10 months)
  ...
  [PASS] pdt_category_mom_velocity compares consecutive calendar months only
  [PASS] budget_status is consistent within every category-month
All metrics reconcile across explores.
```

Reconciliation needs the local lakehouse (`WALLET_DATA_DIR`, default `C:/projects/wallet/data`) and is skipped when it is absent, as in CI.

---

## 6. Architecture & Data Governance Walkthrough

This semantic layer adheres to enterprise data engineering and analytics engineering standards:

1. **Decoupled Medallion Architecture**: The semantic model operates directly over Silver (`master_records`, `dim_accounts`, `dim_categories`, `dim_labels`, `fx_rates`) and Gold (`mart_monthly_pnl`, `mart_expense_summary`) layers, providing centralized governance across multi-currency financial records.
2. **Symmetric Aggregates & Join Safety**: By enforcing primary keys (`transaction_id`, `account_id`, `category_id`, `label_id`) and declaring explicit join relationships (`relationship: many_to_one`), the model guarantees mathematically accurate metrics regardless of query dimensionality or join depth.
3. **Window-Function PDTs**: `pdt_category_mom_velocity` computes month-over-month spend acceleration and 3-month rolling baselines using SQL window functions validated via DuckDB `EXPLAIN`.
4. **Automated CI/CD Quality Gates**: Every pull request and push to `main` triggers automated syntax, reference, primary-key, and `EXPLAIN` validation via `scripts/validate_lookml.py`.
5. **Unified Business Logic**: Critical metric logic—such as Two-Tier Accounting classifications, net cash flow, and multi-period savings rate—is codified once in LookML, ensuring complete metric consistency across all downstream consumers and AI agents.
