view: dim_categories {
  sql_table_name: `@{schema_name}.dim_categories` ;;
  description: "Conformed spend and income categories dimension with parent hierarchy and cardinality. Grain: 1 row per category (category_id)."

  dimension: category_id {
    primary_key: yes
    type: string
    description: "Unique surrogate key for the expense or income category from BudgetBakers"
    sql: ${TABLE}.category_id ;;
  }

  dimension: category_name {
    type: string
    description: "Granular category name (e.g. Groceries, Rent, Restaurant, Fuel, Advisory)"
    sql: ${TABLE}.category_name ;;
  }

  dimension: parent_category {
    type: string
    description: "Parent category roll-up from BudgetBakers hierarchy (e.g. Food & Drinks, Housing, Vehicle, Financial expenses)"
    sql: ${TABLE}.parent_category ;;
  }

  dimension: category_group {
    type: string
    description: "High-level category group classification (e.g. Food & Drinks, Housing, Vehicle, Shopping, Life & Entertainment)"
    sql: ${TABLE}.category_group ;;
  }

  dimension: category_full {
    type: string
    description: "Full hierarchical category path (category_group > category_name)"
    sql: ${TABLE}.category_full ;;
  }

  dimension: cardinality {
    type: string
    description: "BudgetBakers spending priority classification: must, need, want, or none (unclassified)"
    sql: ${TABLE}.cardinality ;;
  }

  dimension: is_discretionary {
    type: yesno
    description: "Indicates non-essential lifestyle or discretionary expense (true when cardinality = 'want')"
    sql: ${TABLE}.is_discretionary ;;
  }

  dimension: is_active {
    type: yesno
    description: "Whether the category is currently active and enabled"
    sql: ${TABLE}.is_active ;;
  }

  dimension: archived {
    type: yesno
    description: "Whether the category is archived"
    sql: ${TABLE}.archived ;;
  }

  dimension: is_custom {
    type: yesno
    description: "Whether this is a user-defined custom category vs a BudgetBakers system category"
    sql: ${TABLE}.is_custom ;;
  }

  measure: count {
    type: count
    description: "Total number of defined categories in the catalog"
    drill_fields: [category_id, category_name, category_group, cardinality, is_discretionary]
  }

  measure: active_categories_count {
    type: count
    description: "Total number of active and enabled categories"
    filters: [is_active: "yes"]
    drill_fields: [category_id, category_name, category_group, cardinality]
  }
}
