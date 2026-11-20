# SQL на PostgreSQL: от JOIN до оконных функций, CTE и рекурсии

Решения учебных задач по SQL в PostgreSQL, сгруппированные по темам: фильтрация и строковые функции, соединения и агрегация, DDL/DML, оконные функции, pivot, а также итоговый проект с аналитикой проектной компании.

## Задача

Показать уверенное владение SQL для аналитики: выборка и фильтрация, соединения нескольких таблиц, агрегация и подзапросы, проектирование таблиц с ограничениями, оконные функции, CTE (в том числе рекурсивные) и материализованные представления. Каждый запрос снабжён комментарием: какой вопрос он решает и какие приёмы использует.

## Данные

- **Скрипты 01–04** (`queries/`) — публичная учебная база **dvdrental** (DVD-прокат: фильмы, покупатели, аренды, платежи, магазины, сотрудники; аналог Pagila). Скачивание и описание схемы: [PostgreSQL Sample Database](https://neon.com/postgresql/getting-started/sample-database).
- **Pivot** (`queries/05`) — самостоятельный пример, таблица с условными данными создаётся в самом скрипте.
- **Итоговый проект** (`final_project/`) — учебная БД курса (Нетология) о проектной компании. Дамп этой базы не публикуется; ниже приведена схема, восстановленная по запросам.

### Схема БД итогового проекта (по используемым полям)

| Таблица | Используемые поля | Смысл |
|---|---|---|
| `project` | `project_id`, `project_name`, `customer_id`, `project_manager_id`, `employees_id` (массив id), `project_cost`, `status`, `sign_date` | проекты |
| `project_payment` | `project_id`, `payment_type`, `amount`, `plan_payment_date`, `fact_transaction_timestamp` | плановые и фактические платежи по проектам |
| `employee` | `employee_id`, `person_id`, `hire_date`, `dismissal_date` | сотрудники |
| `person` | `person_id`, `first_name`, `last_name`, `full_fio`, `birthdate` | персональные данные |
| `customer` | `customer_id`, `customer_name`, `address_id` | контрагенты (заказчики) |
| `address` → `city` → `country` | `city_id`, `city_name`, `country_id`, `country_name` | география контрагентов |
| `type_of_work`, `customer_type_of_work` | `type_of_work_id`, `type_of_work_name`, `customer_id` | типы работ контрагентов (многие-ко-многим) |
| `company_structure` | `unit_id`, `parent_id` | иерархия подразделений |
| `position`, `employee_position` | `position_id`, `unit_id`, `salary`, `rate` | должности, оклады и ставки |

## Содержание

| Файл | Тема | Ключевые приёмы |
|---|---|---|
| [`queries/01_filtering_and_string_functions.sql`](queries/01_filtering_and_string_functions.sql) | Выборка и фильтрация | `DISTINCT`, `LIKE`, диапазоны дат, `LIMIT` / `FETCH FIRST`, `CONCAT_WS`, `SPLIT_PART`, `UPPER` / `LOWER` / `SUBSTRING` |
| [`queries/02_joins_and_aggregation.sql`](queries/02_joins_and_aggregation.sql) | Соединения и агрегация | `INNER` / `LEFT` / `CROSS JOIN`, `LEFT JOIN LATERAL`, анти-соединение, `GROUP BY` / `HAVING`, подзапросы, `STRING_AGG`, `CASE` |
| [`queries/03_ddl_and_dml.sql`](queries/03_ddl_and_dml.sql) | Проектирование таблиц и изменение данных | `CREATE TABLE`, `PRIMARY` / `FOREIGN KEY`, `UNIQUE`, `CHECK`, `DEFAULT`, связи многие-ко-многим, `INSERT ... SELECT UNNEST`, `UPDATE`, `DELETE` |
| [`queries/04_window_functions.sql`](queries/04_window_functions.sql) | Оконные функции | `ROW_NUMBER`, `DENSE_RANK`, `LAG` / `LEAD`, нарастающие итоги, `SUM(SUM()) OVER`, `FIRST_VALUE`, условная агрегация, CTE |
| [`queries/05_pivot_long_to_wide.sql`](queries/05_pivot_long_to_wide.sql) | Pivot | разворот «ключ — значение» в столбцы через `MAX(CASE WHEN ...)` |
| [`final_project/project_company_analytics.sql`](final_project/project_company_analytics.sql) | Итоговый проект (10 задач) | интервалы и `AGE`, `NOT EXISTS`, операции с массивами, оконные функции с `DATE_TRUNC`, скользящее среднее, `WITH RECURSIVE`, `CREATE MATERIALIZED VIEW` |

Примеры задач итогового проекта:
- премия руководителям — 1% от завершённых проектов, вывод всех лидеров при равенстве;
- первая дата месяца, когда нарастающий итог плановых авансов превысил 30 млн руб.;
- фонд окладов подразделения вместе со всеми вложенными подразделениями (рекурсивный обход иерархии);
- материализованное представление-отчёт по проектам с последней оплатой и типами работ контрагента.

## Что можно улучшить

- Запросы не покрыты автоматическими проверками, результаты выполнения в репозитории не приводятся (кроме примера pivot).
- Для части задач возможны более производительные варианты: например, `DISTINCT ON` вместо `ROW_NUMBER` для выбора «последней записи» или индексы под частые фильтры по датам.
- В задаче 4.7 приведены два варианта решения; при равенстве показателей вариант A выбирает покупателя детерминированно (по `customer_id`), вариант B — произвольно.

## Стек

PostgreSQL, SQL (ANSI + расширения PostgreSQL), DBeaver / psql.

## Как запустить

1. Установить PostgreSQL (12+).
2. Скачать архив `dvdrental.zip` со страницы [PostgreSQL Sample Database](https://neon.com/postgresql/getting-started/sample-database) и распаковать (внутри — `dvdrental.tar`).
3. Создать базу и восстановить дамп:

   ```bash
   createdb -U postgres dvdrental
   pg_restore -U postgres -d dvdrental dvdrental.tar
   ```

4. Выполнять запросы из `queries/` по одному в DBeaver / pgAdmin или целиком через psql:

   ```bash
   psql -U postgres -d dvdrental -f queries/02_joins_and_aggregation.sql
   ```

   Скрипт `03_ddl_and_dml.sql` создаёт таблицы в отдельной схеме `ddl_practice`, `05_pivot_long_to_wide.sql` — таблицу `contacts`; обе можно удалить после проверки (`DROP SCHEMA ddl_practice CASCADE; DROP TABLE contacts;`).

5. Итоговый проект требует учебной БД курса, которая не распространяется публично; запросы приведены как демонстрация решений.

_Проект выполнен в рамках обучения по программе Data Science (Нетология, 2025–2027)._
