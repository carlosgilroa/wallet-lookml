project_name: "wallet_lookml"

# Global project configuration for Wallet Personal Finance Analytics
# Sourced from BigQuery Data Warehouse (Medallion Lakehouse)

constant: connection_name {
  value: "wallet_bigquery_dw"
  export: none
}

constant: schema_name {
  value: "wallet_dw"
  export: none
}
