-- Семинар 1. Базы знаний и базы данных.
-- Решения задач 1-7 и дополнительных заданий 8-11.
-- Выполнение: make run
SET TIME ZONE 'Europe/Moscow';

-- Часть 2.2. Наблюдения над исходными данными.
-- По исходному генератору: 3 станции, 7 агрегатов, 18 датчиков,
-- 24462 измерения, 26 событий, 11 записей о ремонтах.
-- Есть разное написание severity: 'alarm' / 'Alarm',
-- 'warning' / 'warning ' (пробел в конце).
-- Датчик TE-999 не имеет измерений; агрегат GPA-4 не имеет датчиков.
-- Возможные дубли ремонтов GPA-2: maintenance id 1, 2, 3.

SELECT 'station' AS table_name, COUNT(*) AS cnt FROM station
UNION ALL SELECT 'unit', COUNT(*) FROM unit
UNION ALL SELECT 'sensor', COUNT(*) FROM sensor
UNION ALL SELECT 'telemetry', COUNT(*) FROM telemetry
UNION ALL SELECT 'event', COUNT(*) FROM event
UNION ALL SELECT 'maintenance', COUNT(*) FROM maintenance
ORDER BY table_name;

SELECT MIN(ts) AS telemetry_start, MAX(ts) AS telemetry_end FROM telemetry;
SELECT kind, COUNT(*) FROM sensor GROUP BY kind ORDER BY kind;
SELECT severity, COUNT(*) FROM event GROUP BY severity ORDER BY severity;
SELECT s.id, s.tag FROM sensor s
WHERE NOT EXISTS (SELECT 1 FROM telemetry t WHERE t.sensor_id = s.id);
SELECT u.id FROM unit u
WHERE NOT EXISTS (SELECT 1 FROM sensor s WHERE s.unit_id = u.id);
SELECT id, unit_id, performed_at, engineer, parts, notes
FROM maintenance WHERE id IN (1, 2, 3) ORDER BY id;

-- Задача 1. Все агрегаты и их площадки.
SELECT u.id, u.model, st.name AS station
FROM unit u
JOIN station st ON st.id = u.station_id
ORDER BY st.name, u.id;

-- Задача 2. Число датчиков у каждого агрегата, включая нулевые.
SELECT u.id AS unit_id, COUNT(s.id) AS sensor_count
FROM unit u
LEFT JOIN sensor s ON s.unit_id = u.id
GROUP BY u.id
ORDER BY u.id;

-- Задача 3. Средняя температура по всем temp-датчикам агрегата.
SELECT u.id AS unit_id, ROUND(AVG(t.value), 1) AS avg_temp
FROM unit u
JOIN sensor s ON s.unit_id = u.id AND s.kind = 'temp'
JOIN telemetry t ON t.sensor_id = s.id
GROUP BY u.id
ORDER BY u.id;

-- Задача 4. Только temp-датчики, у которых максимум > 85.
SELECT s.id, s.kind, MAX(t.value) AS max_value
FROM sensor s
JOIN telemetry t ON t.sensor_id = s.id
WHERE s.kind = 'temp'
GROUP BY s.id, s.kind
HAVING MAX(t.value) > 85
ORDER BY s.id;

-- Задача 5. Почасовой профиль температуры подшипника GPA-2 (TE-302).
SELECT date_trunc('hour', t.ts) AS hour,
       ROUND(AVG(t.value), 1) AS avg_temp
FROM telemetry t
JOIN sensor s ON s.id = t.sensor_id
WHERE s.unit_id = 'GPA-2'
  AND s.tag = 'TE-302'
  AND s.kind = 'temp'
GROUP BY date_trunc('hour', t.ts)
ORDER BY hour;

-- Задача 6. Число событий каждого исходного уровня severity по площадкам.
-- Разные варианты написания намеренно показаны раздельно.
SELECT st.name AS station_name, e.severity, COUNT(*) AS cnt
FROM event e
JOIN unit u ON u.id = e.unit_id
JOIN station st ON st.id = u.station_id
GROUP BY st.name, e.severity
ORDER BY st.name, e.severity;

-- Задача 7. Агрегаты, у которых не было alarm/unplanned_stop.
-- Нормализуем регистр и пробелы, иначе пропустим Alarm.
SELECT u.id, u.model
FROM unit u
WHERE NOT EXISTS (
    SELECT 1
    FROM event e
    WHERE e.unit_id = u.id
      AND LOWER(TRIM(e.severity)) IN ('alarm', 'unplanned_stop')
)
ORDER BY u.id;

-- Задача 8*. Последнее измерение каждого датчика с телеметрией.
SELECT DISTINCT ON (t.sensor_id)
       t.sensor_id, t.ts, t.value
FROM telemetry t
ORDER BY t.sensor_id, t.ts DESC;

-- Задача 9*. Часы с ростом средней температуры TE-302 более 5 градусов.
WITH hourly AS (
    SELECT date_trunc('hour', t.ts) AS hour, AVG(t.value) AS avg_temp
    FROM telemetry t
    JOIN sensor s ON s.id = t.sensor_id
    WHERE s.unit_id = 'GPA-2' AND s.tag = 'TE-302'
    GROUP BY date_trunc('hour', t.ts)
), changes AS (
    SELECT hour, avg_temp,
           LAG(avg_temp) OVER (ORDER BY hour) AS prev_avg
    FROM hourly
)
SELECT hour, ROUND(avg_temp, 1) AS avg_temp,
       ROUND(avg_temp - prev_avg, 1) AS rise
FROM changes
WHERE avg_temp - prev_avg > 5
ORDER BY hour;

-- Задача 10*. Первый ремонт того же агрегата в течение 48 ч после остановки.
SELECT e.id AS event_id, e.unit_id, e.ts AS stopped_at,
       m.id AS maintenance_id, m.performed_at,
       ROUND(EXTRACT(EPOCH FROM (m.performed_at - e.ts))::numeric / 3600, 1)
           AS hours_until_repair,
       (m.id IS NOT NULL) AS repaired_within_48h
FROM event e
LEFT JOIN LATERAL (
    SELECT m.id, m.performed_at
    FROM maintenance m
    WHERE m.unit_id = e.unit_id
      AND m.performed_at >= e.ts
      AND m.performed_at <= e.ts + INTERVAL '48 hours'
    ORDER BY m.performed_at, m.id
    LIMIT 1
) m ON TRUE
WHERE LOWER(TRIM(e.severity)) = 'unplanned_stop'
ORDER BY e.ts;

-- Задача 11*. Потенциальные дубли ремонтов (не удаляем строки).
-- Критерий: тот же агрегат и вид работ, даты различаются не более чем на 36 ч.
SELECT a.id AS first_id, b.id AS possible_duplicate_id,
       a.unit_id, a.performed_at AS first_time, b.performed_at AS second_time,
       a.engineer AS first_engineer, b.engineer AS second_engineer,
       a.notes AS first_notes, b.notes AS second_notes
FROM maintenance a
JOIN maintenance b
  ON a.unit_id = b.unit_id
 AND a.work_type = b.work_type
 AND a.id < b.id
 AND ABS(EXTRACT(EPOCH FROM (a.performed_at - b.performed_at))) <= 36 * 3600
ORDER BY a.id, b.id;
