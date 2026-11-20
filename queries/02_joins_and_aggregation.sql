-- =====================================================================
-- 02. Соединения таблиц, агрегация и подзапросы
-- База: dvdrental (учебная БД PostgreSQL)
-- =====================================================================

SET search_path TO public;


-- ---------------------------------------------------------------------
-- 2.1. Адрес, город и страна проживания каждого покупателя.
-- Техники: цепочка INNER JOIN по четырём таблицам
-- ---------------------------------------------------------------------
SELECT c.first_name, c.last_name, a.address, c1.city, c2.country
FROM customer c
JOIN address a  ON c.address_id = a.address_id
JOIN city c1    ON a.city_id = c1.city_id
JOIN country c2 ON c1.country_id = c2.country_id;


-- ---------------------------------------------------------------------
-- 2.2. Сколько покупателей прикреплено к каждому магазину?
-- Техники: GROUP BY, COUNT
-- ---------------------------------------------------------------------
SELECT store_id, COUNT(customer_id)
FROM customer
GROUP BY store_id;


-- ---------------------------------------------------------------------
-- 2.3. Только магазины, у которых больше 300 покупателей.
-- Техники: GROUP BY + HAVING (фильтр по агрегату)
-- ---------------------------------------------------------------------
SELECT store_id, COUNT(customer_id)
FROM customer
GROUP BY store_id
HAVING COUNT(customer_id) > 300;


-- ---------------------------------------------------------------------
-- 2.4. Для магазинов с более чем 300 покупателями — город магазина
--      и управляющий (фамилия и имя одной строкой).
-- Техники: агрегирующий подзапрос в FROM, HAVING, JOIN по нескольким таблицам
-- ---------------------------------------------------------------------
SELECT
    CONCAT(s.last_name, ' ', s.first_name) AS full_name,
    st.store_id,
    c.city,
    t.customer_count
FROM (
    SELECT store_id, COUNT(customer_id) AS customer_count
    FROM customer
    GROUP BY store_id
    HAVING COUNT(customer_id) > 300
) AS t
JOIN store st   ON t.store_id = st.store_id
JOIN address a  ON st.address_id = a.address_id
JOIN city c     ON a.city_id = c.city_id
JOIN staff s    ON st.manager_staff_id = s.staff_id;


-- ---------------------------------------------------------------------
-- 2.5. Топ-5 покупателей по числу аренд за всё время.
-- Техники: подзапрос с GROUP BY, ORDER BY и LIMIT, JOIN со справочником
-- ---------------------------------------------------------------------
SELECT
    CONCAT(c.last_name, ' ', c.first_name) AS full_name,
    rc.count_rentals
FROM (
    SELECT
        customer_id,
        COUNT(rental_id) AS count_rentals
    FROM rental
    GROUP BY customer_id
    ORDER BY 2 DESC
    LIMIT 5
) AS rc
JOIN customer c ON rc.customer_id = c.customer_id;


-- ---------------------------------------------------------------------
-- 2.6. Профиль покупателя: число аренд, сумма платежей (округлённая до целого),
--      минимальный и максимальный платёж.
-- Техники: LEFT JOIN к агрегированному подзапросу, COUNT / SUM / MIN / MAX, ROUND
-- ---------------------------------------------------------------------
SELECT
    CONCAT(c.last_name, ' ', c.first_name) AS full_name,
    count_rentals,
    ROUND(total_amount),
    min_amount,
    max_amount
FROM customer c
LEFT JOIN (
    SELECT
        r.customer_id,
        COUNT(r.rental_id) AS count_rentals,
        SUM(p.amount)      AS total_amount,
        MIN(p.amount)      AS min_amount,
        MAX(p.amount)      AS max_amount
    FROM rental r
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY r.customer_id
) t ON c.customer_id = t.customer_id;


-- ---------------------------------------------------------------------
-- 2.7. Все пары городов, в которых названия городов различаются.
-- Техники: декартово произведение (CROSS JOIN) с фильтром
-- ---------------------------------------------------------------------
SELECT c1.city, c2.city
FROM city c1
CROSS JOIN city c2
WHERE c1.city != c2.city;


-- ---------------------------------------------------------------------
-- 2.8. Среднее число дней, за которое каждый покупатель возвращает фильм
--      (с точностью до сотых).
-- Техники: разность timestamp -> EXTRACT(EPOCH ...), AVG, ROUND, подзапрос + JOIN
-- ---------------------------------------------------------------------
SELECT
    CONCAT(c.last_name, ' ', c.first_name) AS full_name,
    t.avg_days
FROM (
    SELECT
        customer_id,
        ROUND(AVG(EXTRACT(EPOCH FROM (return_date - rental_date)) / 86400), 2) AS avg_days
    FROM rental
    WHERE return_date IS NOT NULL
    GROUP BY customer_id
) AS t
JOIN customer c ON t.customer_id = c.customer_id;


-- ---------------------------------------------------------------------
-- 2.9. Сводка по фильму: рейтинг, язык, категории, сколько раз брали в аренду
--      и сколько всего заплатили за аренду.
-- Техники: несколько LEFT JOIN к агрегированным подзапросам,
--          STRING_AGG с ORDER BY, COUNT(DISTINCT ...)
-- ---------------------------------------------------------------------
SELECT
    f.title,
    f.rating,
    l.name,
    fc.category_list,
    f.rental_count,
    f.total_amount
FROM film f
LEFT JOIN language l ON f.language_id = l.language_id
LEFT JOIN (
    SELECT
        fc.film_id,
        STRING_AGG(c.name, ', ' ORDER BY c.name) AS category_list
    FROM film_category fc
    LEFT JOIN category c ON fc.category_id = c.category_id
    GROUP BY fc.film_id
) fc ON f.film_id = fc.film_id
LEFT JOIN (
    SELECT
        i.film_id,
        COUNT(DISTINCT r.rental_id) AS rental_count,
        SUM(p.amount)               AS total_amount
    FROM inventory i
    LEFT JOIN rental r  ON i.inventory_id = r.inventory_id
    LEFT JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY i.film_id
) fs ON f.film_id = fs.film_id
ORDER BY f.title;


-- ---------------------------------------------------------------------
-- 2.10. Та же сводка, но только для фильмов, которых нет в прокате
--       (нет ни одной копии в inventory).
-- Техники: анти-соединение (LEFT JOIN ... WHERE ... IS NULL), LEFT JOIN LATERAL,
--          COALESCE для подстановки нулей
-- ---------------------------------------------------------------------
SELECT
    f.title,
    f.rating,
    l.name,
    fc.category_list,
    COALESCE(f.rental_count, 0) AS "количество аренд фильма",
    COALESCE(f.total_amount, 0) AS "общий размер платежей по фильму"
FROM (
    SELECT
        f.film_id, f.language_id, f.title, f.rating,
        COUNT(DISTINCT r.rental_id) AS rental_count,
        SUM(p.amount)               AS total_amount
    FROM film f
    LEFT JOIN inventory i ON f.film_id = i.film_id
    LEFT JOIN rental r    ON i.inventory_id = r.inventory_id
    LEFT JOIN payment p   ON r.rental_id = p.rental_id
    WHERE i.inventory_id IS NULL
    GROUP BY f.film_id
) f
LEFT JOIN language l ON f.language_id = l.language_id
LEFT JOIN LATERAL (
    SELECT
        fc.film_id,
        STRING_AGG(c.name, ', ' ORDER BY c.name) AS category_list
    FROM film_category fc
    LEFT JOIN category c ON fc.category_id = c.category_id
    WHERE f.film_id = fc.film_id
    GROUP BY fc.film_id
) fc ON TRUE
ORDER BY f.title;


-- ---------------------------------------------------------------------
-- 2.11. Число продаж (платежей) каждого сотрудника и признак премии:
--       «Да», если продаж больше 7300, иначе «Нет».
-- Техники: LEFT JOIN, GROUP BY, CASE WHEN
-- ---------------------------------------------------------------------
SELECT
    CONCAT(s.last_name, ' ', s.first_name) AS full_name,
    COUNT(p.payment_id),
    CASE
        WHEN COUNT(p.payment_id) > 7300 THEN 'Да'
        ELSE 'Нет'
    END AS Премия
FROM staff s
LEFT JOIN payment p ON s.staff_id = p.staff_id
GROUP BY s.staff_id;
