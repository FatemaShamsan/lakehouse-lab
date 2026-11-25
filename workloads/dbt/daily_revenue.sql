select
    order_date,
    count(*)    as orders,
    sum(amount) as revenue
from {{ source('silver', 'orders') }}
group by order_date
