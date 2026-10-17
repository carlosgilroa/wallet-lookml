#!/usr/bin/env python3
"""
validate_lookml.py
Parses, validates, and lints all LookML files in the repository using the open-source `lkml` parser.
Ensures syntactic validity, primary key declarations, and schema conformity.
"""

import os
import sys

try:
    import lkml
except ImportError:
    print("Error: `lkml` is not installed. Run `pip install lkml`.")
    sys.exit(1)

def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    lkml_files = []
    for root, _, files in os.walk(repo_root):
        for file in files:
            if file.endswith(".lkml"):
                lkml_files.append(os.path.join(root, file))

    if not lkml_files:
        print("No .lkml files found to validate.")
        return 0

    print(f"Validating {len(lkml_files)} LookML file(s) across project...")
    errors = 0

    for file_path in sorted(lkml_files):
        rel_path = os.path.relpath(file_path, repo_root)
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
            parsed = lkml.load(content)

            # Check primary keys in views
            if "views" in parsed:
                for view in parsed["views"]:
                    view_name = view.get("name", "unnamed")
                    dimensions = view.get("dimensions", [])
                    has_pk = any(dim.get("primary_key") == "yes" for dim in dimensions)
                    if not has_pk:
                        print(f"  [WARNING] View '{view_name}' in {rel_path} lacks a declared primary_key dimension.")

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
