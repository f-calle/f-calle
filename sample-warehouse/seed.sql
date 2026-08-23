-- Adilade sample warehouse: a tiny commerce dataset for local development.
-- Loaded automatically by the postgres container on first boot
-- (docker-entrypoint-initdb.d), or apply manually:
--   psql "$WAREHOUSE_DATABASE_URL" -f sample-warehouse/seed.sql

CREATE TABLE public.customers (
    id      integer PRIMARY KEY,
    name    varchar,            -- NULL for guest checkouts
    region  varchar NOT NULL    -- AMER | EMEA | APAC
);

CREATE TABLE public.raw_orders (
    id          integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES public.customers (id),
    order_date  date NOT NULL,
    status      varchar NOT NULL,          -- completed | pending | returned
    amount      double precision NOT NULL  -- USD
);

INSERT INTO public.customers (id, name, region) VALUES
    (1, 'Alice Nguyen',   'AMER'),
    (2, 'Bruno Costa',    'EMEA'),
    (3, 'Chioma Eze',     'EMEA'),
    (4, 'Daniel Kim',     'APAC'),
    (5, NULL,             'AMER'),
    (6, 'Fatima al-Sayed','EMEA'),
    (7, 'Grace Ito',      'APAC'),
    (8, 'Hugo Alvarez',   'AMER');

INSERT INTO public.raw_orders (id, customer_id, order_date, status, amount) VALUES
    ( 1, 1, '2026-01-05', 'completed',  120.00),
    ( 2, 2, '2026-01-09', 'completed',   45.50),
    ( 3, 3, '2026-01-14', 'returned',    89.99),
    ( 4, 4, '2026-01-21', 'completed',  210.00),
    ( 5, 5, '2026-01-28', 'completed',   32.25),
    ( 6, 1, '2026-02-02', 'completed',   75.00),
    ( 7, 6, '2026-02-06', 'pending',    150.00),
    ( 8, 7, '2026-02-11', 'completed',  310.40),
    ( 9, 8, '2026-02-15', 'completed',   18.75),
    (10, 2, '2026-02-20', 'returned',    60.00),
    (11, 3, '2026-02-25', 'completed',  132.10),
    (12, 4, '2026-03-03', 'completed',   99.99),
    (13, 5, '2026-03-07', 'completed',  245.00),
    (14, 6, '2026-03-12', 'completed',   54.30),
    (15, 7, '2026-03-16', 'pending',     88.00),
    (16, 8, '2026-03-21', 'completed',  176.50),
    (17, 1, '2026-03-27', 'completed',   41.20),
    (18, 2, '2026-04-01', 'completed',  330.00),
    (19, 3, '2026-04-05', 'completed',   27.80),
    (20, 4, '2026-04-10', 'returned',   115.60),
    (21, 5, '2026-04-14', 'completed',   68.90),
    (22, 6, '2026-04-19', 'completed',  142.00),
    (23, 7, '2026-04-24', 'completed',   93.45),
    (24, 8, '2026-04-29', 'pending',     55.00),
    (25, 1, '2026-05-04', 'completed',  188.20),
    (26, 2, '2026-05-08', 'completed',   77.35),
    (27, 3, '2026-05-13', 'completed',  260.00),
    (28, 4, '2026-05-17', 'completed',   36.60),
    (29, 5, '2026-05-22', 'returned',   120.00),
    (30, 6, '2026-05-27', 'completed',   84.75),
    (31, 7, '2026-06-01', 'completed',  199.99),
    (32, 8, '2026-06-06', 'completed',  123.45),
    (33, 1, '2026-06-11', 'pending',     67.00),
    (34, 2, '2026-06-16', 'completed',   58.20),
    (35, 3, '2026-06-21', 'completed',  305.75),
    (36, 4, '2026-06-26', 'completed',   49.90);
