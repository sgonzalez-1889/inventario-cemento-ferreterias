-- ============================================================
-- ESQUEMA: Inventario de Cemento - Ferreterías
-- Ejecutar completo en el SQL Editor de Supabase
-- ============================================================

-- 1. PERFILES (rol de cada usuario autenticado)
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  nombre text,
  rol text not null default 'viewer' check (rol in ('admin','viewer')),
  creado_en timestamptz default now()
);

-- 2. ALMACENES (puntos de venta)
create table if not exists almacenes (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,        -- ej: 'BOSCONIA', 'SANTAMARTA01'
  nombre text not null,                -- ej: 'Ferrotodo Bosconia'
  activo boolean default true,
  creado_en timestamptz default now()
);

-- 3. PRODUCTOS (tipos de cemento / referencias)
create table if not exists productos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,                -- ej: 'Cemento Gris Argos 50kg'
  marca text,                          -- ej: 'Argos'
  presentacion text,                   -- ej: '50kg'
  activo boolean default true,
  creado_en timestamptz default now(),
  unique(nombre, presentacion)
);

-- 4. EXISTENCIA EN SISTEMA (snapshot actual por almacén+producto)
create table if not exists existencia_sistema (
  id uuid primary key default gen_random_uuid(),
  almacen_id uuid not null references almacenes(id) on delete cascade,
  producto_id uuid not null references productos(id) on delete cascade,
  cantidad numeric not null default 0,
  actualizado_por uuid references profiles(id),
  actualizado_en timestamptz default now(),
  unique(almacen_id, producto_id)
);

-- 5. CONTEOS FÍSICOS (histórico - cada conteo queda registrado)
create table if not exists conteos_fisicos (
  id uuid primary key default gen_random_uuid(),
  almacen_id uuid not null references almacenes(id) on delete cascade,
  producto_id uuid not null references productos(id) on delete cascade,
  cantidad numeric not null default 0,
  contado_por uuid references profiles(id),
  contado_en timestamptz default now(),
  nota text
);

create index if not exists idx_conteos_almacen_producto on conteos_fisicos(almacen_id, producto_id, contado_en desc);

-- 6. VISTA DE DIFERENCIAS (último conteo físico vs existencia en sistema)
create or replace view vista_diferencias as
with ultimo_conteo as (
  select distinct on (almacen_id, producto_id)
    almacen_id, producto_id, cantidad as cantidad_conteo, contado_en, contado_por
  from conteos_fisicos
  order by almacen_id, producto_id, contado_en desc
)
select
  a.id as almacen_id,
  a.nombre as almacen_nombre,
  a.codigo as almacen_codigo,
  p.id as producto_id,
  p.nombre as producto_nombre,
  p.presentacion,
  coalesce(es.cantidad, 0) as existencia_sistema,
  uc.cantidad_conteo,
  uc.contado_en,
  (uc.cantidad_conteo - coalesce(es.cantidad, 0)) as diferencia
from almacenes a
join productos p on p.activo = true
left join existencia_sistema es on es.almacen_id = a.id and es.producto_id = p.id
left join ultimo_conteo uc on uc.almacen_id = a.id and uc.producto_id = p.id
where a.activo = true;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table profiles enable row level security;
alter table almacenes enable row level security;
alter table productos enable row level security;
alter table existencia_sistema enable row level security;
alter table conteos_fisicos enable row level security;

-- Cualquier usuario autenticado puede leer su propio perfil
create policy "ver propio perfil" on profiles for select using (auth.uid() = id);

-- Todos los autenticados pueden leer almacenes y productos
create policy "leer almacenes" on almacenes for select using (auth.role() = 'authenticated');
create policy "leer productos" on productos for select using (auth.role() = 'authenticated');
create policy "leer existencia" on existencia_sistema for select using (auth.role() = 'authenticated');
create policy "leer conteos" on conteos_fisicos for select using (auth.role() = 'authenticated');

-- Solo admin puede escribir (insert/update/delete) en las tablas operativas
create policy "admin escribe almacenes" on almacenes for all using (
  exists (select 1 from profiles where id = auth.uid() and rol = 'admin')
);
create policy "admin escribe productos" on productos for all using (
  exists (select 1 from profiles where id = auth.uid() and rol = 'admin')
);
create policy "admin escribe existencia" on existencia_sistema for all using (
  exists (select 1 from profiles where id = auth.uid() and rol = 'admin')
);
create policy "admin escribe conteos" on conteos_fisicos for all using (
  exists (select 1 from profiles where id = auth.uid() and rol = 'admin')
);

-- ============================================================
-- TRIGGER: crear perfil automáticamente al registrarse (rol viewer por defecto)
-- ============================================================
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, rol)
  values (new.id, new.email, 'viewer');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- NOTA: Para convertir tu usuario en admin, ejecuta después de registrarte:
-- update profiles set rol = 'admin' where email = 'tu_correo@ejemplo.com';
-- ============================================================
