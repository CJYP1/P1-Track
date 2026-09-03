-- ============================================================
-- Report Edit 可分派权限
-- 用法：管理员给账号同时勾选 REPEDIT + NB / EB / MA。
-- 前端按 reportOverrides:NB / :EB / :MA 分开保存；数据库再次核对区域，
-- 防止一个区域的 Report 编辑人修改另一个区域。
-- 在 Supabase SQL Editor 整段运行一次（可重复运行）。
-- ============================================================

create or replace function public.rws_set_kv(p_token uuid, p_store text, p_k text, p_value jsonb, p_level text, p_zone_mk text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare s record; old jsonb; report_area text;
begin
  select * into s from _rws_session(p_token);
  if p_store not in ('act_total','act_plan','act_done_m','act_hidden','elem_date','act_def','crit','zdate','act_date','col_month','act_cmt','settings','edited','manpower','act_upd') then
    raise exception 'bad store';
  end if;

  if s.role <> 'admin' then
    if p_store = 'settings' and p_k like 'reportOverrides:%' then
      report_area := split_part(p_k, ':', 2);
      if report_area not in ('NB','EB','MA')
         or not (coalesce(s.allowed_scopes,'[]'::jsonb) ? 'REPEDIT')
         or not (coalesce(s.allowed_scopes,'[]'::jsonb) ? report_area) then
        raise exception 'not permitted: Report Edit + matching area required';
      end if;
    elsif p_store in ('act_total','act_plan','act_hidden','act_def','crit','zdate','act_date','col_month','settings','edited') then
      raise exception 'admin only';
    elsif p_store = 'act_cmt' then
      if not ((coalesce(s.allowed_scopes,'[]'::jsonb) ? 'CMT') or _rws_area_ok(s.allowed_scopes, p_level, p_zone_mk)) then
        raise exception 'not permitted: no comment or area permission';
      end if;
    elsif not _rws_area_ok(s.allowed_scopes, p_level, p_zone_mk) then
      raise exception 'not permitted: outside your assigned area';
    end if;
  end if;

  select value into old from rws_kv where store = p_store and k = p_k;
  if s.role <> 'admin' and p_store = 'act_done_m' and p_value is not null and old is not null
     and jsonb_typeof(p_value) = 'number' and jsonb_typeof(old) = 'number'
     and (p_value#>>'{}')::numeric < (old#>>'{}')::numeric then
    raise exception 'not permitted: 已录入的 Done 不能改小(% -> %),要改小请找 admin', (old#>>'{}'), (p_value#>>'{}');
  end if;

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

