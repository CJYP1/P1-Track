-- L1 M-SLAB 3 / 4 / 5 / 6 belong to Marine (MA) on L1.
-- The app already treats them as Marine; this lets MA accounts save their data
-- (and NB accounts no longer can).  Safe to run more than once.
insert into public.rws_zone_area(level,zone_mk,area) values
('L1','L1|MSLAB3','MA'),
('L1','L1|MSLAB4','MA'),
('L1','L1|MSLAB5','MA'),
('L1','L1|MSLAB6','MA')
on conflict (level,zone_mk) do update set area=excluded.area;
