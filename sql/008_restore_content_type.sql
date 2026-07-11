-- content_type, published_at 컬럼이 어느 시점엔가 빠진 것을 확인해 복구 (안전하게 if not exists 사용)
alter table streams add column if not exists content_type text not null default 'live' check (content_type in ('live', 'video'));
alter table streams add column if not exists published_at timestamptz;
