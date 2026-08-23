---
# Adapted from WrenAI examples/v5-jaffle (Apache-2.0); modified for Adilade — see /NOTICE.
nl: What was our total revenue by month?
sql: |
  SELECT DATE_TRUNC('month', order_date) AS month,
         SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END) AS net_revenue
  FROM orders
  GROUP BY DATE_TRUNC('month', order_date)
  ORDER BY month
source: user
tags:
  - revenue
  - mvp-hardcoded
---

The MVP's hardcoded end-to-end question. Follows the governed revenue
definition (completed orders only) from `knowledge/rules/business-rules.md`;
the cube-path equivalent is `order_metrics.net_revenue` by
`order_date:month`.
