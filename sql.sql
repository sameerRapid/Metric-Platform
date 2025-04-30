                with sdid as (
                    select 
                        distinct service_detail_id, city_id,service_category, city_display_name city,
                        case 
                            when lower(service_category) in ('auto', 'cab', 'link') then 'taxi'
                            when lower(service_category) in ('delivery', 'c2c') then 'delivery_c2c' end supercategory
                    from 
                    datasets.service_level_mapping_qc
                    where service_detail_id_isactive
                ),

                ao as 
                ( -- cap x date
                    select 
                        ao.event_props_ct_location_hex_8_city as  city,
                        ao.profile_identity as captain_id,
                        ao.yyyymmdd yyyymmdd, 
                        count(1) as num_ao,
                        count(case when ao.hh between '06' and '10' then 1 end) as num_ao_morning_peak,
                        count(case when ao.hh between '11' and '15' then 1 end) as num_ao_afternoon,
                        count(case when ao.hh between '16' and '20' then 1 end) as num_ao_evening_peak,
                        count(case when ao.hh >= '21' or ao.hh <= '01' then 1 end) as num_ao_night,
                        count(case when ao.hh between '02' and '05' then 1 end) as num_ao_overnight
                    from
                        clevertap.captain_app_launched_immutable ao
                    where ao.yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') 
                        and date_format(date('{{EndDate}}'), '%Y%m%d')
                    group by city,captain_id, yyyymmdd
                )
                ,

                online_data as 
                ( -- cap x date
                    select 
                        ol.event_props_ct_location_hex_8_city as  city,
                        ol.profile_identity as captain_id,
                        ol.yyyymmdd,
                        count(1) as num_online,
                        count(case when ol.hh between '06' and '10' then 1 end) as num_online_morning_peak,
                        count(case when ol.hh between '11' and '15' then 1 end) as num_online_afternoon,
                        count(case when ol.hh between '16' and '20' then 1 end) as num_online_evening_peak,
                        count(case when ol.hh >= '21' or ol.hh <= '01' then 1 end) as num_online_night,
                        count(case when ol.hh between '02' and '05' then 1 end) as num_online_overnight
                    from
                    clevertap.captain_online_immutable ol
                    where ol.yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
                    group by city,captain_id, yyyymmdd
                )
                ,
                offline_events as (
                    select 
                        event_props_ct_location_hex_8_city city,
                        event_props_user_id captain_id,
                        yyyymmdd,
                        count(1) as num_offline,
                        count(case when hh between '06' and '10' then 1 end) as num_offline_morning_peak,
                        count(case when hh between '11' and '15' then 1 end) as num_offline_afternoon,
                        count(case when hh between '16' and '20' then 1 end) as num_offline_evening_peak,
                        count(case when hh >= '21' or hh <= '01' then 1 end) as num_offline_night,
                        count(case when hh between '02' and '05' then 1 end) as num_offline_overnight
                    from
                        clevertap.captain_offline_immutable
                    where yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
                    group by 1,2,3
                ),

                gross_pings as 
                ( -- cap x date
                    select 
                        city_name city,
                        rider_id captain_id,
                        yyyymmdd,
                        min(case when event_type = 'rider_acknowledged' and sdid.supercategory = 'delivery_c2c' then epoch end) as first_delivery_ping_epoch, 
                        min(case when event_type = 'rider_accepted' and sdid.supercategory = 'delivery_c2c' then epoch end) as first_delivery_accept_epoch, 
                        min(case when event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then epoch end) as first_taxi_ping_epoch,
                        min(case when event_type = 'rider_accepted' and sdid.supercategory = 'taxi' then epoch end) as first_taxi_accept_epoch,
                        count(case when event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then order_id end) as delivery_pings_taxi,
                        count(case when event_type = 'rider_accepted' and sdid.supercategory = 'taxi' then order_id end) as delivery_accepts_taxi,
                        count(case when event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then order_id end) as gross_pings_taxi,
                        count(case when event_type in ('rider_accepted','accepted', 'power_match_accepted') and sdid.supercategory = 'taxi' then order_id end) as accepted_pings_taxi,
                        count(case when event_type in ('rider_busy') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as rider_busy_pings_taxi,
                        count(case when event_type in ('rider_unreachable') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as nrr_pings_taxi,
                        count(case when event_type in ('rider_acknowledge_failed') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as ack_failed_pings_taxi,
                        count(case when event_type in ('rider_accept_failed', 'rider_accept_failed') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as raf_pings_taxi,
                        avg(
                            case when event_type = 'rider_acknowledged' 
                            and sdid.supercategory = 'taxi' then cast(json_extract(first_mile_distance_in_metres, '$.value') as double) end) as gross_fm_taxi,
                        avg(
                            case when event_type = 'rider_acknowledged' 
                            and sdid.supercategory = 'taxi' then cast(json_extract(last_mile_distance_in_metres, '$.value') as double) end) as gross_lm_taxi,
                        count(distinct case when event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_orders_taxi,
                        count(distinct case when event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_orders_taxi,
                        
                        count(case when hh between '06' and '10' 
                              and event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_pings_morning_peak_taxi,
                        count(case when hh between '06' and '10' 
                              and event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_pings_morning_peak_taxi,
                        count(distinct case when hh between '06' and '10' 
                              and event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_orders_morning_peak_taxi,
                        count(distinct case when hh between '06' and '10' 
                              and event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_orders_morning_peak_taxi,
                        
                        count(case when hh between '11' and '15' 
                              and event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_pings_afternoon_taxi,
                        count(case when hh between '11' and '15' 
                              and event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_pings_afternoon_taxi,
                        count(distinct case when hh between '11' and '15' 
                              and event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_orders_afternoon_taxi,
                        count(distinct case when hh between '11' and '15' 
                              and event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_orders_afternoon_taxi,
                        
                        count(case when hh between '16' and '20' 
                              and event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_pings_evening_peak_taxi,
                        count(case when hh between '16' and '20' 
                              and event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_pings_evening_peak_taxi,
                        count(distinct case when hh between '16' and '20' 
                              and event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_orders_evening_peak_taxi,
                        count(distinct case when hh between '16' and '20' 
                              and event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_orders_evening_peak_taxi,
                        
                        count(case when (hh >= '21' or hh<= '01') 
                              and event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_pings_night_taxi,
                        count(case when (hh >= '21' or hh<= '01') 
                              and event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_pings_night_taxi,
                        count(distinct case when (hh >= '21' or hh<= '01') 
                              and event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_orders_night_taxi,
                        count(distinct case when (hh >= '21' or hh<= '01') 
                              and event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_orders_night_taxi,
                        
                        count(case when hh between '02' and '05' 
                              and event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_pings_overnight_taxi,
                        count(case when hh between '02' and '05' 
                              and event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_pings_overnight_taxi,
                        count(distinct case when hh between '02' and '05' 
                              and event_type = 'rider_acknowledged' and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as gross_orders_overnight_taxi,
                        count(distinct case when hh between '02' and '05' 
                              and event_type in ('rider_accepted','accepted') and sdid.supercategory = 'taxi' then concat(rider_id,order_id) end) as accepted_orders_overnight
                    from
                        orders.dispatch_propagation_immutable dpi
                    inner join sdid on sdid.service_detail_id = dpi.service_detail_id and lower(sdid.city) = lower(dpi.city_name)
                    where yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
                    group by 1,2,3
                ),

                odin as (
                    select 
                        yyyymmdd,
                        captain_id, 
                        max(
                            case 
                                when captain_dapr_segment = 'Low DAPR' then 1
                                when captain_dapr_segment = 'Mid DAPR' then 2
                                when captain_dapr_segment = 'High DAPR' then 3
                                when captain_dapr_segment = 'Not Enough Info' then -1
                            end
                        ) as captain_DAPR_segment,
                        avg(customer_call_captain_flag) customer_call_captain_flag,
                        avg(customer_message_captain_flag) customer_message_captain_flag,
                        avg(captain_call_customer_flag) captain_call_customer_flag,
                        avg(captain_message_customer_flag) captain_message_customer_flag,
                        avg(first_mile) as cancelled_fm,
                        avg(last_mile) as cancelled_lm,
                        avg(a2c_distance) a2c_distance,
                        avg(c2p_distance) c2p_distance,
                        avg(time_to_cancel_mins) time_to_cancel_mins,
                        avg(case when event_type = 'customer_cancelled' then 1.0000 else 0.0000 end) as customerCancelled,
                        avg(case when event_type = 'rider_cancelled' then 1.0000 else 0.0000 end) as riderCancelled,
                        count(case when primary_reason like 'Bad Match%' then 1 end) as primary_bad_match,
                        count(case when primary_reason = 'Quick Cancellation' then 1 end) as primary_quick_cancellations,
                        count(case when primary_reason = 'Unclassified' then 1 end) as primary_unclassified,
                        count(case when primary_reason = 'Offline' then 1 end) as primary_offline,
                        count(case when primary_reason like '%Movement in Wrong Direction%' and primary_reason not like '%Bad Match%' then 1 end) as primary_moving_opp,
                        count(case when primary_reason like '%No Movement%' and primary_reason not like '%Bad Match%' then 1 end) as primary_not_moving,
                        count(case when primary_reason like '%No Show%' then 1 end) as primary_noshow,
                        count(case when primary_reason like '%Intent Issue%' then 1 end) as primary_intent_issue,
                        count(case when primary_reason like '%Dormant/Inactive/New%' then 1 end) as primary_dormant_cust
                    from experiments.ocara_event_fact_classified
                    inner join 
                    and yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
                    group by 1,2
                ),


                net_data as 
                (
                    select 
                        city_name,
                        captain_id,
                        -- lower(service_category) as service,
                        yyyymmdd,
                        min(case when order_status = 'dropped' then epoch end) as first_dropped_epoch,
                        count(distinct case when lower(service_category) = 'link' and order_status = 'dropped'then order_id end) as link_orders,
                        count(distinct case when lower(service_category) = 'auto' and order_status = 'dropped'then order_id end) as auto_orders,
                        count(distinct case when lower(service_category) = 'cab' and order_status = 'dropped'then order_id end) as cab_orders,
                        count(distinct case when lower(service_category) = 'delivery' and order_status = 'dropped'then order_id end) as delivery_orders,
                        count(distinct case when lower(service_category) = 'c2c' and order_status = 'dropped'then order_id end) as c2c_orders,
                        avg(case when customer_feedback_rating in (1,2,3,4,5) then customer_feedback_rating end) as avg_customer_rating,
                        count(case when customer_feedback_rating in (1,2,3,4,5) then customer_feedback_rating end) as num_customer_ratings,
                        count(distinct case when customer_feedback_rating in (1,2) then order_id end) as num_low_rated_orders,
                        sum(distinct case when sdid.supercategory = 'taxi' and (spd_fraud_flag!=True or spd_fraud_flag is null) and order_status = 'dropped' then accept_to_pickup_distance end) as fm_taxi,
                        sum(distinct case when sdid.supercategory = 'taxi' and (spd_fraud_flag!=True or spd_fraud_flag is null) and order_status = 'dropped' then distance_final_distance end) as lm_taxi,
                        count(distinct case when sdid.supercategory = 'taxi' and (spd_fraud_flag!=True or spd_fraud_flag is null) and order_status = 'dropped' then order_id end) as net_rides_taxi,
                        count(distinct case when sdid.supercategory = 'taxi' and (spd_fraud_flag!=True or spd_fraud_flag is null) and captain_obj_is_preferred_route and order_status = 'dropped' then order_id end) as net_rides_taxi_gta,
                        count(distinct case when sdid.supercategory = 'taxi' and (spd_fraud_flag!=True or spd_fraud_flag is null) and captain_obj_is_on_ride_booking and order_status = 'dropped' then order_id end) as net_rides_taxi_orb,
                        count(distinct case when sdid.supercategory = 'taxi' and (spd_fraud_flag!=True or spd_fraud_flag is null) and micro_corridor_name is not null and order_status = 'dropped' then order_id end) as net_rides_taxi_mc,
                        count(distinct case when lower(service_category) = 'delivery' and (spd_fraud_flag!=True or spd_fraud_flag is null) and order_status = 'dropped' then order_id end) as net_rides_delivery,
                        count(distinct case when lower(service_category) in ('c2c', 'courier', 'parcel') and (spd_fraud_flag!=True or spd_fraud_flag is null) and order_status = 'dropped' then order_id end) as net_rides_c2c,
                        count(distinct case when spd_fraud_flag=True then order_id end) as num_fraud_rides_all,
                        -- added gta , mc , delivery and courier orders, temporal cuts as well
                        
                        sum(distinct case when hour between '06' and '10' and sdid.supercategory = 'taxi' and order_status = 'dropped' then accept_to_pickup_distance end) as fm_taxi_morning_peak,
                        sum(distinct case when hour between '06' and '10' and sdid.supercategory = 'taxi' and order_status = 'dropped' then distance_final_distance end) as lm_taxi_morning_peak,
                        count(distinct case when hour between '06' and '10' and sdid.supercategory = 'taxi' and order_status = 'dropped' then order_id end) as net_rides_taxi_morning_peak,
                        
                        sum(distinct case when hour between '11' and '15' and sdid.supercategory = 'taxi' and order_status = 'dropped' then accept_to_pickup_distance end) as fm_taxi_afternoon,
                        sum(distinct case when hour between '11' and '15' and sdid.supercategory = 'taxi' and order_status = 'dropped' then distance_final_distance end) as lm_taxi_afternoon,
                        count(distinct case when hour between '11' and '15' and sdid.supercategory = 'taxi' and order_status = 'dropped' then order_id end) as net_rides_taxi_afternoon,
                        
                        sum(distinct case when hour between '16' and '20' and sdid.supercategory = 'taxi' and order_status = 'dropped' then accept_to_pickup_distance end) as fm_taxi_evening_peak,
                        sum(distinct case when hour between '16' and '20' and sdid.supercategory = 'taxi' and order_status = 'dropped' then distance_final_distance end) as lm_taxi_evening_peak,
                        count(distinct case when hour between '16' and '20' and sdid.supercategory = 'taxi' and order_status = 'dropped' then order_id end) as net_rides_taxi_evening_peak,
                        
                        sum(distinct case when (hour >= '21' or hour <= '01') and sdid.supercategory = 'taxi' and order_status = 'dropped' then accept_to_pickup_distance end) as fm_taxi_night,
                        sum(distinct case when (hour >= '21' or hour <= '01') and sdid.supercategory = 'taxi' and order_status = 'dropped' then distance_final_distance end) as lm_taxi_night,
                        count(distinct case when (hour >= '21' or hour <= '01') and sdid.supercategory = 'taxi' and order_status = 'dropped' then order_id end) as net_rides_taxi_night,
                        
                        sum(distinct case when hour between '02' and '05' and sdid.supercategory = 'taxi' and order_status = 'dropped' then accept_to_pickup_distance end) as fm_taxi_overnight,
                        sum(distinct case when hour between '02' and '05' and sdid.supercategory = 'taxi' and order_status = 'dropped' then distance_final_distance end) as lm_taxi_overnight,
                        count(distinct case when hour between '02' and '05' and sdid.supercategory = 'taxi' and order_status = 'dropped' then order_id end) as net_rides_taxi_overnight
                    from
                        orders.order_logs_fact olf
                    inner join sdid 
                        on olf.service_detail_id = sdid.service_detail_id
                    where yyyymmdd between   date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
                    group by 1,2,3
                ),

                        
                suspension as 
                ( -- cap x date
                    Select 
                        distinct 
                            yyyymmdd,
                            riderinfo__userid captain_id,
                            sum(case when lower(riderinfo__suspendedsubservicetypes) like '%link%' then 1 else 0 end) as link_suspension,
                            sum(cast(riderinfo__suspensionduration as double)/(24*3600.0000)) as suspension_duration_days,
                            sum(case when riderinfo__suspensionduration <3600 then 1 else 0 end) as short_suspension,
                            sum(case when riderinfo__suspensionduration <4*3600 and riderinfo__suspensionduration>=3600 then 1 else 0 end) as session_suspension,
                            sum(case when riderinfo__suspensionduration >=4*3600 and riderinfo__suspensionduration <=24*3600 then 1 else 0 end) as day_suspension,
                            sum(case when riderinfo__suspensionduration >24*3600 and riderinfo__suspensionduration <=30*24*3600 then 1 else 0 end) as multiday_suspension,
                            sum(case when riderinfo__suspensionduration >30*24*3600 then 1 else 0 end) as longterm_suspension,
                            sum(case 
                                when riderinfo__source = 'dashboard' and riderinfo__suspensionreason in ('Asked customer to cancel and did offline order', 'Did not complete rides after accepting') 
                                then 1 else 0 
                            end) as quality_campaign_suspension,
                            sum(case when riderinfo__source = 'profiles-dashboard' then 1 else 0 end) as escalated_offence_suspension,
                            sum(
                                case 
                                    when riderinfo__source = 'profiles-dashboard' 
                                    and regexp_extract(lower(riderinfo__suspensionreason), '(captain unprofessional|unethical behaviour|rash driving|harassement|abuse|sexual|assault|drunk|behaviour issue)',0) != '' 
                                    THEN 1 else 0 
                                end
                            ) as escalated_p0_suspension,
                            sum(case when riderinfo__source = 'rapido-loyalty' and riderinfo__suspensionreason in ('customer_cancelled') then 1 else 0 end) as delivery_cc_offence,
                            sum(case when riderinfo__source = 'captain-subscription' and riderinfo__suspensionreason ='' then 1 else 0 end) as cabs_subs_suspension_maybe_noisy
                    from hive.canonical.iceberg_domain_entities_captainservices_immutable
                    where yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
                        and event_type in ('suspension')
                    group by 1,2
                ),

                recharge as (
                    select
                        yyyymmdd,
                        owner_id captain_id,
                        count(case when wlt_post_recharged< -200 then wlt_post_recharged end) as num_balance_lt_200,
                        min(wlt_post_recharged) as min_balance,
                        avg(case when subtype = 'walletRecharge' then amount end) as avg_recharged_amount,
                        count(case when subtype = 'walletRecharge' then amount end) as num_recharges
                    from (
                        select 
                            t2.yyyymmdd,
                            owner_id,
                            amount,
                            subtype,

                            0 as wlt_recharged, -- cast(json_array_get(cast(wallets_amount as json),0) as double) as wlt_recharged,
                            0 as wlt_post_recharged -- cast(json_array_get(cast(wallets_post_balance as json),0) as double) as wlt_post_recharged
                        from
                            payments.transactions_snapshot t2
                        inner join ao on ao.captain_id = t2.owner_id and t2.yyyymmdd = ao.yyyymmdd
                        where
                            t2.yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
                            and owner_type= 'captain'
                    )
                    group by 1,2
                ),
                        
                base as (
                    select
                        distinct 
                            captain_id, 
                            currentvehicle_number, 
                            device_device_id, 
                            license_number, 
                            ride_n_14, 
                            first_ridedate
                    from datasets.captain_supply_journey_summary
                    inner join ao
                        using(captain_id)
                    where lower(city_name) = '{city}'
                    and activation_date is not null
                    and lower(servicename) like '%{service}%'
                ),

                earnings as ( -- add tod, dow and wom level earnings 
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
                ),

                lh as ( -- swap out
                    select 
                        captain_id,
                        clh.yyyymmdd,
                        sum(case when status in ('2','3','6','7','8','10') then duration/3600000.0000 else 0 end) as total_lh,
                        sum(case when status in ('6','7','8','10') then duration/3600000.0000 else 0 end) as ride_time_lh,
                        sum(case when status in ('2','3') then duration/3600000.0000 else 0 end) as idle_lh,
                        sum(case when quarter_hour between '0600' and '1045' and status in ('2','3','6','7','8','10') then duration/3600000.0000 else 0 end) as total_lh_morning_peak,
                        sum(case when quarter_hour between '0600' and '1045' and status in ('2','3') then duration/3600000.0000 else 0 end) as idle_lh_morning_peak,
                        sum(case when quarter_hour between '1100' and '1545' and status in ('2','3','6','7','8','10') then duration/3600000.0000 else 0 end) as total_lh_afternoon,
                        sum(case when quarter_hour between '1100' and '1545' and status in ('2','3') then duration/3600000.0000 else 0 end) as idle_lh_afternoon,
                        sum(case when quarter_hour between '1600' and '2045' and status in ('2','3','6','7','8','10') then duration/3600000.0000 else 0 end) as total_lh_evening_peak,
                        sum(case when quarter_hour between '1600' and '2045' and status in ('2','3') then duration/3600000.0000 else 0 end) as idle_lh_evening_peak,
                        sum(case when (quarter_hour >= '2100' or quarter_hour<= '0145') and status in ('2','3','6','7','8','10') then duration/3600000.0000 else 0 end) as total_lh_night,
                        sum(case when (quarter_hour >= '2100' or quarter_hour<= '0145') and status in ('2','3') then duration/3600000.0000 else 0 end) as idle_lh_night,
                        sum(case when quarter_hour between '0200' and '0545' and status in ('2','3','6','7','8','10') then duration/3600000.0000 else 0 end) as total_lh_overnight,
                        sum(case when quarter_hour between '0200' and '0545' and status in ('2','3') then duration/3600000.0000 else 0 end) as idle_lh_overnight
                    from
                        datasets.captain_login_hours clh
                    inner join online_data 
                        on online_data.captain_id= clh.userid 
                        and online_data.yyyymmdd = clh.yyyymmdd
                    where clh.yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
                    group by 1,2
                )

            
                select 
                    distinct 

                    cast(ao_base.captain_id as varchar) captain_id,
                    cast(ao_base.yyyymmdd as varchar) yyyymmdd,
                    cast(ao_base.currentvehicle_number as varchar) currentvehicle_number ,
                    cast(ao_base.device_device_id as varchar) device_device_id ,
                    cast(ao_base.license_number as varchar) license_number ,
                    cast(coalesce(ao_base.ride_n_14, date'2029-12-31') as varchar) ride_n_14,
                    cast(coalesce(ao_base.first_ridedate,date'2029-12-31') as varchar) first_ridedate,
                    cast(ao_base.PHH_flag as varchar) PHH_flag,
                    cast(ao_base.RTU_flag as varchar) RTU_flag,
                    cast(ao_base.city as varchar) city,

                    cast(coalesce(ao_base.num_ao,0)  as double) num_ao,
                    cast(coalesce(ao_base.num_ao_morning_peak,0)  as double) num_ao_morning_peak,
                    cast(coalesce(ao_base.num_ao_afternoon,0)  as double) num_ao_afternoon,
                    cast(coalesce(ao_base.num_ao_evening_peak,0)  as double) num_ao_evening_peak,
                    cast(coalesce(ao_base.num_ao_night,0)  as double) num_ao_night,
                    cast(coalesce(ao_base.num_ao_overnight,0)  as double) num_ao_overnight,

                    cast(coalesce(num_online,0) as double) num_online,
                    cast(coalesce(num_online_morning_peak,0) as double) num_online_morning_peak,
                    cast(coalesce(num_online_afternoon,0) as double) num_online_afternoon,
                    cast(coalesce(num_online_evening_peak,0) as double) num_online_evening_peak,
                    cast(coalesce(num_online_night,0) as double) num_online_night,
                    cast(coalesce(num_online_overnight,0) as double) num_online_overnight,

                    cast(coalesce(gross_pings,0) as double) gross_pings,
                    cast(coalesce(accepted_pings,0) as double) accepted_pings,
                    cast(coalesce(raf_pings,0) as double) raf_pings,
                    cast(coalesce(gross_fm,0) as double) gross_fm,
                    cast(coalesce(gross_orders,0) as double) gross_orders,
                    cast(coalesce(accepted_orders,0) as double) accepted_orders,
                    cast(coalesce(gross_pings_morning_peak,0) as double) gross_pings_morning_peak,
                    cast(coalesce(accepted_pings_morning_peak,0) as double) accepted_pings_morning_peak,
                    cast(coalesce(gross_orders_morning_peak,0) as double) gross_orders_morning_peak,
                    cast(coalesce(accepted_orders_morning_peak,0) as double) accepted_orders_morning_peak,
                    cast(coalesce(gross_pings_afternoon,0) as double) gross_pings_afternoon,
                    cast(coalesce(accepted_pings_afternoon,0) as double) accepted_pings_afternoon,
                    cast(coalesce(gross_orders_afternoon,0) as double) gross_orders_afternoon,
                    cast(coalesce(accepted_orders_afternoon,0) as double) accepted_orders_afternoon,
                    cast(coalesce(gross_pings_evening_peak,0) as double) gross_pings_evening_peak,
                    cast(coalesce(accepted_pings_evening_peak,0) as double) accepted_pings_evening_peak,
                    cast(coalesce(gross_orders_evening_peak,0) as double) gross_orders_evening_peak,
                    cast(coalesce(accepted_orders_evening_peak,0) as double) accepted_orders_evening_peak,
                    cast(coalesce(gross_pings_night,0) as double) gross_pings_night,
                    cast(coalesce(accepted_pings_night,0) as double) accepted_pings_night,
                    cast(coalesce(gross_orders_night,0) as double) gross_orders_night,
                    cast(coalesce(accepted_orders_night,0) as double) accepted_orders_night,
                    cast(coalesce(gross_pings_overnight,0) as double) gross_pings_overnight,
                    cast(coalesce(accepted_pings_overnight,0) as double) accepted_pings_overnight,
                    cast(coalesce(gross_orders_overnight,0) as double) gross_orders_overnight,
                    cast(coalesce(accepted_orders_overnight,0) as double) accepted_orders_overnight,

                    cast(coalesce(fm_taxi,0) as double) fm_taxi,
                    cast(coalesce(lm_taxi,0) as double) lm_taxi,
                    cast(coalesce(net_rides_taxi,0) as double) net_rides_taxi,
                    cast(coalesce(net_rides_taxi_gta,0) as double) net_rides_taxi_gta,
                    cast(coalesce(net_rides_taxi_orb,0) as double) net_rides_taxi_orb,
                    cast(coalesce(net_rides_taxi_mc,0) as double) net_rides_taxi_mc,
                    cast(coalesce(net_rides_delivery,0) as double) net_rides_delivery,
                    cast(coalesce(net_rides_c2c,0) as double) net_rides_c2c,
                    cast(coalesce(num_fraud_rides_all,0) as double) num_fraud_rides_all,
                    cast(coalesce(fm_taxi_morning_peak,0) as double) fm_taxi_morning_peak,
                    cast(coalesce(lm_taxi_morning_peak,0) as double) lm_taxi_morning_peak,
                    cast(coalesce(net_rides_taxi_morning_peak,0) as double) net_rides_taxi_morning_peak,
                    cast(coalesce(fm_taxi_afternoon,0) as double) fm_taxi_afternoon,
                    cast(coalesce(lm_taxi_afternoon,0) as double) lm_taxi_afternoon,
                    cast(coalesce(net_rides_taxi_afternoon,0) as double) net_rides_taxi_afternoon,
                    cast(coalesce(fm_taxi_evening_peak,0) as double) fm_taxi_evening_peak,
                    cast(coalesce(lm_taxi_evening_peak,0) as double) lm_taxi_evening_peak,
                    cast(coalesce(net_rides_taxi_evening_peak,0) as double) net_rides_taxi_evening_peak,
                    cast(coalesce(fm_taxi_night,0) as double) fm_taxi_night,
                    cast(coalesce(lm_taxi_night,0) as double) lm_taxi_night,
                    cast(coalesce(net_rides_taxi_night,0) as double) net_rides_taxi_night,
                    cast(coalesce(fm_taxi_overnight,0) as double) fm_taxi_overnight,
                    cast(coalesce(lm_taxi_overnight,0) as double) lm_taxi_overnight,
                    cast(coalesce(net_rides_taxi_overnight,0) as double) net_rides_taxi_overnight,
                    cast(coalesce(avg_customer_rating,0) as double) avg_customer_rating,
                    cast(coalesce(num_low_rated_orders,0) as double) num_low_rated_orders,
                    cast(coalesce(num_customer_ratings, 0) as double) num_rated_orders,

                    cast(coalesce(suspension_duration_days,0) as double) suspension_duration_days,
                    cast(coalesce(link_suspension,0) as double) link_suspension,
                    cast(coalesce(short_suspension,0) as double) short_suspension,
                    cast(coalesce(session_suspension,0) as double) session_suspension,
                    cast(coalesce(day_suspension,0) as double) day_suspension,
                    cast(coalesce(multiday_suspension,0) as double) multiday_suspension,
                    cast(coalesce(longterm_suspension,0) as double) longterm_suspension,
                    cast(coalesce(quality_campaign_suspension,0) as double) quality_campaign_suspension,
                    cast(coalesce(escalated_offence_suspension,0) as double) escalated_offence_suspension,
                    cast(coalesce(escalated_p0_suspension,0) as double) escalated_p0_suspension,
                    cast(coalesce(delivery_cc_offence,0) as double) delivery_cc_offence,
                    cast(coalesce(cabs_subs_suspension_maybe_noisy,0) as double) cabs_subs_suspension_maybe_noisy,

                    cast(coalesce(num_balance_lt_200,0) as double) num_balance_lt_200,
                    cast(coalesce(min_balance,0) as double) min_balance,
                    cast(coalesce(avg_recharged_amount,0) as double) avg_recharged_amount,
                    cast(coalesce(num_recharges,0) as double) num_recharges,

                    cast(coalesce(GMV, 0) as double) GMV,
                    cast(coalesce(FM_earnings, 0) as double) FM_earnings,
                    cast(coalesce(LM_earnings, 0) as double) LM_earnings,
                    cast(coalesce(subs_orders, 0) as double) subs_orders,
                    cast(coalesce(order_earnings, 0) as double) order_earnings,
                    cast(coalesce(distributed_sl2_rule_amount, 0) as double) distributed_sl2_rule_amount,
                    cast(coalesce(total_incentives, 0) as double) total_incentives,
                    cast(coalesce(take, 0) as double) take,
                    cast(coalesce(final_captain_earnings, 0) as double) final_captain_earnings,
                    -- cast(coalesce(final_epkm, 0) as double) final_epkm,
                    -- cast(coalesce(order_epkm, 0) as double) order_epkm,
                    -- cast(coalesce(final_eph, 0) as double) final_eph,
                    -- cast(coalesce(order_eph, 0) as double) order_eph,

                    cast(coalesce(total_lh,0) as double) total_lh,
                    cast(coalesce(idle_lh,0) as double) idle_lh,
                    cast(coalesce(total_lh_morning_peak,0) as double) total_lh_morning_peak,
                    cast(coalesce(idle_lh_morning_peak,0) as double) idle_lh_morning_peak,
                    cast(coalesce(total_lh_afternoon,0) as double) total_lh_afternoon,
                    cast(coalesce(idle_lh_afternoon,0) as double) idle_lh_afternoon,
                    cast(coalesce(total_lh_evening_peak,0) as double) total_lh_evening_peak,
                    cast(coalesce(idle_lh_evening_peak,0) as double) idle_lh_evening_peak,
                    cast(coalesce(total_lh_night,0) as double) total_lh_night,
                    cast(coalesce(idle_lh_night,0) as double) idle_lh_night,
                    cast(coalesce(total_lh_overnight,0) as double) total_lh_overnight,
                    cast(coalesce(idle_lh_overnight,0) as double) idle_lh_overnight,

                    cast(coalesce(customer_call_captain_flag,0) as double) customer_call_captain_flag,
                    cast(coalesce(customer_message_captain_flag,0) as double) customer_message_captain_flag,
                    cast(coalesce(captain_call_customer_flag,0) as double) captain_call_customer_flag,
                    cast(coalesce(captain_message_customer_flag,0) as double) captain_message_customer_flag,
                    cast(coalesce(cancelled_fm,0) as double) cancelled_fm,
                    cast(coalesce(cancelled_lm,0) as double) cancelled_lm,
                    cast(coalesce(a2c_distance,0) as double) a2c_distance,
                    cast(coalesce(c2p_distance,0) as double) c2p_distance,
                    cast(coalesce(time_to_cancel_mins,0) as double) time_to_cancel_mins,
                    cast(coalesce(customerCancelled,0) as double) customerCancelled,
                    cast(coalesce(riderCancelled,0) as double) riderCancelled,
                    cast(coalesce(primary_bad_match,0) as double) primary_ocara_bad_match,
                    cast(coalesce(primary_quick_cancellations,0) as double) primary_ocara_quick_cancellations,
                    cast(coalesce(primary_unclassified,0) as double) primary_ocara_unclassified,
                    cast(coalesce(primary_offline,0) as double) primary_ocara_offline,
                    cast(coalesce(primary_moving_opp,0) as double) primary_ocara_moving_opp,
                    cast(coalesce(primary_not_moving,0) as double) primary_ocara_not_moving,
                    cast(coalesce(primary_noshow,0) as double) primary_ocara_noshow,
                    cast(coalesce(primary_intent_issue,0) as double) primary_ocara_intent_issue,

                    cast(case when ao_base.num_ao >0 then 1.00 else 0.00 end  as double) as app_open,
                    cast(case when online_data.num_online >0 then 1.00 else 0.00 end  as double) as online,
                    cast(case when gross_pings>0 then 1.00 else 0.00 end as double) as gross_captain,
                    cast(case when accepted_orders>0 then 1.00 else 0.00 end  as double) as accepted_captain,
                    cast(case when net_rides_taxi >0 then 1.00 else 0.00 end  as double) as net_captain
                from (
                    select 
                        ao.captain_id,
                        ao.yyyymmdd,
                        currentvehicle_number, 
                        device_device_id, 
                        license_number, 
                        ride_n_14,
                        first_ridedate,
                        case when ride_n_14 is null or date_format(ride_n_14, '%Y%m%d') > ao.yyyymmdd then 'HH' else 'PHH' end PHH_flag,
                        case when first_ridedate is null or date_format(first_ridedate, '%Y%m') >= substr(ao.yyyymmdd,1,6) then 'FTU' else 'RTU' end RTU_flag,
                        lower(ao.city) city,
                        num_ao,
                        num_ao_morning_peak,
                        num_ao_afternoon,
                        num_ao_evening_peak,
                        num_ao_night,
                        num_ao_overnight
                    from 
                        ao 
                    inner join base
                        on ao.captain_id = base.captain_id 
                    where 
                        ao.yyyymmdd between date_format(date('{{StartDate}}'), '%Y%m%d') and date_format(date('{{EndDate}}'), '%Y%m%d')
                ) ao_base
                left join online_data 
                    on ao_base.captain_id = online_data.captain_id
                    and ao_base.yyyymmdd = online_data.yyyymmdd 
                left join offline_events
                    on ao_base.captain_id = offline_events.captain_id
                    and ao_base.yyyymmdd = offline_events.yyyymmdd 
                left join gross_pings 
                    on ao_base.captain_id = gross_pings.captain_id 
                    and ao_base.yyyymmdd = gross_pings.yyyymmdd 
                left join net_data 
                    on ao_base.captain_id = net_data.captain_id 
                    and ao_base.yyyymmdd = net_data.yyyymmdd 
                left join suspension 
                    on ao_base.captain_id = suspension.captain_id 
                    and ao_base.yyyymmdd = suspension.yyyymmdd 
                left join recharge 
                    on ao_base.captain_id = recharge.captain_id
                    and ao_base.yyyymmdd = recharge.yyyymmdd 
                left join earnings
                    on ao_base.captain_id = earnings.captain_id
                    and ao_base.yyyymmdd = earnings.yyyymmdd 
                left join lh 
                    on ao_base.captain_id = lh.captain_id
                    and ao_base.yyyymmdd = lh.yyyymmdd 
                left join odin
                    on ao_base.captain_id = odin.captain_id
                    and ao_base.yyyymmdd = odin.yyyymmdd
                    
                    
                    
                    
