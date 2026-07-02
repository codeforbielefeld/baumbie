-- name_botanic als natuerlicher Upsert-Key fuer tree_types
ALTER TABLE tree_types
    ADD CONSTRAINT tree_types_name_botanic_unique UNIQUE (name_botanic);

-- Einheit fuer Werte bewahren (z.B. Wikidata-Quantity: Zahl + Einheit),
-- damit die Einheit beim Import nicht verloren geht; NULL fuer einheitenlose Werte
ALTER TABLE tree_type_attribute_values
    ADD COLUMN unit VARCHAR(255) NULL;

-- unit in den natuerlichen Key aufnehmen, damit Value-Upserts moeglich sind.
-- NULLS NOT DISTINCT, damit einheitenlose Werte (unit = NULL) als gleich gelten
-- und der Upsert-Konflikt auch dort greift.
ALTER TABLE tree_type_attribute_values
    DROP CONSTRAINT tree_type_attribute_values_unique;
ALTER TABLE tree_type_attribute_values
    ADD CONSTRAINT tree_type_attribute_values_unique
    UNIQUE NULLS NOT DISTINCT (tree_type_uuid, tree_type_attribute_uuid, value, unit);
