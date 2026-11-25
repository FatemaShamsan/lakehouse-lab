"""Ingest + clean: PostgreSQL (JDBC) -> Bronze, then validate -> Silver (MERGE) and Quarantine.
Bronze is a full refresh of the source table each run (fine for a small demo); Silver is an upsert by order_id."""
import os
from pyspark.sql import SparkSession, functions as F

spark = SparkSession.builder.appName("ingest-orders").getOrCreate()
for ns in ("bronze", "silver", "gold"):          # gold is created here so dbt only has to create a table in it
    spark.sql(f"CREATE NAMESPACE IF NOT EXISTS lh.{ns}")

# 1) Bronze: raw copy of the source table, exactly as it is in PostgreSQL
raw = (spark.read.format("jdbc")
       .option("url", f"jdbc:postgresql://{os.environ.get('PGHOST', 'postgres.lakehouse')}:5432/orders")
       .option("dbtable", "public.orders")
       .option("user", os.environ["POSTGRES_USER"])
       .option("password", os.environ["POSTGRES_PASSWORD"])
       .option("driver", "org.postgresql.Driver").load())
raw.writeTo("lh.bronze.orders_raw").createOrReplace()

# 2) Validate
df = spark.table("lh.bronze.orders_raw").withColumn("amount_num", F.col("amount").cast("double"))
ok = F.col("customer").isNotNull() & F.col("amount_num").isNotNull()

# 3) Quarantine: rejected rows with the reason
(df.filter(~ok)
   .withColumn("reason", F.when(F.col("customer").isNull(), "customer is null")
                          .otherwise("amount is not a number"))
   .writeTo("lh.silver.orders_quarantine").createOrReplace())

# 4) Silver: typed, deduplicated, upserted
good = (df.filter(ok).dropDuplicates(["order_id"])
          .select("order_id", "customer", F.col("amount_num").alias("amount"),
                  F.to_date("order_date").alias("order_date")))
good.createOrReplaceTempView("updates")
spark.sql("""CREATE TABLE IF NOT EXISTS lh.silver.orders
             (order_id INT, customer STRING, amount DOUBLE, order_date DATE) USING iceberg""")
spark.sql("""MERGE INTO lh.silver.orders t USING updates u ON t.order_id = u.order_id
             WHEN MATCHED THEN UPDATE SET * WHEN NOT MATCHED THEN INSERT *""")

for t in ("lh.bronze.orders_raw", "lh.silver.orders", "lh.silver.orders_quarantine"):
    print(f"{t}: {spark.table(t).count()} rows")
