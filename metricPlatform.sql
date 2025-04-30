with ao as (
      select 
                    ao.event_props_ct_location_hex_8_city as  event_props_ct_location_hex_8_city,
                    ao.profile_identity as captain_id,
                    ao.yyyymmdd yyyymmdd
                from
                    clevertap.captain_app_launched_immutable ao
                where ao.yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
),
paymentsTransaction as (
    select 
        pymnt.yyyymmdd as yyyymmdd,
        pymnt.owner_id as captain_id,
        pymnt.amount as amount,
        pymnt.subtype as subtype,
        cast(json_array_get(cast(pymnt.wallets_amount as json),0) as double) as wlt_recharged,
        cast(json_array_get(cast(pymnt.wallets_post_balance as json),0) as double) as wlt_post_recharged
     from
            payments.transactions_snapshot pymnt
    where  pymnt.yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
)
    select
        paymentsTransaction.captain_id captain_id,

        from paymentsTransaction paymentsTransaction
        inner join ao ao
        on ao.captain_id = paymentsTransaction.owner_id 
        and paymentsTransaction.yyyymmdd = ao.yyyymmdd
        group by captain_id
        --             min(wlt_post_recharged) as min_balance,
        -- avg(case when subtype = 'walletRecharge' then amount end) as avg_recharged_amount,
        -- count(case when subtype = 'walletRecharge' then amount end) as num_recharges