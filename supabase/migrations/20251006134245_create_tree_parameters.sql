-- ============================================================
-- Migration: 20251006134245_create_tree_parameters.sql
-- Purpose: Create the 'tree_parameters' table to store metadata
--          about tree parameters, such as name and linked attribute group.
-- Affected Tables: tree_type_values
-- ============================================================
CREATE TABLE tree_parameters (
    uuid            uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    parameter_name  text NOT NULL,
    attribute       uuid NOT NULL,

    FOREIGN KEY (attribute) REFERENCES public.tree_attributes(uuid) ON DELETE CASCADE
);

comment on table public.tree_parameters is 'Alle Informationen über die Baumparameter. Baumparameter sind Eigenschaften von Baumarten, die einer Attributgruppe zugeordnet sind.';


-- Enable Row-Level Security (RLS)
alter table public.tree_parameters enable row level security;

-- Policy: Allow read access for all users
create policy "Enable read access for all users"
  on public.tree_parameters
  for select
  to public
  using (true);

-- Policy: Allow insert only for owner
create policy "Enable insert only for owner"
  on public.tree_parameters
  for insert
  to authenticated
  with check (user_uuid = auth.uid());

-- Policy: Allow update only for owner
create policy "Enable update only for owner"
  on public.tree_parameters
  for update
  to authenticated
  using (user_uuid = auth.uid());

-- Policy: Allow delete only for owner
create policy "Enable delete only for owner"
  on public.tree_parameters
  for delete
  to authenticated
  using (user_uuid = auth.uid());