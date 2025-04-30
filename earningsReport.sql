with earnings as (
    select  lower(tbls.city) as city,
        tbls.captain_id as captain_id,
        tbls.yyyymmdd as yyyymmdd,
        tbls.GMV as GMV,
        tbls.FM_distance as FM_distance,
        tbls.LM_distance as LM_distance,
        tbls.subs_orders as subs_orders,
        tbls.order_earnings as order_earnings,
        tbls.special_incentives as special_incentives,
        tbls.login_hours as login_hours,
        tbls.idle_hours as idle_hours,
        tbls.take as take,
        tbls.total_incentives as total_incentives,
        tbls.tax_amount as tax_amount,
        tbls.subs_purchase_amount as subs_purchase_amount,
        tbls.distributed_sl2_rule_amount as distributed_sl2_rule_amount
       from reports.sql_ingestion_captain_cm_amt_dist_view tbls
       where tbls.yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
    )
    select earnings.captain_id captain_id,sum(earnings.distributed_sl2_rule_amount) as  sum_captain_distributed_sl2_rule_amount_daily_city 
from earnings earnings
group by captain_id