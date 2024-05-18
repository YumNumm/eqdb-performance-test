DELETE FROM public.users_notification_settings;
DELETE FROM public.users_earthquake_settings;
DELETE FROM public.users_eew_settings;
DELETE FROM public.users;

INSERT INTO public.users(fcm_token)
/* 100ユーザ分のダミーデータ */
SELECT md5(random()::text) FROM generate_series(1, 100);

/* 通知条件のダミーデータ */
INSERT INTO public.users_notification_settings(id, notification_volume)
SELECT id, random() FROM public.users;

/* 地震通知条件のダミーデータ */
INSERT INTO public.users_earthquake_settings(id, region_id, min_jma_intensity)
SELECT
  id,
  region_id,
  (
    SELECT * FROM unnest(enum_range(NULL::jma_intensity)) AS t ORDER BY random() LIMIT 1
  )
FROM public.users
CROSS JOIN generate_series((random()*47)::integer, (random()*47)::integer) AS region_id;