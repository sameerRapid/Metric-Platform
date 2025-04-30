select
                        city,
                        captain_id,
                        yyyymmdd,
                        sum(GMV) as GMV,
                        sum(FM_distance) as FM_earnings,
                        sum(LM_distance) as LM_earnings,
                        sum(subs_orders) as subs_orders,
                        sum(order_earnings) as order_earnings,
                        sum(distributed_sl2_rule_amount) as distributed_sl2_rule_amount,
                        sum(special_incentives) as total_incentives,
                        sum(take) as take,
                        sum(GMV - take + total_incentives - tax_amount - distributed_sl2_rule_amount) as final_captain_earnings,
                        sum(cast(GMV - take + total_incentives - tax_amount - distributed_sl2_rule_amount as double))/sum(cast(coalesce(FM_distance,0)+coalesce(LM_distance,0) as double)) as final_epkm,
                        sum(cast(order_earnings as double))/sum(cast(coalesce(FM_distance,0)+coalesce(LM_distance,0) as double)) as order_epkm,
                        sum(cast(GMV - take + total_incentives - tax_amount - subs_purchase_amount as double))/sum(cast(coalesce(login_hours,0) - coalesce(idle_hours,0) as double)) as final_eph,
                        sum(cast(order_earnings as double))/sum(cast(coalesce(login_hours,0) - coalesce(idle_hours,0) as double)) as order_eph
                    from reports.sql_ingestion_captain_cm_amt_dist_view
                    where city  = '{city}'
                    and yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
                
                    group by 1,2,3
ad
from suspension_detail suspension_detail
left join city_name city_name
on suspension_detail.city_id=city_name.city_id
group by captain_id