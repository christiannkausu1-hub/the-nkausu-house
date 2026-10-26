-- THE NKAUSU HOUSE: ADDITIVE UPGRADE MIGRATION
-- Run this in Supabase SQL Editor AFTER the original supabase-setup.sql has already been applied.
-- This migration adds columns/tables and policies only. It does not drop household records.
-- Review this SQL before running it against a production database.

begin;

-- Extend existing transactions without replacing any existing records.
alter table public.transactions add column if not exists payment_method text not null default 'Other';
alter table public.transactions add column if not exists account_name text not null default 'Cash';
alter table public.transactions add column if not exists to_account text;
alter table public.transactions add column if not exists paid_by text not null default 'me';

-- Transfers are movements between accounts, not income or expense. Existing rows remain unchanged.
alter table public.transactions drop constraint if exists transactions_type_check;
alter table public.transactions add constraint transactions_type_check check (type in ('income','expense','transfer'));
alter table public.transactions drop constraint if exists transactions_paid_by_check;
alter table public.transactions add constraint transactions_paid_by_check check (paid_by in ('me','wife','joint'));
alter table public.transactions drop constraint if exists transactions_payment_method_check;
alter table public.transactions add constraint transactions_payment_method_check check (char_length(trim(payment_method)) between 1 and 80);
alter table public.transactions drop constraint if exists transactions_account_name_check;
alter table public.transactions add constraint transactions_account_name_check check (char_length(trim(account_name)) between 1 and 80);

create table if not exists public.household_budgets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  category text not null check (char_length(trim(category)) between 1 and 80),
  month_start date not null,
  limit_amount numeric(14,2) not null check (limit_amount > 0),
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, category, month_start)
);

create table if not exists public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 120),
  target_amount numeric(14,2) not null check (target_amount > 0),
  current_amount numeric(14,2) not null default 0 check (current_amount >= 0),
  target_date date,
  status text not null default 'active' check (status in ('active','completed','paused')),
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.household_debts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  debt_type text not null check (debt_type in ('owed','receivable')),
  original_amount numeric(14,2) not null check (original_amount >= 0),
  outstanding_amount numeric(14,2) not null default 0 check (outstanding_amount >= 0),
  due_date date,
  monthly_payment numeric(14,2) not null default 0 check (monthly_payment >= 0),
  interest_rate numeric(7,3),
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.household_assets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  category text not null check (char_length(trim(category)) between 1 and 80),
  estimated_value numeric(14,2) not null default 0 check (estimated_value >= 0),
  acquired_on date,
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.household_accounts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  account_name text not null check (char_length(trim(account_name)) between 1 and 80),
  opening_balance numeric(14,2) not null default 0,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, account_name)
);

create table if not exists public.household_audit_log (
  id bigint generated always as identity primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  table_name text not null,
  action text not null check (action in ('INSERT','UPDATE','DELETE')),
  record_id text,
  summary text,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists household_budgets_month_idx on public.household_budgets(household_id, month_start desc);
create index if not exists savings_goals_household_idx on public.savings_goals(household_id, created_at desc);
create index if not exists household_debts_household_idx on public.household_debts(household_id, due_date);
create index if not exists household_assets_household_idx on public.household_assets(household_id);
create index if not exists household_audit_household_date_idx on public.household_audit_log(household_id, created_at desc);

-- Shared members can edit any transaction within their own household, not other households.
drop policy if exists "Members can update household transactions" on public.transactions;
create policy "Members can update household transactions" on public.transactions
for update to authenticated
using (public.is_household_member(household_id))
with check (public.is_household_member(household_id) and created_by is not null);

-- Reusable updated_at trigger function already exists in the original setup; add triggers to new tables.
do $$
declare t text;
begin
  foreach t in array array['household_budgets','savings_goals','household_debts','household_assets','household_accounts'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_set_updated_at', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.set_transaction_updated_at()', t || '_set_updated_at', t);
  end loop;
end $$;

-- Audit transactions using a SECURITY DEFINER trigger so the audit record is written even with RLS enabled.
create or replace function public.audit_household_transaction()
returns trigger language plpgsql security definer set search_path = '' as $$
declare oldj jsonb; newj jsonb; hid uuid; rid text; act text; descr text;
begin
  if TG_OP = 'INSERT' then newj := to_jsonb(NEW); hid := NEW.household_id; rid := NEW.id::text; act := 'INSERT'; descr := coalesce(NEW.description, NEW.category, 'Transaction added');
  elsif TG_OP = 'UPDATE' then oldj := to_jsonb(OLD); newj := to_jsonb(NEW); hid := NEW.household_id; rid := NEW.id::text; act := 'UPDATE'; descr := coalesce(NEW.description, NEW.category, 'Transaction updated');
  else oldj := to_jsonb(OLD); hid := OLD.household_id; rid := OLD.id::text; act := 'DELETE'; descr := coalesce(OLD.description, OLD.category, 'Transaction deleted');
  end if;
  insert into public.household_audit_log(household_id,actor_id,table_name,action,record_id,summary,old_data,new_data)
  values (hid, auth.uid(), 'transactions', act, rid, descr, oldj, newj);
  if TG_OP = 'DELETE' then return OLD; else return NEW; end if;
end;
$$;
drop trigger if exists transactions_audit_log on public.transactions;
create trigger transactions_audit_log after insert or update or delete on public.transactions
for each row execute function public.audit_household_transaction();

-- Audit other financial records (budgets, goals, debts and assets) as well.
create or replace function public.audit_household_financial_record()
returns trigger language plpgsql security definer set search_path = '' as $$
declare oldj jsonb; newj jsonb; hid uuid; rid text; act text; descr text;
begin
  if TG_OP = 'INSERT' then newj := to_jsonb(NEW); hid := (newj->>'household_id')::uuid; rid := newj->>'id'; act := 'INSERT';
  elsif TG_OP = 'UPDATE' then oldj := to_jsonb(OLD); newj := to_jsonb(NEW); hid := (newj->>'household_id')::uuid; rid := newj->>'id'; act := 'UPDATE';
  else oldj := to_jsonb(OLD); hid := (oldj->>'household_id')::uuid; rid := oldj->>'id'; act := 'DELETE';
  end if;
  descr := coalesce(newj->>'name', newj->>'title', newj->>'category', oldj->>'name', oldj->>'title', oldj->>'category', TG_TABLE_NAME);
  insert into public.household_audit_log(household_id,actor_id,table_name,action,record_id,summary,old_data,new_data)
  values (hid, auth.uid(), TG_TABLE_NAME, act, rid, descr, oldj, newj);
  if TG_OP = 'DELETE' then return OLD; else return NEW; end if;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['household_budgets','savings_goals','household_debts','household_assets','household_accounts'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_audit_log', t);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.audit_household_financial_record()', t || '_audit_log', t);
  end loop;
end $$;

-- RLS: all access is restricted to members of the matching household.
alter table public.household_budgets enable row level security;
alter table public.savings_goals enable row level security;
alter table public.household_debts enable row level security;
alter table public.household_assets enable row level security;
alter table public.household_accounts enable row level security;
alter table public.household_audit_log enable row level security;

do $$
declare t text;
begin
  foreach t in array array['household_budgets','savings_goals','household_debts','household_assets','household_accounts'] loop
    execute format('drop policy if exists %I on public.%I', 'Members can view ' || t, t);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_household_member(household_id))', 'Members can view ' || t, t);
    execute format('drop policy if exists %I on public.%I', 'Members can insert ' || t, t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.is_household_member(household_id) and created_by = (select auth.uid()))', 'Members can insert ' || t, t);
    execute format('drop policy if exists %I on public.%I', 'Members can update ' || t, t);
    execute format('create policy %I on public.%I for update to authenticated using (public.is_household_member(household_id)) with check (public.is_household_member(household_id))', 'Members can update ' || t, t);
    execute format('drop policy if exists %I on public.%I', 'Members can delete ' || t, t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.is_household_member(household_id))', 'Members can delete ' || t, t);
  end loop;
end $$;

drop policy if exists "Members can view household audit log" on public.household_audit_log;
create policy "Members can view household audit log" on public.household_audit_log
for select to authenticated using (public.is_household_member(household_id));

grant select, insert, update, delete on public.household_budgets, public.savings_goals, public.household_debts, public.household_assets, public.household_accounts to authenticated;
grant select on public.household_audit_log to authenticated;
grant usage, select on sequence public.household_audit_log_id_seq to authenticated;

commit;

-- Optional verification (run separately):
-- select tablename, rowsecurity from pg_tables where schemaname='public' and tablename in
-- ('transactions','household_budgets','savings_goals','household_debts','household_assets','household_accounts','household_audit_log');
