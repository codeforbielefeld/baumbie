-- ============================================================
-- Migration: 20251006134237_create_tree_attributes.sql
-- Purpose: Create the 'tree_attributes' table to store metadata
--          about tree attributes, such as name and description.
-- Affected Tables: tree_values
-- ============================================================

create table tree_attributes (
    attribute_uuid         uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    attribute_name         text not null,                             
    attribute_description  text

    UNIQUE (attribute_uuid)                               
);

comment on table public.tree_attributes is 'Alle Informationen über die Baumattribute. Baumattribute sind Gruppen von Parametern.';

-- Enable Row-Level Security (RLS)
alter table public.tree_attributes enable row level security;

-- Policy: Allow read access for all users
create policy "Enable read access for all users"
  on public.tree_attributes
  for select
  to public
  using (true);

-- Policy: Allow insert only for owner
create policy "Enable insert only for owner"
  on public.tree_attributes
  for insert
  to authenticated
  with check (user_uuid = auth.uid());

-- Policy: Allow update only for owner
create policy "Enable update only for owner"
  on public.tree_attributes
  for update
  to authenticated
  using (user_uuid = auth.uid());

-- Policy: Allow delete only for owner
create policy "Enable delete only for owner"
  on public.tree_attributes
  for delete
  to authenticated
  using (user_uuid = auth.uid());