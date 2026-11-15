-- QalamStorys Circle backend. Paste into Supabase > SQL Editor > New query > Run (once).

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null default '' check (char_length(name) <= 60)
);
create table if not exists public.circles (
  id text primary key check (id ~ '^[A-Z0-9]{6}$'),
  owner uuid not null default auth.uid() references auth.users on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.members (
  circle_id text not null references public.circles on delete cascade,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  joined_at bigint not null,
  checkin text not null default '',
  primary key (circle_id, user_id)
);
create table if not exists public.chat (
  id bigint generated always as identity primary key,
  circle_id text not null references public.circles on delete cascade,
  by uuid not null default auth.uid() references auth.users on delete cascade,
  kind text not null check (kind in ('text', 'voice')),
  text text check (char_length(text) <= 1000),
  asset text,
  secs int check (secs between 0 and 200),
  at bigint not null
);
create index if not exists chat_circle_at on public.chat (circle_id, at desc);

create or replace function public.is_member(c text) returns boolean
language sql security definer stable set search_path = public as
$$ select exists (select 1 from public.members where circle_id = c and user_id = auth.uid()) $$;

create or replace function public.circle_exists(c text) returns boolean
language sql security definer stable set search_path = public as
$$ select exists (select 1 from public.circles where id = upper(c)) $$;

create or replace function public.members_cap() returns trigger
language plpgsql security definer set search_path = public as
$$ begin
  if (select count(*) from public.members where circle_id = new.circle_id) >= 25 then
    raise exception 'circle_full';
  end if;
  return new;
end $$;
drop trigger if exists members_cap on public.members;
create trigger members_cap before insert on public.members for each row execute function public.members_cap();

alter table public.profiles enable row level security;
alter table public.circles enable row level security;
alter table public.members enable row level security;
alter table public.chat enable row level security;

-- profiles: signed-in users can read names; each user writes only their own row
create policy "profiles read" on public.profiles for select to authenticated using (true);
create policy "profiles insert own" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- circles: create your own; codes are checked via circle_exists(), not listed
create policy "circles insert own" on public.circles for insert to authenticated with check (owner = auth.uid());
create policy "circles read joined" on public.circles for select to authenticated using (owner = auth.uid() or public.is_member(id));

-- members: see your circle; add/update/remove only yourself
create policy "members read" on public.members for select to authenticated using (public.is_member(circle_id));
create policy "members join" on public.members for insert to authenticated with check (user_id = auth.uid());
create policy "members update own" on public.members for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "members leave" on public.members for delete to authenticated using (user_id = auth.uid());

-- chat: members read and post in their circle; delete only your own messages
create policy "chat read" on public.chat for select to authenticated using (public.is_member(circle_id));
create policy "chat post" on public.chat for insert to authenticated with check (by = auth.uid() and public.is_member(circle_id));
create policy "chat delete own" on public.chat for delete to authenticated using (by = auth.uid());

-- live updates
alter publication supabase_realtime add table public.members, public.chat;

-- voice notes: private bucket, files stored as <circle code>/<uuid>.<ext>, 20 MB max
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('voice', 'voice', false, 20971520, array['audio/webm', 'audio/mp4', 'audio/x-m4a', 'audio/aac', 'video/webm', 'video/mp4'])
on conflict (id) do nothing;
create policy "voice read members" on storage.objects for select to authenticated
  using (bucket_id = 'voice' and public.is_member((storage.foldername(name))[1]));
create policy "voice upload members" on storage.objects for insert to authenticated
  with check (bucket_id = 'voice' and public.is_member((storage.foldername(name))[1]));
