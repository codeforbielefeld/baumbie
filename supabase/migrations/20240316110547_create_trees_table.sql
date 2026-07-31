CREATE EXTENSION postgis;


create table public.providers
(
    uuid   uuid default uuid_generate_v4() primary key,
    name varchar not null
);

create table public.trees
(
    uuid                uuid default uuid_generate_v4() primary key,
    provider_id         uuid references public.providers (uuid) on delete set null on update cascade default null,
    source_id           varchar not null, -- ID from the source (pitID)
    location            bigint not null,  -- Standord_N
    location_addition   varchar, -- Zusatz
    current_number      bigint, -- laufende_n
    chopped             boolean, -- gefaellt
    trunk_diameter      double precision, -- Stammdurch
    trunk_circumference double precision, -- Stammumfan
    crown_diameter      double precision, -- Kronendurc
    height              double precision, -- Baumhoehe_
    tree_group          bigint, -- Baumgruppe
    district_number     bigint, -- Bezirk_Nr
    district_name       varchar, -- Bezirk_Bez
    object_number       bigint, -- Objekt_Nr
    object_name         varchar, -- Objekt_Bez
    tree_type_botanic   varchar, -- Baumart_bo
    tree_type_german    varchar, -- Baumart_de
    tree_type_short     varchar, -- Baumart_ku
    care_number         bigint, -- PflE_Art_N
    care_type           varchar, -- PflE_Art_B
    trunk_radius        double precision, -- Stammradiu
    crown_radius        double precision, -- Kronenradi
    geocoordinates      geography(Point, 4326) not null -- geometry.coordinates (Point)
);

comment on table public.trees is 'Alle Informationen über die Bielefelder Bäume.';

alter table public.trees
    owner to postgres;

-- grant select, update, usage on sequence public.trees_id_seq to anon;

-- grant select, update, usage on sequence public.trees_id_seq to authenticated;

-- grant select, update, usage on sequence public.trees_id_seq to service_role;

create index trees_geocoordinates
    on public.trees using gist (geocoordinates);

grant delete, insert, references, select, trigger, truncate, update on public.trees to anon;

grant delete, insert, references, select, trigger, truncate, update on public.trees to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.trees to service_role;

create policy "Enable read access for all users" on "public"."trees" as permissive for select to public using (true);
