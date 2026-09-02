-- ============================================================
-- 修复 CJYNB / CJYEB / CJYMA 等区域账号：
-- 允许更新自己负责区域内的全部构件状态，不再只限 Column。
-- 区域隔离仍由 _rws_area_ok 严格执行，不能修改其他区域。
-- 在 Supabase SQL Editor 执行本文件即可立即生效。
-- ============================================================

create or replace function public.rws_update_element(
  p_token uuid,
  p_element_key text,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s record;
  parts text[];
  lv text;
  zmk text;
  etype text;
  eid text;
  old_status text;
begin
  select * into s from _rws_session(p_token);
  if p_status not in ('todo','wip','done') then
    raise exception 'bad status';
  end if;

  parts := string_to_array(p_element_key, '||');
  if array_length(parts, 1) <> 4 then
    raise exception 'bad element key';
  end if;

  lv := parts[1];
  zmk := parts[2];
  etype := parts[3];
  eid := parts[4];

  if s.role <> 'admin'
     and not _rws_area_ok(s.allowed_scopes, lv, zmk) then
    raise exception 'not permitted: outside your assigned area';
  end if;

  select status into old_status
  from rws_element_status
  where element_key = p_element_key;

  insert into rws_element_status(
    element_key, level, zone_mk, elem_type, elem_id,
    status, updated_by, updated_at
  ) values (
    p_element_key, lv, zmk, etype, eid,
    p_status, s.user_id, now()
  )
  on conflict (element_key) do update
    set status = excluded.status,
        updated_by = excluded.updated_by,
        updated_at = now();

  insert into rws_activity_log(
    user_id, username, action, target_key, old_value, new_value
  ) values (
    s.user_id, s.username, 'element_status', p_element_key,
    to_jsonb(old_status), to_jsonb(p_status)
  );

  return jsonb_build_object(
    'ok', true,
    'element_key', p_element_key,
    'status', p_status
  );
end;
$$;

grant execute on function public.rws_update_element(uuid,text,text)
to anon, authenticated;
