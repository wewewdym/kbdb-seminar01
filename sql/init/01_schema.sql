-- =====================================================================
--  Учебный датасет: условная компрессорная станция
--  Курс «Базы знаний и базы данных», ИУ-1, семинар 1
--
--  Файл загружается автоматически при первом старте контейнера.
--  НЕ редактируйте его: свои запросы пишите в sql/seminar01.sql
-- =====================================================================

-- ---------- Площадки ----------
create table station (
    id      serial primary key,
    name    text not null unique,
    region  text not null
);
comment on table station is 'Площадка (станция), на которой стоит оборудование';

-- ---------- Агрегаты ----------
create table unit (
    id            text primary key,              -- человекочитаемый код: GPA-2, P-1 ...
    station_id    int  not null references station(id),
    kind          text not null,                 -- gas_compressor / pump / cooler
    model         text not null,
    commissioned  date not null,
    status        text not null default 'in_service'   -- in_service / reserve / decommissioned
);
comment on table unit is 'Единица оборудования: газоперекачивающий агрегат, насос, АВО';

-- ---------- Датчики ----------
create table sensor (
    id               serial primary key,
    unit_id          text not null references unit(id),
    kind             text not null,              -- temp / vibration / pressure / load
    tag              text not null,              -- технологическая позиция: TE-301, VT-102 ...
    unit_of_measure  text not null,              -- °C, mm/s, MPa, %
    unique (unit_id, tag)
);
comment on table sensor is 'Датчик, установленный на агрегате';

-- ---------- Телеметрия ----------
create table telemetry (
    ts         timestamptz not null,
    sensor_id  int         not null references sensor(id),
    value      numeric(10,3) not null,
    primary key (sensor_id, ts)
);
comment on table telemetry is 'Измерения датчиков, шаг 1 минута';

-- ---------- События ----------
create table event (
    id        serial primary key,
    unit_id   text not null references unit(id),
    ts        timestamptz not null,
    severity  text not null,                     -- info / warning / alarm / unplanned_stop
    message   text not null
);
comment on table event is 'Журнал событий и аварий (данные «как есть», из SCADA)';

-- ---------- Ремонты и ТО ----------
create table maintenance (
    id            serial primary key,
    unit_id       text not null references unit(id),
    performed_at  timestamptz not null,
    engineer      text not null,
    work_type     text not null,                 -- planned / unplanned / inspection
    parts         text,
    notes         text
);
comment on table maintenance is 'Журнал ремонтов (перенесён из Excel — со всеми последствиями)';
