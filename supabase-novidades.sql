-- Foco: SQL das novidades (grupos, anúncios). Pode rodar mais de uma vez.
-- Rode no Supabase: SQL Editor > New query > colar tudo > Run.
-- GIFs/figurinhas no chat NÃO precisam de tabela nova (vão no campo body de messages).

-- ============ GRUPOS ============
create table if not exists public.groups(
  id bigint generated always as identity primary key,
  name text not null,
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.group_members(
  group_id bigint not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(group_id, user_id)
);
create table if not exists public.group_messages(
  id bigint generated always as identity primary key,
  group_id bigint not null references public.groups(id) on delete cascade,
  sender_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);
create index if not exists group_messages_group_idx on public.group_messages(group_id, created_at);

create or replace function public.is_group_member(gid bigint) returns boolean
language sql security definer set search_path = public stable as $$
  select exists(select 1 from public.group_members where group_id = gid and user_id = auth.uid())
$$;

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_messages enable row level security;

drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups for select to authenticated
  using (created_by = auth.uid() or public.is_group_member(id));
drop policy if exists groups_insert on public.groups;
create policy groups_insert on public.groups for insert to authenticated
  with check (created_by = auth.uid());
drop policy if exists groups_delete on public.groups;
create policy groups_delete on public.groups for delete to authenticated
  using (created_by = auth.uid());

drop policy if exists gm_select on public.group_members;
create policy gm_select on public.group_members for select to authenticated
  using (public.is_group_member(group_id));
drop policy if exists gm_insert on public.group_members;
create policy gm_insert on public.group_members for insert to authenticated
  with check (exists(select 1 from public.groups g where g.id = group_id and g.created_by = auth.uid()));
drop policy if exists gm_delete on public.group_members;
create policy gm_delete on public.group_members for delete to authenticated
  using (user_id = auth.uid() or exists(select 1 from public.groups g where g.id = group_id and g.created_by = auth.uid()));

drop policy if exists gmsg_select on public.group_messages;
create policy gmsg_select on public.group_messages for select to authenticated
  using (public.is_group_member(group_id));
drop policy if exists gmsg_insert on public.group_messages;
create policy gmsg_insert on public.group_messages for insert to authenticated
  with check (sender_id = auth.uid() and public.is_group_member(group_id));

do $$ begin
  alter publication supabase_realtime add table public.group_messages;
exception when others then null;
end $$;

-- ============ ANÚNCIOS ============
create table if not exists public.ads(
  id bigint generated always as identity primary key,
  user_id uuid default auth.uid() references auth.users(id) on delete set null,
  title text not null,
  body text,
  image text,
  link text,
  cta text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','paused')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.ads enable row level security;

drop policy if exists ads_select on public.ads;
create policy ads_select on public.ads for select to authenticated
  using (status = 'approved' or user_id = auth.uid());
drop policy if exists ads_insert on public.ads;
create policy ads_insert on public.ads for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending');

-- Para ATIVAR um anúncio (depois de receber o pagamento):
--   Table Editor > ads > mude status para "approved" (e, se quiser, preencha ends_at).
-- Patrocinador próprio: insira uma linha em ads com status "approved" e user_id vazio.

-- ============ SENHA (conta de teste urgente) ============
-- Define uma senha nova direto no banco (troque e-mail e senha):
-- update auth.users set encrypted_password = extensions.crypt('NovaSenha123', extensions.gen_salt('bf'))
--  where email = 'seu-email@exemplo.com';
