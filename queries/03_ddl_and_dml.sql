-- =====================================================================
-- 03. Проектирование таблиц (DDL) и изменение данных (DML)
-- Выполняется в отдельной схеме, чтобы не пересекаться с одноимёнными
-- таблицами dvdrental (language, country).
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS ddl_practice;
SET search_path TO ddl_practice;


-- ---------------------------------------------------------------------
-- 3.1. Мини-база «языки — народности — страны»: три справочника и две
--      таблицы связей «многие-ко-многим» (по образцу film_actor),
--      по 5 строк в каждой таблице.
--      Справочники: автоинкрементный первичный ключ, название NOT NULL и
--      без дубликатов. Таблицы связей: составной первичный ключ и внешние ключи.
-- Техники: CREATE TABLE, SERIAL, PRIMARY KEY, NOT NULL, UNIQUE, DEFAULT,
--          REFERENCES / FOREIGN KEY, составной PRIMARY KEY, многострочный INSERT
-- ---------------------------------------------------------------------

-- Справочник языков
CREATE TABLE language (
    language_id   SERIAL2 PRIMARY KEY,
    language_name VARCHAR(75) NOT NULL UNIQUE,
    last_update   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO language (language_name) VALUES
    ('Испанский'),
    ('Французский'),
    ('Русский'),
    ('Немецкий'),
    ('Японский');

-- Справочник народностей
CREATE TABLE ethnicity (
    ethnicity_id   SERIAL2 PRIMARY KEY,
    ethnicity_name VARCHAR(50) NOT NULL UNIQUE,
    last_update    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO ethnicity (ethnicity_name) VALUES
    ('Славяне'),
    ('Немцы'),
    ('Французы'),
    ('Японцы'),
    ('Испанцы');

-- Справочник стран
CREATE TABLE country (
    country_id   SERIAL2 PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL UNIQUE,
    last_update  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO country (country_name) VALUES
    ('Россия'),
    ('Япония'),
    ('Германия'),
    ('Франция'),
    ('Испания');

-- Связь «язык — народность» (внешние ключи объявлены на уровне столбцов)
CREATE TABLE language_ethnicity (
    language_id  INT2 NOT NULL REFERENCES language (language_id),
    ethnicity_id INT2 NOT NULL REFERENCES ethnicity (ethnicity_id),
    PRIMARY KEY (language_id, ethnicity_id)
);

INSERT INTO language_ethnicity (language_id, ethnicity_id) VALUES
    (1, 5),
    (2, 3),
    (3, 1),
    (4, 2),
    (5, 4);

-- Связь «народность — страна» (внешние ключи объявлены на уровне таблицы)
CREATE TABLE ethnicity_country (
    ethnicity_id INT2 NOT NULL,
    country_id   INT2 NOT NULL,
    PRIMARY KEY (ethnicity_id, country_id),
    FOREIGN KEY (ethnicity_id) REFERENCES ethnicity (ethnicity_id),
    FOREIGN KEY (country_id) REFERENCES country (country_id)
);

INSERT INTO ethnicity_country (ethnicity_id, country_id) VALUES
    (1, 1),
    (2, 3),
    (3, 4),
    (4, 2),
    (5, 5);


-- ---------------------------------------------------------------------
-- 3.2. Таблица фильмов film_new: название обязательно, год > 0,
--      цена аренды по умолчанию 0.99, длительность обязательна и > 0.
-- Техники: CHECK-ограничения, DEFAULT, NUMERIC(4,2)
-- ---------------------------------------------------------------------
CREATE TABLE film_new (
    film_new_id      SERIAL PRIMARY KEY,
    film_name        VARCHAR(255) NOT NULL,
    film_year        INTEGER CHECK (film_year > 0),
    film_rental_rate NUMERIC(4,2) DEFAULT 0.99,
    film_duration    INTEGER NOT NULL CHECK (film_duration > 0)
);


-- ---------------------------------------------------------------------
-- 3.3. Заполнить film_new пятью фильмами, данные заданы параллельными массивами
--      (название, год, цена, длительность).
-- Техники: INSERT ... SELECT, UNNEST от нескольких массивов
-- ---------------------------------------------------------------------
INSERT INTO film_new (film_name, film_year, film_rental_rate, film_duration)
SELECT *
FROM UNNEST(
    ARRAY['The Shawshank Redemption', 'The Green Mile', 'Back to the Future', 'Forrest Gump', 'Schindlers List'],
    ARRAY[1994, 1999, 1985, 1994, 1993],
    ARRAY[2.99, 0.99, 1.99, 2.99, 3.99],
    ARRAY[142, 189, 116, 142, 195]
);


-- ---------------------------------------------------------------------
-- 3.4. Цена аренды всех фильмов выросла на 1.41.
-- Техники: UPDATE
-- ---------------------------------------------------------------------
UPDATE film_new
SET film_rental_rate = film_rental_rate + 1.41;


-- ---------------------------------------------------------------------
-- 3.5. Фильм «Back to the Future» сняли с проката — удалить его.
-- Техники: DELETE с условием
-- ---------------------------------------------------------------------
DELETE FROM film_new
WHERE film_name = 'Back to the Future'
  AND film_new_id = 3;


-- ---------------------------------------------------------------------
-- 3.6. Добавить ещё один фильм.
-- Техники: INSERT ... VALUES
-- ---------------------------------------------------------------------
INSERT INTO film_new (film_name, film_year, film_rental_rate, film_duration)
VALUES ('The Predator', 1987, 4.4, 104);


-- ---------------------------------------------------------------------
-- 3.7. Все поля film_new плюс длительность в часах, округлённая до десятых.
-- Техники: вычисляемый столбец, деление на 60.0 (без целочисленного деления), ROUND
-- ---------------------------------------------------------------------
SELECT *, ROUND(film_duration / 60.0, 1)
FROM film_new;


-- ---------------------------------------------------------------------
-- 3.8. Удалить таблицу film_new.
-- Техники: DROP TABLE
-- ---------------------------------------------------------------------
DROP TABLE film_new;
