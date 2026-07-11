-- 유저 제보 남용 방지 1: 하루 제보 개수 제한 (계정당 5개)
create or replace function enforce_submission_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  today_count int;
begin
  select count(*) into today_count
  from streams
  where source = 'user'
    and added_by = new.added_by
    and added_at >= date_trunc('day', now());

  if today_count >= 5 then
    raise exception 'submission_rate_limit_exceeded';
  end if;

  return new;
end;
$$;

create trigger enforce_submission_rate_limit_trigger
  before insert on streams
  for each row
  when (new.source = 'user')
  execute function enforce_submission_rate_limit();
