---
nl: What is our total revenue?
sql: |
  SELECT SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END) AS net_revenue
  FROM orders
source: user
tags:
  - revenue
---
