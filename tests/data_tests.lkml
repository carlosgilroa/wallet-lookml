# LookML Data Tests: Automated model assertion tests

test: assert_unique_transaction_id {
  explore_source: fct_transactions {
    column: transaction_id {}
    column: transaction_count {}
  }
  assert: transaction_id_is_unique {
    expression: ${fct_transactions.transaction_count} = 1 ;;
  }
}

test: assert_positive_spend_measure {
  explore_source: fct_transactions {
    column: total_spend_usd {}
  }
  assert: total_spend_is_positive_magnitude {
    expression: ${fct_transactions.total_spend_usd} >= 0 ;;
  }
}

test: assert_refunds_never_increase_spend {
  explore_source: fct_transactions {
    column: total_spend_cop {}
    column: gross_spend_cop {}
  }
  assert: net_spend_not_above_gross {
    expression: ${fct_transactions.total_spend_cop} <= ${fct_transactions.gross_spend_cop} ;;
  }
}

test: assert_monthly_income_excludes_refunds {
  explore_source: mart_monthly_pnl {
    column: total_income_cop {}
    column: total_operating_income {}
    column: total_capital_income {}
  }
  assert: income_is_operating_plus_capital {
    expression: ABS(${mart_monthly_pnl.total_income_cop} - ${mart_monthly_pnl.total_operating_income} - ${mart_monthly_pnl.total_capital_income}) < 1 ;;
  }
}
