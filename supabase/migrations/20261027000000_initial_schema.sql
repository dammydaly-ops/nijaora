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
