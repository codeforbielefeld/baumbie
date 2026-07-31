-- Column-Rename zuerst, damit nachfolgende Statements den neuen Namen nutzen koennen
ALTER TABLE tree_type_attributes
    RENAME COLUMN tree_attribute_group_uuid TO tree_type_attribute_group_uuid;

-- Attribut-Namen pro Provider eindeutig (statt global)
ALTER TABLE tree_type_attributes
    DROP CONSTRAINT tree_type_attributes_name_unique;
ALTER TABLE tree_type_attributes
    ADD CONSTRAINT tree_type_attributes_provider_name_unique
    UNIQUE (provider_uuid, name);

-- Value-Typ nullable, konsistent mit Attribut-Typ
ALTER TABLE tree_type_attribute_values
    ALTER COLUMN type DROP NOT NULL;

-- Natuerlicher Key fuer Upserts auf Values
ALTER TABLE tree_type_attribute_values
    ADD CONSTRAINT tree_type_attribute_values_unique
    UNIQUE (tree_type_uuid, tree_type_attribute_uuid, value);

-- Matching-Lookup-Beschleunigung (NICHT unique -- Cultivar-Fallback)
CREATE INDEX tree_types_wikidata_id_idx
    ON tree_types (wikidata_id);

-- FK-Indizes (Postgres legt diese nicht automatisch an)
CREATE INDEX tree_type_attribute_values_tree_type_uuid_idx
    ON tree_type_attribute_values (tree_type_uuid);
CREATE INDEX tree_type_attribute_values_tree_type_attribute_uuid_idx
    ON tree_type_attribute_values (tree_type_attribute_uuid);
CREATE INDEX tree_type_attributes_provider_uuid_idx
    ON tree_type_attributes (provider_uuid);
CREATE INDEX tree_type_attributes_tree_type_attribute_group_uuid_idx
    ON tree_type_attributes (tree_type_attribute_group_uuid);
CREATE INDEX trees_tree_type_uuid_idx
    ON trees (tree_type_uuid);
