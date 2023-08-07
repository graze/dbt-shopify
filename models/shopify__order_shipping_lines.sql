with shipping_order_lines as (

    select *
    from {{ var('shopify_order_shipping_line') }}

),tax_lines as (

    select *
    from {{ var('shopify_order_shipping_tax_line')}}

), tax_lines_aggregated as (

    select
        tax_lines.order_shipping_line_id,
        tax_lines.source_relation,
        sum(tax_lines.price) as order_line_tax

    from tax_lines
    group by 1,2

), 
discount_application as (
    select
        discount_application.order_id,
        discount_application.source_relation,
        max(case
            when value_type = 'percentage' then (value/100) * shipping_order_lines.price
            when value_type = 'fixed_amount' then value
        end) as discount_amount
    from {{ var('shopify_discount_application') }} AS discount_application
    inner join shipping_order_lines
        on discount_application.order_id = shipping_order_lines.order_id
    where discount_application.target_type = 'shipping_line'
    group by discount_application.order_id, discount_application.source_relation

),
joined as (

    select
        shipping_order_lines.*,
        coalesce(tax_lines_aggregated.order_line_tax, 0) as order_line_tax,
        coalesce(discount_application.discount_amount, 0) as order_line_discount_allocation
    from shipping_order_lines
    left join tax_lines_aggregated
        on tax_lines_aggregated.order_shipping_line_id = shipping_order_lines.order_shipping_line_id
        and tax_lines_aggregated.source_relation = shipping_order_lines.source_relation
    left join discount_application
        ON discount_application.order_id = shipping_order_lines.order_id
        AND discount_application.source_relation = shipping_order_lines.source_relation
)

select *
from joined
