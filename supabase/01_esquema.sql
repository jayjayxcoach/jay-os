-- JAY OS · base de datos en Supabase
-- Equipo, proyectos, tareas y registro de actividad. Solo las personas cuyo
-- correo está en "members" pueden ver y cambiar datos.

create extension if not exists pgcrypto;

-- ---------- Tablas ----------
create table if not exists public.members (
  id          text primary key default ('m-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
  name        text not null,
  role        text not null default '',
  color       text not null default 'lav',
  email       text unique,
  phone       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.projects (
  id          text primary key default ('p-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
  name        text not null,
  color       text not null default 'lav',
  estado      text not null default 'Activo',
  etapa       text not null default 'Montaje',
  tipo        text not null default 'Producto propio',
  prio        text not null default 'Media',
  start       date,
  launch      date,
  owner       text references public.members(id) on delete set null,
  notes       text not null default '',
  rank        int,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.tasks (
  id          text primary key default ('t-' || replace(gen_random_uuid()::text, '-', '')),
  title       text not null,
  project_id  text references public.projects(id) on delete cascade,
  assignee    text references public.members(id) on delete set null,
  status      text not null default 'todo' check (status in ('todo', 'doing', 'done')),
  prio        int  not null default 3 check (prio between 1 and 4),
  phase       int  check (phase between 0 and 5),
  start       date,
  due         date,
  focus       boolean not null default false,
  blocks      boolean not null default false,
  notes       text not null default '',
  done_by     text references public.members(id) on delete set null,
  done_at     timestamptz,
  created_by  text references public.members(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists tasks_project_idx  on public.tasks(project_id);
create index if not exists tasks_assignee_idx on public.tasks(assignee);
create index if not exists tasks_due_idx      on public.tasks(due);

-- Cada tarea terminada deja una línea aquí. De esta tabla sale el aviso al grupo de WhatsApp.
create table if not exists public.activity (
  id          bigint generated always as identity primary key,
  kind        text not null,
  task_id     text,
  task_title  text,
  project_id  text,
  member_id   text,
  created_at  timestamptz not null default now(),
  sent_at     timestamptz
);

-- ---------- Quién está conectado ----------
create or replace function public.current_member() returns text
language sql stable security definer set search_path = public as $$
  select id from public.members
  where email is not null and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  limit 1
$$;

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_member() is not null
$$;

-- ---------- Reglas automáticas ----------
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create or replace function public.tasks_before_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  if tg_op = 'INSERT' then
    new.created_by := coalesce(new.created_by, public.current_member());
  end if;
  if new.status = 'done' then
    if tg_op = 'INSERT' or old.status is distinct from 'done' then
      new.done_at := coalesce(new.done_at, now());
      new.done_by := coalesce(public.current_member(), new.done_by);
    end if;
  else
    new.done_at := null;
    new.done_by := null;
  end if;
  return new;
end $$;

create or replace function public.tasks_after_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'done' and (tg_op = 'INSERT' or old.status is distinct from 'done') then
    insert into public.activity (kind, task_id, task_title, project_id, member_id)
    values ('task_done', new.id, new.title, new.project_id, new.done_by);
  end if;
  return new;
end $$;

drop trigger if exists members_touch on public.members;
create trigger members_touch before update on public.members
  for each row execute function public.touch_updated_at();

drop trigger if exists projects_touch on public.projects;
create trigger projects_touch before update on public.projects
  for each row execute function public.touch_updated_at();

drop trigger if exists tasks_before on public.tasks;
create trigger tasks_before before insert or update on public.tasks
  for each row execute function public.tasks_before_write();

drop trigger if exists tasks_after on public.tasks;
create trigger tasks_after after insert or update on public.tasks
  for each row execute function public.tasks_after_write();

-- ---------- Seguridad ----------
alter table public.members  enable row level security;
alter table public.projects enable row level security;
alter table public.tasks    enable row level security;
alter table public.activity enable row level security;

drop policy if exists "equipo" on public.members;
create policy "equipo" on public.members  for all to authenticated using (public.is_member()) with check (public.is_member());
drop policy if exists "equipo" on public.projects;
create policy "equipo" on public.projects for all to authenticated using (public.is_member()) with check (public.is_member());
drop policy if exists "equipo" on public.tasks;
create policy "equipo" on public.tasks    for all to authenticated using (public.is_member()) with check (public.is_member());
drop policy if exists "equipo lee" on public.activity;
create policy "equipo lee" on public.activity for select to authenticated using (public.is_member());

revoke all on public.members, public.projects, public.tasks, public.activity from anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.members, public.projects, public.tasks to authenticated;
grant select on public.activity to authenticated;
revoke execute on function public.current_member(), public.is_member() from anon;

-- ---------- Tiempo real ----------
do $$
begin
  begin alter publication supabase_realtime add table public.members;  exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.projects; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.tasks;    exception when duplicate_object then null; end;
end $$;
