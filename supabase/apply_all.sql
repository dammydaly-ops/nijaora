-- Nijaora combined setup. Generated from supabase/migrations in order.
-- Paste this whole file into the Supabase SQL editor and run it once.
-- It is idempotent and wrapped in one transaction.

begin;

-- ---------------------------------------------------------------------------
-- Source: supabase\migrations\20261027000000_initial_schema.sql
-- ---------------------------------------------------------------------------
-- Nijaora initial schema.
-- Run this in the Supabase SQL editor (or via the Supabase CLI).
-- Reference data is seeded separately in 20261027000100_reference_data.sql.

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('customer', 'business', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.operating_model as enum ('fixed_location', 'mobile');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.availability as enum ('available_today', 'busy_this_week', 'not_taking_jobs');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.category_kind as enum ('service', 'product');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.listing_type as enum ('product', 'service');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.price_type as enum ('fixed', 'from', 'negotiable', 'on_request');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.message_type as enum ('text', 'image', 'system');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Reference data
-- ---------------------------------------------------------------------------
create table if not exists public.states (
  id text primary key,
  code text not null unique,
  name text not null,
  dataset_version text not null default '2026.10.1',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.lgas (
  id text primary key,
  state_id text not null references public.states(id) on delete cascade,
  name text not null,
  adjacent_ids text[] not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (state_id, name),
  unique (id, state_id)
);

create table if not exists public.neighbourhoods (
  id text primary key,
  lga_id text not null references public.lgas(id) on delete cascade,
  name text not null,
  aliases text[] not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (lga_id, name),
  unique (id, lga_id)
);

create table if not exists public.categories (
  id text primary key,
  parent_id text references public.categories(id) on delete set null,
  name text not null,
  description text not null default '',
  synonyms text[] not null default '{}',
  kind public.category_kind not null default 'service',
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint categories_not_own_parent check (parent_id is null or parent_id <> id)
);

create index if not exists categories_parent_idx on public.categories(parent_id);
create index if not exists categories_kind_idx on public.categories(kind);

-- ---------------------------------------------------------------------------
-- People
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role public.user_role not null default 'customer',
  avatar_url text,
  state_id text references public.states(id),
  lga_id text references public.lgas(id),
  neighbourhood_id text references public.neighbourhoods(id),
  is_suspended boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (lga_id, state_id) references public.lgas(id, state_id),
  foreign key (neighbourhood_id, lga_id) references public.neighbourhoods(id, lga_id)
);

create index if not exists profiles_role_idx on public.profiles(role);

-- ---------------------------------------------------------------------------
-- Businesses
-- ---------------------------------------------------------------------------
create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  slug text not null unique,
  name text not null,
  description text not null default '',
  primary_category_id text references public.categories(id),
  state_id text not null references public.states(id),
  lga_id text not null references public.lgas(id),
  neighbourhood_id text references public.neighbourhoods(id),
  base_area text not null,
  operating_model public.operating_model not null default 'fixed_location',
  service_area_lga_ids text[] not null default '{}',
  availability public.availability not null default 'available_today',
  verification_level smallint not null default 1
    check (verification_level between 0 and 3),
  light_score numeric(5,4) not null default 0
    check (light_score between 0 and 1),
  completeness numeric(5,4) not null default 0
    check (completeness between 0 and 1),
  median_response_minutes integer not null default 0
    check (median_response_minutes >= 0),
  rating numeric(3,2) not null default 0
    check (rating between 0 and 5),
  review_count integer not null default 0 check (review_count >= 0),
  photos text[] not null default '{}',
  owner_photo_url text,
  owner_bio text,
  has_product boolean not null default false,
  has_service boolean not null default false,
  is_published boolean not null default false,
  is_suspended boolean not null default false,
  whatsapp_number text,
  phone_number text,
  opening_hours text,
  search_vector tsvector generated always as (
    setweight(to_tsvector('simple', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(base_area, '')), 'C')
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (lga_id, state_id) references public.lgas(id, state_id),
  foreign key (neighbourhood_id, lga_id) references public.neighbourhoods(id, lga_id)
);

create index if not exists businesses_owner_idx on public.businesses(owner_id);
create index if not exists businesses_state_lga_idx on public.businesses(state_id, lga_id);
create index if not exists businesses_primary_category_idx on public.businesses(primary_category_id);
create index if not exists businesses_published_idx on public.businesses(is_published, is_suspended);
create index if not exists businesses_search_idx on public.businesses using gin(search_vector);
create index if not exists businesses_name_trgm_idx on public.businesses using gin(name gin_trgm_ops);

create table if not exists public.business_categories (
  business_id uuid not null references public.businesses(id) on delete cascade,
  category_id text not null references public.categories(id) on delete cascade,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (business_id, category_id)
);

create unique index if not exists business_categories_one_primary
  on public.business_categories(business_id)
  where is_primary;

-- ---------------------------------------------------------------------------
-- Listings and products
-- ---------------------------------------------------------------------------
create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category_id text references public.categories(id),
  type public.listing_type not null,
  title text not null,
  description text not null default '',
  price_type public.price_type not null default 'on_request',
  price integer check (price is null or price >= 0),
  images text[] not null default '{}',
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists listings_business_idx on public.listings(business_id);
create index if not exists listings_type_idx on public.listings(type);
create index if not exists listings_category_idx on public.listings(category_id);
create index if not exists listings_title_trgm_idx on public.listings using gin(title gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- Reviews
-- ---------------------------------------------------------------------------
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  author_id uuid references public.profiles(id) on delete set null,
  author_name text not null default 'Nijaora customer',
  rating smallint not null check (rating between 1 and 5),
  text text not null check (char_length(text) between 10 and 2000),
  reply text,
  replied_at timestamptz,
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  unique (business_id, author_id)
);

create index if not exists reviews_business_idx on public.reviews(business_id, created_at desc);
create index if not exists reviews_author_idx on public.reviews(author_id);

-- ---------------------------------------------------------------------------
-- Chat
-- ---------------------------------------------------------------------------
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  business_owner_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete set null,
  last_message_at timestamptz,
  last_message_text text,
  unread_for_customer integer not null default 0 check (unread_for_customer >= 0),
  unread_for_business integer not null default 0 check (unread_for_business >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, customer_id)
);

create index if not exists conversations_customer_idx on public.conversations(customer_id, last_message_at desc);
create index if not exists conversations_business_idx on public.conversations(business_owner_id, last_message_at desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  is_from_business boolean not null default false,
  type public.message_type not null default 'text',
  text text not null default '',
  image_url text,
  sent_at timestamptz not null default now(),
  read_at timestamptz,
  constraint messages_have_content check (
    (type = 'text' and char_length(text) > 0) or
    (type = 'image' and image_url is not null)
  )
);

create index if not exists messages_conversation_idx on public.messages(conversation_id, sent_at);

-- ---------------------------------------------------------------------------
-- Safety and admin
-- ---------------------------------------------------------------------------
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  target_type text not null check (target_type in ('business', 'review', 'message', 'user')),
  target_id text not null,
  reason text not null,
  details text,
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null
);

create index if not exists reports_status_idx on public.reports(status, created_at desc);

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_type text,
  target_id text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_logs_created_idx
  on public.admin_audit_logs(created_at desc);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.can_review(p_business_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_user_id is not null
    and exists (
      select 1
      from public.conversations c
      where c.business_id = p_business_id
        and c.customer_id = p_user_id
        and c.created_at <= now() - interval '1 day'
        and (
          select count(*)
          from public.messages m
          where m.conversation_id = c.id
            and m.sender_id = p_user_id
        ) >= 2
        and exists (
          select 1
          from public.messages m
          where m.conversation_id = c.id
            and m.is_from_business
        )
    )
    and not exists (
      select 1 from public.reviews r
      where r.business_id = p_business_id and r.author_id = p_user_id
    )
    and not exists (
      select 1 from public.businesses b
      where b.id = p_business_id and b.owner_id = p_user_id
    )
    and (
      select count(*)
      from public.reviews r
      where r.author_id = p_user_id
        and r.created_at > now() - interval '1 day'
    ) < 3;
$$;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists businesses_set_updated_at on public.businesses;
create trigger businesses_set_updated_at
before update on public.businesses
for each row execute function public.set_updated_at();

drop trigger if exists listings_set_updated_at on public.listings;
create trigger listings_set_updated_at
before update on public.listings
for each row execute function public.set_updated_at();

drop trigger if exists conversations_set_updated_at on public.conversations;
create trigger conversations_set_updated_at
before update on public.conversations
for each row execute function public.set_updated_at();

-- Create a profile for every Supabase Auth user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    case
      when new.raw_user_meta_data->>'role' = 'business'
        then 'business'::public.user_role
      else 'customer'::public.user_role
    end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Keep conversations.business_owner_id in sync with the business owner.
create or replace function public.set_conversation_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select owner_id into new.business_owner_id
  from public.businesses
  where id = new.business_id;

  if new.business_owner_id is null then
    raise exception 'business not found';
  end if;
  return new;
end;
$$;

drop trigger if exists conversations_set_owner on public.conversations;
create trigger conversations_set_owner
before insert or update of business_id on public.conversations
for each row execute function public.set_conversation_owner();

-- Keep the primary category on the business row.
create or replace function public.sync_primary_category()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    if old.is_primary then
      update public.businesses
      set primary_category_id = (
        select category_id from public.business_categories
        where business_id = old.business_id
        order by created_at
        limit 1
      )
      where id = old.business_id;
    end if;
    return old;
  end if;

  if new.is_primary then
    update public.businesses
    set primary_category_id = new.category_id
    where id = new.business_id;
  end if;
  return new;
end;
$$;

drop trigger if exists business_categories_sync_primary on public.business_categories;
create trigger business_categories_sync_primary
after insert or update or delete on public.business_categories
for each row execute function public.sync_primary_category();

-- Refresh has_product / has_service when listings change.
create or replace function public.refresh_business_listing_flags(p_business_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.businesses b
  set has_product = exists (
        select 1 from public.listings l
        where l.business_id = p_business_id and l.type = 'product'
      ),
      has_service = exists (
        select 1 from public.listings l
        where l.business_id = p_business_id and l.type = 'service'
      ),
      updated_at = now()
  where b.id = p_business_id;
$$;

create or replace function public.listings_after_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_business_listing_flags(old.business_id);
    return old;
  end if;
  perform public.refresh_business_listing_flags(new.business_id);
  return new;
end;
$$;

drop trigger if exists listings_refresh_flags on public.listings;
create trigger listings_refresh_flags
after insert or update or delete on public.listings
for each row execute function public.listings_after_change();

-- Refresh rating aggregates when reviews change.
create or replace function public.refresh_business_rating(p_business_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.businesses b
  set rating = coalesce((
        select round(avg(r.rating)::numeric, 2)
        from public.reviews r
        where r.business_id = p_business_id and not r.is_hidden
      ), 0),
      review_count = (
        select count(*)
        from public.reviews r
        where r.business_id = p_business_id and not r.is_hidden
      ),
      updated_at = now()
  where b.id = p_business_id;
$$;

create or replace function public.reviews_after_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_business_rating(old.business_id);
    return old;
  end if;
  perform public.refresh_business_rating(new.business_id);
  return new;
end;
$$;

drop trigger if exists reviews_refresh_rating on public.reviews;
create trigger reviews_refresh_rating
after insert or update or delete on public.reviews
for each row execute function public.reviews_after_change();

-- Keep conversation previews and unread counters current.
create or replace function public.messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set last_message_at = new.sent_at,
      last_message_text = case
        when new.type = 'text' then left(new.text, 140)
        when new.type = 'image' then 'Photo'
        else 'Update'
      end,
      unread_for_customer = unread_for_customer
        + case when new.is_from_business then 1 else 0 end,
      unread_for_business = unread_for_business
        + case when new.is_from_business then 0 else 1 end,
      updated_at = now()
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists messages_after_insert on public.messages;
create trigger messages_after_insert
after insert on public.messages
for each row execute function public.messages_after_insert();

create or replace function public.messages_after_read()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.read_at is not null and old.read_at is null then
    update public.conversations
    set unread_for_customer = greatest(
          unread_for_customer - case when new.is_from_business then 1 else 0 end,
          0
        ),
        unread_for_business = greatest(
          unread_for_business - case when new.is_from_business then 0 else 1 end,
          0
        ),
        updated_at = now()
    where id = new.conversation_id;
  end if;
  return new;
end;
$$;

drop trigger if exists messages_after_read on public.messages;
create trigger messages_after_read
after update of read_at on public.messages
for each row execute function public.messages_after_read();

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_is_participant boolean;
begin
  select exists (
    select 1 from public.conversations
    where id = p_conversation_id
      and (customer_id = v_uid or business_owner_id = v_uid or public.is_admin())
  ) into v_is_participant;

  if not v_is_participant then
    raise exception 'not a participant';
  end if;

  update public.messages
  set read_at = now()
  where conversation_id = p_conversation_id
    and read_at is null
    and sender_id <> v_uid;
end;
$$;

create or replace function public.reply_to_review(p_review_id uuid, p_reply text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
begin
  select business_id into v_business_id
  from public.reviews
  where id = p_review_id;

  if v_business_id is null then
    raise exception 'review not found';
  end if;

  if not exists (
    select 1 from public.businesses
    where id = v_business_id and owner_id = auth.uid()
  ) and not public.is_admin() then
    raise exception 'not allowed';
  end if;

  update public.reviews
  set reply = p_reply, replied_at = now()
  where id = p_review_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.states enable row level security;
alter table public.lgas enable row level security;
alter table public.neighbourhoods enable row level security;
alter table public.categories enable row level security;
alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_categories enable row level security;
alter table public.listings enable row level security;
alter table public.reviews enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.reports enable row level security;
alter table public.admin_audit_logs enable row level security;

-- Public reference data.
drop policy if exists states_read on public.states;
create policy states_read on public.states
  for select to anon, authenticated using (active);

drop policy if exists lgas_read on public.lgas;
create policy lgas_read on public.lgas
  for select to anon, authenticated using (active);

drop policy if exists neighbourhoods_read on public.neighbourhoods;
create policy neighbourhoods_read on public.neighbourhoods
  for select to anon, authenticated using (active);

drop policy if exists categories_read on public.categories;
create policy categories_read on public.categories
  for select to anon, authenticated using (active);

-- Profiles: public display data; users edit only their own row and cannot
-- promote themselves to admin.
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles
  for select to anon, authenticated using (not is_suspended or id = auth.uid() or public.is_admin());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (
    id = auth.uid()
    and (
      role = public.current_user_role()
      or (
        public.current_user_role() = 'customer'
        and role = 'business'
      )
    )
  );

-- Businesses: public read when published; owners and admins manage.
drop policy if exists businesses_read on public.businesses;
create policy businesses_read on public.businesses
  for select to anon, authenticated
  using (
    (is_published and not is_suspended)
    or owner_id = auth.uid()
    or public.is_admin()
  );

drop policy if exists businesses_insert on public.businesses;
create policy businesses_insert on public.businesses
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and public.current_user_role() in ('business', 'admin')
  );

drop policy if exists businesses_update on public.businesses;
create policy businesses_update on public.businesses
  for update to authenticated
  using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());

drop policy if exists businesses_delete on public.businesses;
create policy businesses_delete on public.businesses
  for delete to authenticated
  using (owner_id = auth.uid() or public.is_admin());

-- Business categories follow business visibility.
drop policy if exists business_categories_read on public.business_categories;
create policy business_categories_read on public.business_categories
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_id
        and ((b.is_published and not b.is_suspended) or b.owner_id = auth.uid() or public.is_admin())
    )
  );

drop policy if exists business_categories_write on public.business_categories;
create policy business_categories_write on public.business_categories
  for all to authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_id and (b.owner_id = auth.uid() or public.is_admin())
    )
  )
  with check (
    exists (
      select 1 from public.businesses b
      where b.id = business_id and (b.owner_id = auth.uid() or public.is_admin())
    )
  );

-- Listings.
drop policy if exists listings_read on public.listings;
create policy listings_read on public.listings
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_id
        and ((b.is_published and not b.is_suspended) or b.owner_id = auth.uid() or public.is_admin())
    )
  );

drop policy if exists listings_write on public.listings;
create policy listings_write on public.listings
  for all to authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_id and (b.owner_id = auth.uid() or public.is_admin())
    )
  )
  with check (
    exists (
      select 1 from public.businesses b
      where b.id = business_id and (b.owner_id = auth.uid() or public.is_admin())
    )
  );

-- Reviews.
drop policy if exists reviews_read on public.reviews;
create policy reviews_read on public.reviews
  for select to anon, authenticated
  using (
    (not is_hidden and exists (
      select 1 from public.businesses b
      where b.id = business_id and b.is_published and not b.is_suspended
    ))
    or author_id = auth.uid()
    or public.is_admin()
  );

drop policy if exists reviews_insert on public.reviews;
create policy reviews_insert on public.reviews
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.can_review(business_id, auth.uid())
  );

drop policy if exists reviews_delete_own on public.reviews;
create policy reviews_delete_own on public.reviews
  for delete to authenticated
  using (author_id = auth.uid() or public.is_admin());

-- Conversations.
drop policy if exists conversations_read on public.conversations;
create policy conversations_read on public.conversations
  for select to authenticated
  using (
    customer_id = auth.uid()
    or business_owner_id = auth.uid()
    or public.is_admin()
  );

drop policy if exists conversations_insert on public.conversations;
create policy conversations_insert on public.conversations
  for insert to authenticated
  with check (
    customer_id = auth.uid()
    and customer_id <> business_owner_id
  );

drop policy if exists conversations_update on public.conversations;
create policy conversations_update on public.conversations
  for update to authenticated
  using (
    customer_id = auth.uid()
    or business_owner_id = auth.uid()
    or public.is_admin()
  )
  with check (
    customer_id = auth.uid()
    or business_owner_id = auth.uid()
    or public.is_admin()
  );

-- Messages.
drop policy if exists messages_read on public.messages;
create policy messages_read on public.messages
  for select to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.customer_id = auth.uid() or c.business_owner_id = auth.uid() or public.is_admin())
    )
  );

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (
          (c.customer_id = auth.uid() and not is_from_business)
          or (c.business_owner_id = auth.uid() and is_from_business)
          or public.is_admin()
        )
    )
  );

drop policy if exists messages_mark_read on public.messages;
create policy messages_mark_read on public.messages
  for update to authenticated
  using (
    sender_id <> auth.uid()
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.customer_id = auth.uid() or c.business_owner_id = auth.uid())
    )
  )
  with check (read_at is not null);

-- Reports.
drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid());

drop policy if exists reports_read on public.reports;
create policy reports_read on public.reports
  for select to authenticated
  using (reporter_id = auth.uid() or public.is_admin());

drop policy if exists reports_admin_update on public.reports;
create policy reports_admin_update on public.reports
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Audit logs: admins read and write; everyone else has no access.
drop policy if exists admin_audit_logs_read on public.admin_audit_logs;
create policy admin_audit_logs_read on public.admin_audit_logs
  for select to authenticated
  using (public.is_admin());

drop policy if exists admin_audit_logs_insert on public.admin_audit_logs;
create policy admin_audit_logs_insert on public.admin_audit_logs
  for insert to authenticated
  with check (admin_id = auth.uid() and public.is_admin());


-- ---------------------------------------------------------------------------
-- Source: supabase\migrations\20261027000100_reference_data.sql
-- ---------------------------------------------------------------------------
-- Nijaora reference data: 37 states/FCT, 774 LGAs, pilot neighbourhoods.
-- Generated from the open Nigeria Locations Dataset 2026 and the curated Nijaora pilot data.

insert into public.states (id, code, name) values
  ('ng-ab', 'ab', 'Abia'),
  ('ng-ad', 'ad', 'Adamawa'),
  ('ng-ak', 'ak', 'Akwa Ibom'),
  ('ng-an', 'an', 'Anambra'),
  ('ng-ba', 'ba', 'Bauchi'),
  ('ng-by', 'by', 'Bayelsa'),
  ('ng-be', 'be', 'Benue'),
  ('ng-bo', 'bo', 'Borno'),
  ('ng-cr', 'cr', 'Cross River'),
  ('ng-de', 'de', 'Delta'),
  ('ng-eb', 'eb', 'Ebonyi'),
  ('ng-ed', 'ed', 'Edo'),
  ('ng-ek', 'ek', 'Ekiti'),
  ('ng-en', 'en', 'Enugu'),
  ('ng-fc', 'fc', 'Federal Capital Territory'),
  ('ng-go', 'go', 'Gombe'),
  ('ng-im', 'im', 'Imo'),
  ('ng-ji', 'ji', 'Jigawa'),
  ('ng-kd', 'kd', 'Kaduna'),
  ('ng-kn', 'kn', 'Kano'),
  ('ng-kt', 'kt', 'Katsina'),
  ('ng-ke', 'ke', 'Kebbi'),
  ('ng-ko', 'ko', 'Kogi'),
  ('ng-kw', 'kw', 'Kwara'),
  ('ng-la', 'la', 'Lagos'),
  ('ng-na', 'na', 'Nasarawa'),
  ('ng-ni', 'ni', 'Niger'),
  ('ng-og', 'og', 'Ogun'),
  ('ng-on', 'on', 'Ondo'),
  ('ng-os', 'os', 'Osun'),
  ('ng-oy', 'oy', 'Oyo'),
  ('ng-pl', 'pl', 'Plateau'),
  ('ng-ri', 'ri', 'Rivers'),
  ('ng-so', 'so', 'Sokoto'),
  ('ng-ta', 'ta', 'Taraba'),
  ('ng-yo', 'yo', 'Yobe'),
  ('ng-za', 'za', 'Zamfara')
on conflict (id) do update set code = excluded.code, name = excluded.name;

insert into public.lgas (id, state_id, name, adjacent_ids) values
  ('ng-ab-aba-north', 'ng-ab', 'Aba North', '{}'::text[]),
  ('ng-ab-aba-south', 'ng-ab', 'Aba South', '{}'::text[]),
  ('ng-ab-arochukwu', 'ng-ab', 'Arochukwu', '{}'::text[]),
  ('ng-ab-bende', 'ng-ab', 'Bende', '{}'::text[]),
  ('ng-ab-ikwuano', 'ng-ab', 'Ikwuano', '{}'::text[]),
  ('ng-ab-isiala-ngwa-north', 'ng-ab', 'Isiala Ngwa North', '{}'::text[]),
  ('ng-ab-isiala-ngwa-south', 'ng-ab', 'Isiala Ngwa South', '{}'::text[]),
  ('ng-ab-isuikwuato', 'ng-ab', 'Isuikwuato', '{}'::text[]),
  ('ng-ab-obi-ngwa', 'ng-ab', 'Obi Ngwa', '{}'::text[]),
  ('ng-ab-ohafia', 'ng-ab', 'Ohafia', '{}'::text[]),
  ('ng-ab-osisioma', 'ng-ab', 'Osisioma', '{}'::text[]),
  ('ng-ab-ugwunagbo', 'ng-ab', 'Ugwunagbo', '{}'::text[]),
  ('ng-ab-ukwa-east', 'ng-ab', 'Ukwa East', '{}'::text[]),
  ('ng-ab-ukwa-west', 'ng-ab', 'Ukwa West', '{}'::text[]),
  ('ng-ab-umuahia-north', 'ng-ab', 'Umuahia North', '{}'::text[]),
  ('ng-ab-umuahia-south', 'ng-ab', 'Umuahia South', '{}'::text[]),
  ('ng-ab-umu-nneochi', 'ng-ab', 'Umu Nneochi', '{}'::text[]),
  ('ng-ad-demsa', 'ng-ad', 'Demsa', '{}'::text[]),
  ('ng-ad-fufure', 'ng-ad', 'Fufure', '{}'::text[]),
  ('ng-ad-ganye', 'ng-ad', 'Ganye', '{}'::text[]),
  ('ng-ad-gayuk', 'ng-ad', 'Gayuk', '{}'::text[]),
  ('ng-ad-gombi', 'ng-ad', 'Gombi', '{}'::text[]),
  ('ng-ad-grie', 'ng-ad', 'Grie', '{}'::text[]),
  ('ng-ad-hong', 'ng-ad', 'Hong', '{}'::text[]),
  ('ng-ad-jada', 'ng-ad', 'Jada', '{}'::text[]),
  ('ng-ad-lamurde', 'ng-ad', 'Lamurde', '{}'::text[]),
  ('ng-ad-madagali', 'ng-ad', 'Madagali', '{}'::text[]),
  ('ng-ad-maiha', 'ng-ad', 'Maiha', '{}'::text[]),
  ('ng-ad-mayo-belwa', 'ng-ad', 'Mayo Belwa', '{}'::text[]),
  ('ng-ad-michika', 'ng-ad', 'Michika', '{}'::text[]),
  ('ng-ad-mubi-north', 'ng-ad', 'Mubi North', '{}'::text[]),
  ('ng-ad-mubi-south', 'ng-ad', 'Mubi South', '{}'::text[]),
  ('ng-ad-numan', 'ng-ad', 'Numan', '{}'::text[]),
  ('ng-ad-shelleng', 'ng-ad', 'Shelleng', '{}'::text[]),
  ('ng-ad-song', 'ng-ad', 'Song', '{}'::text[]),
  ('ng-ad-toungo', 'ng-ad', 'Toungo', '{}'::text[]),
  ('ng-ad-yola-north', 'ng-ad', 'Yola North', '{}'::text[]),
  ('ng-ad-yola-south', 'ng-ad', 'Yola South', '{}'::text[]),
  ('ng-ak-abak', 'ng-ak', 'Abak', '{}'::text[]),
  ('ng-ak-eastern-obolo', 'ng-ak', 'Eastern Obolo', '{}'::text[]),
  ('ng-ak-eket', 'ng-ak', 'Eket', '{}'::text[]),
  ('ng-ak-esit-eket', 'ng-ak', 'Esit Eket', '{}'::text[]),
  ('ng-ak-essien-udim', 'ng-ak', 'Essien Udim', '{}'::text[]),
  ('ng-ak-etim-ekpo', 'ng-ak', 'Etim Ekpo', '{}'::text[]),
  ('ng-ak-etinan', 'ng-ak', 'Etinan', '{}'::text[]),
  ('ng-ak-ibeno', 'ng-ak', 'Ibeno', '{}'::text[]),
  ('ng-ak-ibesikpo-asutan', 'ng-ak', 'Ibesikpo Asutan', '{}'::text[]),
  ('ng-ak-ibiono-ibom', 'ng-ak', 'Ibiono Ibom', '{}'::text[]),
  ('ng-ak-ika', 'ng-ak', 'Ika', '{}'::text[]),
  ('ng-ak-ikono', 'ng-ak', 'Ikono', '{}'::text[]),
  ('ng-ak-ikot-abasi', 'ng-ak', 'Ikot Abasi', '{}'::text[]),
  ('ng-ak-ikot-ekpene', 'ng-ak', 'Ikot Ekpene', '{}'::text[]),
  ('ng-ak-ini', 'ng-ak', 'Ini', '{}'::text[]),
  ('ng-ak-itu', 'ng-ak', 'Itu', '{}'::text[]),
  ('ng-ak-mbo', 'ng-ak', 'Mbo', '{}'::text[]),
  ('ng-ak-mkpat-enin', 'ng-ak', 'Mkpat Enin', '{}'::text[]),
  ('ng-ak-nsit-atai', 'ng-ak', 'Nsit Atai', '{}'::text[]),
  ('ng-ak-nsit-ibom', 'ng-ak', 'Nsit Ibom', '{}'::text[]),
  ('ng-ak-nsit-ubium', 'ng-ak', 'Nsit Ubium', '{}'::text[]),
  ('ng-ak-obot-akara', 'ng-ak', 'Obot Akara', '{}'::text[]),
  ('ng-ak-okobo', 'ng-ak', 'Okobo', '{}'::text[]),
  ('ng-ak-onna', 'ng-ak', 'Onna', '{}'::text[]),
  ('ng-ak-oron', 'ng-ak', 'Oron', '{}'::text[]),
  ('ng-ak-oruk-anam', 'ng-ak', 'Oruk Anam', '{}'::text[]),
  ('ng-ak-udung-uko', 'ng-ak', 'Udung Uko', '{}'::text[]),
  ('ng-ak-ukanafun', 'ng-ak', 'Ukanafun', '{}'::text[]),
  ('ng-ak-uruan', 'ng-ak', 'Uruan', '{}'::text[]),
  ('ng-ak-urue-offong-oruko', 'ng-ak', 'Urue-Offong/Oruko', '{}'::text[]),
  ('ng-ak-uyo', 'ng-ak', 'Uyo', '{}'::text[]),
  ('ng-an-aguata', 'ng-an', 'Aguata', '{}'::text[]),
  ('ng-an-anambra-east', 'ng-an', 'Anambra East', '{}'::text[]),
  ('ng-an-anambra-west', 'ng-an', 'Anambra West', '{}'::text[]),
  ('ng-an-anaocha', 'ng-an', 'Anaocha', '{}'::text[]),
  ('ng-an-awka-north', 'ng-an', 'Awka North', '{}'::text[]),
  ('ng-an-awka-south', 'ng-an', 'Awka South', '{}'::text[]),
  ('ng-an-ayamelum', 'ng-an', 'Ayamelum', '{}'::text[]),
  ('ng-an-dunukofia', 'ng-an', 'Dunukofia', '{}'::text[]),
  ('ng-an-ekwusigo', 'ng-an', 'Ekwusigo', '{}'::text[]),
  ('ng-an-idemili-north', 'ng-an', 'Idemili North', '{}'::text[]),
  ('ng-an-idemili-south', 'ng-an', 'Idemili South', '{}'::text[]),
  ('ng-an-ihiala', 'ng-an', 'Ihiala', '{}'::text[]),
  ('ng-an-njikoka', 'ng-an', 'Njikoka', '{}'::text[]),
  ('ng-an-nnewi-north', 'ng-an', 'Nnewi North', '{}'::text[]),
  ('ng-an-nnewi-south', 'ng-an', 'Nnewi South', '{}'::text[]),
  ('ng-an-ogbaru', 'ng-an', 'Ogbaru', '{}'::text[]),
  ('ng-an-onitsha-north', 'ng-an', 'Onitsha North', '{}'::text[]),
  ('ng-an-onitsha-south', 'ng-an', 'Onitsha South', '{}'::text[]),
  ('ng-an-orumba-north', 'ng-an', 'Orumba North', '{}'::text[]),
  ('ng-an-orumba-south', 'ng-an', 'Orumba South', '{}'::text[]),
  ('ng-an-oyi', 'ng-an', 'Oyi', '{}'::text[]),
  ('ng-ba-alkaleri', 'ng-ba', 'Alkaleri', '{}'::text[]),
  ('ng-ba-bauchi', 'ng-ba', 'Bauchi', '{}'::text[]),
  ('ng-ba-bogoro', 'ng-ba', 'Bogoro', '{}'::text[]),
  ('ng-ba-damban', 'ng-ba', 'Damban', '{}'::text[]),
  ('ng-ba-darazo', 'ng-ba', 'Darazo', '{}'::text[]),
  ('ng-ba-dass', 'ng-ba', 'Dass', '{}'::text[]),
  ('ng-ba-gamawa', 'ng-ba', 'Gamawa', '{}'::text[]),
  ('ng-ba-ganjuwa', 'ng-ba', 'Ganjuwa', '{}'::text[]),
  ('ng-ba-giade', 'ng-ba', 'Giade', '{}'::text[]),
  ('ng-ba-itas-gadau', 'ng-ba', 'Itas/Gadau', '{}'::text[]),
  ('ng-ba-jama-are', 'ng-ba', 'Jama''are', '{}'::text[]),
  ('ng-ba-katagum', 'ng-ba', 'Katagum', '{}'::text[]),
  ('ng-ba-kirfi', 'ng-ba', 'Kirfi', '{}'::text[]),
  ('ng-ba-misau', 'ng-ba', 'Misau', '{}'::text[]),
  ('ng-ba-ningi', 'ng-ba', 'Ningi', '{}'::text[]),
  ('ng-ba-shira', 'ng-ba', 'Shira', '{}'::text[]),
  ('ng-ba-tafawa-balewa', 'ng-ba', 'Tafawa Balewa', '{}'::text[]),
  ('ng-ba-toro', 'ng-ba', 'Toro', '{}'::text[]),
  ('ng-ba-warji', 'ng-ba', 'Warji', '{}'::text[]),
  ('ng-ba-zaki', 'ng-ba', 'Zaki', '{}'::text[]),
  ('ng-by-brass', 'ng-by', 'Brass', '{}'::text[]),
  ('ng-by-ekeremor', 'ng-by', 'Ekeremor', '{}'::text[]),
  ('ng-by-kolokuma-opokuma', 'ng-by', 'Kolokuma/Opokuma', '{}'::text[]),
  ('ng-by-nembe', 'ng-by', 'Nembe', '{}'::text[]),
  ('ng-by-ogbia', 'ng-by', 'Ogbia', '{}'::text[]),
  ('ng-by-sagbama', 'ng-by', 'Sagbama', '{}'::text[]),
  ('ng-by-southern-ijaw', 'ng-by', 'Southern Ijaw', '{}'::text[]),
  ('ng-by-yenagoa', 'ng-by', 'Yenagoa', '{}'::text[]),
  ('ng-be-ado', 'ng-be', 'Ado', '{}'::text[]),
  ('ng-be-agatu', 'ng-be', 'Agatu', '{}'::text[]),
  ('ng-be-apa', 'ng-be', 'Apa', '{}'::text[]),
  ('ng-be-buruku', 'ng-be', 'Buruku', '{}'::text[]),
  ('ng-be-gboko', 'ng-be', 'Gboko', '{}'::text[]),
  ('ng-be-guma', 'ng-be', 'Guma', '{}'::text[]),
  ('ng-be-gwer-east', 'ng-be', 'Gwer East', '{}'::text[]),
  ('ng-be-gwer-west', 'ng-be', 'Gwer West', '{}'::text[]),
  ('ng-be-katsina-ala', 'ng-be', 'Katsina-Ala', '{}'::text[]),
  ('ng-be-konshisha', 'ng-be', 'Konshisha', '{}'::text[]),
  ('ng-be-kwande', 'ng-be', 'Kwande', '{}'::text[]),
  ('ng-be-logo', 'ng-be', 'Logo', '{}'::text[]),
  ('ng-be-makurdi', 'ng-be', 'Makurdi', '{}'::text[]),
  ('ng-be-obi', 'ng-be', 'Obi', '{}'::text[]),
  ('ng-be-ogbadibo', 'ng-be', 'Ogbadibo', '{}'::text[]),
  ('ng-be-ohimini', 'ng-be', 'Ohimini', '{}'::text[]),
  ('ng-be-oju', 'ng-be', 'Oju', '{}'::text[]),
  ('ng-be-okpokwu', 'ng-be', 'Okpokwu', '{}'::text[]),
  ('ng-be-otukpo', 'ng-be', 'Otukpo', '{}'::text[]),
  ('ng-be-tarka', 'ng-be', 'Tarka', '{}'::text[]),
  ('ng-be-ukum', 'ng-be', 'Ukum', '{}'::text[]),
  ('ng-be-ushongo', 'ng-be', 'Ushongo', '{}'::text[]),
  ('ng-be-vandeikya', 'ng-be', 'Vandeikya', '{}'::text[]),
  ('ng-bo-abadam', 'ng-bo', 'Abadam', '{}'::text[]),
  ('ng-bo-askira-uba', 'ng-bo', 'Askira/Uba', '{}'::text[]),
  ('ng-bo-bama', 'ng-bo', 'Bama', '{}'::text[]),
  ('ng-bo-bayo', 'ng-bo', 'Bayo', '{}'::text[]),
  ('ng-bo-biu', 'ng-bo', 'Biu', '{}'::text[]),
  ('ng-bo-chibok', 'ng-bo', 'Chibok', '{}'::text[]),
  ('ng-bo-damboa', 'ng-bo', 'Damboa', '{}'::text[]),
  ('ng-bo-dikwa', 'ng-bo', 'Dikwa', '{}'::text[]),
  ('ng-bo-gubio', 'ng-bo', 'Gubio', '{}'::text[]),
  ('ng-bo-guzamala', 'ng-bo', 'Guzamala', '{}'::text[]),
  ('ng-bo-gwoza', 'ng-bo', 'Gwoza', '{}'::text[]),
  ('ng-bo-hawul', 'ng-bo', 'Hawul', '{}'::text[]),
  ('ng-bo-jere', 'ng-bo', 'Jere', '{}'::text[]),
  ('ng-bo-kaga', 'ng-bo', 'Kaga', '{}'::text[]),
  ('ng-bo-kala-balge', 'ng-bo', 'Kala/Balge', '{}'::text[]),
  ('ng-bo-konduga', 'ng-bo', 'Konduga', '{}'::text[]),
  ('ng-bo-kukawa', 'ng-bo', 'Kukawa', '{}'::text[]),
  ('ng-bo-kwaya-kusar', 'ng-bo', 'Kwaya Kusar', '{}'::text[]),
  ('ng-bo-mafa', 'ng-bo', 'Mafa', '{}'::text[]),
  ('ng-bo-magumeri', 'ng-bo', 'Magumeri', '{}'::text[]),
  ('ng-bo-maiduguri', 'ng-bo', 'Maiduguri', '{}'::text[]),
  ('ng-bo-marte', 'ng-bo', 'Marte', '{}'::text[]),
  ('ng-bo-mobbar', 'ng-bo', 'Mobbar', '{}'::text[]),
  ('ng-bo-monguno', 'ng-bo', 'Monguno', '{}'::text[]),
  ('ng-bo-ngala', 'ng-bo', 'Ngala', '{}'::text[]),
  ('ng-bo-nganzai', 'ng-bo', 'Nganzai', '{}'::text[]),
  ('ng-bo-shani', 'ng-bo', 'Shani', '{}'::text[]),
  ('ng-cr-abi', 'ng-cr', 'Abi', '{}'::text[]),
  ('ng-cr-akamkpa', 'ng-cr', 'Akamkpa', '{}'::text[]),
  ('ng-cr-akpabuyo', 'ng-cr', 'Akpabuyo', '{}'::text[]),
  ('ng-cr-bakassi', 'ng-cr', 'Bakassi', '{}'::text[]),
  ('ng-cr-bekwarra', 'ng-cr', 'Bekwarra', '{}'::text[]),
  ('ng-cr-biase', 'ng-cr', 'Biase', '{}'::text[]),
  ('ng-cr-boki', 'ng-cr', 'Boki', '{}'::text[]),
  ('ng-cr-calabar-municipal', 'ng-cr', 'Calabar Municipal', '{}'::text[]),
  ('ng-cr-calabar-south', 'ng-cr', 'Calabar South', '{}'::text[]),
  ('ng-cr-etung', 'ng-cr', 'Etung', '{}'::text[]),
  ('ng-cr-ikom', 'ng-cr', 'Ikom', '{}'::text[]),
  ('ng-cr-obanliku', 'ng-cr', 'Obanliku', '{}'::text[]),
  ('ng-cr-obubra', 'ng-cr', 'Obubra', '{}'::text[]),
  ('ng-cr-obudu', 'ng-cr', 'Obudu', '{}'::text[]),
  ('ng-cr-odukpani', 'ng-cr', 'Odukpani', '{}'::text[]),
  ('ng-cr-ogoja', 'ng-cr', 'Ogoja', '{}'::text[]),
  ('ng-cr-yakuur', 'ng-cr', 'Yakuur', '{}'::text[]),
  ('ng-cr-yala', 'ng-cr', 'Yala', '{}'::text[]),
  ('ng-de-aniocha-north', 'ng-de', 'Aniocha North', '{}'::text[]),
  ('ng-de-aniocha-south', 'ng-de', 'Aniocha South', '{}'::text[]),
  ('ng-de-bomadi', 'ng-de', 'Bomadi', '{}'::text[]),
  ('ng-de-burutu', 'ng-de', 'Burutu', '{}'::text[]),
  ('ng-de-ethiope-east', 'ng-de', 'Ethiope East', '{}'::text[]),
  ('ng-de-ethiope-west', 'ng-de', 'Ethiope West', '{}'::text[]),
  ('ng-de-ika-north-east', 'ng-de', 'Ika North East', '{}'::text[]),
  ('ng-de-ika-south', 'ng-de', 'Ika South', '{}'::text[]),
  ('ng-de-isoko-north', 'ng-de', 'Isoko North', '{}'::text[]),
  ('ng-de-isoko-south', 'ng-de', 'Isoko South', '{}'::text[]),
  ('ng-de-ndokwa-east', 'ng-de', 'Ndokwa East', '{}'::text[]),
  ('ng-de-ndokwa-west', 'ng-de', 'Ndokwa West', '{}'::text[]),
  ('ng-de-okpe', 'ng-de', 'Okpe', '{}'::text[]),
  ('ng-de-oshimili-north', 'ng-de', 'Oshimili North', '{}'::text[]),
  ('ng-de-oshimili-south', 'ng-de', 'Oshimili South', '{}'::text[]),
  ('ng-de-patani', 'ng-de', 'Patani', '{}'::text[]),
  ('ng-de-sapele', 'ng-de', 'Sapele', '{}'::text[]),
  ('ng-de-udu', 'ng-de', 'Udu', '{}'::text[]),
  ('ng-de-ughelli-north', 'ng-de', 'Ughelli North', '{}'::text[]),
  ('ng-de-ughelli-south', 'ng-de', 'Ughelli South', '{}'::text[]),
  ('ng-de-ukwuani', 'ng-de', 'Ukwuani', '{}'::text[]),
  ('ng-de-uvwie', 'ng-de', 'Uvwie', '{}'::text[]),
  ('ng-de-warri-north', 'ng-de', 'Warri North', '{}'::text[]),
  ('ng-de-warri-south', 'ng-de', 'Warri South', '{}'::text[]),
  ('ng-de-warri-south-west', 'ng-de', 'Warri South West', '{}'::text[]),
  ('ng-eb-abakaliki', 'ng-eb', 'Abakaliki', '{}'::text[]),
  ('ng-eb-afikpo-north', 'ng-eb', 'Afikpo North', '{}'::text[]),
  ('ng-eb-afikpo-south', 'ng-eb', 'Afikpo South', '{}'::text[]),
  ('ng-eb-ebonyi', 'ng-eb', 'Ebonyi', '{}'::text[]),
  ('ng-eb-ezza-north', 'ng-eb', 'Ezza North', '{}'::text[]),
  ('ng-eb-ezza-south', 'ng-eb', 'Ezza South', '{}'::text[]),
  ('ng-eb-ikwo', 'ng-eb', 'Ikwo', '{}'::text[]),
  ('ng-eb-ishielu', 'ng-eb', 'Ishielu', '{}'::text[]),
  ('ng-eb-ivo', 'ng-eb', 'Ivo', '{}'::text[]),
  ('ng-eb-izzi', 'ng-eb', 'Izzi', '{}'::text[]),
  ('ng-eb-ohaozara', 'ng-eb', 'Ohaozara', '{}'::text[]),
  ('ng-eb-ohaukwu', 'ng-eb', 'Ohaukwu', '{}'::text[]),
  ('ng-eb-onicha', 'ng-eb', 'Onicha', '{}'::text[]),
  ('ng-ed-akoko-edo', 'ng-ed', 'Akoko-Edo', '{}'::text[]),
  ('ng-ed-egor', 'ng-ed', 'Egor', '{}'::text[]),
  ('ng-ed-esan-central', 'ng-ed', 'Esan Central', '{}'::text[]),
  ('ng-ed-esan-north-east', 'ng-ed', 'Esan North-East', '{}'::text[]),
  ('ng-ed-esan-south-east', 'ng-ed', 'Esan South-East', '{}'::text[]),
  ('ng-ed-esan-west', 'ng-ed', 'Esan West', '{}'::text[]),
  ('ng-ed-etsako-central', 'ng-ed', 'Etsako Central', '{}'::text[]),
  ('ng-ed-etsako-east', 'ng-ed', 'Etsako East', '{}'::text[]),
  ('ng-ed-etsako-west', 'ng-ed', 'Etsako West', '{}'::text[]),
  ('ng-ed-igueben', 'ng-ed', 'Igueben', '{}'::text[]),
  ('ng-ed-ikpoba-okha', 'ng-ed', 'Ikpoba Okha', '{}'::text[]),
  ('ng-ed-oredo', 'ng-ed', 'Oredo', '{}'::text[]),
  ('ng-ed-orhionmwon', 'ng-ed', 'Orhionmwon', '{}'::text[]),
  ('ng-ed-ovia-north-east', 'ng-ed', 'Ovia North-East', '{}'::text[]),
  ('ng-ed-ovia-south-west', 'ng-ed', 'Ovia South-West', '{}'::text[]),
  ('ng-ed-owan-east', 'ng-ed', 'Owan East', '{}'::text[]),
  ('ng-ed-owan-west', 'ng-ed', 'Owan West', '{}'::text[]),
  ('ng-ed-uhunmwonde', 'ng-ed', 'Uhunmwonde', '{}'::text[]),
  ('ng-ek-ado-ekiti', 'ng-ek', 'Ado Ekiti', '{}'::text[]),
  ('ng-ek-efon', 'ng-ek', 'Efon', '{}'::text[]),
  ('ng-ek-ekiti-east', 'ng-ek', 'Ekiti East', '{}'::text[]),
  ('ng-ek-ekiti-south-west', 'ng-ek', 'Ekiti South-West', '{}'::text[]),
  ('ng-ek-ekiti-west', 'ng-ek', 'Ekiti West', '{}'::text[]),
  ('ng-ek-emure', 'ng-ek', 'Emure', '{}'::text[]),
  ('ng-ek-gbonyin', 'ng-ek', 'Gbonyin', '{}'::text[]),
  ('ng-ek-ido-osi', 'ng-ek', 'Ido Osi', '{}'::text[]),
  ('ng-ek-ijero', 'ng-ek', 'Ijero', '{}'::text[]),
  ('ng-ek-ikere', 'ng-ek', 'Ikere', '{}'::text[]),
  ('ng-ek-ikole', 'ng-ek', 'Ikole', '{}'::text[]),
  ('ng-ek-ilejemeje', 'ng-ek', 'Ilejemeje', '{}'::text[]),
  ('ng-ek-irepodun-ifelodun', 'ng-ek', 'Irepodun/Ifelodun', '{}'::text[]),
  ('ng-ek-ise-orun', 'ng-ek', 'Ise/Orun', '{}'::text[]),
  ('ng-ek-moba', 'ng-ek', 'Moba', '{}'::text[]),
  ('ng-ek-oye', 'ng-ek', 'Oye', '{}'::text[]),
  ('ng-en-aninri', 'ng-en', 'Aninri', '{}'::text[]),
  ('ng-en-awgu', 'ng-en', 'Awgu', '{}'::text[]),
  ('ng-en-enugu-east', 'ng-en', 'Enugu East', '{}'::text[]),
  ('ng-en-enugu-north', 'ng-en', 'Enugu North', '{}'::text[]),
  ('ng-en-enugu-south', 'ng-en', 'Enugu South', '{}'::text[]),
  ('ng-en-ezeagu', 'ng-en', 'Ezeagu', '{}'::text[]),
  ('ng-en-igbo-etiti', 'ng-en', 'Igbo Etiti', '{}'::text[]),
  ('ng-en-igbo-eze-north', 'ng-en', 'Igbo Eze North', '{}'::text[]),
  ('ng-en-igbo-eze-south', 'ng-en', 'Igbo Eze South', '{}'::text[]),
  ('ng-en-isi-uzo', 'ng-en', 'Isi Uzo', '{}'::text[]),
  ('ng-en-nkanu-east', 'ng-en', 'Nkanu East', '{}'::text[]),
  ('ng-en-nkanu-west', 'ng-en', 'Nkanu West', '{}'::text[]),
  ('ng-en-nsukka', 'ng-en', 'Nsukka', '{}'::text[]),
  ('ng-en-oji-river', 'ng-en', 'Oji River', '{}'::text[]),
  ('ng-en-udenu', 'ng-en', 'Udenu', '{}'::text[]),
  ('ng-en-udi', 'ng-en', 'Udi', '{}'::text[]),
  ('ng-en-uzo-uwani', 'ng-en', 'Uzo Uwani', '{}'::text[]),
  ('ng-fc-abaji', 'ng-fc', 'Abaji', '{}'::text[]),
  ('ng-fc-abuja-municipal-amac', 'ng-fc', 'Abuja Municipal (AMAC)', array['ng-fc-bwari', 'ng-fc-gwagwalada', 'ng-fc-kuje']),
  ('ng-fc-bwari', 'ng-fc', 'Bwari', '{}'::text[]),
  ('ng-fc-gwagwalada', 'ng-fc', 'Gwagwalada', '{}'::text[]),
  ('ng-fc-kuje', 'ng-fc', 'Kuje', '{}'::text[]),
  ('ng-fc-kwali', 'ng-fc', 'Kwali', '{}'::text[]),
  ('ng-go-akko', 'ng-go', 'Akko', '{}'::text[]),
  ('ng-go-balanga', 'ng-go', 'Balanga', '{}'::text[]),
  ('ng-go-billiri', 'ng-go', 'Billiri', '{}'::text[]),
  ('ng-go-dukku', 'ng-go', 'Dukku', '{}'::text[]),
  ('ng-go-funakaye', 'ng-go', 'Funakaye', '{}'::text[]),
  ('ng-go-gombe', 'ng-go', 'Gombe', '{}'::text[]),
  ('ng-go-kaltungo', 'ng-go', 'Kaltungo', '{}'::text[]),
  ('ng-go-kwami', 'ng-go', 'Kwami', '{}'::text[]),
  ('ng-go-nafada', 'ng-go', 'Nafada', '{}'::text[]),
  ('ng-go-shongom', 'ng-go', 'Shongom', '{}'::text[]),
  ('ng-go-yamaltu-deba', 'ng-go', 'Yamaltu/Deba', '{}'::text[]),
  ('ng-im-aboh-mbaise', 'ng-im', 'Aboh Mbaise', '{}'::text[]),
  ('ng-im-ahiazu-mbaise', 'ng-im', 'Ahiazu Mbaise', '{}'::text[]),
  ('ng-im-ehime-mbano', 'ng-im', 'Ehime Mbano', '{}'::text[]),
  ('ng-im-ezinihitte', 'ng-im', 'Ezinihitte', '{}'::text[]),
  ('ng-im-ideato-north', 'ng-im', 'Ideato North', '{}'::text[]),
  ('ng-im-ideato-south', 'ng-im', 'Ideato South', '{}'::text[]),
  ('ng-im-ihitte-uboma', 'ng-im', 'Ihitte/Uboma', '{}'::text[]),
  ('ng-im-ikeduru', 'ng-im', 'Ikeduru', '{}'::text[]),
  ('ng-im-isiala-mbano', 'ng-im', 'Isiala Mbano', '{}'::text[]),
  ('ng-im-isu', 'ng-im', 'Isu', '{}'::text[]),
  ('ng-im-mbaitoli', 'ng-im', 'Mbaitoli', '{}'::text[]),
  ('ng-im-ngor-okpala', 'ng-im', 'Ngor Okpala', '{}'::text[]),
  ('ng-im-njaba', 'ng-im', 'Njaba', '{}'::text[]),
  ('ng-im-nkwerre', 'ng-im', 'Nkwerre', '{}'::text[]),
  ('ng-im-nwangele', 'ng-im', 'Nwangele', '{}'::text[]),
  ('ng-im-obowo', 'ng-im', 'Obowo', '{}'::text[]),
  ('ng-im-oguta', 'ng-im', 'Oguta', '{}'::text[]),
  ('ng-im-ohaji-egbema', 'ng-im', 'Ohaji/Egbema', '{}'::text[]),
  ('ng-im-okigwe', 'ng-im', 'Okigwe', '{}'::text[]),
  ('ng-im-orlu', 'ng-im', 'Orlu', '{}'::text[]),
  ('ng-im-orsu', 'ng-im', 'Orsu', '{}'::text[]),
  ('ng-im-oru-east', 'ng-im', 'Oru East', '{}'::text[]),
  ('ng-im-oru-west', 'ng-im', 'Oru West', '{}'::text[]),
  ('ng-im-owerri-municipal', 'ng-im', 'Owerri Municipal', '{}'::text[]),
  ('ng-im-owerri-north', 'ng-im', 'Owerri North', '{}'::text[]),
  ('ng-im-owerri-west', 'ng-im', 'Owerri West', '{}'::text[]),
  ('ng-im-unuimo', 'ng-im', 'Unuimo', '{}'::text[]),
  ('ng-ji-auyo', 'ng-ji', 'Auyo', '{}'::text[]),
  ('ng-ji-babura', 'ng-ji', 'Babura', '{}'::text[]),
  ('ng-ji-biriniwa', 'ng-ji', 'Biriniwa', '{}'::text[]),
  ('ng-ji-birnin-kudu', 'ng-ji', 'Birnin Kudu', '{}'::text[]),
  ('ng-ji-buji', 'ng-ji', 'Buji', '{}'::text[]),
  ('ng-ji-dutse', 'ng-ji', 'Dutse', '{}'::text[]),
  ('ng-ji-gagarawa', 'ng-ji', 'Gagarawa', '{}'::text[]),
  ('ng-ji-garki', 'ng-ji', 'Garki', '{}'::text[]),
  ('ng-ji-gumel', 'ng-ji', 'Gumel', '{}'::text[]),
  ('ng-ji-guri', 'ng-ji', 'Guri', '{}'::text[]),
  ('ng-ji-gwaram', 'ng-ji', 'Gwaram', '{}'::text[]),
  ('ng-ji-gwiwa', 'ng-ji', 'Gwiwa', '{}'::text[]),
  ('ng-ji-hadejia', 'ng-ji', 'Hadejia', '{}'::text[]),
  ('ng-ji-jahun', 'ng-ji', 'Jahun', '{}'::text[]),
  ('ng-ji-kafin-hausa', 'ng-ji', 'Kafin Hausa', '{}'::text[]),
  ('ng-ji-kaugama', 'ng-ji', 'Kaugama', '{}'::text[]),
  ('ng-ji-kazaure', 'ng-ji', 'Kazaure', '{}'::text[]),
  ('ng-ji-kiri-kasama', 'ng-ji', 'Kiri Kasama', '{}'::text[]),
  ('ng-ji-kiyawa', 'ng-ji', 'Kiyawa', '{}'::text[]),
  ('ng-ji-maigatari', 'ng-ji', 'Maigatari', '{}'::text[]),
  ('ng-ji-malam-madori', 'ng-ji', 'Malam Madori', '{}'::text[]),
  ('ng-ji-miga', 'ng-ji', 'Miga', '{}'::text[]),
  ('ng-ji-ringim', 'ng-ji', 'Ringim', '{}'::text[]),
  ('ng-ji-roni', 'ng-ji', 'Roni', '{}'::text[]),
  ('ng-ji-sule-tankarkar', 'ng-ji', 'Sule Tankarkar', '{}'::text[]),
  ('ng-ji-taura', 'ng-ji', 'Taura', '{}'::text[]),
  ('ng-ji-yankwashi', 'ng-ji', 'Yankwashi', '{}'::text[]),
  ('ng-kd-birnin-gwari', 'ng-kd', 'Birnin Gwari', '{}'::text[]),
  ('ng-kd-chikun', 'ng-kd', 'Chikun', '{}'::text[]),
  ('ng-kd-giwa', 'ng-kd', 'Giwa', '{}'::text[]),
  ('ng-kd-igabi', 'ng-kd', 'Igabi', '{}'::text[]),
  ('ng-kd-ikara', 'ng-kd', 'Ikara', '{}'::text[]),
  ('ng-kd-jaba', 'ng-kd', 'Jaba', '{}'::text[]),
  ('ng-kd-jema-a', 'ng-kd', 'Jema''a', '{}'::text[]),
  ('ng-kd-kachia', 'ng-kd', 'Kachia', '{}'::text[]),
  ('ng-kd-kaduna-north', 'ng-kd', 'Kaduna North', '{}'::text[]),
  ('ng-kd-kaduna-south', 'ng-kd', 'Kaduna South', '{}'::text[]),
  ('ng-kd-kagarko', 'ng-kd', 'Kagarko', '{}'::text[]),
  ('ng-kd-kajuru', 'ng-kd', 'Kajuru', '{}'::text[]),
  ('ng-kd-kaura', 'ng-kd', 'Kaura', '{}'::text[]),
  ('ng-kd-kauru', 'ng-kd', 'Kauru', '{}'::text[]),
  ('ng-kd-kubau', 'ng-kd', 'Kubau', '{}'::text[]),
  ('ng-kd-kudan', 'ng-kd', 'Kudan', '{}'::text[]),
  ('ng-kd-lere', 'ng-kd', 'Lere', '{}'::text[]),
  ('ng-kd-makarfi', 'ng-kd', 'Makarfi', '{}'::text[]),
  ('ng-kd-sabon-gari', 'ng-kd', 'Sabon Gari', '{}'::text[]),
  ('ng-kd-sanga', 'ng-kd', 'Sanga', '{}'::text[]),
  ('ng-kd-soba', 'ng-kd', 'Soba', '{}'::text[]),
  ('ng-kd-zangon-kataf', 'ng-kd', 'Zangon Kataf', '{}'::text[]),
  ('ng-kd-zaria', 'ng-kd', 'Zaria', '{}'::text[]),
  ('ng-kn-ajingi', 'ng-kn', 'Ajingi', '{}'::text[]),
  ('ng-kn-albasu', 'ng-kn', 'Albasu', '{}'::text[]),
  ('ng-kn-bagwai', 'ng-kn', 'Bagwai', '{}'::text[]),
  ('ng-kn-bebeji', 'ng-kn', 'Bebeji', '{}'::text[]),
  ('ng-kn-bichi', 'ng-kn', 'Bichi', '{}'::text[]),
  ('ng-kn-bunkure', 'ng-kn', 'Bunkure', '{}'::text[]),
  ('ng-kn-dala', 'ng-kn', 'Dala', '{}'::text[]),
  ('ng-kn-dambatta', 'ng-kn', 'Dambatta', '{}'::text[]),
  ('ng-kn-dawakin-kudu', 'ng-kn', 'Dawakin Kudu', '{}'::text[]),
  ('ng-kn-dawakin-tofa', 'ng-kn', 'Dawakin Tofa', '{}'::text[]),
  ('ng-kn-doguwa', 'ng-kn', 'Doguwa', '{}'::text[]),
  ('ng-kn-fagge', 'ng-kn', 'Fagge', '{}'::text[]),
  ('ng-kn-gabasawa', 'ng-kn', 'Gabasawa', '{}'::text[]),
  ('ng-kn-garko', 'ng-kn', 'Garko', '{}'::text[]),
  ('ng-kn-garun-mallam', 'ng-kn', 'Garun Mallam', '{}'::text[]),
  ('ng-kn-gaya', 'ng-kn', 'Gaya', '{}'::text[]),
  ('ng-kn-gezawa', 'ng-kn', 'Gezawa', '{}'::text[]),
  ('ng-kn-gwale', 'ng-kn', 'Gwale', '{}'::text[]),
  ('ng-kn-gwarzo', 'ng-kn', 'Gwarzo', '{}'::text[]),
  ('ng-kn-kabo', 'ng-kn', 'Kabo', '{}'::text[]),
  ('ng-kn-kano-municipal', 'ng-kn', 'Kano Municipal', '{}'::text[]),
  ('ng-kn-karaye', 'ng-kn', 'Karaye', '{}'::text[]),
  ('ng-kn-kibiya', 'ng-kn', 'Kibiya', '{}'::text[]),
  ('ng-kn-kiru', 'ng-kn', 'Kiru', '{}'::text[]),
  ('ng-kn-kumbotso', 'ng-kn', 'Kumbotso', '{}'::text[]),
  ('ng-kn-kunchi', 'ng-kn', 'Kunchi', '{}'::text[]),
  ('ng-kn-kura', 'ng-kn', 'Kura', '{}'::text[]),
  ('ng-kn-madobi', 'ng-kn', 'Madobi', '{}'::text[]),
  ('ng-kn-makoda', 'ng-kn', 'Makoda', '{}'::text[]),
  ('ng-kn-minjibir', 'ng-kn', 'Minjibir', '{}'::text[]),
  ('ng-kn-nasarawa', 'ng-kn', 'Nasarawa', '{}'::text[]),
  ('ng-kn-rano', 'ng-kn', 'Rano', '{}'::text[]),
  ('ng-kn-rimin-gado', 'ng-kn', 'Rimin Gado', '{}'::text[]),
  ('ng-kn-rogo', 'ng-kn', 'Rogo', '{}'::text[]),
  ('ng-kn-shanono', 'ng-kn', 'Shanono', '{}'::text[]),
  ('ng-kn-sumaila', 'ng-kn', 'Sumaila', '{}'::text[]),
  ('ng-kn-takai', 'ng-kn', 'Takai', '{}'::text[]),
  ('ng-kn-tarauni', 'ng-kn', 'Tarauni', '{}'::text[]),
  ('ng-kn-tofa', 'ng-kn', 'Tofa', '{}'::text[]),
  ('ng-kn-tsanyawa', 'ng-kn', 'Tsanyawa', '{}'::text[]),
  ('ng-kn-tudun-wada', 'ng-kn', 'Tudun Wada', '{}'::text[]),
  ('ng-kn-ungogo', 'ng-kn', 'Ungogo', '{}'::text[]),
  ('ng-kn-warawa', 'ng-kn', 'Warawa', '{}'::text[]),
  ('ng-kn-wudil', 'ng-kn', 'Wudil', '{}'::text[]),
  ('ng-kt-bakori', 'ng-kt', 'Bakori', '{}'::text[]),
  ('ng-kt-batagarawa', 'ng-kt', 'Batagarawa', '{}'::text[]),
  ('ng-kt-batsari', 'ng-kt', 'Batsari', '{}'::text[]),
  ('ng-kt-baure', 'ng-kt', 'Baure', '{}'::text[]),
  ('ng-kt-bindawa', 'ng-kt', 'Bindawa', '{}'::text[]),
  ('ng-kt-charanchi', 'ng-kt', 'Charanchi', '{}'::text[]),
  ('ng-kt-dandume', 'ng-kt', 'Dandume', '{}'::text[]),
  ('ng-kt-danja', 'ng-kt', 'Danja', '{}'::text[]),
  ('ng-kt-dan-musa', 'ng-kt', 'Dan Musa', '{}'::text[]),
  ('ng-kt-daura', 'ng-kt', 'Daura', '{}'::text[]),
  ('ng-kt-dutsi', 'ng-kt', 'Dutsi', '{}'::text[]),
  ('ng-kt-dutsin-ma', 'ng-kt', 'Dutsin-Ma', '{}'::text[]),
  ('ng-kt-faskari', 'ng-kt', 'Faskari', '{}'::text[]),
  ('ng-kt-funtua', 'ng-kt', 'Funtua', '{}'::text[]),
  ('ng-kt-ingawa', 'ng-kt', 'Ingawa', '{}'::text[]),
  ('ng-kt-jibia', 'ng-kt', 'Jibia', '{}'::text[]),
  ('ng-kt-kafur', 'ng-kt', 'Kafur', '{}'::text[]),
  ('ng-kt-kaita', 'ng-kt', 'Kaita', '{}'::text[]),
  ('ng-kt-kankara', 'ng-kt', 'Kankara', '{}'::text[]),
  ('ng-kt-kankia', 'ng-kt', 'Kankia', '{}'::text[]),
  ('ng-kt-katsina', 'ng-kt', 'Katsina', '{}'::text[]),
  ('ng-kt-kurfi', 'ng-kt', 'Kurfi', '{}'::text[]),
  ('ng-kt-kusada', 'ng-kt', 'Kusada', '{}'::text[]),
  ('ng-kt-mai-adua', 'ng-kt', 'Mai''Adua', '{}'::text[]),
  ('ng-kt-malumfashi', 'ng-kt', 'Malumfashi', '{}'::text[]),
  ('ng-kt-mani', 'ng-kt', 'Mani', '{}'::text[]),
  ('ng-kt-mashi', 'ng-kt', 'Mashi', '{}'::text[]),
  ('ng-kt-matazu', 'ng-kt', 'Matazu', '{}'::text[]),
  ('ng-kt-musawa', 'ng-kt', 'Musawa', '{}'::text[]),
  ('ng-kt-rimi', 'ng-kt', 'Rimi', '{}'::text[]),
  ('ng-kt-sabuwa', 'ng-kt', 'Sabuwa', '{}'::text[]),
  ('ng-kt-safana', 'ng-kt', 'Safana', '{}'::text[]),
  ('ng-kt-sandamu', 'ng-kt', 'Sandamu', '{}'::text[]),
  ('ng-kt-zango', 'ng-kt', 'Zango', '{}'::text[]),
  ('ng-ke-aleiro', 'ng-ke', 'Aleiro', '{}'::text[]),
  ('ng-ke-arewa-dandi', 'ng-ke', 'Arewa Dandi', '{}'::text[]),
  ('ng-ke-argungu', 'ng-ke', 'Argungu', '{}'::text[]),
  ('ng-ke-augie', 'ng-ke', 'Augie', '{}'::text[]),
  ('ng-ke-bagudo', 'ng-ke', 'Bagudo', '{}'::text[]),
  ('ng-ke-birnin-kebbi', 'ng-ke', 'Birnin Kebbi', '{}'::text[]),
  ('ng-ke-bunza', 'ng-ke', 'Bunza', '{}'::text[]),
  ('ng-ke-dandi', 'ng-ke', 'Dandi', '{}'::text[]),
  ('ng-ke-fakai', 'ng-ke', 'Fakai', '{}'::text[]),
  ('ng-ke-gwandu', 'ng-ke', 'Gwandu', '{}'::text[]),
  ('ng-ke-jega', 'ng-ke', 'Jega', '{}'::text[]),
  ('ng-ke-kalgo', 'ng-ke', 'Kalgo', '{}'::text[]),
  ('ng-ke-koko-besse', 'ng-ke', 'Koko/Besse', '{}'::text[]),
  ('ng-ke-maiyama', 'ng-ke', 'Maiyama', '{}'::text[]),
  ('ng-ke-ngaski', 'ng-ke', 'Ngaski', '{}'::text[]),
  ('ng-ke-sakaba', 'ng-ke', 'Sakaba', '{}'::text[]),
  ('ng-ke-shanga', 'ng-ke', 'Shanga', '{}'::text[]),
  ('ng-ke-suru', 'ng-ke', 'Suru', '{}'::text[]),
  ('ng-ke-wasagu-danko', 'ng-ke', 'Wasagu/Danko', '{}'::text[]),
  ('ng-ke-yauri', 'ng-ke', 'Yauri', '{}'::text[]),
  ('ng-ke-zuru', 'ng-ke', 'Zuru', '{}'::text[]),
  ('ng-ko-adavi', 'ng-ko', 'Adavi', '{}'::text[]),
  ('ng-ko-ajaokuta', 'ng-ko', 'Ajaokuta', '{}'::text[]),
  ('ng-ko-ankpa', 'ng-ko', 'Ankpa', '{}'::text[]),
  ('ng-ko-bassa', 'ng-ko', 'Bassa', '{}'::text[]),
  ('ng-ko-dekina', 'ng-ko', 'Dekina', '{}'::text[]),
  ('ng-ko-ibaji', 'ng-ko', 'Ibaji', '{}'::text[]),
  ('ng-ko-idah', 'ng-ko', 'Idah', '{}'::text[]),
  ('ng-ko-igalamela-odolu', 'ng-ko', 'Igalamela-Odolu', '{}'::text[]),
  ('ng-ko-ijumu', 'ng-ko', 'Ijumu', '{}'::text[]),
  ('ng-ko-kabba-bunu', 'ng-ko', 'Kabba/Bunu', '{}'::text[]),
  ('ng-ko-kogi', 'ng-ko', 'Kogi', '{}'::text[]),
  ('ng-ko-lokoja', 'ng-ko', 'Lokoja', '{}'::text[]),
  ('ng-ko-mopa-muro', 'ng-ko', 'Mopa-Muro', '{}'::text[]),
  ('ng-ko-ofu', 'ng-ko', 'Ofu', '{}'::text[]),
  ('ng-ko-ogori-magongo', 'ng-ko', 'Ogori/Magongo', '{}'::text[]),
  ('ng-ko-okehi', 'ng-ko', 'Okehi', '{}'::text[]),
  ('ng-ko-okene', 'ng-ko', 'Okene', '{}'::text[]),
  ('ng-ko-olamaboro', 'ng-ko', 'Olamaboro', '{}'::text[]),
  ('ng-ko-omala', 'ng-ko', 'Omala', '{}'::text[]),
  ('ng-ko-yagba-east', 'ng-ko', 'Yagba East', '{}'::text[]),
  ('ng-ko-yagba-west', 'ng-ko', 'Yagba West', '{}'::text[]),
  ('ng-kw-asa', 'ng-kw', 'Asa', '{}'::text[]),
  ('ng-kw-baruten', 'ng-kw', 'Baruten', '{}'::text[]),
  ('ng-kw-edu', 'ng-kw', 'Edu', '{}'::text[]),
  ('ng-kw-ekiti', 'ng-kw', 'Ekiti', '{}'::text[]),
  ('ng-kw-ifelodun', 'ng-kw', 'Ifelodun', '{}'::text[]),
  ('ng-kw-ilorin-east', 'ng-kw', 'Ilorin East', '{}'::text[]),
  ('ng-kw-ilorin-south', 'ng-kw', 'Ilorin South', '{}'::text[]),
  ('ng-kw-ilorin-west', 'ng-kw', 'Ilorin West', '{}'::text[]),
  ('ng-kw-irepodun', 'ng-kw', 'Irepodun', '{}'::text[]),
  ('ng-kw-isin', 'ng-kw', 'Isin', '{}'::text[]),
  ('ng-kw-kaiama', 'ng-kw', 'Kaiama', '{}'::text[]),
  ('ng-kw-moro', 'ng-kw', 'Moro', '{}'::text[]),
  ('ng-kw-offa', 'ng-kw', 'Offa', '{}'::text[]),
  ('ng-kw-oke-ero', 'ng-kw', 'Oke Ero', '{}'::text[]),
  ('ng-kw-oyun', 'ng-kw', 'Oyun', '{}'::text[]),
  ('ng-kw-pategi', 'ng-kw', 'Pategi', '{}'::text[]),
  ('ng-la-agege', 'ng-la', 'Agege', '{}'::text[]),
  ('ng-la-ajeromi-ifelodun', 'ng-la', 'Ajeromi-Ifelodun', '{}'::text[]),
  ('ng-la-alimosho', 'ng-la', 'Alimosho', '{}'::text[]),
  ('ng-la-amuwo-odofin', 'ng-la', 'Amuwo-Odofin', '{}'::text[]),
  ('ng-la-apapa', 'ng-la', 'Apapa', '{}'::text[]),
  ('ng-la-badagry', 'ng-la', 'Badagry', '{}'::text[]),
  ('ng-la-epe', 'ng-la', 'Epe', '{}'::text[]),
  ('ng-la-eti-osa', 'ng-la', 'Eti-Osa', array['ng-la-lagos-island', 'ng-la-ibeju-lekki']),
  ('ng-la-ibeju-lekki', 'ng-la', 'Ibeju-Lekki', '{}'::text[]),
  ('ng-la-ifako-ijaiye', 'ng-la', 'Ifako-Ijaiye', '{}'::text[]),
  ('ng-la-ikeja', 'ng-la', 'Ikeja', array['ng-la-agege', 'ng-la-ifako-ijaiye', 'ng-la-kosofe', 'ng-la-oshodi-isolo']),
  ('ng-la-ikorodu', 'ng-la', 'Ikorodu', '{}'::text[]),
  ('ng-la-kosofe', 'ng-la', 'Kosofe', '{}'::text[]),
  ('ng-la-lagos-island', 'ng-la', 'Lagos Island', '{}'::text[]),
  ('ng-la-lagos-mainland', 'ng-la', 'Lagos Mainland', array['ng-la-surulere', 'ng-la-mushin', 'ng-la-shomolu']),
  ('ng-la-mushin', 'ng-la', 'Mushin', '{}'::text[]),
  ('ng-la-ojo', 'ng-la', 'Ojo', '{}'::text[]),
  ('ng-la-oshodi-isolo', 'ng-la', 'Oshodi-Isolo', '{}'::text[]),
  ('ng-la-shomolu', 'ng-la', 'Shomolu', '{}'::text[]),
  ('ng-la-surulere', 'ng-la', 'Surulere', array['ng-la-lagos-mainland', 'ng-la-mushin', 'ng-la-oshodi-isolo', 'ng-la-apapa']),
  ('ng-na-akwanga', 'ng-na', 'Akwanga', '{}'::text[]),
  ('ng-na-awe', 'ng-na', 'Awe', '{}'::text[]),
  ('ng-na-doma', 'ng-na', 'Doma', '{}'::text[]),
  ('ng-na-karu', 'ng-na', 'Karu', '{}'::text[]),
  ('ng-na-keana', 'ng-na', 'Keana', '{}'::text[]),
  ('ng-na-keffi', 'ng-na', 'Keffi', '{}'::text[]),
  ('ng-na-kokona', 'ng-na', 'Kokona', '{}'::text[]),
  ('ng-na-lafia', 'ng-na', 'Lafia', '{}'::text[]),
  ('ng-na-nasarawa', 'ng-na', 'Nasarawa', '{}'::text[]),
  ('ng-na-nasarawa-egon', 'ng-na', 'Nasarawa Egon', '{}'::text[]),
  ('ng-na-obi', 'ng-na', 'Obi', '{}'::text[]),
  ('ng-na-toto', 'ng-na', 'Toto', '{}'::text[]),
  ('ng-na-wamba', 'ng-na', 'Wamba', '{}'::text[]),
  ('ng-ni-agaie', 'ng-ni', 'Agaie', '{}'::text[]),
  ('ng-ni-agwara', 'ng-ni', 'Agwara', '{}'::text[]),
  ('ng-ni-bida', 'ng-ni', 'Bida', '{}'::text[]),
  ('ng-ni-borgu', 'ng-ni', 'Borgu', '{}'::text[]),
  ('ng-ni-bosso', 'ng-ni', 'Bosso', '{}'::text[]),
  ('ng-ni-chanchaga', 'ng-ni', 'Chanchaga', '{}'::text[]),
  ('ng-ni-edati', 'ng-ni', 'Edati', '{}'::text[]),
  ('ng-ni-gbako', 'ng-ni', 'Gbako', '{}'::text[]),
  ('ng-ni-gurara', 'ng-ni', 'Gurara', '{}'::text[]),
  ('ng-ni-katcha', 'ng-ni', 'Katcha', '{}'::text[]),
  ('ng-ni-kontagora', 'ng-ni', 'Kontagora', '{}'::text[]),
  ('ng-ni-lapai', 'ng-ni', 'Lapai', '{}'::text[]),
  ('ng-ni-lavun', 'ng-ni', 'Lavun', '{}'::text[]),
  ('ng-ni-magama', 'ng-ni', 'Magama', '{}'::text[]),
  ('ng-ni-mariga', 'ng-ni', 'Mariga', '{}'::text[]),
  ('ng-ni-mashegu', 'ng-ni', 'Mashegu', '{}'::text[]),
  ('ng-ni-mokwa', 'ng-ni', 'Mokwa', '{}'::text[]),
  ('ng-ni-moya', 'ng-ni', 'Moya', '{}'::text[]),
  ('ng-ni-paikoro', 'ng-ni', 'Paikoro', '{}'::text[]),
  ('ng-ni-rafi', 'ng-ni', 'Rafi', '{}'::text[]),
  ('ng-ni-rijau', 'ng-ni', 'Rijau', '{}'::text[]),
  ('ng-ni-shiroro', 'ng-ni', 'Shiroro', '{}'::text[]),
  ('ng-ni-suleja', 'ng-ni', 'Suleja', '{}'::text[]),
  ('ng-ni-tafa', 'ng-ni', 'Tafa', '{}'::text[]),
  ('ng-ni-wushishi', 'ng-ni', 'Wushishi', '{}'::text[]),
  ('ng-og-abeokuta-north', 'ng-og', 'Abeokuta North', '{}'::text[]),
  ('ng-og-abeokuta-south', 'ng-og', 'Abeokuta South', '{}'::text[]),
  ('ng-og-ado-odo-ota', 'ng-og', 'Ado-Odo/Ota', '{}'::text[]),
  ('ng-og-ewekoro', 'ng-og', 'Ewekoro', '{}'::text[]),
  ('ng-og-ifo', 'ng-og', 'Ifo', '{}'::text[]),
  ('ng-og-ijebu-east', 'ng-og', 'Ijebu East', '{}'::text[]),
  ('ng-og-ijebu-north', 'ng-og', 'Ijebu North', '{}'::text[]),
  ('ng-og-ijebu-north-east', 'ng-og', 'Ijebu North East', '{}'::text[]),
  ('ng-og-ijebu-ode', 'ng-og', 'Ijebu Ode', '{}'::text[]),
  ('ng-og-ikenne', 'ng-og', 'Ikenne', '{}'::text[]),
  ('ng-og-imeko-afon', 'ng-og', 'Imeko Afon', '{}'::text[]),
  ('ng-og-ipokia', 'ng-og', 'Ipokia', '{}'::text[]),
  ('ng-og-obafemi-owode', 'ng-og', 'Obafemi Owode', '{}'::text[]),
  ('ng-og-odeda', 'ng-og', 'Odeda', '{}'::text[]),
  ('ng-og-odogbolu', 'ng-og', 'Odogbolu', '{}'::text[]),
  ('ng-og-ogun-waterside', 'ng-og', 'Ogun Waterside', '{}'::text[]),
  ('ng-og-remo-north', 'ng-og', 'Remo North', '{}'::text[]),
  ('ng-og-sagamu', 'ng-og', 'Sagamu', '{}'::text[]),
  ('ng-og-yewa-north', 'ng-og', 'Yewa North', '{}'::text[]),
  ('ng-og-yewa-south', 'ng-og', 'Yewa South', '{}'::text[]),
  ('ng-on-akoko-north-east', 'ng-on', 'Akoko North-East', '{}'::text[]),
  ('ng-on-akoko-north-west', 'ng-on', 'Akoko North-West', '{}'::text[]),
  ('ng-on-akoko-south-east', 'ng-on', 'Akoko South-East', '{}'::text[]),
  ('ng-on-akoko-south-west', 'ng-on', 'Akoko South-West', '{}'::text[]),
  ('ng-on-akure-north', 'ng-on', 'Akure North', '{}'::text[]),
  ('ng-on-akure-south', 'ng-on', 'Akure South', '{}'::text[]),
  ('ng-on-ese-odo', 'ng-on', 'Ese Odo', '{}'::text[]),
  ('ng-on-idanre', 'ng-on', 'Idanre', '{}'::text[]),
  ('ng-on-ifedore', 'ng-on', 'Ifedore', '{}'::text[]),
  ('ng-on-ilaje', 'ng-on', 'Ilaje', '{}'::text[]),
  ('ng-on-ile-oluji-okeigbo', 'ng-on', 'Ile Oluji/Okeigbo', '{}'::text[]),
  ('ng-on-irele', 'ng-on', 'Irele', '{}'::text[]),
  ('ng-on-odigbo', 'ng-on', 'Odigbo', '{}'::text[]),
  ('ng-on-okitipupa', 'ng-on', 'Okitipupa', '{}'::text[]),
  ('ng-on-ondo-east', 'ng-on', 'Ondo East', '{}'::text[]),
  ('ng-on-ondo-west', 'ng-on', 'Ondo West', '{}'::text[]),
  ('ng-on-ose', 'ng-on', 'Ose', '{}'::text[]),
  ('ng-on-owo', 'ng-on', 'Owo', '{}'::text[]),
  ('ng-os-atakunmosa-east', 'ng-os', 'Atakunmosa East', '{}'::text[]),
  ('ng-os-atakunmosa-west', 'ng-os', 'Atakunmosa West', '{}'::text[]),
  ('ng-os-aiyedaade', 'ng-os', 'Aiyedaade', '{}'::text[]),
  ('ng-os-aiyedire', 'ng-os', 'Aiyedire', '{}'::text[]),
  ('ng-os-boluwaduro', 'ng-os', 'Boluwaduro', '{}'::text[]),
  ('ng-os-boripe', 'ng-os', 'Boripe', '{}'::text[]),
  ('ng-os-ede-north', 'ng-os', 'Ede North', '{}'::text[]),
  ('ng-os-ede-south', 'ng-os', 'Ede South', '{}'::text[]),
  ('ng-os-egbedore', 'ng-os', 'Egbedore', '{}'::text[]),
  ('ng-os-ejigbo', 'ng-os', 'Ejigbo', '{}'::text[]),
  ('ng-os-ife-central', 'ng-os', 'Ife Central', '{}'::text[]),
  ('ng-os-ife-east', 'ng-os', 'Ife East', '{}'::text[]),
  ('ng-os-ife-north', 'ng-os', 'Ife North', '{}'::text[]),
  ('ng-os-ife-south', 'ng-os', 'Ife South', '{}'::text[]),
  ('ng-os-ifedayo', 'ng-os', 'Ifedayo', '{}'::text[]),
  ('ng-os-ifelodun', 'ng-os', 'Ifelodun', '{}'::text[]),
  ('ng-os-ila', 'ng-os', 'Ila', '{}'::text[]),
  ('ng-os-ilesa-east', 'ng-os', 'Ilesa East', '{}'::text[]),
  ('ng-os-ilesa-west', 'ng-os', 'Ilesa West', '{}'::text[]),
  ('ng-os-irepodun', 'ng-os', 'Irepodun', '{}'::text[]),
  ('ng-os-irewole', 'ng-os', 'Irewole', '{}'::text[]),
  ('ng-os-isokan', 'ng-os', 'Isokan', '{}'::text[]),
  ('ng-os-iwo', 'ng-os', 'Iwo', '{}'::text[]),
  ('ng-os-obokun', 'ng-os', 'Obokun', '{}'::text[]),
  ('ng-os-odo-otin', 'ng-os', 'Odo Otin', '{}'::text[]),
  ('ng-os-ola-oluwa', 'ng-os', 'Ola Oluwa', '{}'::text[]),
  ('ng-os-olorunda', 'ng-os', 'Olorunda', '{}'::text[]),
  ('ng-os-oriade', 'ng-os', 'Oriade', '{}'::text[]),
  ('ng-os-orolu', 'ng-os', 'Orolu', '{}'::text[]),
  ('ng-os-osogbo', 'ng-os', 'Osogbo', '{}'::text[]),
  ('ng-oy-afijio', 'ng-oy', 'Afijio', '{}'::text[]),
  ('ng-oy-akinyele', 'ng-oy', 'Akinyele', '{}'::text[]),
  ('ng-oy-atiba', 'ng-oy', 'Atiba', '{}'::text[]),
  ('ng-oy-atisbo', 'ng-oy', 'Atisbo', '{}'::text[]),
  ('ng-oy-egbeda', 'ng-oy', 'Egbeda', '{}'::text[]),
  ('ng-oy-ibadan-north', 'ng-oy', 'Ibadan North', array['ng-oy-ibadan-north-east', 'ng-oy-ibadan-north-west', 'ng-oy-ibadan-south-west', 'ng-oy-egbeda', 'ng-oy-lagelu']),
  ('ng-oy-ibadan-north-east', 'ng-oy', 'Ibadan North-East', '{}'::text[]),
  ('ng-oy-ibadan-north-west', 'ng-oy', 'Ibadan North-West', '{}'::text[]),
  ('ng-oy-ibadan-south-east', 'ng-oy', 'Ibadan South-East', '{}'::text[]),
  ('ng-oy-ibadan-south-west', 'ng-oy', 'Ibadan South-West', '{}'::text[]),
  ('ng-oy-ibarapa-central', 'ng-oy', 'Ibarapa Central', '{}'::text[]),
  ('ng-oy-ibarapa-east', 'ng-oy', 'Ibarapa East', '{}'::text[]),
  ('ng-oy-ibarapa-north', 'ng-oy', 'Ibarapa North', '{}'::text[]),
  ('ng-oy-ido', 'ng-oy', 'Ido', '{}'::text[]),
  ('ng-oy-irepo', 'ng-oy', 'Irepo', '{}'::text[]),
  ('ng-oy-iseyin', 'ng-oy', 'Iseyin', '{}'::text[]),
  ('ng-oy-itesiwaju', 'ng-oy', 'Itesiwaju', '{}'::text[]),
  ('ng-oy-iwajowa', 'ng-oy', 'Iwajowa', '{}'::text[]),
  ('ng-oy-kajola', 'ng-oy', 'Kajola', '{}'::text[]),
  ('ng-oy-lagelu', 'ng-oy', 'Lagelu', '{}'::text[]),
  ('ng-oy-ogbomosho-north', 'ng-oy', 'Ogbomosho North', '{}'::text[]),
  ('ng-oy-ogbomosho-south', 'ng-oy', 'Ogbomosho South', '{}'::text[]),
  ('ng-oy-ogo-oluwa', 'ng-oy', 'Ogo Oluwa', '{}'::text[]),
  ('ng-oy-olorunsogo', 'ng-oy', 'Olorunsogo', '{}'::text[]),
  ('ng-oy-oluyole', 'ng-oy', 'Oluyole', '{}'::text[]),
  ('ng-oy-ona-ara', 'ng-oy', 'Ona Ara', '{}'::text[]),
  ('ng-oy-orelope', 'ng-oy', 'Orelope', '{}'::text[]),
  ('ng-oy-ori-ire', 'ng-oy', 'Ori Ire', '{}'::text[]),
  ('ng-oy-oyo', 'ng-oy', 'Oyo', '{}'::text[]),
  ('ng-oy-oyo-east', 'ng-oy', 'Oyo East', '{}'::text[]),
  ('ng-oy-saki-east', 'ng-oy', 'Saki East', '{}'::text[]),
  ('ng-oy-saki-west', 'ng-oy', 'Saki West', '{}'::text[]),
  ('ng-oy-surulere', 'ng-oy', 'Surulere', '{}'::text[]),
  ('ng-pl-barkin-ladi', 'ng-pl', 'Barkin Ladi', '{}'::text[]),
  ('ng-pl-bassa', 'ng-pl', 'Bassa', '{}'::text[]),
  ('ng-pl-bokkos', 'ng-pl', 'Bokkos', '{}'::text[]),
  ('ng-pl-jos-east', 'ng-pl', 'Jos East', '{}'::text[]),
  ('ng-pl-jos-north', 'ng-pl', 'Jos North', '{}'::text[]),
  ('ng-pl-jos-south', 'ng-pl', 'Jos South', '{}'::text[]),
  ('ng-pl-kanam', 'ng-pl', 'Kanam', '{}'::text[]),
  ('ng-pl-kanke', 'ng-pl', 'Kanke', '{}'::text[]),
  ('ng-pl-langtang-north', 'ng-pl', 'Langtang North', '{}'::text[]),
  ('ng-pl-langtang-south', 'ng-pl', 'Langtang South', '{}'::text[]),
  ('ng-pl-mangu', 'ng-pl', 'Mangu', '{}'::text[]),
  ('ng-pl-mikang', 'ng-pl', 'Mikang', '{}'::text[]),
  ('ng-pl-pankshin', 'ng-pl', 'Pankshin', '{}'::text[]),
  ('ng-pl-qua-an-pan', 'ng-pl', 'Qua''an Pan', '{}'::text[]),
  ('ng-pl-riyom', 'ng-pl', 'Riyom', '{}'::text[]),
  ('ng-pl-shendam', 'ng-pl', 'Shendam', '{}'::text[]),
  ('ng-pl-wase', 'ng-pl', 'Wase', '{}'::text[]),
  ('ng-ri-abua-odual', 'ng-ri', 'Abua/Odual', '{}'::text[]),
  ('ng-ri-ahoada-east', 'ng-ri', 'Ahoada East', '{}'::text[]),
  ('ng-ri-ahoada-west', 'ng-ri', 'Ahoada West', '{}'::text[]),
  ('ng-ri-akuku-toru', 'ng-ri', 'Akuku-Toru', '{}'::text[]),
  ('ng-ri-andoni', 'ng-ri', 'Andoni', '{}'::text[]),
  ('ng-ri-asari-toru', 'ng-ri', 'Asari-Toru', '{}'::text[]),
  ('ng-ri-bonny', 'ng-ri', 'Bonny', '{}'::text[]),
  ('ng-ri-degema', 'ng-ri', 'Degema', '{}'::text[]),
  ('ng-ri-eleme', 'ng-ri', 'Eleme', '{}'::text[]),
  ('ng-ri-emuoha', 'ng-ri', 'Emuoha', '{}'::text[]),
  ('ng-ri-etche', 'ng-ri', 'Etche', '{}'::text[]),
  ('ng-ri-gokana', 'ng-ri', 'Gokana', '{}'::text[]),
  ('ng-ri-ikwerre', 'ng-ri', 'Ikwerre', '{}'::text[]),
  ('ng-ri-khana', 'ng-ri', 'Khana', '{}'::text[]),
  ('ng-ri-obio-akpor', 'ng-ri', 'Obio/Akpor', '{}'::text[]),
  ('ng-ri-ogba-egbema-ndoni', 'ng-ri', 'Ogba/Egbema/Ndoni', '{}'::text[]),
  ('ng-ri-ogu-bolo', 'ng-ri', 'Ogu/Bolo', '{}'::text[]),
  ('ng-ri-okrika', 'ng-ri', 'Okrika', '{}'::text[]),
  ('ng-ri-omuma', 'ng-ri', 'Omuma', '{}'::text[]),
  ('ng-ri-opobo-nkoro', 'ng-ri', 'Opobo/Nkoro', '{}'::text[]),
  ('ng-ri-oyigbo', 'ng-ri', 'Oyigbo', '{}'::text[]),
  ('ng-ri-port-harcourt', 'ng-ri', 'Port Harcourt', '{}'::text[]),
  ('ng-ri-tai', 'ng-ri', 'Tai', '{}'::text[]),
  ('ng-so-binji', 'ng-so', 'Binji', '{}'::text[]),
  ('ng-so-bodinga', 'ng-so', 'Bodinga', '{}'::text[]),
  ('ng-so-dange-shuni', 'ng-so', 'Dange Shuni', '{}'::text[]),
  ('ng-so-gada', 'ng-so', 'Gada', '{}'::text[]),
  ('ng-so-goronyo', 'ng-so', 'Goronyo', '{}'::text[]),
  ('ng-so-gudu', 'ng-so', 'Gudu', '{}'::text[]),
  ('ng-so-gwadabawa', 'ng-so', 'Gwadabawa', '{}'::text[]),
  ('ng-so-illela', 'ng-so', 'Illela', '{}'::text[]),
  ('ng-so-isa', 'ng-so', 'Isa', '{}'::text[]),
  ('ng-so-kebbe', 'ng-so', 'Kebbe', '{}'::text[]),
  ('ng-so-kware', 'ng-so', 'Kware', '{}'::text[]),
  ('ng-so-rabah', 'ng-so', 'Rabah', '{}'::text[]),
  ('ng-so-sabon-birni', 'ng-so', 'Sabon Birni', '{}'::text[]),
  ('ng-so-shagari', 'ng-so', 'Shagari', '{}'::text[]),
  ('ng-so-silame', 'ng-so', 'Silame', '{}'::text[]),
  ('ng-so-sokoto-north', 'ng-so', 'Sokoto North', '{}'::text[]),
  ('ng-so-sokoto-south', 'ng-so', 'Sokoto South', '{}'::text[]),
  ('ng-so-tambuwal', 'ng-so', 'Tambuwal', '{}'::text[]),
  ('ng-so-tangaza', 'ng-so', 'Tangaza', '{}'::text[]),
  ('ng-so-tureta', 'ng-so', 'Tureta', '{}'::text[]),
  ('ng-so-wamako', 'ng-so', 'Wamako', '{}'::text[]),
  ('ng-so-wurno', 'ng-so', 'Wurno', '{}'::text[]),
  ('ng-so-yabo', 'ng-so', 'Yabo', '{}'::text[]),
  ('ng-ta-ardo-kola', 'ng-ta', 'Ardo Kola', '{}'::text[]),
  ('ng-ta-bali', 'ng-ta', 'Bali', '{}'::text[]),
  ('ng-ta-donga', 'ng-ta', 'Donga', '{}'::text[]),
  ('ng-ta-gashaka', 'ng-ta', 'Gashaka', '{}'::text[]),
  ('ng-ta-gassol', 'ng-ta', 'Gassol', '{}'::text[]),
  ('ng-ta-ibi', 'ng-ta', 'Ibi', '{}'::text[]),
  ('ng-ta-jalingo', 'ng-ta', 'Jalingo', '{}'::text[]),
  ('ng-ta-karim-lamido', 'ng-ta', 'Karim Lamido', '{}'::text[]),
  ('ng-ta-kurmi', 'ng-ta', 'Kurmi', '{}'::text[]),
  ('ng-ta-lau', 'ng-ta', 'Lau', '{}'::text[]),
  ('ng-ta-sardauna', 'ng-ta', 'Sardauna', '{}'::text[]),
  ('ng-ta-takum', 'ng-ta', 'Takum', '{}'::text[]),
  ('ng-ta-ussa', 'ng-ta', 'Ussa', '{}'::text[]),
  ('ng-ta-wukari', 'ng-ta', 'Wukari', '{}'::text[]),
  ('ng-ta-yorro', 'ng-ta', 'Yorro', '{}'::text[]),
  ('ng-ta-zing', 'ng-ta', 'Zing', '{}'::text[]),
  ('ng-yo-bade', 'ng-yo', 'Bade', '{}'::text[]),
  ('ng-yo-bursari', 'ng-yo', 'Bursari', '{}'::text[]),
  ('ng-yo-damaturu', 'ng-yo', 'Damaturu', '{}'::text[]),
  ('ng-yo-fika', 'ng-yo', 'Fika', '{}'::text[]),
  ('ng-yo-fune', 'ng-yo', 'Fune', '{}'::text[]),
  ('ng-yo-geidam', 'ng-yo', 'Geidam', '{}'::text[]),
  ('ng-yo-gujba', 'ng-yo', 'Gujba', '{}'::text[]),
  ('ng-yo-gulani', 'ng-yo', 'Gulani', '{}'::text[]),
  ('ng-yo-jakusko', 'ng-yo', 'Jakusko', '{}'::text[]),
  ('ng-yo-karasuwa', 'ng-yo', 'Karasuwa', '{}'::text[]),
  ('ng-yo-machina', 'ng-yo', 'Machina', '{}'::text[]),
  ('ng-yo-nangere', 'ng-yo', 'Nangere', '{}'::text[]),
  ('ng-yo-nguru', 'ng-yo', 'Nguru', '{}'::text[]),
  ('ng-yo-potiskum', 'ng-yo', 'Potiskum', '{}'::text[]),
  ('ng-yo-tarmuwa', 'ng-yo', 'Tarmuwa', '{}'::text[]),
  ('ng-yo-yunusari', 'ng-yo', 'Yunusari', '{}'::text[]),
  ('ng-yo-yusufari', 'ng-yo', 'Yusufari', '{}'::text[]),
  ('ng-za-anka', 'ng-za', 'Anka', '{}'::text[]),
  ('ng-za-bakura', 'ng-za', 'Bakura', '{}'::text[]),
  ('ng-za-birnin-magaji-kiyaw', 'ng-za', 'Birnin Magaji/Kiyaw', '{}'::text[]),
  ('ng-za-bukkuyum', 'ng-za', 'Bukkuyum', '{}'::text[]),
  ('ng-za-bungudu', 'ng-za', 'Bungudu', '{}'::text[]),
  ('ng-za-gummi', 'ng-za', 'Gummi', '{}'::text[]),
  ('ng-za-gusau', 'ng-za', 'Gusau', '{}'::text[]),
  ('ng-za-kaura-namoda', 'ng-za', 'Kaura Namoda', '{}'::text[]),
  ('ng-za-maradun', 'ng-za', 'Maradun', '{}'::text[]),
  ('ng-za-maru', 'ng-za', 'Maru', '{}'::text[]),
  ('ng-za-shinkafi', 'ng-za', 'Shinkafi', '{}'::text[]),
  ('ng-za-talata-mafara', 'ng-za', 'Talata Mafara', '{}'::text[]),
  ('ng-za-tsafe', 'ng-za', 'Tsafe', '{}'::text[]),
  ('ng-za-zurmi', 'ng-za', 'Zurmi', '{}'::text[])
on conflict (id) do update set state_id = excluded.state_id, name = excluded.name, adjacent_ids = excluded.adjacent_ids;

insert into public.neighbourhoods (id, lga_id, name, aliases) values
  ('ng-oy-ibadan-north-bodija', 'ng-oy-ibadan-north', 'Bodija', '{}'::text[]),
  ('ng-oy-ibadan-north-agbowo', 'ng-oy-ibadan-north', 'Agbowo', '{}'::text[]),
  ('ng-oy-ibadan-north-mokola', 'ng-oy-ibadan-north', 'Mokola', '{}'::text[]),
  ('ng-oy-ibadan-north-university-of-ibadan', 'ng-oy-ibadan-north', 'University of Ibadan', array['UI']),
  ('ng-la-surulere-ojuelegba', 'ng-la-surulere', 'Ojuelegba', '{}'::text[]),
  ('ng-la-surulere-bode-thomas', 'ng-la-surulere', 'Bode Thomas', '{}'::text[]),
  ('ng-la-surulere-aguda', 'ng-la-surulere', 'Aguda', '{}'::text[]),
  ('ng-la-surulere-itire', 'ng-la-surulere', 'Itire', '{}'::text[]),
  ('ng-la-surulere-adeniran-ogunsanya', 'ng-la-surulere', 'Adeniran Ogunsanya', '{}'::text[]),
  ('ng-la-ikeja-allen-avenue', 'ng-la-ikeja', 'Allen Avenue', '{}'::text[]),
  ('ng-la-ikeja-opebi', 'ng-la-ikeja', 'Opebi', '{}'::text[]),
  ('ng-la-ikeja-oregun', 'ng-la-ikeja', 'Oregun', '{}'::text[]),
  ('ng-la-ikeja-maryland', 'ng-la-ikeja', 'Maryland', '{}'::text[]),
  ('ng-la-ikeja-agidingbi', 'ng-la-ikeja', 'Agidingbi', '{}'::text[]),
  ('ng-la-ikeja-ogba', 'ng-la-ikeja', 'Ogba', '{}'::text[]),
  ('ng-la-eti-osa-lekki-phase-1', 'ng-la-eti-osa', 'Lekki Phase 1', array['Lekki']),
  ('ng-la-eti-osa-victoria-island', 'ng-la-eti-osa', 'Victoria Island', array['VI']),
  ('ng-la-eti-osa-ikoyi', 'ng-la-eti-osa', 'Ikoyi', '{}'::text[]),
  ('ng-la-eti-osa-ajah', 'ng-la-eti-osa', 'Ajah', '{}'::text[]),
  ('ng-la-eti-osa-sangotedo', 'ng-la-eti-osa', 'Sangotedo', '{}'::text[]),
  ('ng-la-eti-osa-chevron-drive', 'ng-la-eti-osa', 'Chevron Drive', '{}'::text[]),
  ('ng-fc-abuja-municipal-amac-wuse-2', 'ng-fc-abuja-municipal-amac', 'Wuse 2', array['Wuse']),
  ('ng-fc-abuja-municipal-amac-garki', 'ng-fc-abuja-municipal-amac', 'Garki', '{}'::text[]),
  ('ng-fc-abuja-municipal-amac-maitama', 'ng-fc-abuja-municipal-amac', 'Maitama', '{}'::text[]),
  ('ng-fc-abuja-municipal-amac-asokoro', 'ng-fc-abuja-municipal-amac', 'Asokoro', '{}'::text[]),
  ('ng-fc-abuja-municipal-amac-gwarinpa', 'ng-fc-abuja-municipal-amac', 'Gwarinpa', '{}'::text[]),
  ('ng-fc-abuja-municipal-amac-kubwa', 'ng-fc-abuja-municipal-amac', 'Kubwa', '{}'::text[])
on conflict (id) do update set lga_id = excluded.lga_id, name = excluded.name, aliases = excluded.aliases;


insert into public.categories (id, parent_id, name, description, synonyms, kind, sort_order) values
  ('construction-building', null, 'Construction & Building', 'Builders, masons and finishing trades', array['construction', 'builder', 'building', 'site work'], 'service', 0),
  ('bricklaying', 'construction-building', 'Bricklaying & Masonry', 'Bricklayers and masons for walls, blocks and plastering', array['bricklayer', 'mason', 'blockwork', 'plaster'], 'service', 1),
  ('concrete', 'construction-building', 'Concrete & Blockwork', 'Concrete casting, foundations and block moulding', array['concrete', 'foundation', 'casting'], 'service', 2),
  ('roofing', 'construction-building', 'Roofing', 'Roof installation, repairs and waterproofing', array['roofer', 'roof', 'aluminium roof', 'stone coated'], 'service', 3),
  ('tiling', 'construction-building', 'Tiling & Flooring', 'Floor and wall tiles, marble and terrazzo', array['tiler', 'tiles', 'flooring', 'marble'], 'service', 4),
  ('welding', 'construction-building', 'Welding & Metalwork', 'Gates, railings, burglar bars and metal fabrication', array['welder', 'gate', 'railing', 'metal work'], 'service', 5),
  ('aluminium-glass', 'construction-building', 'Aluminium & Glass', 'Windows, sliding doors, mirrors and glass fittings', array['aluminium', 'glass', 'window', 'sliding door'], 'service', 6),
  ('building-engineer', 'construction-building', 'Building Engineers', 'Structural and civil engineering support', array['engineer', 'structural', 'civil engineer'], 'service', 7),
  ('surveying', 'construction-building', 'Land Surveying', 'Land measurement, demarcation and survey plans', array['surveyor', 'land survey', 'demarcation'], 'service', 8),
  ('home-repairs', null, 'Home Repairs & Maintenance', 'Plumbers, electricians and repair technicians', array['repair', 'maintenance', 'handyman', 'home service'], 'service', 9),
  ('plumbing', 'home-repairs', 'Plumbing', 'Leaks, pipes, pumps and water systems', array['plumber', 'pipe', 'leak', 'water', 'borehole', 'tap', 'tank'], 'service', 10),
  ('electrical', 'home-repairs', 'Electrical', 'Wiring, repairs, inverters and solar', array['electrician', 'wiring', 'socket', 'light', 'generator', 'inverter', 'solar', 'meter'], 'service', 11),
  ('painting', 'home-repairs', 'Painting & Finishing', 'Interior and exterior painting, POP and screeding', array['painter', 'paint', 'pop', 'screeding'], 'service', 12),
  ('ac-technician', 'home-repairs', 'AC & Refrigeration', 'Air-conditioner, fridge and freezer repairs', array['ac', 'air conditioner', 'fridge', 'freezer'], 'service', 13),
  ('generator-technician', 'home-repairs', 'Generator & Inverter', 'Generator servicing, repairs and inverter installation', array['generator', 'inverter', 'gen mechanic'], 'service', 14),
  ('appliance-repair', 'home-repairs', 'Appliance Repair', 'Washing machines, microwaves and home appliances', array['appliance', 'washing machine', 'microwave'], 'service', 15),
  ('solar-installation', 'home-repairs', 'Solar Installation', 'Solar panels, batteries and off-grid systems', array['solar', 'panel', 'battery', 'inverter'], 'service', 16),
  ('handyman', 'home-repairs', 'Handyman', 'Small repairs, fittings and odd jobs', array['handyman', 'odd jobs', 'repairs'], 'service', 17),
  ('fashion-tailoring', null, 'Fashion & Tailoring', 'Tailors, designers and footwear makers', array['fashion', 'tailor', 'sewing', 'clothing'], 'service', 18),
  ('tailoring', 'fashion-tailoring', 'Tailoring & Seamstress', 'Tailors, seamstresses and custom clothing', array['tailor', 'seamstress', 'fashion designer', 'sewing', 'agbada', 'ankara', 'dress', 'kaftan'], 'service', 19),
  ('fashion-designer', 'fashion-tailoring', 'Fashion Designers', 'Bespoke designs, bridal and ready-to-wear', array['designer', 'bridal', 'bespoke', 'ready to wear'], 'service', 20),
  ('shoemaker', 'fashion-tailoring', 'Shoemakers', 'Custom shoes, sandals and shoe repairs', array['shoe', 'cobbler', 'sandal', 'footwear'], 'service', 21),
  ('wig-maker', 'fashion-tailoring', 'Wig Makers', 'Wig construction, styling and revamping', array['wig', 'hair vendor', 'frontal'], 'service', 22),
  ('embroidery', 'fashion-tailoring', 'Embroidery & Beading', 'Machine embroidery, beading and applique', array['embroidery', 'beading', 'applique'], 'service', 23),
  ('fashion', 'fashion-tailoring', 'Fashion & Accessories', 'Ready-to-wear, bags and accessories', array['fashion', 'clothes', 'boutique', 'accessories', 'bags', 'shoes', 'jewellery', 'jewelry'], 'service', 24),
  ('beauty-personal-care', null, 'Beauty & Personal Care', 'Barbers, hairdressers, makeup and nails', array['beauty', 'grooming', 'personal care'], 'service', 25),
  ('barber', 'beauty-personal-care', 'Barbers', 'Haircuts, shaving and beard grooming', array['barber', 'haircut', 'shave', 'beard'], 'service', 26),
  ('hairdresser', 'beauty-personal-care', 'Hairdressers', 'Braids, weaves, styling and treatments', array['hairdresser', 'braids', 'weave', 'stylist'], 'service', 27),
  ('hair-makeup', 'beauty-personal-care', 'Hair & Makeup', 'Hair styling, bridal and event makeup', array['makeup', 'makeup artist', 'hair', 'hairstylist', 'gele', 'braids', 'beauty', 'bridal'], 'service', 28),
  ('makeup-artist', 'beauty-personal-care', 'Makeup Artists', 'Bridal, editorial and event makeup', array['mua', 'makeup', 'bridal makeup'], 'service', 29),
  ('nail-technician', 'beauty-personal-care', 'Nail Technicians', 'Manicure, pedicure, gel and acrylic nails', array['nails', 'manicure', 'pedicure', 'gel'], 'service', 30),
  ('spa-massage', 'beauty-personal-care', 'Spa & Massage', 'Massage, spa treatments and wellness', array['spa', 'massage', 'wellness'], 'service', 31),
  ('skincare', 'beauty-personal-care', 'Skincare Specialists', 'Facials, skincare consultations and treatments', array['skincare', 'facial', 'skin'], 'service', 32),
  ('automotive-services', null, 'Automotive Services', 'Mechanics, auto electricians and car care', array['car', 'automobile', 'vehicle', 'auto'], 'service', 33),
  ('mechanic', 'automotive-services', 'Mechanics', 'Engine, suspension and general car repairs', array['mechanic', 'engine', 'car repair', 'suspension'], 'service', 34),
  ('auto-electrician', 'automotive-services', 'Auto Electricians', 'Car wiring, batteries and electrical faults', array['auto electrician', 'car wiring', 'battery'], 'service', 35),
  ('vulcanizer', 'automotive-services', 'Vulcanizers', 'Tyre repairs, balancing and inflation', array['vulcanizer', 'tyre', 'tire', 'wheel'], 'service', 36),
  ('panel-beater', 'automotive-services', 'Panel Beaters', 'Body repairs, dent removal and spraying', array['panel beater', 'body work', 'dent', 'spray'], 'service', 37),
  ('car-wash', 'automotive-services', 'Car Wash & Detailing', 'Washing, polishing and interior detailing', array['car wash', 'detailing', 'polish'], 'service', 38),
  ('auto-painter', 'automotive-services', 'Auto Painters', 'Car painting and colour matching', array['auto paint', 'car paint', 'spray painter'], 'service', 39),
  ('wheel-alignment', 'automotive-services', 'Wheel Alignment', 'Alignment, balancing and suspension checks', array['alignment', 'balancing', 'wheel'], 'service', 40),
  ('technology-electronics', null, 'Technology & Electronics', 'Phone, laptop and IT support', array['tech', 'electronics', 'gadget', 'it'], 'service', 41),
  ('phone-repair', 'technology-electronics', 'Phone Repairers', 'Screen replacement, battery and software repairs', array['phone repair', 'screen', 'battery', 'iphone', 'android'], 'service', 42),
  ('laptop-repair', 'technology-electronics', 'Laptop & Computer Repair', 'Laptop repairs, upgrades and data recovery', array['laptop', 'computer', 'repair', 'data recovery'], 'service', 43),
  ('it-technician', 'technology-electronics', 'IT Technicians', 'Computer setup, networking and support', array['it', 'technician', 'support'], 'service', 44),
  ('web-developer', 'technology-electronics', 'Web Developers', 'Websites, e-commerce and landing pages', array['website', 'web', 'developer', 'ecommerce'], 'service', 45),
  ('app-developer', 'technology-electronics', 'App Developers', 'Mobile apps and software products', array['app', 'mobile app', 'software'], 'service', 46),
  ('cctv-installer', 'technology-electronics', 'CCTV & Security', 'CCTV, alarms and access control', array['cctv', 'camera', 'security', 'alarm'], 'service', 47),
  ('network-engineer', 'technology-electronics', 'Network Engineers', 'Wi-Fi, cabling and network setup', array['network', 'wifi', 'cabling'], 'service', 48),
  ('furniture-woodwork', null, 'Furniture & Woodwork', 'Furniture makers, carpenters and upholsterers', array['furniture', 'wood', 'woodwork'], 'service', 49),
  ('carpentry', 'furniture-woodwork', 'Carpentry', 'Furniture, fittings and woodwork', array['carpenter', 'furniture', 'wood', 'cabinet', 'wardrobe', 'bed', 'table', 'kitchen cabinet'], 'service', 50),
  ('furniture-maker', 'furniture-woodwork', 'Furniture Makers', 'Custom sofas, beds, tables and wardrobes', array['furniture', 'sofa', 'bed', 'table', 'wardrobe'], 'service', 51),
  ('upholsterer', 'furniture-woodwork', 'Upholsterers', 'Sofa upholstery, cushions and re-covering', array['upholstery', 'sofa', 'cushion'], 'service', 52),
  ('cabinet-maker', 'furniture-woodwork', 'Cabinet Makers', 'Kitchen cabinets, wardrobes and storage', array['cabinet', 'kitchen', 'wardrobe', 'storage'], 'service', 53),
  ('wood-carver', 'furniture-woodwork', 'Wood Carvers', 'Carved doors, panels and decorative wood', array['carving', 'wood carving', 'door'], 'service', 54),
  ('interior-decorator', 'furniture-woodwork', 'Interior Decorators', 'Interior styling, curtains and space planning', array['interior', 'decor', 'curtain', 'styling'], 'service', 55),
  ('cleaning-domestic', null, 'Cleaning & Domestic Services', 'Cleaners, laundry, gardeners and pest control', array['cleaning', 'domestic', 'home service'], 'service', 56),
  ('home-cleaner', 'cleaning-domestic', 'Home Cleaners', 'Deep cleaning, move-in and move-out cleaning', array['cleaner', 'deep clean', 'house cleaning'], 'service', 57),
  ('laundry', 'cleaning-domestic', 'Laundry & Dry Cleaning', 'Wash, ironing, dry cleaning and pickup', array['laundry', 'dry cleaning', 'ironing', 'wash'], 'service', 58),
  ('gardener', 'cleaning-domestic', 'Gardeners', 'Lawn care, pruning and garden maintenance', array['gardener', 'lawn', 'pruning'], 'service', 59),
  ('pest-control', 'cleaning-domestic', 'Pest Control', 'Rats, cockroaches, termites and bedbugs', array['pest', 'fumigation', 'termite', 'cockroach', 'rat'], 'service', 60),
  ('fumigation', 'cleaning-domestic', 'Fumigation', 'Fumigation and disinfection services', array['fumigation', 'disinfection', 'sanitise'], 'service', 61),
  ('office-cleaning', 'cleaning-domestic', 'Office Cleaning', 'Office, shop and commercial cleaning', array['office cleaning', 'commercial cleaning'], 'service', 62),
  ('pool-cleaning', 'cleaning-domestic', 'Pool Cleaning', 'Swimming pool cleaning and maintenance', array['pool', 'swimming pool'], 'service', 63),
  ('food-catering', null, 'Food & Catering', 'Caterers, bakers and food vendors', array['food', 'catering', 'kitchen'], 'service', 64),
  ('caterer', 'food-catering', 'Caterers', 'Event catering, buffets and bulk meals', array['caterer', 'catering', 'buffet', 'event food'], 'service', 65),
  ('baker', 'food-catering', 'Bakers', 'Bread, pastries and baked goods', array['baker', 'bread', 'pastry'], 'service', 66),
  ('cake-maker', 'food-catering', 'Cake Makers', 'Birthday, wedding and custom cakes', array['cake', 'wedding cake', 'birthday cake'], 'service', 67),
  ('small-chops', 'food-catering', 'Small Chops Vendors', 'Small chops, snacks and party packs', array['small chops', 'snacks', 'puff puff', 'samosa'], 'service', 68),
  ('food-vendor', 'food-catering', 'Food Vendors', 'Local meals, lunch packs and daily food', array['food vendor', 'lunch', 'local food', 'mama put'], 'service', 69),
  ('private-chef', 'food-catering', 'Private Chefs', 'Private dining, meal prep and home chefs', array['private chef', 'meal prep', 'chef'], 'service', 70),
  ('bartender', 'food-catering', 'Event Bartenders', 'Cocktails, drinks and event bar service', array['bartender', 'cocktail', 'drinks'], 'service', 71),
  ('events-creative', null, 'Events & Creative Services', 'Photographers, decorators, DJs and designers', array['event', 'creative', 'media'], 'service', 72),
  ('photographer', 'events-creative', 'Photographers', 'Events, portraits, product and lifestyle photography', array['photographer', 'photo', 'portrait', 'product shoot'], 'service', 73),
  ('videographer', 'events-creative', 'Videographers', 'Event coverage, music videos and video editing', array['videographer', 'video', 'coverage', 'editing'], 'service', 74),
  ('decorator', 'events-creative', 'Decorators', 'Event decor, rentals and styling', array['decorator', 'event decor', 'rentals', 'styling'], 'service', 75),
  ('dj', 'events-creative', 'DJs', 'Parties, weddings and event DJs', array['dj', 'disc jockey', 'music'], 'service', 76),
  ('graphic-designer', 'events-creative', 'Graphic Designers', 'Logos, flyers, branding and social media design', array['graphic designer', 'logo', 'flyer', 'branding'], 'service', 77),
  ('printer', 'events-creative', 'Printers', 'Flyers, banners, shirts and large format printing', array['printer', 'printing', 'banner', 'flyer'], 'service', 78),
  ('event-planner', 'events-creative', 'Event Planners', 'Wedding, birthday and corporate event planning', array['event planner', 'wedding planner', 'planner'], 'service', 79),
  ('mc', 'events-creative', 'MCs & Hosts', 'Event hosts, MCs and anchors', array['mc', 'host', 'anchor'], 'service', 80),
  ('sound-engineer', 'events-creative', 'Sound Engineers', 'Sound setup, mixing and live audio', array['sound', 'audio', 'mixer'], 'service', 81),
  ('florist', 'events-creative', 'Florists', 'Flowers, bouquets and event florals', array['florist', 'flowers', 'bouquet'], 'service', 82),
  ('crafts-handmade', null, 'Crafts & Handmade Products', 'Jewellery, beadwork, leather and candles', array['craft', 'handmade', 'artisan'], 'service', 83),
  ('jewellery-maker', 'crafts-handmade', 'Jewellery Makers', 'Custom jewellery, repairs and precious stones', array['jewellery', 'jewelry', 'jeweller', 'gold', 'silver'], 'service', 84),
  ('bead-maker', 'crafts-handmade', 'Bead Makers', 'Beaded jewellery, waist beads and accessories', array['beads', 'beadwork', 'waist beads'], 'service', 85),
  ('leatherworker', 'crafts-handmade', 'Leatherworkers', 'Leather bags, belts, sandals and wallets', array['leather', 'bag', 'belt', 'wallet'], 'service', 86),
  ('candle-maker', 'crafts-handmade', 'Candle Makers', 'Scented candles, wax melts and gifts', array['candle', 'wax', 'scented'], 'service', 87),
  ('soap-maker', 'crafts-handmade', 'Soap Makers', 'Handmade soap, body butter and natural care', array['soap', 'body butter', 'natural'], 'service', 88),
  ('pottery', 'crafts-handmade', 'Pottery & Ceramics', 'Handmade pottery, ceramics and clay work', array['pottery', 'ceramics', 'clay'], 'service', 89),
  ('crochet', 'crafts-handmade', 'Crochet & Knitting', 'Crochet, knitting and handmade textiles', array['crochet', 'knitting', 'yarn'], 'service', 90),
  ('agriculture-outdoor', null, 'Agriculture & Outdoor Services', 'Farmers, landscapers and irrigation', array['agriculture', 'farm', 'outdoor'], 'service', 91),
  ('farmer', 'agriculture-outdoor', 'Farmers', 'Crop farming, produce and farm services', array['farmer', 'crop', 'farm', 'produce'], 'service', 92),
  ('fish-farmer', 'agriculture-outdoor', 'Fish Farmers', 'Catfish, tilapia and fish farming', array['fish', 'catfish', 'aquaculture'], 'service', 93),
  ('poultry', 'agriculture-outdoor', 'Poultry Farmers', 'Chicken, eggs and poultry supplies', array['poultry', 'chicken', 'eggs'], 'service', 94),
  ('landscaper', 'agriculture-outdoor', 'Landscapers', 'Landscaping, lawns and outdoor design', array['landscaper', 'landscaping', 'lawn'], 'service', 95),
  ('irrigation', 'agriculture-outdoor', 'Irrigation Technicians', 'Irrigation systems, pumps and water management', array['irrigation', 'pump', 'water system'], 'service', 96),
  ('agro-consultant', 'agriculture-outdoor', 'Agro Consultants', 'Farm planning, soil and agribusiness advice', array['agro', 'consultant', 'soil', 'farm advice'], 'service', 97),
  ('tree-felling', 'agriculture-outdoor', 'Tree Felling', 'Tree cutting, pruning and stump removal', array['tree felling', 'tree cutting', 'stump'], 'service', 98),
  ('moving-delivery', null, 'Moving & Delivery', 'Movers, dispatch riders and logistics', array['moving', 'delivery', 'logistics'], 'service', 99),
  ('mover', 'moving-delivery', 'Movers', 'House, office and furniture moving', array['mover', 'moving', 'relocation'], 'service', 100),
  ('dispatch-rider', 'moving-delivery', 'Dispatch Riders', 'Same-day dispatch and errand delivery', array['dispatch', 'rider', 'errand', 'same day'], 'service', 101),
  ('delivery', 'moving-delivery', 'Delivery Providers', 'Parcel, food and bulk delivery', array['delivery', 'parcel', 'courier'], 'service', 102),
  ('logistics', 'moving-delivery', 'Logistics Companies', 'Haulage, freight and supply chain', array['logistics', 'haulage', 'freight'], 'service', 103),
  ('truck-hire', 'moving-delivery', 'Truck Hire', 'Trucks, vans and construction haulage', array['truck', 'van', 'hire'], 'service', 104),
  ('packing', 'moving-delivery', 'Packing Services', 'Packing, wrapping and unpacking', array['packing', 'wrapping', 'unpacking'], 'service', 105),
  ('tutoring-skills', null, 'Tutoring & Skilled Services', 'Tutors, instructors and exam prep', array['tutor', 'lesson', 'training', 'instructor'], 'service', 106),
  ('private-tutor', 'tutoring-skills', 'Private Tutors', 'Home and online tutoring for school subjects', array['tutor', 'lesson', 'home tutor', 'school'], 'service', 107),
  ('music-instructor', 'tutoring-skills', 'Music Instructors', 'Piano, guitar, drums and voice lessons', array['music', 'piano', 'guitar', 'drums', 'voice'], 'service', 108),
  ('sewing-instructor', 'tutoring-skills', 'Sewing Instructors', 'Tailoring and fashion design training', array['sewing', 'tailoring school', 'fashion training'], 'service', 109),
  ('language-tutor', 'tutoring-skills', 'Language Tutors', 'English, French, Yoruba, Igbo and Hausa', array['language', 'english', 'french', 'yoruba', 'igbo'], 'service', 110),
  ('exam-prep', 'tutoring-skills', 'Exam Prep', 'JAMB, WAEC, NECO and IELTS preparation', array['jamb', 'waec', 'neco', 'ielts', 'exam'], 'service', 111),
  ('coding-instructor', 'tutoring-skills', 'Coding Instructors', 'Coding, robotics and digital skills for children', array['coding', 'programming', 'robotics', 'digital skills'], 'service', 112),
  ('driving-instructor', 'tutoring-skills', 'Driving Instructors', 'Driving lessons and licence preparation', array['driving', 'driving school', 'licence'], 'service', 113),
  ('products-fashion', null, 'Ready-made Clothing & Fashion', 'Clothes, shoes, bags and accessories', array['clothing', 'fashion', 'shoes', 'bags'], 'product', 114),
  ('product-clothing', 'products-fashion', 'Clothing', 'Ready-to-wear clothes for men, women and children', array['clothes', 'dress', 'shirt', 'trouser'], 'product', 115),
  ('product-shoes', 'products-fashion', 'Shoes & Bags', 'Shoes, sandals, bags and purses', array['shoes', 'bags', 'sandals', 'purse'], 'product', 116),
  ('product-accessories', 'products-fashion', 'Accessories', 'Belts, watches, jewellery and fashion accessories', array['accessories', 'watch', 'belt', 'jewellery'], 'product', 117),
  ('products-furniture', null, 'Furniture & Home Decor', 'Furniture, decor and home textiles', array['furniture', 'decor', 'home'], 'product', 118),
  ('product-furniture', 'products-furniture', 'Furniture', 'Sofas, beds, tables and storage', array['sofa', 'bed', 'table', 'chair'], 'product', 119),
  ('product-decor', 'products-furniture', 'Home Decor', 'Vases, wall art, mirrors and decor pieces', array['decor', 'vase', 'mirror', 'wall art'], 'product', 120),
  ('product-bedding', 'products-furniture', 'Bedding & Textiles', 'Bedsheets, curtains, towels and pillows', array['bedsheet', 'curtain', 'towel', 'pillow'], 'product', 121),
  ('products-crafts', null, 'Handmade Crafts', 'Jewellery, beadwork, leather and candles', array['crafts', 'handmade', 'artisan'], 'product', 122),
  ('product-jewellery', 'products-crafts', 'Jewellery', 'Handmade and fine jewellery', array['jewellery', 'jewelry', 'necklace', 'earrings'], 'product', 123),
  ('product-beadwork', 'products-crafts', 'Beadwork', 'Beaded bags, waist beads and accessories', array['beads', 'beadwork', 'waist beads'], 'product', 124),
  ('product-leather', 'products-crafts', 'Leather Goods', 'Leather bags, belts, wallets and sandals', array['leather', 'bag', 'belt', 'wallet'], 'product', 125),
  ('product-candles', 'products-crafts', 'Candles & Soaps', 'Scented candles, soaps and body care', array['candle', 'soap', 'body butter'], 'product', 126),
  ('products-food', null, 'Food & Beverages', 'Packaged food, bakery and drinks', array['food', 'beverages', 'drinks'], 'product', 127),
  ('product-food', 'products-food', 'Packaged Food', 'Spices, sauces, snacks and packaged meals', array['food', 'spices', 'sauce', 'snacks'], 'product', 128),
  ('product-bakery', 'products-food', 'Bakery & Confectionery', 'Bread, cakes, pastries and sweets', array['bakery', 'bread', 'cake', 'pastry'], 'product', 129),
  ('product-drinks', 'products-food', 'Drinks', 'Juices, zobo, palm wine and soft drinks', array['drinks', 'juice', 'zobo', 'wine'], 'product', 130),
  ('products-beauty', null, 'Beauty & Personal Care Products', 'Skincare, haircare and cosmetics', array['beauty products', 'skincare', 'cosmetics'], 'product', 131),
  ('product-skincare', 'products-beauty', 'Skincare', 'Creams, oils, serums and natural skincare', array['skincare', 'cream', 'oil', 'serum'], 'product', 132),
  ('product-haircare', 'products-beauty', 'Haircare', 'Shampoo, conditioner, oils and hair products', array['haircare', 'shampoo', 'conditioner'], 'product', 133),
  ('product-cosmetics', 'products-beauty', 'Cosmetics', 'Makeup, lashes and beauty tools', array['makeup', 'cosmetics', 'lashes'], 'product', 134),
  ('products-electronics', null, 'Electronics & Gadgets', 'Phones, computers and gadgets', array['electronics', 'gadgets', 'phones'], 'product', 135),
  ('product-phones', 'products-electronics', 'Phones & Accessories', 'Phones, chargers, cases and screen protectors', array['phone', 'charger', 'case'], 'product', 136),
  ('product-computers', 'products-electronics', 'Computers', 'Laptops, desktops and computer accessories', array['laptop', 'computer', 'desktop'], 'product', 137),
  ('product-gadgets', 'products-electronics', 'Gadgets', 'Smart watches, speakers and small electronics', array['gadget', 'watch', 'speaker'], 'product', 138),
  ('products-building', null, 'Building Materials', 'Tiles, paint, hardware and fittings', array['building materials', 'hardware'], 'product', 139),
  ('product-tiles', 'products-building', 'Tiles', 'Floor tiles, wall tiles and marble', array['tiles', 'marble', 'floor'], 'product', 140),
  ('product-paint', 'products-building', 'Paint', 'Emulsion, gloss, texture and painting tools', array['paint', 'emulsion', 'gloss'], 'product', 141),
  ('product-hardware', 'products-building', 'Hardware', 'Doors, locks, pipes, tools and fittings', array['hardware', 'lock', 'pipe', 'tools'], 'product', 142),
  ('products-agriculture', null, 'Agricultural Products', 'Fresh produce, grains and livestock', array['agriculture', 'farm produce'], 'product', 143),
  ('product-produce', 'products-agriculture', 'Fresh Produce', 'Vegetables, fruits and fresh farm produce', array['vegetables', 'fruits', 'produce'], 'product', 144),
  ('product-grains', 'products-agriculture', 'Grains & Tubers', 'Rice, beans, yam, garri and grains', array['rice', 'beans', 'yam', 'garri', 'grains'], 'product', 145),
  ('product-livestock', 'products-agriculture', 'Livestock & Poultry', 'Chicken, eggs, fish and livestock', array['chicken', 'eggs', 'fish', 'livestock'], 'product', 146),
  ('products-art', null, 'Art & Prints', 'Paintings, prints and framing', array['art', 'prints', 'painting'], 'product', 147),
  ('product-art', 'products-art', 'Art', 'Paintings, sculptures and original art', array['painting', 'sculpture', 'art'], 'product', 148),
  ('product-prints', 'products-art', 'Prints & Framing', 'Posters, prints and picture framing', array['print', 'poster', 'frame'], 'product', 149),
  ('products-baby', null, 'Baby & Kids', 'Clothing, toys and baby essentials', array['baby', 'kids', 'children'], 'product', 150),
  ('product-baby-clothing', 'products-baby', 'Baby Clothing', 'Baby clothes, shoes and accessories', array['baby clothes', 'baby shoes'], 'product', 151),
  ('product-toys', 'products-baby', 'Toys', 'Educational toys, games and play items', array['toys', 'games', 'educational'], 'product', 152),
  ('products-auto', null, 'Automotive Parts', 'Car parts, tyres and accessories', array['auto parts', 'car parts'], 'product', 153),
  ('product-auto-parts', 'products-auto', 'Auto Parts', 'Engine parts, batteries and car accessories', array['auto parts', 'battery', 'engine'], 'product', 154),
  ('product-tyres', 'products-auto', 'Tyres & Wheels', 'Tyres, rims and wheel accessories', array['tyres', 'tires', 'rims', 'wheels'], 'product', 155)
on conflict (id) do update set parent_id = excluded.parent_id, name = excluded.name, description = excluded.description, synonyms = excluded.synonyms, kind = excluded.kind, sort_order = excluded.sort_order;


-- ---------------------------------------------------------------------------
-- Source: supabase\migrations\20261027000200_storage_buckets.sql
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Storage buckets for owner, business and listing photos.
--
-- Paths are owner-scoped:
--   profile-photos/<auth.uid()>/<file>
--   business-photos/<business_id>/<file>
--   listing-photos/<business_id>/<listing_id>/<file>
--
-- Public read keeps marketplace photos cacheable. Writes are limited to the
-- authenticated owner of the profile/business.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values
  ('profile-photos', 'profile-photos', true),
  ('business-photos', 'business-photos', true),
  ('listing-photos', 'listing-photos', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Public read marketplace photos" on storage.objects;
create policy "Public read marketplace photos"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id in ('profile-photos', 'business-photos', 'listing-photos'));

drop policy if exists "Owners upload profile photos" on storage.objects;
create policy "Owners upload profile photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners update profile photos" on storage.objects;
create policy "Owners update profile photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners delete profile photos" on storage.objects;
create policy "Owners delete profile photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners upload business photos" on storage.objects;
create policy "Owners upload business photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'business-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owners update business photos" on storage.objects;
create policy "Owners update business photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'business-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'business-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owners delete business photos" on storage.objects;
create policy "Owners delete business photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'business-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owners upload listing photos" on storage.objects;
create policy "Owners upload listing photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'listing-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owners update listing photos" on storage.objects;
create policy "Owners update listing photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'listing-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'listing-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owners delete listing photos" on storage.objects;
create policy "Owners delete listing photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'listing-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );


-- ---------------------------------------------------------------------------
-- Source: supabase\migrations\20261027000300_grants.sql
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Source: supabase\migrations\20261112000000_business_address.sql
-- ---------------------------------------------------------------------------
-- Optional public business address supplied by the owner.
alter table public.businesses
  add column if not exists address text;

comment on column public.businesses.address is
  'Optional public shop/street address supplied by the owner.';

commit;
