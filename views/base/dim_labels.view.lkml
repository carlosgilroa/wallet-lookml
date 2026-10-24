view: dim_labels {
  sql_table_name: `@{schema_name}.dim_labels` ;;

  dimension: label_id {
    primary_key: yes
    type: string
    description: "Unique identifier for the transaction label/tag from BudgetBakers"
    sql: ${TABLE}.label_id ;;
  }

  dimension: label_name {
    type: string
    description: "Human-readable tag/label name attached to transactions (projects, trips, owners)"
    sql: ${TABLE}.label_name ;;
  }

  dimension: is_active {
    type: yesno
    description: "Whether the label is currently active (not archived)"
    sql: ${TABLE}.is_active ;;
  }

  dimension: archived {
    type: yesno
    description: "Whether the label has been archived"
    sql: ${TABLE}.archived ;;
  }

  dimension: transaction_count {
    type: number
    description: "Number of ledger transactions tagged with this label"
    sql: ${TABLE}.transaction_count ;;
  }

  dimension: total_inflows_cop {
    type: number
    description: "Total cumulative inflows in COP associated with this label"
    sql: ${TABLE}.total_inflows_cop ;;
    value_format_name: decimal_2
  }

  dimension: total_outflows_cop {
    type: number
    description: "Total cumulative outflows in COP associated with this label"
    sql: ${TABLE}.total_outflows_cop ;;
    value_format_name: decimal_2
  }

  dimension: net_balance_cop {
    type: number
    description: "Net cashflow balance in COP for this label (total_inflows_cop - total_outflows_cop)"
    sql: ${TABLE}.net_balance_cop ;;
    value_format_name: decimal_2
  }

  measure: count {
    type: count
    description: "Total number of transaction labels"
    drill_fields: [label_id, label_name, is_active, transaction_count, total_outflows_cop]
  }

  measure: sum_labeled_outflows_cop {
    type: sum
    description: "Sum of total outflows in COP across selected labels"
    sql: ${total_outflows_cop} ;;
    value_format_name: decimal_2
  }
}
