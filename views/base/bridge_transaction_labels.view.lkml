view: bridge_transaction_labels {
  sql_table_name: `@{schema_name}.bridge_transaction_labels` ;;
  description: "Bridge between transactions and labels. Grain: 1 row per transaction_id + label_id. A transaction with several labels appears once per label, so totals across labels can exceed the overall total."

  dimension: transaction_label_pk {
    primary_key: yes
    type: string
    hidden: yes
    description: "Compound primary key: transaction_id + label_id"
    sql: CONCAT(${TABLE}.transaction_id, '_', ${TABLE}.label_id) ;;
  }

  dimension: transaction_id {
    hidden: yes
    type: string
    description: "Foreign key to fct_transactions"
    sql: ${TABLE}.transaction_id ;;
  }

  dimension: label_id {
    hidden: yes
    type: string
    description: "Foreign key to dim_labels"
    sql: ${TABLE}.label_id ;;
  }

  measure: tagged_transaction_count {
    type: count_distinct
    description: "Number of distinct transactions carrying the selected labels"
    sql: ${transaction_id} ;;
  }
}
