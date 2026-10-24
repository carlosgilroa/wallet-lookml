view: dim_fx_rates {
  sql_table_name: `@{schema_name}.fx_rates` ;;

  dimension: date {
    primary_key: yes
    type: string
    description: "Exchange rate calendar date (YYYY-MM-DD)"
    sql: ${TABLE}.date ;;
  }

  dimension_group: fx {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    datatype: date
    description: "Daily exchange rate timestamp"
    sql: CAST(${TABLE}.date AS DATE) ;;
  }

  dimension: usd_cop {
    type: number
    description: "Daily USD to COP exchange rate (TRM from Banco de la República)"
    sql: ${TABLE}.usd_cop ;;
    value_format_name: decimal_2
  }

  dimension: eur_usd {
    type: number
    description: "Daily EUR to USD cross exchange rate"
    sql: ${TABLE}.eur_usd ;;
    value_format_name: decimal_4
  }

  dimension: eur_cop {
    type: number
    description: "Daily EUR to COP exchange rate"
    sql: ${TABLE}.eur_cop ;;
    value_format_name: decimal_2
  }

  dimension: gbp_usd {
    type: number
    description: "Daily GBP to USD cross exchange rate"
    sql: ${TABLE}.gbp_usd ;;
    value_format_name: decimal_4
  }

  dimension: gbp_cop {
    type: number
    description: "Daily GBP to COP exchange rate"
    sql: ${TABLE}.gbp_cop ;;
    value_format_name: decimal_2
  }

  measure: average_usd_cop_rate {
    type: average
    description: "Average USD to COP TRM exchange rate across the selected timeframe"
    sql: ${usd_cop} ;;
    value_format_name: decimal_2
  }

  measure: average_eur_cop_rate {
    type: average
    description: "Average EUR to COP exchange rate across the selected timeframe"
    sql: ${eur_cop} ;;
    value_format_name: decimal_2
  }
}
