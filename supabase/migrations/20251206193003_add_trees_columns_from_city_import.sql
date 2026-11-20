ALTER TABLE public.trees 
    ALTER COLUMN tree_group TYPE VARCHAR USING tree_group::varchar,
    ALTER COLUMN object_number TYPE VARCHAR USING object_number::varchar,
    ADD COLUMN object_number_1 BIGINT NOT NULL,
    ADD COLUMN planting_year SMALLINT;
    
