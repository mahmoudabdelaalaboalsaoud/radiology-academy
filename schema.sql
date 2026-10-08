-- شغّل هذا الملف كاملًا مرة واحدة في Supabase > SQL Editor

create table if not exists profiles(
  id uuid primary key references auth.users on delete cascade,
  full_name text, phone text, email text,
  role text not null default 'student' check (role in ('student','admin')),
  sub_until date,
  last_seen timestamptz default now(),
  created_at timestamptz default now()
);
create table if not exists courses(
  id uuid primary key default gen_random_uuid(),
  title text not null, description text, cover_url text,
  created_at timestamptz default now()
);
create table if not exists lessons(
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses on delete cascade,
  title text not null, position int default 0, is_free boolean default false,
  created_at timestamptz default now()
);
create table if not exists lesson_media(
  lesson_id uuid primary key references lessons on delete cascade,
  video_url text, notes text
);
create table if not exists flashcards(
  id uuid primary key default gen_random_uuid(),
  course_id uuid references courses on delete cascade,
  front text not null, back text not null
);
create table if not exists messages_log(
  id uuid primary key default gen_random_uuid(),
  student_id uuid references profiles on delete cascade,
  channel text, body text, created_at timestamptz default now()
);

create or replace function is_admin() returns boolean
language sql security definer stable set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;

create or replace function has_sub() returns boolean
language sql security definer stable set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and sub_until>=current_date) $$;

create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  insert into profiles(id,full_name,phone,email)
  values(new.id,new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'phone',new.email);
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function handle_new_user();

-- يمنع الطالب من تعديل صلاحيته أو اشتراكه بنفسه
create or replace function protect_profile() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is not null and not is_admin()
     and (new.role is distinct from old.role or new.sub_until is distinct from old.sub_until) then
    raise exception 'not allowed';
  end if;
  return new;
end $$;
drop trigger if exists trg_protect_profile on profiles;
create trigger trg_protect_profile before update on profiles
for each row execute function protect_profile();

alter table profiles enable row level security;
alter table courses enable row level security;
alter table lessons enable row level security;
alter table lesson_media enable row level security;
alter table flashcards enable row level security;
alter table messages_log enable row level security;

create policy "p_sel" on profiles for select to authenticated using (id=auth.uid() or is_admin());
create policy "p_upd" on profiles for update to authenticated using (id=auth.uid() or is_admin()) with check (id=auth.uid() or is_admin());

create policy "c_sel" on courses for select to authenticated using (true);
create policy "c_adm" on courses for all to authenticated using (is_admin()) with check (is_admin());

create policy "l_sel" on lessons for select to authenticated using (true);
create policy "l_adm" on lessons for all to authenticated using (is_admin()) with check (is_admin());

create policy "m_sel" on lesson_media for select to authenticated using (
  is_admin() or has_sub() or exists(select 1 from lessons l where l.id=lesson_id and l.is_free));
create policy "m_adm" on lesson_media for all to authenticated using (is_admin()) with check (is_admin());

create policy "f_sel" on flashcards for select to authenticated using (is_admin() or has_sub());
create policy "f_adm" on flashcards for all to authenticated using (is_admin()) with check (is_admin());

create policy "g_adm" on messages_log for all to authenticated using (is_admin()) with check (is_admin());

-- بعد إنشاء حسابك من الموقع، فعّل نفسك أدمن (غيّر الإيميل):
-- update profiles set role='admin' where email='your@email.com';
