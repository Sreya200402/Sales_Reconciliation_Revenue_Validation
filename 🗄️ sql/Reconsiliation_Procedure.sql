use ecommerces;

-- RECONCILIATION PROCEDURE
create or alter procedure proc_reconciliation_base
as
begin
    with recon as (
        select
            i.order_id,
            i.expected_value,
            p.actual_value,
            i.expected_value - p.actual_value as difference_value,
            case
                when (i.expected_value - p.actual_value) = 0 then 'match'
                when (i.expected_value - p.actual_value) > 0 then 'underpaid'
                else 'overpaid'
            end as category
        from
        (
            select order_id, sum(price + freight_value) as expected_value
            from order_items
            group by order_id
        ) i
        join
        (
            select order_id, sum(payment_value) as actual_value
            from order_payments
            group by order_id
        ) p
        on i.order_id = p.order_id
    )
    select * from recon;
end;

exec proc_reconciliation_base;
