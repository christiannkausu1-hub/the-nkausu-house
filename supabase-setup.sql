-- THE NKAUSU HOUSE — Supabase setup
-- Run once in Supabase SQL Editor for a NEW project. Do not drop existing tables when upgrading.
-- Uses Supabase Auth (auth.users), household membership and Row Level Security.
create extension if not exists pgcrypto;

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 100),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (household_id,user_id),
  -- Each user can belong to one household in this simple household-accounting model.
  unique (user_id)
);

create table if not exists public.household_invitations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  code_hash text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days'),
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  type text not null check (type in ('income','expense')),
  amount numeric(14,2) not null check (amount > 0),
  transaction_date date not null default current_date,
  category text not null check (char_length(trim(category)) between 1 and 80),
  description text not null check (char_length(trim(description)) between 1 and 180),
  notes text check (notes is null or char_length(notes) <= 1000),
  transaction_tags text[] not null default '{}'::text[],
  is_reversed boolean not null default false,
  is_reversal boolean not null default false,
  reversal_of uuid references public.transactions(id) on delete set null,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists transactions_household_date_idx on public.transactions(household_id, transaction_date desc);
create index if not exists transactions_household_type_idx on public.transactions(household_id, type);
create index if not exists household_members_user_idx on public.household_members(user_id);
create index if not exists household_invitations_household_idx on public.household_invitations(household_id, expires_at);

create or replace function public.is_household_member(target_household uuid)
returns boolean language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.household_members hm
    where hm.household_id = target_household and hm.user_id = (select auth.uid())
  );
$$;

create or replace function public.is_household_owner(target_household uuid)
returns boolean language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.household_members hm
    where hm.household_id = target_household and hm.user_id = (select auth.uid()) and hm.role = 'owner'
  );
$$;

revoke all on function public.is_household_member(uuid) from public;
revoke all on function public.is_household_owner(uuid) from public;
grant execute on function public.is_household_member(uuid) to authenticated;
grant execute on function public.is_household_owner(uuid) to authenticated;

create or replace function public.create_household(household_name text)
returns uuid language plpgsql security definer
set search_path = ''
as $$
declare new_household_id uuid;
begin
  if auth.uid() is null then raise exception 'You must sign in first'; end if;
  if exists (select 1 from public.household_members where user_id = auth.uid()) then
    raise exception 'Your account already belongs to a household';
  end if;
  if household_name is null or char_length(trim(household_name)) not between 1 and 100 then
    raise exception 'Household name must be between 1 and 100 characters';
  end if;
  insert into public.households(name,created_by) values (trim(household_name),auth.uid())
    returning id into new_household_id;
  insert into public.household_members(household_id,user_id,role)
    values (new_household_id,auth.uid(),'owner');
  return new_household_id;
end;
$$;

create or replace function public.create_household_invitation()
returns text language plpgsql security definer
set search_path = ''
as $$
declare target_household uuid; raw_code text;
begin
  if auth.uid() is null then raise exception 'You must sign in first'; end if;
  select household_id into target_household from public.household_members
    where user_id = auth.uid() and role = 'owner';
  if target_household is null then raise exception 'Only the household owner can create invitations'; end if;
  raw_code := upper(encode(gen_random_bytes(9),'hex'));
  insert into public.household_invitations(household_id,code_hash,created_by,expires_at)
    values (target_household,encode(digest(raw_code,'sha256'),'hex'),auth.uid(),now()+interval '7 days');
  return raw_code;
end;
$$;

create or replace function public.join_household(invitation_code text)
returns uuid language plpgsql security definer
set search_path = ''
as $$
declare target_household uuid; invite_id uuid;
begin
  if auth.uid() is null then raise exception 'You must sign in first'; end if;
  if exists (select 1 from public.household_members where user_id = auth.uid()) then
    raise exception 'Your account already belongs to a household';
  end if;
  if invitation_code is null or char_length(trim(invitation_code)) < 8 then
    raise exception 'Enter a valid invitation code';
  end if;
  select id, household_id into invite_id,target_household
  from public.household_invitations
  where code_hash = encode(digest(upper(trim(invitation_code)),'sha256'),'hex')
    and used_at is null and expires_at > now()
  for update;
  if invite_id is null then raise exception 'Invitation code is invalid, expired, or already used'; end if;
  insert into public.household_members(household_id,user_id,role)
    values(target_household,auth.uid(),'member');
  update public.household_invitations set used_at = now() where id = invite_id;
  return target_household;
end;
$$;

revoke all on function public.create_household(text) from public;
revoke all on function public.create_household_invitation() from public;
revoke all on function public.join_household(text) from public;
grant execute on function public.create_household(text) to authenticated;
grant execute on function public.create_household_invitation() to authenticated;
grant execute on function public.join_household(text) to authenticated;

create or replace function public.set_transaction_updated_at()
returns trigger language plpgsql set search_path = ''
as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists transactions_set_updated_at on public.transactions;
create trigger transactions_set_updated_at before update on public.transactions
for each row execute function public.set_transaction_updated_at();

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invitations enable row level security;
alter table public.transactions enable row level security;

drop policy if exists "Members can view their household" on public.households;
create policy "Members can view their household" on public.households
for select to authenticated using (public.is_household_member(id));
drop policy if exists "Owners can update household" on public.households;
create policy "Owners can update household" on public.households
for update to authenticated using (public.is_household_owner(id)) with check (public.is_household_owner(id));

drop policy if exists "Members can view household membership" on public.household_members;
create policy "Members can view household membership" on public.household_members
for select to authenticated using (public.is_household_member(household_id));
-- Membership is added only through security-definer household functions; no direct insert/update/delete policies.

drop policy if exists "Owners can view invitations" on public.household_invitations;
create policy "Owners can view invitations" on public.household_invitations
for select to authenticated using (public.is_household_owner(household_id));
-- Invitation rows are only created/consumed through security-definer functions.

drop policy if exists "Members can view household transactions" on public.transactions;
create policy "Members can view household transactions" on public.transactions
for select to authenticated using (public.is_household_member(household_id));
drop policy if exists "Members can add household transactions" on public.transactions;
create policy "Members can add household transactions" on public.transactions
for insert to authenticated with check (
  public.is_household_member(household_id) and created_by = (select auth.uid())
);
drop policy if exists "Members can update household transactions" on public.transactions;
create policy "Members can update household transactions" on public.transactions
for update to authenticated using (public.is_household_member(household_id))
with check (public.is_household_member(household_id) and created_by = (select auth.uid()));
drop policy if exists "Members can delete household transactions" on public.transactions;
create policy "Members can delete household transactions" on public.transactions
for delete to authenticated using (public.is_household_member(household_id));

grant usage on schema public to authenticated;
grant select, update on public.households to authenticated;
grant select on public.household_members, public.household_invitations to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;

-- Optional post-setup verification:
-- select tablename, rowsecurity from pg_tables where schemaname='public'
--   and tablename in ('households','household_members','household_invitations','transactions');
