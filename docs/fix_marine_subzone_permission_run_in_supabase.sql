-- ============================================================
-- 修复:非 admin(有 Marine/MA 权限)编辑 marine 细分(L1 的 C*/P*,如 C1-6)时
--   报 "not permitted: outside your assigned area"。
--
-- 原因:marine 细分不是真实分区,不在 rws_zone_area 表里,_rws_area_for 返回 NULL,
--   于是权限判定认为它"不属于任何区" → 拒绝。
--
-- 办法:让 L1 上"查不到的区"回退成 'MA'(它们就是 marine 细分),与前端一致
--   (前端 zoneCat 也把未匹配的 L1 区当作 Marine)。表里已有的真实区仍用其真实区域。
--
-- 安全、可重复跑。在 Supabase SQL Editor 里整段跑一次即可。
-- 顺序:这份只重定义 _rws_area_for 这一个辅助函数;只有"完整建库_admin123.sql"会覆盖它,
--   所以跑完这份后不要再回头跑"完整建库"(其它补丁不碰这个函数,不受影响)。
-- ============================================================

create or replace function public._rws_area_for(p_level text, p_zone_mk text)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select area from rws_zone_area where level = p_level and zone_mk = p_zone_mk),
    case when p_level = 'L1' then 'MA' else null end
  );
$$;
