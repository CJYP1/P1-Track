-- L1 M-SLAB 1-6 belong to Marine (MA): MA accounts can save their data, NB accounts no longer can.
-- Run once in the Supabase SQL Editor (safe to run again).
insert into public.rws_zone_area(level,zone_mk,area) values
('L1','L1|MSLAB1','MA'),
('L1','L1|MSLAB2','MA'),
('L1','L1|MSLAB3','MA'),
('L1','L1|MSLAB4','MA'),
('L1','L1|MSLAB5','MA'),
('L1','L1|MSLAB6','MA')
on conflict (level,zone_mk) do update set area=excluded.area;
