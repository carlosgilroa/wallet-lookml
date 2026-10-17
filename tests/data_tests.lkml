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
