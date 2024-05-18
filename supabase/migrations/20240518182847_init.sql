ALTER DATABASE postgres
SET timezone to 'Asia/Tokyo';

--------------- FOUNDATION FUNCTIONS ---------------
CREATE OR REPLACE FUNCTION uuid_generate_v7() RETURNS UUID AS
$$
BEGIN
    return encode(set_bit(set_bit(overlay(
        uuid_send(gen_random_uuid())
        placing substring(int8send(floor(extract(epoch from clock_timestamp()) * 1000)::bigint) from 3)
        from 1 for 6
    ), 52, 1), 53, 1), 'hex')::uuid;
END
$$ LANGUAGE plpgsql;

--------------- ENUM DEFINITION ---------------
CREATE TYPE jma_intensity AS ENUM ('0', '1', '2', '3', '4', '!5-', '5-', '5+', '6-', '6+', '7');
CREATE TYPE jma_lg_intensity AS ENUM ('0', '1', '2', '3', '4');

--------------- TELEGRAM TABLE ---------------
CREATE TABLE telegram (
  id SERIAL PRIMARY KEY NOT NULL,
  event_id BIGINT NOT NULL,
  type TEXT NOT NULL,
  schema_type TEXT NOT NULL,
  status TEXT NOT NULL,
  info_type TEXT NOT NULL,
  press_time TIMESTAMPTZ NOT NULL,
  report_time TIMESTAMPTZ NOT NULL,
  valid_time TIMESTAMPTZ,
  serial_no INT,
  headline TEXT,
  body JSONB NOT NULL
);

ALTER TABLE telegram ENABLE ROW LEVEL SECURITY;
CREATE POLICY telegram_select_policy ON telegram FOR SELECT USING (true);

CREATE TABLE eew (
  id SERIAL PRIMARY KEY NOT NULL,
  event_id BIGINT NOT NULL,
  type TEXT NOT NULL,
  schema_type TEXT NOT NULL,
  status TEXT NOT NULL,
  info_type TEXT NOT NULL,
  serial_no INT,
  headline TEXT,
  is_canceled BOOLEAN NOT NULL,
  is_warning BOOLEAN,
  is_last_info BOOLEAN NOT NULL,
  origin_time TIMESTAMPTZ,
  arrival_time TIMESTAMPTZ,
  hypo_name TEXT,
  depth SMALLINT,
  latitude DECIMAL(3,1),
  longitude DECIMAL(4,1),
  magnitude DECIMAL(2,1),
  forecast_max_intensity jma_intensity,
  forecast_max_lpgm_intensity jma_lg_intensity
);

ALTER TABLE eew ENABLE ROW LEVEL SECURITY;
CREATE POLICY eew_select_policy ON eew FOR SELECT USING (true);

--------------- EARTHQUAKE TABLE ---------------
CREATE TABLE earthquake (
  event_id BIGINT PRIMARY KEY NOT NULL,
  status TEXT NOT NULL,
  magnitude DECIMAL(2,1),
  magnitude_condition TEXT,
  max_intensity jma_intensity,
  max_lpgm_intensity jma_lg_intensity,
  depth INT,
  latitude DECIMAL(6,3),
  longitude DECIMAL(6,3),
  epicenter_code SMALLINT,
  epicenter_detail_code SMALLINT,
  arrival_time TIMESTAMPTZ,
  origin_time TIMESTAMPTZ,
  headline TEXT DEFAULT(null),
  text TEXT DEFAULT(null),
  max_intensity_region_ids SMALLINT[] DEFAULT(null)
);

CREATE INDEX IF NOT EXISTS earthquake_magnitude_idx ON earthquake("magnitude", "magnitude_condition");
CREATE INDEX IF NOT EXISTS earthquake_max_intensity_idx ON earthquake("max_intensity");
CREATE INDEX IF NOT EXISTS earthquake_max_lpgm_intensity_idx ON earthquake("max_lpgm_intensity");
CREATE INDEX IF NOT EXISTS earthquake_depth_idx ON earthquake("depth");
CREATE INDEX IF NOT EXISTS earthquake_epicenter_idx ON earthquake("epicenter_code");
CREATE INDEX IF NOT EXISTS earthquake_origin_time_idx ON earthquake("origin_time");

ALTER TABLE earthquake ENABLE ROW LEVEL SECURITY;
CREATE POLICY earthquake_select_policy ON earthquake FOR SELECT USING (true);
--------------- INTENSITY SUB DIVISION TABLE ---------------
CREATE TABLE IF NOT EXISTS intensity_sub_division (
  id SERIAL PRIMARY KEY NOT NULL,
  event_id BIGINT NOT NULL REFERENCES public.earthquake(event_id),
  area_code VARCHAR(5) NOT NULL,
  max_intensity jma_intensity NOT NULL,
  max_lpgm_intensity jma_lg_intensity NULL,
  UNIQUE("event_id", "area_code")
);

CREATE INDEX intensity_sub_division_max_intensity_idx ON intensity_sub_division("max_intensity");
CREATE INDEX intensity_sub_division_max_lpgm_intensity_idx ON intensity_sub_division("max_lpgm_intensity");

ALTER TABLE intensity_sub_division ENABLE ROW LEVEL SECURITY;
CREATE POLICY intensity_sub_division_select_policy ON intensity_sub_division FOR SELECT USING (true);

--------------- INFORMATION TABLE ---------------
CREATE TYPE information_author AS ENUM('jma', 'developer', 'unknown');
CREATE TYPE information_level AS ENUM('info', 'warning', 'critical');

CREATE TABLE information (
  id SERIAL PRIMARY KEY NOT NULL,
  title TEXT NOT NULL,
  author information_author NOT NULL DEFAULT 'unknown',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  event_id INT,
  type TEXT NOT NULL,
  level information_level NOT NULL,
  body JSONB NOT NULL
);

ALTER TABLE information ENABLE ROW LEVEL SECURITY;
CREATE POLICY information_select_policy ON information FOR SELECT USING (true);

--------------- TSUNAMI TABLE ---------------
CREATE TABLE tsunami (
  id SERIAL PRIMARY KEY,
  event_id BIGINT NOT NULL,
  serial_no INT,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL,
  info_type TEXT NOT NULL,
  press_at TIMESTAMPTZ NOT NULL,
  report_at TIMESTAMPTZ NOT NULL,
  valid_at TIMESTAMPTZ,
  body JSONB NOT NULL,
  headline TEXT
);

CREATE INDEX tsunami_event_id_idx ON tsunami("event_id");
CREATE INDEX tsunami_valid_at_idx ON tsunami("valid_at");

ALTER TABLE tsunami ENABLE ROW LEVEL SECURITY;
CREATE POLICY tsunami_select_policy ON tsunami FOR SELECT USING (true);


--------------- EEW FUNCTION ---------------
-- serial_no が最新のものを返す event_id ごとに 1 つだけ返す
CREATE OR REPLACE FUNCTION latest_eew() RETURNS SETOF eew AS
$$
SELECT DISTINCT ON (event_id) * FROM eew ORDER BY event_id, serial_no DESC
LIMIT 5;
$$ LANGUAGE SQL;

--------------- USERS TABLE ---------------
CREATE TABLE public.users (
  id UUID UNIQUE DEFAULT uuid_generate_v7(),
  fcm_token TEXT,
  /* apns_token TEXT DEFAULT null 今後の拡張用 */
  PRIMARY KEY (id, fcm_token)
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--------------- USERS_NOTIFICATION_SETTINGS TABLE ---------------
CREATE TABLE public.users_notification_settings (
  id UUID REFERENCES public.users(id),
  notification_volume DECIMAL(2,1) DEFAULT 1.0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, /* upsert時に一緒に書き換え忘れずに (TRIGGER書いても良い。) */
  /*　もろもろの設定 */
  PRIMARY KEY (id)
);
ALTER TABLE public.users_notification_settings ENABLE ROW LEVEL SECURITY;

--------------- USERS_EARTHQUAKE_SETTINGS TABLE ---------------
CREATE TABLE public.users_earthquake_settings (
  id UUID REFERENCES public.users(id),
  region_id SMALLINT NOT NULL, /* 気象庁のコード表22府県予報区:code (9011~9474) */
  min_jma_intensity jma_intensity NOT NULL, /* 通知する最低震度 */
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, /* upsert時に一緒に書き換え忘れずに (TRIGGER書いても良い。) */
  PRIMARY KEY (id, region_id)
);
ALTER TABLE public.users_earthquake_settings ENABLE ROW LEVEL SECURITY;

--------------- USERS_EEW_SETTINGS TABLE ---------------
CREATE TABLE public.users_eew_settings (
  id UUID REFERENCES public.users(id),
  region_id SMALLINT NOT NULL DEFAULT 0, /* 気象庁のコード表23都道府県等: code (01~47) */
  min_jma_intensity jma_intensity NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, /* upsert時に一緒に書き換え忘れずに (TRIGGER書いても良い。) */
  PRIMARY KEY (id, region_id)
);
ALTER TABLE public.users_eew_settings ENABLE ROW LEVEL SECURITY;