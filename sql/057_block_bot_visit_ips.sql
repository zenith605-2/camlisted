-- 구글봇이 방문자로 계속 집계되는 문제의 근본 차단.
--
-- 배경: 052에서 이미 쌓인 66.249.% 행을 지웠고 app.js에 UA 기반 IS_BOT 필터도 넣었지만,
-- 2026-07-22 하루에만 66.249.89.32 한 IP가 168건 기록됐다. 구글 렌더링 서비스(WRS)는
-- 일반 Chrome UA로도 오기 때문에 UA 검사만으로는 못 막는다. 게다가 GitHub Pages(CDN) 캐시 때문에
-- 크롤러가 예전 app.js를 한동안 계속 쓸 수 있어서 클라이언트 수정만으로는 즉시 효과가 없다.
--
-- 그래서 DB 쪽에서 한 번 더 막는다. 66.249.64.0/19는 구글 전용 대역이라 실제 사람이 쓸 일이 없다.

-- (1) 크롤러 IP 대역 목록. 새 대역을 막고 싶으면 여기에 접두사만 추가하면 된다.
create table if not exists bot_ip_prefixes (
  prefix text primary key,
  note   text,
  added_at timestamptz not null default now()
);
alter table bot_ip_prefixes enable row level security;
-- 관리자(service_role)만 다룬다. 별도 정책이 없으므로 anon/authenticated는 읽지도 쓰지도 못한다.

insert into bot_ip_prefixes (prefix, note) values
  ('66.249.', 'Googlebot / Google Web Rendering Service (66.249.64.0/19)')
on conflict (prefix) do nothing;

-- (2) 크롤러 대역에서 온 insert는 조용히 버린다.
--     (에러를 던지면 클라이언트 콘솔에 노출되니 그냥 null 반환으로 무시)
create or replace function block_bot_visit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.ip is not null
     and exists (select 1 from bot_ip_prefixes p where new.ip like p.prefix || '%')
  then
    return null;
  end if;
  return new;
end; $$;

drop trigger if exists visit_log_block_bot on visit_log;
create trigger visit_log_block_bot
before insert on visit_log
for each row execute function block_bot_visit();

-- (3) 오늘까지 쌓인 크롤러 행 정리 (052와 같은 내용, 재실행해도 안전)
delete from visit_durations where visitor_key in (
  select visitor_key from visit_log
  where exists (select 1 from bot_ip_prefixes p where visit_log.ip like p.prefix || '%')
);
delete from visit_log
where exists (select 1 from bot_ip_prefixes p where visit_log.ip like p.prefix || '%');

-- (4) 확인용: 오늘 남은 방문 집계
select count(*) as rows_today, count(distinct ip) as distinct_ips
from visit_log
where visit_date = (now() at time zone 'Asia/Seoul')::date;
