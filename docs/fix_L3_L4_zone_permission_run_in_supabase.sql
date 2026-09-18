-- Fix area-account saves on L3/L4.
-- Root cause: rws_zone_area had no L3/L4 rows, so _rws_area_ok returned false.
-- Safe to run repeatedly (upsert).

insert into public.rws_zone_area(level,zone_mk,area) values
('L3','L3|3.4','MA'),('L3','L3|3.2','MA'),('L3','L3|1.2','MA'),
('L3','L3|3.4T','MA'),('L3','L3|3.2T','MA'),('L3','L3|P1.2T','MA'),
('L3','L3|1.1','MA'),('L3','L3|3.3CIST','MA'),('L3','L3|3.3T','MA'),
('L3','L3|3.1T','MA'),('L3','L3|3.1CIST','MA'),
('L3','L3|2.4','NB'),('L3','L3|2.4T','NB'),('L3','L3|2.3T','NB'),
('L3','L3|2.6CIST','NB'),('L3','L3|2.2','NB'),('L3','L3|2.6CIS','NB'),
('L3','L3|2.3CIST','NB'),('L3','L3|2.2T','NB'),('L3','L3|2.1T','NB'),
('L3','L3|2.1','NB'),('L3','L3|2.1CIS','NB'),('L3','L3|2.1CIST','NB'),
('L3','L3|4.2','EB'),('L3','L3|4.2T','EB'),('L3','L3|4.1','EB'),
('L3','L3|4.4','EB'),('L3','L3|4.1CIST','EB'),('L3','L3|4.3T','EB'),
('L3','L3|4.3CIST','EB'),
('L4','L4|3.4','MA'),('L4','L4|3.2','MA'),('L4','L4|1.2','MA'),
('L4','L4|3.4T','MA'),('L4','L4|3.2T','MA'),('L4','L4|P1.2T','MA'),
('L4','L4|1.1','MA'),('L4','L4|3.3CIST','MA'),('L4','L4|3.3T','MA'),
('L4','L4|3.1T','MA'),('L4','L4|3.1CIST','MA'),
('L4','L4|2.4','NB'),('L4','L4|2.4T','NB'),('L4','L4|2.3T','NB'),
('L4','L4|2.6CIST','NB'),('L4','L4|2.2','NB'),('L4','L4|2.6CIS','NB'),
('L4','L4|2.3CIST','NB'),('L4','L4|2.2T','NB'),('L4','L4|2.1T','NB'),
('L4','L4|2.1','NB'),('L4','L4|2.1CIS','NB'),('L4','L4|2.1CIST','NB'),
('L4','L4|4.2','EB'),('L4','L4|4.2T','EB'),('L4','L4|4.1','EB'),
('L4','L4|4.4','EB'),('L4','L4|4.1CIST','EB'),('L4','L4|4.3T','EB'),
('L4','L4|4.3CIST','EB')
on conflict (level,zone_mk) do update set area=excluded.area;

-- Quick verification: both rows should return NB.
select level, zone_mk, area
from public.rws_zone_area
where (level, zone_mk) in (('L3','L3|2.1'),('L4','L4|2.1'))
order by level;
