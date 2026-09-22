-- ============================================================
-- 允许获授权的 Site 账号更正已录入的 Actual / Done 数量。
-- 可增加、减少或清空；区域权限、Admin-only 项目和 activity log 均保留。
-- 在 Supabase SQL Editor 整段运行一次（可重复运行）。
-- ============================================================

create or replace function public.rws_set_kv(p_token uuid, p_store text, p_k text, p_value jsonb, p_level text, p_zone_mk text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare s record; old jsonb; report_area text; comment_to text;
begin
  select * into s from _rws_session(p_token);
  select value into old from rws_kv where store = p_store and k = p_k;
  if p_store not in ('act_total','act_plan','act_done_m','act_hidden','elem_date','act_def','crit','zdate','act_date','col_month','act_cmt','settings','edited','manpower','act_upd') then
    raise exception 'bad store';
  end if;

  if s.role <> 'admin' then
    if p_store = 'settings' and p_k = 'bimLinks' then
      if not (coalesce(s.allowed_scopes,'[]'::jsonb) ? 'PLAN') then
        raise exception 'not permitted: Admin or Planning required for BIM links';
      end if;
    elsif p_store = 'settings' and p_k like 'reportOverrides:%' then
      report_area := split_part(p_k, ':', 2);
      if report_area not in ('NB','EB','MA')
         or not (coalesce(s.allowed_scopes,'[]'::jsonb) ? 'REPEDIT')
         or not (coalesce(s.allowed_scopes,'[]'::jsonb) ? report_area) then
        raise exception 'not permitted: Report Edit + matching area required';
      end if;
    elsif p_store in ('act_total','act_plan','act_hidden','act_def','crit','zdate','act_date','col_month','settings','edited') then
      raise exception 'admin only';
    elsif p_store = 'act_cmt' then
      if p_value is null then
        raise exception 'not permitted: only admin can delete comments';
      elsif old is null then
        if not (coalesce(s.allowed_scopes,'[]'::jsonb) ? 'CMT') then
          raise exception 'not permitted: Comment permission required';
        end if;
      else
        comment_to := coalesce(p_value->>'to', old->>'to', '');
        if comment_to = 'Planning' and not (coalesce(s.allowed_scopes,'[]'::jsonb) ? 'PLAN') then
          raise exception 'not permitted: Planning comment';
        elsif comment_to = 'PM' and not _rws_area_ok(s.allowed_scopes, p_level, p_zone_mk) then
          raise exception 'not permitted: PM comment outside assigned area';
        end if;
      end if;
    elsif not _rws_area_ok(s.allowed_scopes, p_level, p_zone_mk) then
      raise exception 'not permitted: outside your assigned area';
    end if;
  end if;

  -- No monotonic restriction: authorised Site users may correct a mistaken
  -- act_done_m value downward or clear it. The old/new values remain audited.
  if p_value is null then
    delete from rws_kv where store = p_store and k = p_k;
  else
    insert into rws_kv(store,k,value,level,zone_mk,updated_by,updated_at)
      values (p_store,p_k,p_value,p_level,p_zone_mk,s.user_id,now())
    on conflict (store,k) do update set value=excluded.value, level=excluded.level,
      zone_mk=excluded.zone_mk, updated_by=excluded.updated_by, updated_at=now();
  end if;
  insert into rws_activity_log(user_id,username,action,target_key,old_value,new_value)
    values (s.user_id,s.username,p_store,p_k,old,p_value);
  return jsonb_build_object('ok',true);
end;$$;

create or replace function public.rws_update_slab_qty(p_token uuid, p_qty_key text, p_level text, p_zone_mk text, p_qty numeric)
returns jsonb language plpgsql security definer set search_path = public as $$
declare s record; old_qty numeric;
begin
  select * into s from _rws_session(p_token);
  if s.role <> 'admin' and not _rws_area_ok(s.allowed_scopes, p_level, p_zone_mk) then
    raise exception 'not permitted: outside your assigned area';
  end if;
  select qty into old_qty from rws_slab_qty where qty_key = p_qty_key;
  -- Authorised Site users may also correct Slab/Pilecap quantities downward.
  insert into rws_slab_qty(qty_key, level, zone_mk, qty, updated_by, updated_at)
    values (p_qty_key, p_level, p_zone_mk, p_qty, s.user_id, now())
  on conflict (qty_key) do update set qty = excluded.qty, updated_by = excluded.updated_by, updated_at = now();
  insert into rws_activity_log(user_id, username, action, target_key, old_value, new_value)
    values (s.user_id, s.username, 'slab_qty', p_qty_key, to_jsonb(old_qty), to_jsonb(p_qty));
  return jsonb_build_object('ok', true, 'qty_key', p_qty_key, 'qty', p_qty);
end;$$;
