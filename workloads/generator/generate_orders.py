"""Event generator: writes 10 new orders into the source PostgreSQL each run.
Some rows are deliberately dirty (missing customer, non-numeric amount) so the pipeline has something to reject.
Per run, with i = 1..10: customer is NULL for i = 5 and 10, amount is 'abc' for i = 7.
So every run adds 10 raw rows, of which 7 are valid and 3 are rejected. Everything else is deterministic."""
import os, time
from datetime import date, timedelta
import psycopg2

host = os.environ.get("PGHOST", "postgres.lakehouse")
for attempt in range(30):                      # wait up to ~60 s for PostgreSQL
    try:
        conn = psycopg2.connect(host=host, dbname="orders", user=os.environ["POSTGRES_USER"],
                                password=os.environ["POSTGRES_PASSWORD"])
        break
    except psycopg2.OperationalError as e:
        print("waiting for postgres:", str(e).strip()[:80]); time.sleep(2)
else:
    raise SystemExit("PostgreSQL not reachable")

cur = conn.cursor()
cur.execute("""CREATE TABLE IF NOT EXISTS public.orders (
    order_id   SERIAL PRIMARY KEY,
    customer   TEXT,
    amount     TEXT,
    order_date TEXT,
    created_at TIMESTAMP DEFAULT now())""")

today, yesterday = date.today(), date.today() - timedelta(days=1)
customers = ["alice", "bob", "carol", "dina"]
for i in range(1, 11):
    customer = None if i % 5 == 0 else customers[i % 4]
    amount = "abc" if i == 7 else str(10 + 2.5 * i)
    day = today if i % 2 == 0 else yesterday
    cur.execute("INSERT INTO public.orders (customer, amount, order_date) VALUES (%s, %s, %s)",
                (customer, amount, day.isoformat()))
conn.commit()
cur.execute("SELECT count(*) FROM public.orders")
print("inserted 10 orders; total rows in source:", cur.fetchone()[0])
