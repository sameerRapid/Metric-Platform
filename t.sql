]with csjs as (
    select 
        sjs.captain_id as captain_id, 
        regexp_replace(lower(sjs.servicename),'[^a-zA-Z0-9,]','') as  servicename
    from datasets.captain_supply_journey_summary as sjs
    where sjs.registration_date <=date_format({{end_ymd}},'%Y-%m-%d')
),
service_name as (
  select a.service_category service_category,
  regexp_replace(array_join(array_agg(distinct a.service_level),'|'),'[^a-zA-Z0-9|]','') as service_level
  from datasets.service_level_mapping_qc a
  group by service_category
),
service as (
  select captain_id,
  max(case when regexp_extract(csjs.servicename, service_name.service_level, 0)!='' and lower(service_category)='cab' then service_category 
       else ''
       end) as cab, 
  max(case when regexp_extract(csjs.servicename, service_name.service_level, 0)!='' and lower(service_category)='link' then service_category 
       else ''
       end) as link,
  max(case when regexp_extract(csjs.servicename, service_name.service_level, 0)!='' and lower(service_category)='auto' then service_category 
       else ''
  end) as auto,
  max(case when regexp_extract(csjs.servicename, service_name.service_level, 0)!='' and lower(service_category)='delivery' then service_category 
       else ''
  end) as delivery,
  max(case when regexp_extract(csjs.servicename, service_name.service_level, 0)!='' and lower(service_category)='c2c' then service_category 
       else ''
  end) as c2c
  from csjs
  cross join service_name
  group by captain_id
),
 ao as (
  select *
  from mne.ms_1258688567_375063565 a
  where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
online  as (
  select *
  from mne.ms_4043640280_375063565 a
  where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
lh as (
  select *
  from  mne.ms_718608755_375063565 a
  where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
olf as (
 select *
 from mne.ms_1720715499_375063565 a
 where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
dpi as(
  select *
  from mne.ms_125836489_375063565 a
  where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
offline as (
   select *
   from  mne.ms_4270853686_375063565 a
   where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
byob as (
 select *
   from mne.ms_2467573470_375063565 a
   where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
redeemgems as (
  select *
  from mne.ms_2013342159_375063565 a
  where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
servicelevel as (
  select *
  from mne.ms_446570670_375063565 a
  where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
sv as (
  select *
  from mne.ms_2012550830_2833648508 a
  where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
gemcoins as (
   select *
   from mne.ms_2233214824_375063565 a
   where date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') between date_format({{start_ymd}},'%Y%m%d') and date_format({{end_ymd}},'%Y%m%d')
    and a.time_level='daily'
    and a.service_hierarchy='NA'
),
finalTbl as(
    select a.captain_id,
            a.geo_city as city,
            date_format(date_parse(a.time_value,'%Y-%m-%d-%H-%i'),'%Y%m%d') as time_value,
            max_captain_is_auto_ncr_service_level_captain,
            max_captain_is_auto_pet_service_level_captain,
            max_captain_is_auto_pool_service_level_captain,
            max_captain_is_bike_metro_service_level_captain,
            max_captain_is_bike_pink_service_level_captain,
            max_captain_is_cab_economy_service_level_captain,
            max_captain_is_cab_premium_service_level_captain,
            max_captain_is_cab_share_service_level_captain,
            max_captain_is_cab_suv_service_level_captain,
            max_captain_is_cabac_service_level_captain,
            max_captain_is_e_rickshaw_service_level_captain,
            max_captain_is_link_service_level_captain,
            max_captain_is_scooty_service_level_captain,
            sum_captain_idle_lh_afternoon_daily_city,
            sum_captain_idle_lh_daily_city,
            sum_captain_idle_lh_evening_peak_daily_city,
            sum_captain_idle_lh_morning_peak_daily_city,
            sum_captain_idle_lh_night_daily_city,
            sum_captain_total_lh_afternoon_daily_city,
            sum_captain_total_lh_daily_city,
            sum_captain_total_lh_evening_peak_daily_city,
            sum_captain_total_lh_morning_peak_daily_city,
            sum_captain_total_lh_night_daily_city,
            count_captain_auto_orders_all_day_city,
            count_captain_c2c_orders_all_day_city,
            count_captain_cab_orders_all_day_city,
            count_captain_customer_low_rating_taxi_all_day_city,
            count_captain_customer_rating_taxi_all_day_city,
            count_captain_delivery_orders_all_day_city,
            count_captain_fraud_rides_all_day_city,
            count_captain_link_orders_all_day_city,
            count_captain_net_rides_taxi_afternoon_city,
            count_captain_net_rides_taxi_all_day_city,
            count_captain_net_rides_taxi_evening_peak_city,
            count_captain_net_rides_taxi_gta_all_day_city,
            count_captain_net_rides_taxi_mc_all_day_city,
            count_captain_net_rides_taxi_morning_peak_city,
            count_captain_net_rides_taxi_orb_all_day_city,
            count_captain_net_rides_taxi_rest_midnight_city,
            max_captain_last_dropped_epoch_all_day_city,
            min_captain_first_dropped_epoch_all_day_city,
            sum_captain_customer_rating_taxi_all_day_city,
            sum_captain_net_fm_taxi_afternoon_city,
            sum_captain_net_fm_taxi_all_day_city,
            sum_captain_net_fm_taxi_evening_peak_city,
            sum_captain_net_fm_taxi_morning_peak_city,
            sum_captain_net_fm_taxi_rest_midnight_city,
            sum_captain_net_lm_taxi_afternoon_city,
            sum_captain_net_lm_taxi_all_day_city,
            sum_captain_net_lm_taxi_evening_peak_city,
            sum_captain_net_lm_taxi_morning_peak_city,
            sum_captain_net_lm_taxi_rest_midnight_city,
            captain_avg_rating,
            count_captain_accepted_orders_afternoon_taxi,
            count_captain_accepted_orders_all_day_taxi,
            count_captain_accepted_orders_evening_peak_taxi,
            count_captain_accepted_orders_morning_peak_taxi,
            count_captain_accepted_pings_afternoon_taxi,
            count_captain_accepted_pings_auto_all_day_city,
            count_captain_accepted_pings_cab_all_day_city,
            count_captain_accepted_pings_delivery_all_day_city,
            count_captain_accepted_pings_evening_peak_taxi,
            count_captain_accepted_pings_link_all_day_city,
            count_captain_accepted_pings_morning_peak_taxi,
            count_captain_accepted_pings_rest_midnight_taxi,
            count_captain_accepted_pings_taxi_all_day_city,
            count_captain_ack_failed_pings_taxi_all_day_city,
            count_captain_gross_orders_afternoon_taxi,
            count_captain_gross_orders_all_day_taxi,
            count_captain_gross_orders_evening_peak_taxi,
            count_captain_gross_orders_morning_peak_taxi,
            count_captain_gross_orders_rest_midnight_taxi,
            count_captain_gross_pings_afternoon_taxi,
            count_captain_gross_pings_auto_all_day_city,
            count_captain_gross_pings_cab_all_day_city,
            count_captain_gross_pings_delivery_all_day_city,
            count_captain_gross_pings_evening_peak_taxi,
            count_captain_gross_pings_link_all_day_city,
            count_captain_gross_pings_morning_peak_taxi,
            count_captain_gross_pings_rest_midnight_taxi,
            count_captain_gross_pings_taxi_all_day_city,
            count_captain_nrr_pings_taxi_all_day_city,
            count_captain_raf_pings_taxi_all_day_city,
            count_captain_rider_busy_pings_taxi,
            min_captain_first_delivery_accept_epoch_all_day_city,
            min_captain_first_delivery_ping_epoch_all_day_city,
            min_captain_first_taxi_accept_epoch_all_day_city,
            min_captain_first_taxi_ping_epoch_all_day_city,
            sum_captain_gross_fm_all_day_taxi,
            sum_captain_gross_lm_all_day_taxi,
            count_num_offline_afternoon_daily_city,
            count_num_offline_daily_city,
            count_num_offline_evening_peak_daily_city,
            count_num_offline_morning_peak_daily_city,
            count_num_offline_rest_midnight_daily_city,
            count_captain_num_online_daily_city,
            count_num_online_afternoon_daily_city,
            count_num_online_evening_peak_daily_city,
            count_num_online_morning_peak_daily_city,
            count_num_online_rest_midnight_daily_city,
            count_captain_number_app_open_captains_daily_all_day_city,
            count_captain_number_app_opens_daily_afternoon_city,
            count_captain_number_app_opens_daily_all_day_city,
            count_captain_number_app_opens_daily_evening_peak_city,
            count_captain_number_app_opens_daily_morning_peak_city,
            count_captain_number_app_opens_daily_rest_midnight_city,
            min_captain_first_app_open_epoch_city,
            max_captain_subs_page_visited_all_day_city,
            sum_captain_redeemed_coins_all_day_city,
            byob_confirmed_commission_model,
            byob_confirmed_epkm_model,
            byob_confirmed_subs_model,
            byob_page_visited_flag,
            byob_plan_confirmed_flag,
            byob_plan_explored_flag,
            count_byob_plan_confirmed,
            count_captain_gem_ftux_coins_all_day_city
    from ao a
    full outer join online b
    on a.captain_id=b.captain_id
    and a.geo_city=b.geo_city
    and a.time_value=b.time_value
    full outer join lh c
    on a.captain_id =c.captain_id
    and a.geo_city=c.geo_city
    and a.time_value=c.time_value
    full outer join olf d
    on a.captain_id=d.captain_id
    and a.geo_city=d.geo_city
    and a.time_value=d.time_value
    full outer join dpi e
    on a.captain_id=e.captain_id
    and a.geo_city=e.geo_city
    and a.time_value=e.time_value
    full outer join offline f
    on a.captain_id=f.captain_id
    and a.geo_city=f.geo_city
    and a.time_value=f.time_value
    full outer join byob g
    on a.captain_id=g.captain_id
    and a.geo_city=g.geo_city
    and a.time_value=g.time_value
    full outer join redeemgems h
    on a.captain_id=h.captain_id
    and a.geo_city=h.geo_city
    and a.time_value=h.time_value
    full outer join servicelevel i
    on a.captain_id=i.captain_id
    and a.geo_city=i.geo_city
    and a.time_value=i.time_value
    full outer join sv j
    on a.captain_id=j.subs_visited_page_captain_id
    and a.time_value=j.time_value
    full outer join gemcoins k
    on a.captain_id=k.captain_id
    and a.time_value=k.time_value
)
select a.captain_id,a.city,time_value yyyymmdd,
            trim(trailing '_' from ((if(cab='','',cab||'_')||if(link='','',link||'_')||if(auto='','',auto||'_')||if(delivery='','',delivery||'_')||if(c2c='','',c2c)))) as service_category,
            max_captain_is_auto_ncr_service_level_captain,
            max_captain_is_auto_pet_service_level_captain,
            max_captain_is_auto_pool_service_level_captain,
            max_captain_is_bike_metro_service_level_captain,
            max_captain_is_bike_pink_service_level_captain,
            max_captain_is_cab_economy_service_level_captain,
            max_captain_is_cab_premium_service_level_captain,
            max_captain_is_cab_share_service_level_captain,
            max_captain_is_cab_suv_service_level_captain,
            max_captain_is_cabac_service_level_captain,
            max_captain_is_e_rickshaw_service_level_captain,
            max_captain_is_link_service_level_captain,
            max_captain_is_scooty_service_level_captain,
            sum_captain_idle_lh_afternoon_daily_city,
            sum_captain_idle_lh_daily_city,
            sum_captain_idle_lh_evening_peak_daily_city,
            sum_captain_idle_lh_morning_peak_daily_city,
            sum_captain_idle_lh_night_daily_city,
            sum_captain_total_lh_afternoon_daily_city,
            sum_captain_total_lh_daily_city,
            sum_captain_total_lh_evening_peak_daily_city,
            sum_captain_total_lh_morning_peak_daily_city,
            sum_captain_total_lh_night_daily_city,
            count_captain_auto_orders_all_day_city,
            count_captain_c2c_orders_all_day_city,
            count_captain_cab_orders_all_day_city,
            count_captain_customer_low_rating_taxi_all_day_city,
            count_captain_customer_rating_taxi_all_day_city,
            count_captain_delivery_orders_all_day_city,
            count_captain_fraud_rides_all_day_city,
            count_captain_link_orders_all_day_city,
            count_captain_net_rides_taxi_afternoon_city,
            count_captain_net_rides_taxi_all_day_city,
            count_captain_net_rides_taxi_evening_peak_city,
            count_captain_net_rides_taxi_gta_all_day_city,
            count_captain_net_rides_taxi_mc_all_day_city,
            count_captain_net_rides_taxi_morning_peak_city,
            count_captain_net_rides_taxi_orb_all_day_city,
            count_captain_net_rides_taxi_rest_midnight_city,
            max_captain_last_dropped_epoch_all_day_city,
            min_captain_first_dropped_epoch_all_day_city,
            sum_captain_customer_rating_taxi_all_day_city,
            sum_captain_net_fm_taxi_afternoon_city,
            sum_captain_net_fm_taxi_all_day_city,
            sum_captain_net_fm_taxi_evening_peak_city,
            sum_captain_net_fm_taxi_morning_peak_city,
            sum_captain_net_fm_taxi_rest_midnight_city,
            sum_captain_net_lm_taxi_afternoon_city,
            sum_captain_net_lm_taxi_all_day_city,
            sum_captain_net_lm_taxi_evening_peak_city,
            sum_captain_net_lm_taxi_morning_peak_city,
            sum_captain_net_lm_taxi_rest_midnight_city,
            captain_avg_rating,
            count_captain_accepted_orders_afternoon_taxi,
            count_captain_accepted_orders_all_day_taxi,
            count_captain_accepted_orders_evening_peak_taxi,
            count_captain_accepted_orders_morning_peak_taxi,
            count_captain_accepted_pings_afternoon_taxi,
            count_captain_accepted_pings_auto_all_day_city,
            count_captain_accepted_pings_cab_all_day_city,
            count_captain_accepted_pings_delivery_all_day_city,
            count_captain_accepted_pings_evening_peak_taxi,
            count_captain_accepted_pings_link_all_day_city,
            count_captain_accepted_pings_morning_peak_taxi,
            count_captain_accepted_pings_rest_midnight_taxi,
            count_captain_accepted_pings_taxi_all_day_city,
            count_captain_ack_failed_pings_taxi_all_day_city,
            count_captain_gross_orders_afternoon_taxi,
            count_captain_gross_orders_all_day_taxi,
            count_captain_gross_orders_evening_peak_taxi,
            count_captain_gross_orders_morning_peak_taxi,
            count_captain_gross_orders_rest_midnight_taxi,
            count_captain_gross_pings_afternoon_taxi,
            count_captain_gross_pings_auto_all_day_city,
            count_captain_gross_pings_cab_all_day_city,
            count_captain_gross_pings_delivery_all_day_city,
            count_captain_gross_pings_evening_peak_taxi,
            count_captain_gross_pings_link_all_day_city,
            count_captain_gross_pings_morning_peak_taxi,
            count_captain_gross_pings_rest_midnight_taxi,
            count_captain_gross_pings_taxi_all_day_city,
            count_captain_nrr_pings_taxi_all_day_city,
            count_captain_raf_pings_taxi_all_day_city,
            count_captain_rider_busy_pings_taxi,
            min_captain_first_delivery_accept_epoch_all_day_city,
            min_captain_first_delivery_ping_epoch_all_day_city,
            min_captain_first_taxi_accept_epoch_all_day_city,
            min_captain_first_taxi_ping_epoch_all_day_city,
            sum_captain_gross_fm_all_day_taxi,
            sum_captain_gross_lm_all_day_taxi,
            count_num_offline_afternoon_daily_city,
            count_num_offline_daily_city,
            count_num_offline_evening_peak_daily_city,
            count_num_offline_morning_peak_daily_city,
            count_num_offline_rest_midnight_daily_city,
            count_captain_num_online_daily_city,
            count_num_online_afternoon_daily_city,
            count_num_online_evening_peak_daily_city,
            count_num_online_morning_peak_daily_city,
            count_num_online_rest_midnight_daily_city,
            count_captain_number_app_open_captains_daily_all_day_city,
            count_captain_number_app_opens_daily_afternoon_city,
            count_captain_number_app_opens_daily_all_day_city,
            count_captain_number_app_opens_daily_evening_peak_city,
            count_captain_number_app_opens_daily_morning_peak_city,
            count_captain_number_app_opens_daily_rest_midnight_city,
            min_captain_first_app_open_epoch_city,
            max_captain_subs_page_visited_all_day_city,
            sum_captain_redeemed_coins_all_day_city,
            byob_confirmed_commission_model,
            byob_confirmed_epkm_model,
            byob_confirmed_subs_model,
            byob_page_visited_flag,
            byob_plan_confirmed_flag,
            byob_plan_explored_flag,
            count_byob_plan_confirmed,
            count_captain_gem_ftux_coins_all_day_city
from finalTbl a
left join service b
on a.captain_id=b.captain_id
