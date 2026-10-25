project_name: "wallet_lookml"

# Global project configuration for Wallet Personal Finance Analytics
# Sourced from BigQuery Data Warehouse (Medallion Lakehouse).
# The same SQL also runs locally on DuckDB over the Parquet lakehouse, so derived-table SQL
# must stay portable between BigQuery and DuckDB. All monetary fields are in COP.

constant: connection_name {
  value: "wallet_bigquery_dw"
  export: none
}

constant: schema_name {
  value: "wallet_lake"
  export: none
}
