create or alter procedure proc_run_reconciliation_analysis
as
begin
    declare @start_time datetime,
            @end_time datetime;

    begin try

        print '=============================================';
        print 'starting revenue reconciliation analysis';
        print '=============================================';

        set @start_time = getdate();

        -------------------------------------------------
        -- 1. base reconciliation
        -------------------------------------------------
        print '>> running base reconciliation';

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


        -------------------------------------------------
        -- 2. mismatch percentage
        -------------------------------------------------
        print '>> calculating mismatch percentage';

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
        select 
            count(case when category != 'match' then 1 end) * 100.0 / count(*) as mismatch_percentage
        from recon;


        -------------------------------------------------
        -- 3. revenue impact
        -------------------------------------------------
        print '>> calculating revenue impact';

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
        select 
            coalesce(sum(case when category = 'underpaid' then difference_value end),0) as total_underpaid,
            coalesce(sum(case when category = 'overpaid' then abs(difference_value) end),0) as total_overpaid
        from recon;


        -------------------------------------------------
        -- 4. distribution
        -------------------------------------------------
        print '>> calculating distribution';

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
        select
            category,
            count(*) as total_category,
            count(*) * 100.0 / sum(count(*)) over() as percentage
        from recon
        group by category;


        -------------------------------------------------
        -- 5. top mismatches
        -------------------------------------------------
        print '>> identifying top mismatches';

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
        select top 10
            order_id,
            category,
            abs(difference_value) as highest_mismatch
        from recon
        where category != 'match'
        order by abs(difference_value) desc;


        -------------------------------------------------
        -- 6. region + status analysis
        -------------------------------------------------
        print '>> analyzing region and status impact';

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
        select 
            c.customer_state,
            o.order_status,
            count(*) as mismatch_count,
            round(count(*) * 100.0 / sum(count(*)) over(),2) as percentage
        from recon r
        join orders o on r.order_id = o.order_id
        join customers c on o.customer_id = c.customer_id
        where r.category != 'match'
        group by c.customer_state, o.order_status
        order by mismatch_count desc;


        set @end_time = getdate();

        print '=============================================';
        print 'analysis completed successfully';
        print 'total execution time: '
              + cast(datediff(second,@start_time,@end_time) as varchar) + ' seconds';
        print '=============================================';

    end try

    begin catch
        print 'error occurred';
        print error_message();
    end catch

end;


go



exec proc_run_reconciliation_analysis;



