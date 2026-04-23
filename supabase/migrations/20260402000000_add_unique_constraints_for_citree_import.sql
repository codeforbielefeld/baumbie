ALTER TABLE providers ADD CONSTRAINT providers_name_unique UNIQUE (name);

ALTER TABLE tree_types ADD CONSTRAINT tree_types_citree_id_unique UNIQUE (citree_id);

ALTER TABLE tree_type_attribute_groups ADD CONSTRAINT tree_type_attribute_groups_name_unique UNIQUE (name);

ALTER TABLE tree_type_attributes ADD CONSTRAINT tree_type_attributes_name_unique UNIQUE (name);
