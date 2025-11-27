CREATE TABLE tree_types
(
    uuid         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         varchar(100) NOT NULL,
    name_trivial varchar(100) NOT NULL,
    name_botanic varchar(100) NOT NULL,
    strain       varchar(100)
);
comment
on table public.tree_types is 'Diese Tabelle listet Baumarten (Beispiel: "Eiche")';
grant
    references,
    select
    on public.tree_types to anon;
grant
    references,
    select
    on public.tree_types to authenticated;
grant
delete
,
    insert,
    references,
select, trigger, truncate,
update on public.tree_types to service_role;
--

CREATE TABLE tree_attribute_groups
(
    uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(100) NOT NULL
);
comment
on table public.tree_attribute_groups is 'Diese Tabelle bildet Attributgruppen ab. Eine Gruppe kann multiple Attribute enthalten. (Beispiel: "Klimabedingungen") ';
grant
    references,
    select
    on public.tree_attribute_groups to anon;
grant
    references,
    select
    on public.tree_attribute_groups to authenticated;
grant
delete
,
insert,
    references,
select, trigger, truncate,
update on public.tree_attribute_groups to service_role;
---
CREATE TABLE tree_attributes
(
    uuid                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                      varchar(100) NOT NULL,
    description               varchar(300) NOT NULL,
    tree_attribute_group_uuid UUID         NOT NULL REFERENCES tree_attribute_groups (uuid) ON DELETE CASCADE
);
comment
on table public.tree_attributes is 'Diese Tabelle bildet einzelne Attribute ab (Beispiel: "Lichtverhältnisse")';
grant
    references,
    select
    on public.tree_attributes to anon;
grant
    references,
    select
    on public.tree_attributes to authenticated;
grant
delete
,
      insert,
    references,
select, trigger, truncate,
update on public.tree_attributes to service_role;
--
CREATE TABLE tree_attribute_values
(
    uuid                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name                varchar(100) NOT NULL,
    tree_attribute_uuid UUID         NOT NULL REFERENCES tree_attributes (uuid) ON DELETE CASCADE
);
comment
on table public.tree_attribute_values is 'Diese Tabelle listet Attribut-Werte (Beispiel: "sonnig")';
grant
    references,
    select
    on public.tree_attribute_values to anon;
grant
    references,
    select
    on public.tree_attribute_values to authenticated;
grant
delete
,
    insert,
    references,
select, trigger, truncate,
update on public.tree_attribute_values to service_role;
---
CREATE TABLE tree_type_attribute_value_references
(
    uuid                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tree_type_uuid            UUID NOT NULL REFERENCES tree_types (uuid) ON DELETE CASCADE,
    tree_attribute_uuid       UUID NOT NULL REFERENCES tree_attributes (uuid) ON DELETE CASCADE,
    tree_attribute_value_uuid UUID NOT NULL REFERENCES tree_attribute_values (uuid) ON DELETE CASCADE
);
comment
on table public.tree_type_attribute_value_references is 'Diese Tabelle bildet Triple aus Baumtyp, Attribut und Value ab (Beispiel: "Eiche - Lichtverhältnis - sonnig")';
grant
    references,
    select
    on public.tree_type_attribute_value_references to anon;
grant
    references,
    select
    on public.tree_type_attribute_value_references to authenticated;
grant
delete
,
    insert,
    references,
select, trigger, truncate,
update on public.tree_type_attribute_value_references to service_role;