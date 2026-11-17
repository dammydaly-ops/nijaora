-- Optional public business address supplied by the owner.
-- Discovery still works from state/LGA/neighbourhood; the address is only
-- displayed when the owner chooses to add it.

alter table public.businesses
  add column if not exists address text;

comment on column public.businesses.address is
  'Optional public shop/street address supplied by the owner.';
