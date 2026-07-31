CREATE TABLE tree_types
(
    uuid         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         varchar(255) NOT NULL,
    name_trivial varchar(255) NOT NULL,
    name_botanic varchar(255) NOT NULL,
    strain       varchar(255) NULL,
    description  TEXT         NULL,
    citree_id    varchar(255) NULL,
    wikidata_id  varchar(255) NULL
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

CREATE TABLE tree_type_attribute_groups
(
    uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(255) NOT NULL,
    description TEXT NULL
);
comment
on table public.tree_type_attribute_groups is 'Diese Tabelle bildet Attributgruppen ab. Eine Gruppe kann multiple Attribute enthalten. (Beispiel: "Klimabedingungen") ';
grant
    references,
    select
    on public.tree_type_attribute_groups to anon;
grant
    references,
    select
    on public.tree_type_attribute_groups to authenticated;
grant
delete
,
insert,
    references,
select, trigger, truncate,
update on public.tree_type_attribute_groups to service_role;
---
CREATE TABLE tree_type_attributes
(
    uuid                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                      VARCHAR(255) NOT NULL,
    description               TEXT         NULL,
    type                      VARCHAR(255) NULL,    --- z.B. "string", "number", "boolean"
    provider_uuid             UUID         NULL     REFERENCES providers (uuid) ON DELETE SET NULL,
    provider_attribute_id     VARCHAR(255) NULL,    --- ID des Attributs beim Provider, z.B. P123 bei Wikidata
    tree_attribute_group_uuid UUID         NULL     REFERENCES tree_type_attribute_groups (uuid) ON DELETE SET NULL
);
comment
on table public.tree_type_attributes is 'Diese Tabelle bildet einzelne Attribute ab (Beispiel: "Lichtverhältnisse")';
grant
    references,
    select
    on public.tree_type_attributes to anon;
grant
    references,
    select
    on public.tree_type_attributes to authenticated;
grant
delete
,
      insert,
    references,
select, trigger, truncate,
update on public.tree_type_attributes to service_role;
---
CREATE TABLE tree_type_attribute_values
(
    uuid                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tree_type_uuid            UUID NOT NULL REFERENCES tree_types (uuid) ON DELETE CASCADE,
    tree_type_attribute_uuid  UUID NOT NULL REFERENCES tree_type_attributes (uuid) ON DELETE CASCADE,
    type                      VARCHAR(255) NOT NULL,
    value                     TEXT NOT NULL
);
comment
on table public.tree_type_attribute_values is 'Diese Tabelle bildet Triple aus Baumtyp, Attribut und Value ab (Beispiel: "Eiche - Lichtverhältnis - sonnig")';
grant
    references,
    select
    on public.tree_type_attribute_values to anon;
grant
    references,
    select
    on public.tree_type_attribute_values to authenticated;
grant
delete
,
    insert,
    references,
select, trigger, truncate,
update on public.tree_type_attribute_values to service_role;

ALTER TABLE trees ADD COLUMN tree_type_uuid UUID NULL REFERENCES tree_types (uuid) ON DELETE SET NULL;
comment
on column public.trees.tree_type_uuid is 'Verweis auf die Baumart (tree_types) dieses Baumes';