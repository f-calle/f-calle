<!-- Adapted from WrenAI examples/v5-jaffle (Apache-2.0); modified for Adilade — see /NOTICE. -->
# Business rules

- "Revenue" ALWAYS means **net revenue**: `SUM(amount)` over orders with
  `status = 'completed'` only. Pending and returned orders are excluded.
  Use the `order_metrics.net_revenue` measure; never invent a different
  revenue formula.
- All monetary amounts are USD.
- `orders.status` is one of: `completed`, `pending`, `returned`.
- `customers.name` may be NULL for guest checkouts; count them as customers.
- `customers.region` is one of: `AMER`, `EMEA`, `APAC`.
