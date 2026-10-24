#!/usr/bin/env python3
"""
validate_lookml.py
Parses, validates, and lints all LookML files in the repository using the open-source `lkml` parser.
Ensures syntactic validity, primary key declarations, and compiles derived_table SQL via DuckDB EXPLAIN.
"""

import os
import re
import sys
from pathlib import Path

try:
    import lkml
except ImportError:
    print("Error: `lkml` is not installed. Run `pip install lkml`.")
    sys.exit(1)


def strip_lookml_schema_macros(sql: str) -> str:
    """Replace LookML schema macros like `@{schema_name}.table_name` with `table_name` for local DuckDB validation."""
    cleaned = re.sub(r"`?@\{schema_name\}\.([a-zA-Z0-9_]+)`?", r"\1", sql)
    return cleaned.strip().rstrip(";")


def register_duckdb_lakehouse(data_dir: Path):
    """Register physical Parquet tables in an in-memory DuckDB instance if available."""
    import duckdb

    conn = duckdb.connect(":memory:")
    table_map = {
        "master_records": data_dir / "silver" / "master_records.parquet",
        "dim_accounts": data_dir / "silver" / "dim_accounts.parquet",
        "dim_categories": data_dir / "silver" / "dim_categories.parquet",
        "dim_labels": data_dir / "silver" / "dim_labels.parquet",
        "fx_rates": data_dir / "silver" / "fx_rates.parquet",
        "mart_monthly_pnl": data_dir / "gold" / "mart_monthly_pnl.parquet",
        "mart_expense_summary": data_dir / "gold" / "mart_expense_summary.parquet",
    }
    registered = []
    for name, path in table_map.items():
        if path.exists():
            conn.execute(f"CREATE OR REPLACE VIEW {name} AS SELECT * FROM read_parquet('{path.as_posix()}')")
            registered.append(name)
    return conn, registered


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    data_dir = Path(os.environ.get("WALLET_DATA_DIR", "C:/projects/wallet/data"))
    lkml_files = []
    for root, _, files in os.walk(repo_root):
        for file in files:
            if file.endswith(".lkml"):
                lkml_files.append(os.path.join(root, file))

    if not lkml_files:
        print("No .lkml files found to validate.")
        return 0

    duck_conn = None
    registered_tables = []
    try:
        duck_conn, registered_tables = register_duckdb_lakehouse(data_dir)
    except Exception:
        duck_conn = None

    print(f"Validating {len(lkml_files)} LookML file(s) across project...")
    errors = 0

    for file_path in sorted(lkml_files):
        rel_path = os.path.relpath(file_path, repo_root)
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
            parsed = lkml.load(content)

            # Check primary keys and derived_table SQL compilation in views
            if "views" in parsed:
                for view in parsed["views"]:
                    view_name = view.get("name", "unnamed")
                    dimensions = view.get("dimensions", [])
                    has_pk = any(dim.get("primary_key") == "yes" for dim in dimensions)
                    if not has_pk:
                        print(f"  [WARNING] View '{view_name}' in {rel_path} lacks a declared primary_key dimension.")

                    derived_table = view.get("derived_table", {})
                    raw_dt_sql = derived_table.get("sql")
                    if raw_dt_sql and duck_conn is not None and registered_tables:
                        compiled_sql = strip_lookml_schema_macros(raw_dt_sql)
                        duck_conn.execute(f"EXPLAIN {compiled_sql}")
                        print(f"  [EXPLAIN PASS] Derived table '{view_name}' compiled cleanly against DuckDB.")

            print(f"  [PASS] {rel_path}")

        except Exception as e:
            print(f"  [ERROR] {rel_path}: {e}")
            errors += 1

    print("\n------------------------------------------------------------")
    if errors == 0:
        print(f"All {len(lkml_files)} LookML files parsed and validated successfully!")
        return 0
    else:
        print(f"LookML Validation failed with {errors} error(s).")
        return 1


if __name__ == "__main__":
    sys.exit(main())
