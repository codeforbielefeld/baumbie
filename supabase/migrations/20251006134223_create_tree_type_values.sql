-- ============================================================
-- Migration: 20251006134223_create_tree_type_values.sql
-- Purpose: Create the 'tree_type_values' table to store characteristics of each tree type,
--          consisting of a tree type, an attribute group, a parameter, and a parameter value.
-- Affected Tables: tree_type_values
-- ============================================================
CREATE TABLE tree_parameters (
    tree_type_uuid      uuid NOT NULL,
    attribute_uuid      uuid NOT NULL,
    parameter_uuid      uuid NOT NULL,
    parameter_value     text NOT NULL,

    FOREIGN KEY (tree_type_uuid) REFERENCES public.trees(uuid) ON DELETE CASCADE,
    FOREIGN KEY (parameter_uuid) REFERENCES public.tree_parameters(uuid) ON DELETE CASCADE,
    FOREIGN KEY (attribute_uuid) REFERENCES public.tree_attributes(attribute_uuid) ON DELETE CASCADE,

    UNIQUE (tree_type_uuid, attribute_uuid, parameter_uuid)
);

comment on table public.tree_parameters is 'Alle Werte für alle Baumparameter pro Baumart, sowie Zuordnung zur Attributgruppe.';

-- Enable Row-Level Security (RLS)
alter table public.tree_parameters enable row level security;

-- Policy: Allow read access for all users
create policy "Enable read access for all users"
  on public.tree_values
  for select
  to public
  using (true);

-- Policy: Allow insert only for owner
create policy "Enable insert only for owner"
  on public.tree_values
  for insert
  to authenticated
  with check (user_uuid = auth.uid());

-- Policy: Allow update only for owner
create policy "Enable update only for owner"
  on public.tree_values
  for update
  to authenticated
  using (user_uuid = auth.uid());

-- Policy: Allow delete only for owner
create policy "Enable delete only for owner"
  on public.tree_values
  for delete
  to authenticated
  using (user_uuid = auth.uid());