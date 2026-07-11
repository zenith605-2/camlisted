-- 5단계: 카테고리 DB화 + 기여기반 열람권
-- Supabase SQL Editor에서 1회 실행하세요.

-- ===== A. 카테고리 DB화 =====
create table categories (
  key text primary key,
  keywords text[] not null default '{}',
  label_en text not null,
  label_ko text,
  label_ja text,
  label_zh text,
  label_es text,
  sort_order int not null default 0
);

alter table categories enable row level security;

create policy "categories_public_read"
  on categories for select
  using (true);

insert into categories (key, keywords, label_en, label_ko, label_ja, label_zh, label_es, sort_order) values
  ('beach', array['beach','해수욕장','해변','바다','playa','海滩','ビーチ'], 'Beach', '해변', 'ビーチ', '海滩', 'Playa', 10),
  ('parking', array['parking','주차장','estacionamiento','停车场','駐車場'], 'Parking', '주차장', '駐車場', '停车场', 'Estacionamiento', 20),
  ('traffic', array['traffic','도로','교통','고속도로','carretera','tráfico','交通','道路','高速'], 'Traffic', '교통/도로', '交通・道路', '交通/道路', 'Tráfico/Carretera', 30),
  ('harbor', array['harbor','port','항구','puerto','港','港口'], 'Harbor', '항구', '港', '港口', 'Puerto', 40),
  ('mountain', array['mountain','산','ski','스키장','montaña','山','スキー'], 'Mountain', '산/스키장', '山・スキー場', '山区/滑雪场', 'Montaña/Esquí', 50),
  ('downtown', array['downtown','도심','street','거리','city','시내','centro','街','都市'], 'Downtown', '도심', '繁華街', '市中心', 'Centro', 60),
  ('dashcam', array['dashcam','dash cam','블랙박스','行车记录仪','ドライブレコーダー','cámara de salpicadero'], 'Dashcam', '블랙박스', 'ドライブレコーダー', '行车记录仪', 'Cámara de salpicadero', 70),
  ('wildlife', array['wildlife','야생동물','동물원','zoo','野生动物','野生生物','動物園','vida silvestre'], 'Wildlife', '야생동물', '野生動物', '野生动物', 'Vida silvestre', 80),
  ('crowd', array['crowd','군중','인파','보행자','pedestrian','人群','群衆','多人数'], 'Crowd', '군중/보행자', '人混み/歩行者', '人群/行人', 'Multitud/Peatones', 90),
  ('other', array[]::text[], 'Other', '기타', 'その他', '其他', 'Otro', 999);

-- ===== B. 기여기반 열람권 =====
alter table profiles add column bonus_credits int not null default 0;

create table view_log (
  user_id uuid not null references auth.users(id) on delete cascade,
  view_date date not null default current_date,
  view_count int not null default 0,
  primary key (user_id, view_date)
);

alter table view_log enable row level security;

create policy "view_log_owner_all"
  on view_log for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table unlocked_videos (
  user_id uuid not null references auth.users(id) on delete cascade,
  video_id text not null references streams(video_id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, video_id)
);

alter table unlocked_videos enable row level security;

create policy "unlocked_videos_owner_all"
  on unlocked_videos for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function unlock_video(p_video_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_added_at timestamptz;
  v_is_new boolean;
  v_view_count int;
  v_credits int;
  daily_free_limit constant int := 5;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'reason', 'login_required');
  end if;

  if exists (select 1 from unlocked_videos where user_id = v_user and video_id = p_video_id) then
    return jsonb_build_object('ok', true, 'method', 'already');
  end if;

  select added_at into v_added_at from streams where video_id = p_video_id;
  v_is_new := v_added_at is not null and v_added_at > now() - interval '7 days';

  if not v_is_new then
    insert into unlocked_videos (user_id, video_id) values (v_user, p_video_id)
      on conflict do nothing;
    return jsonb_build_object('ok', true, 'method', 'not_new');
  end if;

  insert into view_log (user_id, view_date, view_count)
    values (v_user, current_date, 0)
    on conflict (user_id, view_date) do nothing;

  select view_count into v_view_count from view_log where user_id = v_user and view_date = current_date;

  if v_view_count < daily_free_limit then
    update view_log set view_count = view_count + 1 where user_id = v_user and view_date = current_date;
    insert into unlocked_videos (user_id, video_id) values (v_user, p_video_id);
    return jsonb_build_object('ok', true, 'method', 'free', 'remaining', daily_free_limit - v_view_count - 1);
  end if;

  select bonus_credits into v_credits from profiles where id = v_user;
  if coalesce(v_credits, 0) > 0 then
    update profiles set bonus_credits = bonus_credits - 1 where id = v_user;
    insert into unlocked_videos (user_id, video_id) values (v_user, p_video_id);
    return jsonb_build_object('ok', true, 'method', 'credit', 'remaining_credits', v_credits - 1);
  end if;

  return jsonb_build_object('ok', false, 'reason', 'no_quota');
end;
$$;

grant execute on function unlock_video(text) to authenticated;

create or replace function grant_bonus_credit(p_user_id uuid, p_amount int default 1)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update profiles set bonus_credits = bonus_credits + p_amount where id = p_user_id;
end;
$$;

grant execute on function grant_bonus_credit(uuid, int) to service_role;
