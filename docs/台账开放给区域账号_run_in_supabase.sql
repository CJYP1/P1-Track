-- 构件台账 (Element register) 开放给 NB / EB / MA 账号
-- 在 Supabase SQL Editor 里整份运行一次即可。
-- 只改 rws_set_kv：允许有 NB / EB / MA 区域的账号保存台账相关的 settings
-- (elemDrop / elemGone / elemMove / elemNew / elemPurge / elemRetype / hideCols / hideColsUndo)。
-- 其余规则与 fix_report_edit_and_zone_area_run_in_supabase.sql 完全相同。

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
    elsif p_store = 'settings' and p_k in ('elemDrop','elemGone','elemMove','elemNew','elemPurge','elemRetype','hideCols','hideColsUndo') then
      -- Element register: NB / EB / MA accounts may edit it too.  The page only shows and
      -- changes rows in the account's own area(s).
      if not (coalesce(s.allowed_scopes,'[]'::jsonb) ?| array['NB','EB','MA']) then
        raise exception 'not permitted: Element register needs an NB / EB / MA account';
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
