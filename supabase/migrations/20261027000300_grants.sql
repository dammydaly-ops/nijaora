-- API role grants.
--
-- Supabase projects do not always grant table privileges to the anon and
-- authenticated roles when tables are created through SQL. RLS decides which
-- rows are visible, but the role still needs the underlying table privilege.

grant usage on schema public to anon, authenticated;

-- Public reference and marketplace read data.
grant select on table
  public.states,
  public.lgas,
  public.neighbourhoods,
  public.categories,
  public.profiles,
  public.businesses,
  public.business_categories,
  public.listings,
  public.reviews
to anon, authenticated;

-- Signed-in users can read their private rows; RLS limits them to their own
-- conversations, messages and reports.
grant select on table
  public.conversations,
  public.messages,
  public.reports
to authenticated;

grant select on table public.admin_audit_logs to authenticated;

-- Owners and admins write through RLS policies.
grant update on table public.profiles to authenticated;

grant insert, update, delete on table
  public.businesses,
  public.business_categories,
  public.listings,
  public.reviews,
  public.conversations,
  public.messages,
  public.reports
to authenticated;

-- RLS policies call these helpers, and the app calls the RPCs.
grant execute on all functions in schema public to anon, authenticated;
