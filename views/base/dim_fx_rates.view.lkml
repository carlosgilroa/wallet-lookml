view: dim_fx_rates {
  sql_table_name: `@{schema_name}.dim_fx_rates` ;;

  dimension: fx_rate_id {
    primary_key: yes
    type: string
    hidden: yes
    sql: CONCAT(CAST(${TABLE}.fx_date AS STRING), '_', ${TABLE}.base_currency, '_', ${TABLE}.target_currency) ;;
  }

  dimension_group: fx {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    datatype: date
    sql: ${TABLE}.fx_date ;;
  }

  dimension: base_currency {
    type: string
    description: "Source currency (e.g. COP, EUR, USD)"
    sql: ${TABLE}.base_currency ;;
  }

  dimension: target_currency {
    type: string
    description: "Target normalized currency (typically USD or COP)"
    sql: ${TABLE}.target_currency ;;
  }

  dimension: exchange_rate {
    type: number
    description: "Daily official exchange rate (TRM from Banco de la República API)"
    sql: ${TABLE}.rate ;;
    value_format_name: decimal_4
  }

  measure: average_exchange_rate {
    type: average
    description: "Average exchange rate across the selected timeframe"
    sql: ${exchange_rate} ;;
    value_format_name: decimal_4
  }
}
