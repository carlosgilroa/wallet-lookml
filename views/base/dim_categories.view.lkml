view: dim_categories {
  sql_table_name: `@{schema_name}.dim_categories` ;;

  dimension: category_id {
    primary_key: yes
    type: string
    description: "Unique surrogate key for the expense or income category"
    sql: ${TABLE}.category_id ;;
  }

  dimension: category_name {
    type: string
    description: "Granular category name (e.g. Groceries, Rent, AWS/GCP, Sinking Funds)"
    sql: ${TABLE}.category_name ;;
  }

  dimension: parent_category {
    type: string
    description: "Higher-level roll-up (e.g. Housing, Sustenance, Cloud/Tech, Capital Allocation)"
    sql: ${TABLE}.parent_category ;;
  }

  dimension: accounting_tier {
    type: number
    description: "Two-Tier Accounting Model: Tier 1 (Routine Living Expenses) vs Tier 2 (Capital Sinking Funds & Investments)"
    sql: ${TABLE}.accounting_tier ;;
  }

  dimension: tier_classification {
    type: string
    description: "Human-readable label for the accounting tier"
    case: {
      when: {
        sql: ${accounting_tier} = 1 ;;
        label: "Tier 1: Routine Operational Expense"
      }
      when: {
        sql: ${accounting_tier} = 2 ;;
        label: "Tier 2: Capital Sinking Fund / Investment"
      }
      else: "Unclassified"
    }
  }

  dimension: is_discretionary {
    type: yesno
    description: "Indicates non-essential or lifestyle expense"
    sql: ${TABLE}.is_discretionary ;;
  }

  measure: count {
    type: count
    description: "Total number of classified categories"
    drill_fields: [category_id, category_name, parent_category, tier_classification]
  }
}
