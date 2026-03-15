--
-- PostgreSQL database dump
--

\restrict FdtBQOmV726738QqF8GTp6rqM2FYEfsWPtZ5i7hFHGOdjJU2VBswJYbp649d3Tx

-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bulochkin_staffs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bulochkin_staffs (
    user_id integer NOT NULL,
    login text NOT NULL,
    password_hash text NOT NULL,
    full_name text,
    is_admin boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: bulochkin_staffs_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bulochkin_staffs_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bulochkin_staffs_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bulochkin_staffs_user_id_seq OWNED BY public.bulochkin_staffs.user_id;


--
-- Name: disposal_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disposal_items (
    disposal_item_id integer NOT NULL,
    disposal_id bigint,
    product_id bigint,
    quantity numeric(10,2) NOT NULL,
    CONSTRAINT disposal_items_quantity_check CHECK ((quantity >= (0)::numeric))
);


--
-- Name: disposal_items_archive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disposal_items_archive (
    archive_item_id integer NOT NULL,
    disposal_id integer NOT NULL,
    product_name text NOT NULL,
    category_name text NOT NULL,
    measure_name text NOT NULL,
    point_name text NOT NULL,
    quantity numeric(10,2) NOT NULL,
    disposal_date date NOT NULL,
    CONSTRAINT disposal_items_archive_quantity_check CHECK ((quantity >= (0)::numeric))
);


--
-- Name: disposal_items_archive_archive_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.disposal_items_archive_archive_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: disposal_items_archive_archive_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.disposal_items_archive_archive_item_id_seq OWNED BY public.disposal_items_archive.archive_item_id;


--
-- Name: disposal_items_disposal_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.disposal_items_disposal_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: disposal_items_disposal_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.disposal_items_disposal_item_id_seq OWNED BY public.disposal_items.disposal_item_id;


--
-- Name: disposals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disposals (
    disposal_id integer NOT NULL,
    point_id integer,
    disposal_date date NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'Черновик'::text
);


--
-- Name: disposals_disposal_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.disposals_disposal_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: disposals_disposal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.disposals_disposal_id_seq OWNED BY public.disposals.disposal_id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    order_item_id integer NOT NULL,
    order_id bigint,
    product_id bigint,
    quantity numeric(10,2) NOT NULL,
    CONSTRAINT order_items_quantity_check CHECK ((quantity >= (0)::numeric))
);


--
-- Name: order_items_archive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items_archive (
    archive_item_id integer NOT NULL,
    order_id integer NOT NULL,
    product_name text NOT NULL,
    category_name text NOT NULL,
    point_name text NOT NULL,
    measure_name text NOT NULL,
    quantity numeric(10,2) NOT NULL,
    order_date date NOT NULL,
    CONSTRAINT order_items_archive_quantity_check CHECK ((quantity >= (0)::numeric))
);


--
-- Name: order_items_archive_archive_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_items_archive_archive_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_items_archive_archive_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_items_archive_archive_item_id_seq OWNED BY public.order_items_archive.archive_item_id;


--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_items_order_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_items_order_item_id_seq OWNED BY public.order_items.order_item_id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    order_id integer NOT NULL,
    point_id integer,
    order_date date NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'Черновик'::text
);


--
-- Name: orders_order_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_order_id_seq OWNED BY public.orders.order_id;


--
-- Name: points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.points (
    point_id integer NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: points_point_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.points_point_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: points_point_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.points_point_id_seq OWNED BY public.points.point_id;


--
-- Name: product_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_categories (
    product_category_id integer NOT NULL,
    name text NOT NULL
);


--
-- Name: product_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.product_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.product_categories_id_seq OWNED BY public.product_categories.product_category_id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    product_id integer NOT NULL,
    product_category_id bigint,
    name text NOT NULL,
    is_active boolean DEFAULT true,
    measure_id smallint,
    sort_order integer DEFAULT 0
);


--
-- Name: products_product_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.products_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.products_product_id_seq OWNED BY public.products.product_id;


--
-- Name: staff_points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_points (
    user_id bigint NOT NULL,
    point_id bigint NOT NULL
);


--
-- Name: unit_of_measure; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unit_of_measure (
    measure_id integer NOT NULL,
    name text NOT NULL
);


--
-- Name: unit_of_measure_measure_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.unit_of_measure_measure_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: unit_of_measure_measure_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.unit_of_measure_measure_id_seq OWNED BY public.unit_of_measure.measure_id;


--
-- Name: bulochkin_staffs user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulochkin_staffs ALTER COLUMN user_id SET DEFAULT nextval('public.bulochkin_staffs_user_id_seq'::regclass);


--
-- Name: disposal_items disposal_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disposal_items ALTER COLUMN disposal_item_id SET DEFAULT nextval('public.disposal_items_disposal_item_id_seq'::regclass);


--
-- Name: disposal_items_archive archive_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disposal_items_archive ALTER COLUMN archive_item_id SET DEFAULT nextval('public.disposal_items_archive_archive_item_id_seq'::regclass);


--
-- Name: disposals disposal_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disposals ALTER COLUMN disposal_id SET DEFAULT nextval('public.disposals_disposal_id_seq'::regclass);


--
-- Name: order_items order_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items ALTER COLUMN order_item_id SET DEFAULT nextval('public.order_items_order_item_id_seq'::regclass);


--
-- Name: order_items_archive archive_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items_archive ALTER COLUMN archive_item_id SET DEFAULT nextval('public.order_items_archive_archive_item_id_seq'::regclass);


--
-- Name: orders order_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN order_id SET DEFAULT nextval('public.orders_order_id_seq'::regclass);


--
-- Name: points point_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.points ALTER COLUMN point_id SET DEFAULT nextval('public.points_point_id_seq'::regclass);


--
-- Name: product_categories product_category_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories ALTER COLUMN product_category_id SET DEFAULT nextval('public.product_categories_id_seq'::regclass);


--
-- Name: products product_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products ALTER COLUMN product_id SET DEFAULT nextval('public.products_product_id_seq'::regclass);


--
-- Name: unit_of_measure measure_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_of_measure ALTER COLUMN measure_id SET DEFAULT nextval('public.unit_of_measure_measure_id_seq'::regclass);


--
-- Data for Name: bulochkin_staffs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bulochkin_staffs (user_id, login, password_hash, full_name, is_admin, created_at) FROM stdin;
1	boss	1234	Смирнова Елена Владимировна	t	2026-03-13 20:29:56.613621+00
\.


--
-- Data for Name: disposal_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.disposal_items (disposal_item_id, disposal_id, product_id, quantity) FROM stdin;
\.


--
-- Data for Name: disposal_items_archive; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.disposal_items_archive (archive_item_id, disposal_id, product_name, category_name, measure_name, point_name, quantity, disposal_date) FROM stdin;
\.


--
-- Data for Name: disposals; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.disposals (disposal_id, point_id, disposal_date, created_at, status) FROM stdin;
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.order_items (order_item_id, order_id, product_id, quantity) FROM stdin;
\.


--
-- Data for Name: order_items_archive; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.order_items_archive (archive_item_id, order_id, product_name, category_name, point_name, measure_name, quantity, order_date) FROM stdin;
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.orders (order_id, point_id, order_date, created_at, status) FROM stdin;
\.


--
-- Data for Name: points; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.points (point_id, name, is_active, created_at) FROM stdin;
1	Поляна	t	2026-03-13 20:30:32.934516+00
2	Южный	t	2026-03-13 20:30:32.934516+00
3	Ленина	t	2026-03-13 20:30:32.934516+00
4	Магнит	t	2026-03-13 20:30:32.934516+00
5	Катюшки	t	2026-03-13 20:30:32.934516+00
6	Химки_1	t	2026-03-13 20:30:32.934516+00
7	Химки_2	t	2026-03-13 20:30:32.934516+00
8	Мелодия	t	2026-03-13 20:30:32.934516+00
9	Химки_Новые	t	2026-03-13 20:30:32.934516+00
10	Фермер	t	2026-03-13 20:30:32.934516+00
11	Химки_5	t	2026-03-13 20:30:32.934516+00
12	Долгопрудный	t	2026-03-13 20:30:32.934516+00
13	Булошная	t	2026-03-13 20:30:32.934516+00
\.


--
-- Data for Name: product_categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_categories (product_category_id, name) FROM stdin;
1	Выпечка
2	Сдоба
3	Хлеб
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.products (product_id, product_category_id, name, is_active, measure_id, sort_order) FROM stdin;
1	3	Монастырский	t	2	1
2	3	Пеклеванный	t	2	2
3	3	Саечка	t	2	3
4	3	Багет Французский	t	2	4
5	2	Тесто для пирожков	t	2	1
6	2	Ватрушка Венгерская	t	2	2
7	2	Гребешок с малиной	t	2	3
8	1	Бублик	t	2	1
9	1	Векошник	t	2	2
10	1	Курник	t	2	3
\.


--
-- Data for Name: staff_points; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.staff_points (user_id, point_id) FROM stdin;
\.


--
-- Data for Name: unit_of_measure; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.unit_of_measure (measure_id, name) FROM stdin;
1	кг
2	шт
3	упак
\.


--
-- Name: bulochkin_staffs_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bulochkin_staffs_user_id_seq', 1, true);


--
-- Name: disposal_items_archive_archive_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.disposal_items_archive_archive_item_id_seq', 1, false);


--
-- Name: disposal_items_disposal_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.disposal_items_disposal_item_id_seq', 1, false);


--
-- Name: disposals_disposal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.disposals_disposal_id_seq', 1, false);


--
-- Name: order_items_archive_archive_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.order_items_archive_archive_item_id_seq', 1, false);


--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.order_items_order_item_id_seq', 1, false);


--
-- Name: orders_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.orders_order_id_seq', 1, false);


--
-- Name: points_point_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.points_point_id_seq', 13, true);


--
-- Name: product_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.product_categories_id_seq', 3, true);


--
-- Name: products_product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.products_product_id_seq', 10, true);


--
-- Name: unit_of_measure_measure_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.unit_of_measure_measure_id_seq', 3, true);


--
-- Name: bulochkin_staffs bulochkin_staffs_login_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulochkin_staffs
    ADD CONSTRAINT bulochkin_staffs_login_key UNIQUE (login);


--
-- Name: bulochkin_staffs bulochkin_staffs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulochkin_staffs
    ADD CONSTRAINT bulochkin_staffs_pkey PRIMARY KEY (user_id);


--
-- Name: disposal_items_archive disposal_items_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disposal_items_archive
    ADD CONSTRAINT disposal_items_archive_pkey PRIMARY KEY (archive_item_id);


--
-- Name: disposal_items disposal_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disposal_items
    ADD CONSTRAINT disposal_items_pkey PRIMARY KEY (disposal_item_id);


--
-- Name: disposals disposals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disposals
    ADD CONSTRAINT disposals_pkey PRIMARY KEY (disposal_id);


--
-- Name: order_items_archive order_items_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items_archive
    ADD CONSTRAINT order_items_archive_pkey PRIMARY KEY (archive_item_id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_item_id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- Name: points points_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.points
    ADD CONSTRAINT points_pkey PRIMARY KEY (point_id);


--
-- Name: product_categories product_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_pkey PRIMARY KEY (product_category_id);


--
-- Name: products products_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_name_unique UNIQUE (name);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- Name: staff_points staff_points_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_points
    ADD CONSTRAINT staff_points_pkey PRIMARY KEY (user_id, point_id);


--
-- Name: unit_of_measure unit_of_measure_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_of_measure
    ADD CONSTRAINT unit_of_measure_pkey PRIMARY KEY (measure_id);


--
-- Name: order_items ux_order_product; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT ux_order_product UNIQUE (order_id, product_id);


--
-- Name: disposal_items_archive disposal_items_archive_disposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disposal_items_archive
    ADD CONSTRAINT disposal_items_archive_disposal_id_fkey FOREIGN KEY (disposal_id) REFERENCES public.disposals(disposal_id) ON DELETE CASCADE;


--
-- Name: disposal_items disposal_items_disposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disposal_items
    ADD CONSTRAINT disposal_items_disposal_id_fkey FOREIGN KEY (disposal_id) REFERENCES public.disposals(disposal_id) ON DELETE CASCADE;


--
-- Name: disposal_items disposal_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disposal_items
    ADD CONSTRAINT disposal_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id);


--
-- Name: disposals disposals_point_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disposals
    ADD CONSTRAINT disposals_point_id_fkey FOREIGN KEY (point_id) REFERENCES public.points(point_id);


--
-- Name: order_items_archive order_items_archive_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items_archive
    ADD CONSTRAINT order_items_archive_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id);


--
-- Name: orders orders_point_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_point_id_fkey FOREIGN KEY (point_id) REFERENCES public.points(point_id);


--
-- Name: products products_measure_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_measure_id_fkey FOREIGN KEY (measure_id) REFERENCES public.unit_of_measure(measure_id);


--
-- Name: products products_product_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_product_category_id_fkey FOREIGN KEY (product_category_id) REFERENCES public.product_categories(product_category_id);


--
-- Name: staff_points staff_points_point_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_points
    ADD CONSTRAINT staff_points_point_id_fkey FOREIGN KEY (point_id) REFERENCES public.points(point_id) ON DELETE CASCADE;


--
-- Name: staff_points staff_points_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_points
    ADD CONSTRAINT staff_points_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.bulochkin_staffs(user_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict FdtBQOmV726738QqF8GTp6rqM2FYEfsWPtZ5i7hFHGOdjJU2VBswJYbp649d3Tx

