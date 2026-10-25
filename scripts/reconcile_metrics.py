#!/usr/bin/env python3
"""
reconcile_metrics.py
Compiles LookML measures to SQL and checks that every explore gives the same answer for the
same business question (spend, income, cashflow, savings rate) on the local DuckDB lakehouse.

Only the LookML subset used in this project is supported: ${TABLE}/${field} references, measure
filters (yes/no, equality, comma lists, '-' negation), and sum/count/count_distinct/average/max/number
measures. Run with WALLET_DATA_DIR pointing at the wallet data folder.
"""

import os
import re
import sys
from pathlib import Path

import duckdb
import lkml

REPO_ROOT = Path(__file__).resolve().parent.parent
TOLERANCE = 0.01

TABLES = {
    "master_records": "silver/master_records.parquet",
    "dim_accounts": "silver/dim_accounts.parquet",
    "dim_categories": "silver/dim_categories.parquet",
    "dim_labels": "silver/dim_labels.parquet",
    "fx_rates": "silver/fx_rates.parquet",
    "bridge_transaction_labels": "silver/bridge_transaction_labels.parquet",
    "mart_monthly_pnl": "gold/mart_monthly_pnl.parquet",
    "mart_expense_summary": "gold/mart_expense_summary.parquet",
    "mart_category_budget": "gold/mart_category_budget.parquet",
}


def strip_schema_macros(sql: str) -> str:
    return re.sub(r"`?@\{schema_name\}\.([a-zA-Z0-9_]+)`?", r"\1", sql).strip().rstrip(";")


class View:
    def __init__(self, raw: dict):
        self.name = raw["name"]
        self.raw = raw
        self.dimensions = {d["name"]: d for d in raw.get("dimensions", [])}
        self.dimension_groups = {g["name"]: g for g in raw.get("dimension_groups", [])}
        self.measures = {m["name"]: m for m in raw.get("measures", [])}
        if raw.get("sql_table_name"):
            self.table_sql = strip_schema_macros(raw["sql_table_name"])
        else:
            self.table_sql = f"({strip_schema_macros(raw['derived_table']['sql'])})"

    def _refs(self, sql: str, alias: str, resolve) -> str:
        sql = sql.replace("${TABLE}", alias)
        return re.sub(r"\$\{([a-zA-Z0-9_]+)\}", lambda m: f"({resolve(m.group(1), alias)})", sql)

    def dimension_sql(self, name: str, alias: str) -> str:
        dim = self.dimensions.get(name)
        if dim is None:
            for group_name, group in self.dimension_groups.items():
                if name.startswith(f"{group_name}_"):
                    return self._refs(group["sql"], alias, self.dimension_sql)
            raise KeyError(f"{self.name}: unknown dimension '{name}'")
        if "sql" not in dim:
            raise KeyError(f"{self.name}.{name}: dimensions without sql are not supported")
        return self._refs(dim["sql"], alias, self.dimension_sql)

    def _filter_condition(self, field: str, value: str, alias: str) -> str:
        dim = self.dimensions[field]
        expr = self.dimension_sql(field, alias)
        if dim.get("type") == "yesno":
            return f"({expr}) = {'TRUE' if value == 'yes' else 'FALSE'}"
        negate = value.startswith("-")
        values = [v.strip() for v in value.lstrip("-").split(",")]
        quoted = ", ".join("'" + v.replace("'", "''") + "'" for v in values)
        return f"({expr}) {'NOT IN' if negate else 'IN'} ({quoted})"

    def measure_sql(self, name: str, alias: str) -> str:
        if name not in self.measures:
            return self.dimension_sql(name, alias)
        m = self.measures[name]
        mtype = m["type"]
        if mtype == "number":
            return self._refs(m["sql"], alias, self.measure_sql)

        conditions = [
            self._filter_condition(field, value, alias)
            for group in m.get("filters__all", [])
            for f in group
            for field, value in f.items()
        ]
        cond = " AND ".join(conditions)
        if mtype == "count":
            return f"COUNT(CASE WHEN {cond} THEN 1 END)" if cond else "COUNT(*)"
        expr = self._refs(m["sql"], alias, self.dimension_sql)
        if cond:
            expr = f"CASE WHEN {cond} THEN {expr} END"
        agg = {"sum": "SUM", "average": "AVG", "max": "MAX", "min": "MIN", "count_distinct": "COUNT(DISTINCT"}[mtype]
        return f"{agg} {expr})" if mtype == "count_distinct" else f"{agg}({expr})"

    def query(self, measures) -> str:
        cols = [f"{self.measure_sql(m, 't')} AS {m}" for m in measures]
        return f"SELECT {', '.join(cols)} FROM {self.table_sql} AS t"

    def primary_key(self):
        for name, dim in self.dimensions.items():
            if dim.get("primary_key") == "yes":
                return name
        return None


def load_views() -> dict:
    views = {}
    for path in sorted((REPO_ROOT / "views").glob("**/*.view.lkml")):
        for raw in lkml.load(path.read_text(encoding="utf-8")).get("views", []):
            views[raw["name"]] = View(raw)
    return views


def by_month(conn, view: View, measure: str, month_dim: str) -> dict:
    """Aggregate a measure per YYYY-MM. month_dim may be a day-level date, so the grouping truncates in SQL."""
    month_expr = f"SUBSTR(CAST({view.dimension_sql(month_dim, 't')} AS STRING), 1, 7)"
    sql = f"SELECT {month_expr} AS grp, {view.measure_sql(measure, 't')} FROM {view.table_sql} AS t GROUP BY 1"
    return {k: (v or 0.0) for k, v in conn.execute(sql).fetchall()}


def scalar(conn, view: View, measure: str):
    return conn.execute(view.query([measure])).fetchone()[0]


def main() -> int:
    data_dir = Path(os.environ.get("WALLET_DATA_DIR", "C:/projects/wallet/data"))
    missing = [rel for rel in TABLES.values() if not (data_dir / rel).exists()]
    if missing:
        print(f"Skipping reconciliation: lakehouse files not found under {data_dir} ({', '.join(missing)})")
        return 0

    conn = duckdb.connect(":memory:")
    for name, rel in TABLES.items():
        conn.execute(f"CREATE VIEW {name} AS SELECT * FROM read_parquet('{(data_dir / rel).as_posix()}')")

    views = load_views()
    fct, pnl = views["fct_transactions"], views["mart_monthly_pnl"]
    summary, budget, velocity = views["mart_expense_summary"], views["mart_category_budget"], views["pdt_category_mom_velocity"]
    failures = 0

    def check(label: str, left: dict, right: dict):
        nonlocal failures
        bad = {
            k: (left.get(k, 0.0), right.get(k, 0.0))
            for k in sorted(set(left) | set(right))
            if abs(left.get(k, 0.0) - right.get(k, 0.0)) > TOLERANCE
        }
        if bad:
            failures += 1
            print(f"  [FAIL] {label}: {bad}")
        else:
            print(f"  [PASS] {label} ({len(left)} months)")

    def check_scalar(label: str, left, right):
        nonlocal failures
        if left is None or right is None or abs(left - right) > TOLERANCE:
            failures += 1
            print(f"  [FAIL] {label}: {left} vs {right}")
        else:
            print(f"  [PASS] {label} ({left:.2f})")

    print("Reconciling LookML metrics across explores...")

    # Ledger vs monthly P&L mart
    pairs = [
        ("total_spend_cop", "total_spend_cop"),
        ("total_income_cop", "total_income_cop"),
        ("net_cash_flow_cop", "total_net_cashflow"),
        ("tier1_operational_spend_cop", "total_operational_expenses"),
        ("tier2_capital_spend_cop", "total_capital_expenses"),
        ("operating_income_cop", "total_operating_income"),
        ("capital_inflow_cop", "total_capital_income"),
        ("operating_margin_cop", "total_operating_margin"),
    ]
    for fct_measure, pnl_measure in pairs:
        check(
            f"fct_transactions.{fct_measure} = mart_monthly_pnl.{pnl_measure}",
            by_month(conn, fct, fct_measure, "transaction_month"),
            by_month(conn, pnl, pnl_measure, "year_month"),
        )

    for measure in ("savings_rate_pct", "operating_savings_rate_pct"):
        check_scalar(
            f"fct_transactions.{measure} = mart_monthly_pnl.{measure} (all months)",
            scalar(conn, fct, measure),
            scalar(conn, pnl, measure),
        )

    # Other spend explores vs monthly P&L
    pnl_spend = by_month(conn, pnl, "total_spend_cop", "year_month")
    check("mart_expense_summary.total_spend_cop = mart_monthly_pnl.total_spend_cop",
          by_month(conn, summary, "total_spend_cop", "year_month"), pnl_spend)
    check("pdt_category_mom_velocity.total_monthly_spend_cop = mart_monthly_pnl.total_spend_cop",
          by_month(conn, velocity, "total_monthly_spend_cop", "year_month"), pnl_spend)
    check("mart_category_budget.total_spend_cop = mart_monthly_pnl.total_operational_expenses",
          by_month(conn, budget, "total_spend_cop", "year_month"),
          by_month(conn, pnl, "total_operational_expenses", "year_month"))

    # Velocity PDT must compare consecutive calendar months
    gaps = conn.execute(f"""
        WITH v AS ({velocity.table_sql[1:-1]}),
        l AS (SELECT year_month, LAG(year_month) OVER (PARTITION BY category_id ORDER BY year_month) AS prev FROM v)
        SELECT COUNT(*) FROM l
        WHERE prev IS NOT NULL
          AND CAST(year_month || '-01' AS DATE) <> CAST(prev || '-01' AS DATE) + INTERVAL 1 MONTH
    """).fetchone()[0]
    if gaps:
        failures += 1
        print(f"  [FAIL] pdt_category_mom_velocity has {gaps} non-consecutive month comparisons")
    else:
        print("  [PASS] pdt_category_mom_velocity compares consecutive calendar months only")

    # Budget status must agree for every row of a category-month
    inconsistent = conn.execute("""
        SELECT COUNT(*) FROM (
            SELECT year_month, category_group, category_name FROM mart_expense_summary
            WHERE tier_group LIKE '%Tier 1%' GROUP BY 1, 2, 3 HAVING COUNT(DISTINCT budget_status) > 1
        )
    """).fetchone()[0]
    if inconsistent:
        failures += 1
        print(f"  [FAIL] {inconsistent} category-months have conflicting budget_status rows")
    else:
        print("  [PASS] budget_status is consistent within every category-month")

    # Primary keys must be unique and bridge keys must resolve
    pk_failures_before = failures
    for view in views.values():
        pk = view.primary_key()
        if pk is None:
            continue
        expr = view.dimension_sql(pk, "t")
        total, distinct = conn.execute(
            f"SELECT COUNT(*), COUNT(DISTINCT {expr}) FROM {view.table_sql} AS t"
        ).fetchone()
        if total != distinct:
            failures += 1
            print(f"  [FAIL] {view.name}.{pk} is not unique ({total} rows, {distinct} distinct)")
    if failures == pk_failures_before:
        print(f"  [PASS] primary keys are unique on all {len(views)} views")

    orphans = conn.execute("""
        SELECT
            (SELECT COUNT(*) FROM bridge_transaction_labels WHERE transaction_id NOT IN (SELECT id FROM master_records)),
            (SELECT COUNT(*) FROM bridge_transaction_labels WHERE label_id NOT IN (SELECT label_id FROM dim_labels))
    """).fetchone()
    if any(orphans):
        failures += 1
        print(f"  [FAIL] bridge_transaction_labels orphans (transactions, labels): {orphans}")
    else:
        print("  [PASS] bridge_transaction_labels keys resolve to transactions and labels")

    print("------------------------------------------------------------")
    if failures:
        print(f"Metric reconciliation failed with {failures} problem(s).")
        return 1
    print("All metrics reconcile across explores.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
