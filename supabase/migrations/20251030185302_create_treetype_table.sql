CREATE TABLE tree_type (
    uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(100) NOT NULL,
    name_trivial varchar(100) NOT NULL,
    name_botanic varchar(100) NOT NULL,
    strain varchar(100)
);
comment on table public.tree_type is 'Diese Tabelle listet Baumarten (Beispiel: "Eiche")';
grant,
    references,
    select on public.tree_type to anon;
grant,
    references,
    select on public.tree_type to authenticated;
grant delete,
    insert,
    references,
    select,
    trigger,
    truncate,
    update on public.tree_type to service_role;
--

CREATE TABLE tree_attribute_groups (
    uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(100) NOT NULL
);
comment on table public.tree_attribute_groups is 'Diese Tabelle bildet Attributgruppen ab. Eine Gruppe kann multiple Attribute enthalten. (Beispiel: "Klimabedingungen") ';
grant,
    references,
    select on public.tree_attribute_groups to anon;
grant,
    references,
    select on public.tree_attribute_groups to authenticated;
grant delete,
    insert,
    references,
    select,
    trigger,
    truncate,
    update on public.tree_attribute_groups to service_role;
---
CREATE TABLE tree_attributes (
    uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(100) NOT NULL,
    description varchar(300) NOT NULL,
    ref_tree_attribute_group UUID NOT NULL REFERENCES tree_attribute_groups(uuid) ON DELETE CASCADE
);
comment on table public.tree_attributes is 'Diese Tabelle bildet einzelne Attribute ab (Beispiel: "Lichtverhältnisse")';
grant,
    references,
    select on public.tree_attributes to anon;
grant,
    references,
    select on public.tree_attributes to authenticated;
grant delete,
    insert,
    references,
    select,
    trigger,
    truncate,
    update on public.tree_attributes to service_role;
--
CREATE TABLE tree_attribute_values (
uuid PRIMARY KEY DEFAULT gen_random_uuid(),
name varchar(100) NOT NULL,
ref_tree_attributes UUID NOT NULL REFERENCES tree_attributes(uuid) ON DELETE CASCADE
);
comment on table public.tree_attribute_values is 'Diese Tabelle listet Attribut-Werte (Beispiel: "sonnig")';
grant,
    references,
    select on public.tree_attribute_values to anon;
grant,
    references,
    select on public.tree_attribute_values to authenticated;
grant delete,
    insert,
    references,
    select,
    trigger,
    truncate,
    update on public.tree_attribute_values to service_role;
---
CREATE TABLE tree_type_attribute_value_reference (
    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ref_tree_type UUID NOT NULL REFERENCES ref_tree_type(uuid) ON DELETE CASCADE,
    ref_tree_attribute UUID NOT NULL REFERENCES ref_tree_attribute(uuid) ON DELETE CASCADE,
    ref_tree_attribute_value UUID NOT NULL REFERENCES ref_tree_attribute_value(uuid) ON DELETE CASCADE
);
comment on table public.tree_type_attribute_value_reference is 'Diese Tabelle bildet Triple aus Baumtyp, Attribut und Value ab (Beispiel: "Eiche - Lichtverhältnis - sonnig")';
grant,
    references,
    select on public.tree_type_attribute_value_reference to anon;
grant,
    references,
    select on public.tree_type_attribute_value_reference to authenticated;
grant delete,
    insert,
    references,
    select,
    trigger,
    truncate,
    update on public.tree_type_attribute_value_reference to service_role;