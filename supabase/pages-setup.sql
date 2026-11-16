-- QalamStorys Pages (notes workspace) sync. Run once in Supabase > SQL Editor > New query > Run.
-- Each signed-in person can read and write only their own pages.

create table if not exists public.pages (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  id text not null check (char_length(id) <= 40),
  data jsonb not null check (pg_column_size(data) <= 200000),
  updated_at bigint not null,
  primary key (user_id, id)
);

alter table public.pages enable row level security;

drop policy if exists "pages own read" on public.pages;
drop policy if exists "pages own write" on public.pages;
drop policy if exists "pages own update" on public.pages;
drop policy if exists "pages own delete" on public.pages;
create policy "pages own read" on public.pages for select to authenticated using (user_id = auth.uid());
create policy "pages own write" on public.pages for insert to authenticated with check (user_id = auth.uid());
create policy "pages own update" on public.pages for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "pages own delete" on public.pages for delete to authenticated using (user_id = auth.uid());
