-- =====================================================================
-- Итоговый проект курса «SQL и получение данных»
-- Аналитика проектной компании: проекты, сотрудники, платежи, оргструктура.
-- База: учебная БД курса (схема описана в README, дамп не публикуется).
-- =====================================================================


-- ---------------------------------------------------------------------
-- F1. Сколько проектов подписано в 2023 году? (одно число)
-- Техники: COUNT, EXTRACT(YEAR ...)
-- ---------------------------------------------------------------------
SELECT COUNT(*)
FROM project
WHERE EXTRACT(YEAR FROM sign_date) = 2023;


-- ---------------------------------------------------------------------
-- F2. Суммарный возраст всех сотрудников, нанятых в 2022 году, одним
--     значением вида «... years ... months ... days»
--     (условие: не более двух функций для работы с датами).
-- Техники: AGE (возвращает interval), SUM по interval, JOIN
-- ---------------------------------------------------------------------
SELECT SUM(AGE(birthdate))
FROM employee e
JOIN person p ON e.person_id = p.person_id
WHERE EXTRACT(YEAR FROM e.hire_date) = 2022;


-- ---------------------------------------------------------------------
-- F3. Работающий сотрудник с фамилией на «М» длиной ровно 8 букв и самым
--     большим стажем; при равенстве — один случайный.
--     Вывод: «Имя Фамилия» и дата найма.
-- Техники: ILIKE, LENGTH, ORDER BY с RANDOM() как tie-break, LIMIT
-- ---------------------------------------------------------------------
SELECT
    CONCAT(p.first_name, ' ', p.last_name) AS full_name,
    e.hire_date
FROM employee e
JOIN person p ON e.person_id = p.person_id
WHERE p.last_name ILIKE 'м%'
  AND LENGTH(p.last_name) = 8
  AND e.dismissal_date IS NULL
ORDER BY e.hire_date ASC, RANDOM()
LIMIT 1;


-- ---------------------------------------------------------------------
-- F4. Средний возраст (полных лет) уволенных сотрудников, которые не
--     участвуют ни в одном проекте (ни как исполнители, ни как руководители).
--     Если данных нет — вернуть 0.
-- Техники: NOT EXISTS, пересечение массивов (&&), AGE + EXTRACT, COALESCE
-- ---------------------------------------------------------------------
SELECT COALESCE(AVG(EXTRACT(YEAR FROM AGE(current_date, p.birthdate))), 0)
FROM employee e
JOIN person p ON e.person_id = p.person_id
WHERE e.dismissal_date IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM project prj
      WHERE prj.employees_id && ARRAY[e.employee_id]
         OR prj.project_manager_id = e.employee_id
  );


-- ---------------------------------------------------------------------
-- F5. Сколько всего фактически получено платежей от контрагентов
--     из города Жуковский (Россия)? (одно число)
-- Техники: цепочка JOIN по шести таблицам, фильтр по фактической оплате
-- ---------------------------------------------------------------------
SELECT SUM(amount)
FROM project_payment pp
JOIN project pr  ON pp.project_id = pr.project_id
JOIN customer c  ON pr.customer_id = c.customer_id
JOIN address a   ON c.address_id = a.address_id
JOIN city ci     ON a.city_id = ci.city_id
JOIN country co  ON ci.country_id = co.country_id
WHERE ci.city_name = 'Жуковский'
  AND co.country_name = 'Россия'
  AND pp.fact_transaction_timestamp IS NOT NULL;


-- ---------------------------------------------------------------------
-- F6. Руководитель проекта получает премию 1% от стоимости завершённых
--     проектов. Кто получит наибольшую премию? Вывести id, ФИО и размер
--     премии; при равенстве — всех.
-- Техники: CTE, агрегация, сравнение с MAX через подзапрос (сохраняет «ничьи»)
-- ---------------------------------------------------------------------
WITH cte AS (
    SELECT
        p.project_manager_id,
        p1.full_fio,
        SUM(p.project_cost * 0.01) AS bonus
    FROM project p
    JOIN employee e ON p.project_manager_id = e.employee_id
    JOIN person p1  ON e.person_id = p1.person_id
    WHERE p.status = 'Завершен'
    GROUP BY p.project_manager_id, p1.full_fio
)
SELECT project_manager_id, full_fio, bonus
FROM cte
WHERE bonus = (
    SELECT MAX(bonus)
    FROM cte
);


-- ---------------------------------------------------------------------
-- F7. Нарастающий итог плановых авансовых платежей отдельно внутри каждого
--     месяца. Для каждого месяца найти дату, на которой итог впервые
--     превысил 30 000 000 руб.
-- Техники: SUM() OVER (PARTITION BY DATE_TRUNC('month', ...)), CTE,
--          ROW_NUMBER для выбора первой строки после порога
-- ---------------------------------------------------------------------
WITH cte AS (
    SELECT
        plan_payment_date,
        SUM(amount) OVER (
            PARTITION BY DATE_TRUNC('month', plan_payment_date)
            ORDER BY plan_payment_date
            ROWS UNBOUNDED PRECEDING
        ) AS cumul_amount
    FROM project_payment
    WHERE payment_type = 'Авансовый'
)
SELECT plan_payment_date, cumul_amount
FROM (
    SELECT
        plan_payment_date,
        cumul_amount,
        ROW_NUMBER() OVER (PARTITION BY DATE_TRUNC('month', plan_payment_date) ORDER BY plan_payment_date) AS rn
    FROM cte
    WHERE cumul_amount > 30000000
) t
WHERE rn = 1;


-- ---------------------------------------------------------------------
-- F8. Фонд фактических окладов (оклад × ставка) подразделения с id = 17
--     вместе со всеми вложенными подразделениями. (одно число)
-- Техники: рекурсивный CTE (WITH RECURSIVE) по иерархии parent_id -> unit_id
-- ---------------------------------------------------------------------
WITH RECURSIVE r AS (
    SELECT *, 0 AS level
    FROM company_structure
    WHERE unit_id = 17
    UNION
    SELECT cs.*, r.level + 1 AS level
    FROM r
    JOIN company_structure cs ON r.unit_id = cs.parent_id
)
SELECT SUM(ep.salary * ep.rate)
FROM r
JOIN position p           ON r.unit_id = p.unit_id
JOIN employee_position ep ON p.position_id = ep.position_id;


-- ---------------------------------------------------------------------
-- F9. Одним запросом: пронумеровать фактические платежи внутри каждого года
--     по дате; оставить платежи с номером, кратным 5; посчитать по ним
--     скользящее среднее (окно: 2 строки до и 2 после) и сумму этих средних.
--     Вывести годы, в которых суммарная стоимость подписанных проектов
--     меньше этой суммы.
-- Техники: несколько CTE, ROW_NUMBER с PARTITION BY годом, остаток от деления,
--          AVG() OVER (ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING), CROSS JOIN
-- ---------------------------------------------------------------------
WITH cte1 AS (
    -- Нумерация, фильтрация, скользящее среднее
    SELECT
        AVG(amount) OVER (
            ORDER BY fact_transaction_timestamp
            ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
        ) AS moving_avg
    FROM (
        SELECT
            amount,
            fact_transaction_timestamp,
            ROW_NUMBER() OVER (
                PARTITION BY EXTRACT(YEAR FROM fact_transaction_timestamp)
                ORDER BY fact_transaction_timestamp
            ) AS rn
        FROM project_payment
        WHERE fact_transaction_timestamp IS NOT NULL
    ) t
    WHERE rn % 5 = 0
),
cte2 AS (
    -- Сумма стоимости проектов по годам подписания
    SELECT
        EXTRACT(YEAR FROM sign_date) AS project_year,
        SUM(project_cost)            AS total_project_cost
    FROM project
    WHERE sign_date IS NOT NULL
    GROUP BY EXTRACT(YEAR FROM sign_date)
)
SELECT
    project_year,
    total_project_cost
FROM cte2
CROSS JOIN (
    SELECT SUM(moving_avg) AS total_moving_avg
    FROM cte1
) t1
WHERE total_project_cost < total_moving_avg;


-- ---------------------------------------------------------------------
-- F10. Материализованное представление-отчёт по проектам: id и название
--      проекта, дата и сумма последней фактической оплаты, ФИО руководителя,
--      контрагент и список типов работ контрагента одной строкой.
-- Техники: CREATE MATERIALIZED VIEW, несколько CTE, STRING_AGG,
--          ROW_NUMBER для «последней записи», LEFT JOIN, REFRESH
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW project_report AS
WITH aggregated_work_types AS (
    SELECT
        c.customer_id,
        STRING_AGG(tow.type_of_work_name, ', ') AS work_types_list
    FROM customer c
    LEFT JOIN customer_type_of_work ct ON c.customer_id = ct.customer_id
    LEFT JOIN type_of_work tow         ON ct.type_of_work_id = tow.type_of_work_id
    GROUP BY c.customer_id
),
latest_payments AS (
    SELECT
        project_id,
        amount,
        fact_transaction_timestamp,
        ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY fact_transaction_timestamp DESC) AS rn
    FROM project_payment
    WHERE fact_transaction_timestamp IS NOT NULL
)
SELECT
    p.project_id,
    p.project_name,
    lp.fact_transaction_timestamp AS last_payment_date,
    lp.amount                     AS last_payment_amount,
    pers.full_fio                 AS manager_full_name,
    c.customer_name,
    awt.work_types_list
FROM project p
JOIN customer c                       ON p.customer_id = c.customer_id
LEFT JOIN latest_payments lp          ON p.project_id = lp.project_id AND lp.rn = 1
LEFT JOIN employee emp                ON p.project_manager_id = emp.employee_id
LEFT JOIN person pers                 ON emp.person_id = pers.person_id
LEFT JOIN aggregated_work_types awt   ON c.customer_id = awt.customer_id;

REFRESH MATERIALIZED VIEW project_report;
