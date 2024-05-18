DELETE FROM public.users_notification_settings;
DELETE FROM public.users_earthquake_settings;
DELETE FROM public.users_eew_settings;
DELETE FROM public.users;

INSERT INTO public.users(fcm_token)
/* 5000ユーザ分のダミーデータ */
SELECT md5(random()::text) FROM generate_series(1, 5000);

/* 通知条件のダミーデータ */
INSERT INTO public.users_notification_settings(id, notification_volume)
SELECT id, random() FROM public.users;

