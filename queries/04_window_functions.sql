-- =====================================================================
-- 04. Оконные функции и CTE
-- База: dvdrental (учебная БД PostgreSQL)
-- =====================================================================

SET search_path TO public;


-- ---------------------------------------------------------------------
-- 4.1. Для каждого платежа четыре оконных показателя:
--      сквозной номер по дате; номер внутри покупателя по дате;
--      нарастающая сумма платежей покупателя (по дате, затем по сумме);
--      ранг платежа внутри покупателя по убыванию суммы (равные суммы — равный ранг).
-- Техники: ROW_NUMBER, SUM() OVER с ORDER BY (нарастающий итог), DENSE_RANK,
--          PARTITION BY
-- ---------------------------------------------------------------------
SELECT
    payment_id, payment_date, customer_id, amount,
    ROW_NUMBER() OVER (ORDER BY payment_date),
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY payment_date),
    SUM(amount)  OVER (PARTITION BY customer_id ORDER BY payment_date, amount),
    DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY amount DESC)
FROM payment
ORDER BY payment_id;


-- ---------------------------------------------------------------------
-- 4.2. Рядом с каждым платежом покупателя — размер его предыдущего платежа
--      (для первого платежа — 0.0).
-- Техники: LAG со значением по умолчанию
-- ---------------------------------------------------------------------
SELECT
    payment_id, payment_date, customer_id, amount,
    LAG(amount, 1, 0.0) OVER (PARTITION BY customer_id ORDER BY payment_date)
FROM payment
ORDER BY customer_id, payment_date;


-- ---------------------------------------------------------------------
-- 4.3. Насколько следующий платёж покупателя отличается от текущего.
-- Техники: LEAD, арифметика над оконной функцией
-- ---------------------------------------------------------------------
SELECT
    payment_id, payment_date, customer_id, amount,
    LEAD(amount) OVER (PARTITION BY customer_id ORDER BY payment_date),
    amount - LEAD(amount) OVER (PARTITION BY customer_id ORDER BY payment_date)
FROM payment
ORDER BY customer_id, payment_date;


-- ---------------------------------------------------------------------
-- 4.4. Последний платёж каждого покупателя (все поля таблицы платежей).
-- Техники: CTE, ROW_NUMBER с сортировкой DESC, фильтр по номеру строки
-- ---------------------------------------------------------------------
WITH cte AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY payment_date DESC) AS rn
    FROM payment
)
SELECT
    payment_id,
    customer_id,
    staff_id,
    rental_id,
    amount,
    payment_date
FROM cte
WHERE rn = 1
ORDER BY customer_id;


-- ---------------------------------------------------------------------
-- 4.5. Продажи каждого сотрудника по дням за август 2005 года
--      и нарастающий итог по дням.
-- Техники: оконная функция поверх агрегата SUM(SUM(...)) OVER,
--          ROWS UNBOUNDED PRECEDING, группировка по дате без времени (::date)
-- ---------------------------------------------------------------------
SELECT
    CONCAT(s.first_name, ' ', s.last_name) AS full_name,
    SUM(p.amount),
    SUM(SUM(p.amount)) OVER (
        PARTITION BY s.staff_id
        ORDER BY DATE(p.payment_date)
        ROWS UNBOUNDED PRECEDING
    )
FROM staff s
JOIN payment p ON s.staff_id = p.staff_id
WHERE p.payment_date >= '2005-08-01'
  AND p.payment_date < '2005-09-01'
GROUP BY s.staff_id, p.payment_date::date
ORDER BY full_name, p.payment_date::date;


-- ---------------------------------------------------------------------
-- 4.6. Акция 20.08.2005: скидку получал автор каждого сотого платежа за день.
--      Кто из покупателей получил скидку?
-- Техники: ROW_NUMBER в подзапросе, остаток от деления (%), DISTINCT
-- ---------------------------------------------------------------------
SELECT DISTINCT
    t.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS full_name
FROM (
    SELECT
        customer_id,
        ROW_NUMBER() OVER (ORDER BY payment_date) AS rn
    FROM payment
    WHERE payment_date::date = '2005-08-20'
) t
JOIN customer c ON t.customer_id = c.customer_id
WHERE rn % 100 = 0
ORDER BY customer_id;


-- ---------------------------------------------------------------------
-- 4.7. Для каждой страны три покупателя: больше всех аренд; наибольшая
--      сумма платежей; самая поздняя аренда. При равенстве выводится один.
-- ---------------------------------------------------------------------

-- Вариант A.
-- Техники: CTE, три ROW_NUMBER по агрегатам в одном проходе (детерминированный
--          tie-break по customer_id), условная агрегация MAX(CASE WHEN ...)
WITH cte AS (
    SELECT
        co.country,
        CONCAT(cu.first_name, ' ', cu.last_name) AS full_name,
        ROW_NUMBER() OVER (PARTITION BY co.country ORDER BY COUNT(r.rental_id) DESC, cu.customer_id) AS rn_count,
        ROW_NUMBER() OVER (PARTITION BY co.country ORDER BY SUM(p.amount) DESC, cu.customer_id)      AS rn_amount,
        ROW_NUMBER() OVER (PARTITION BY co.country ORDER BY MAX(r.rental_date) DESC, cu.customer_id) AS rn_last
    FROM customer cu
    JOIN address a      ON cu.address_id = a.address_id
    JOIN city ci        ON a.city_id = ci.city_id
    JOIN country co     ON ci.country_id = co.country_id
    LEFT JOIN rental r  ON cu.customer_id = r.customer_id
    LEFT JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY co.country, cu.customer_id
)
SELECT
    country,
    MAX(CASE WHEN rn_count = 1 THEN full_name END),
    MAX(CASE WHEN rn_amount = 1 THEN full_name END),
    MAX(CASE WHEN rn_last = 1 THEN full_name END)
FROM cte
GROUP BY country
ORDER BY country;

-- Вариант B.
-- Техники: FIRST_VALUE по агрегатам + SELECT DISTINCT для схлопывания строк
SELECT DISTINCT
    co.country_id,
    co.country AS "название страны",
    FIRST_VALUE(c.last_name || ' ' || c.first_name) OVER (PARTITION BY co.country_id ORDER BY COUNT(i.film_id) DESC),
    FIRST_VALUE(c.last_name || ' ' || c.first_name) OVER (PARTITION BY co.country_id ORDER BY SUM(p.amount) DESC),
    FIRST_VALUE(c.last_name || ' ' || c.first_name) OVER (PARTITION BY co.country_id ORDER BY MAX(r.rental_date) DESC)
FROM country co
JOIN city ci          ON co.country_id = ci.country_id
JOIN address a        ON ci.city_id = a.city_id
LEFT JOIN customer c  ON a.address_id = c.address_id
LEFT JOIN rental r    ON c.customer_id = r.customer_id
LEFT JOIN inventory i ON r.inventory_id = i.inventory_id
LEFT JOIN payment p   ON r.rental_id = p.rental_id
GROUP BY co.country_id, c.customer_id
ORDER BY country;
