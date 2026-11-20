-- =====================================================================
-- 05. Разворот «длинной» таблицы в «широкую» (pivot)
-- Самостоятельный пример, не зависит от dvdrental. Данные условные.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.1. Таблица контактов хранится в формате «ключ — значение»
--      (одна строка на атрибут). Нужно получить по одной строке на человека
--      со столбцами FIO, Phone, Email.
-- Техники: условная агрегация MAX(CASE WHEN ...) + GROUP BY
-- ---------------------------------------------------------------------

CREATE TABLE contacts (
    Name  VARCHAR(50),
    key   VARCHAR(20),
    value VARCHAR(100)
);

INSERT INTO contacts (Name, key, value) VALUES
    ('Ivanov', 'FIO',   'Иванов Иван Иванович'),
    ('Ivanov', 'Phone', '+(7) 111-111111'),
    ('Ivanov', 'Email', 'ivanov@ivanov.com'),
    ('Petrov', 'FIO',   'Петров Петр Петрович'),
    ('Petrov', 'Phone', '+(7) 222-222222'),
    ('Petrov', 'Email', 'petrov@petrov.com');

SELECT
    Name,
    MAX(CASE WHEN key = 'FIO'   THEN value END) AS FIO,
    MAX(CASE WHEN key = 'Phone' THEN value END) AS Phone,
    MAX(CASE WHEN key = 'Email' THEN value END) AS Email
FROM contacts
GROUP BY Name;

-- Результат:
-- name   | fio                  | phone           | email
-- -------+----------------------+-----------------+------------------
-- Ivanov | Иванов Иван Иванович | +(7) 111-111111 | ivanov@ivanov.com
-- Petrov | Петров Петр Петрович | +(7) 222-222222 | petrov@petrov.com
