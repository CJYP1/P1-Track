-- =====================================================================
-- Sliding session expiry  /  会话自动续期
--
-- Today a session dies 18 hours after you sign in, however much you use
-- it: sign in at 3 pm and you are thrown out the next morning in the
-- middle of an edit.  This makes every use of a live session push its
-- expiry 18 hours ahead, so you are only signed out after 18 hours of
-- NOT using the app.
--
-- The expiry is rewritten at most about once an hour (only when less than
-- 17 h are left), so a page that syncs every few seconds does not write to
-- rws_sessions on every call.
--
-- Same signature as before; nothing else changes.  Run once in the
-- Supabase SQL editor.  To undo, re-run the _rws_session definition from
-- 完整建库_admin123.sql.
-- =====================================================================
create or replace function public._rws_session(p_token uuid)
returns table(user_id uuid, username text, role text, allowed_scopes jsonb)
language plpgsql security definer set search_path = public as $$
begin
  update rws_sessions s
     set expires_at = now() + interval '18 hours'
   where s.token = p_token
     and s.expires_at > now()
     and s.expires_at < now() + interval '17 hours';
  return query
    select u.id, u.username, u.role, u.allowed_scopes
    from rws_sessions s join rws_users u on u.id = s.user_id
    where s.token = p_token and s.expires_at > now() and u.active;
  if not found then raise exception 'invalid or expired session'; end if;
end;$$;
