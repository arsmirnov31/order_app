--
-- PostgreSQL database dump
--

\restrict d4iKl83Zdy6mhtlgknNiGhvBVhFd26yVUchLjYvDk0fFJdagxxjeqtYZiNlvQBO

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

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: add_info_product_disposal(integer, integer, numeric); Type: PROCEDURE; Schema: public; Owner: flask_user
--

CREATE PROCEDURE public.add_info_product_disposal(IN p_disposal_id integer, IN p_product_id integer, IN p_quantity numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
   	rows_affected INTEGER;
BEGIN
	update disposal_items
	set quantity = p_quantity
	where disposal_id = p_disposal_id 
	  and product_id = p_product_id;

	GET DIAGNOSTICS rows_affected = ROW_COUNT;

	IF rows_affected = 0 THEN
		insert into disposal_items
			(disposal_id, product_id, quantity)
		values (p_disposal_id, p_product_id, p_quantity);
	END IF;
END;
$$;


ALTER PROCEDURE public.add_info_product_disposal(IN p_disposal_id integer, IN p_product_id integer, IN p_quantity numeric) OWNER TO flask_user;

--
-- Name: add_info_product_order(integer, integer, numeric); Type: PROCEDURE; Schema: public; Owner: flask_user
--

CREATE PROCEDURE public.add_info_product_order(IN p_order_id integer, IN p_product_id integer, IN p_quantity numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
   	rows_affected INTEGER;
BEGIN
	update order_items
	set 
		quantity = p_quantity
	,	delivered_quantity = p_quantity
	where order_id = p_order_id 
	  and product_id = p_product_id;

	GET DIAGNOSTICS rows_affected = ROW_COUNT;

	IF rows_affected = 0 THEN
		insert into order_items
			(order_id, product_id, quantity, delivered_quantity)
		values (p_order_id, p_product_id, p_quantity, p_quantity);
	END IF;
END;
$$;


ALTER PROCEDURE public.add_info_product_order(IN p_order_id integer, IN p_product_id integer, IN p_quantity numeric) OWNER TO flask_user;

--
-- Name: add_user(text, text, text, boolean); Type: PROCEDURE; Schema: public; Owner: flask_user
--

CREATE PROCEDURE public.add_user(IN p_login text, IN p_full_name text, IN p_password_text text, IN p_is_admin boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
	if exists (select * from public.bulochkin_staffs where login = p_login) then
		RAISE EXCEPTION 'Логин % уже существует', p_login;
	end if;

	insert into public.bulochkin_staffs 
	(
		login
	,	password_hash
	,	full_name
	,	is_admin
	,	created_at
	,	is_active
	) 
	values
	(
		p_login
	,	crypt(p_password_text, gen_salt('bf'))
	,	p_full_name
	,	p_is_admin
	,	now()
	,	true
	);
	
	
END;
$$;


ALTER PROCEDURE public.add_user(IN p_login text, IN p_full_name text, IN p_password_text text, IN p_is_admin boolean) OWNER TO flask_user;

--
-- Name: auth_login(text, text); Type: FUNCTION; Schema: public; Owner: flask_user
--

CREATE FUNCTION public.auth_login(p_login text, p_password text) RETURNS TABLE(ret_code integer, user_id integer, is_admin boolean)
    LANGUAGE plpgsql
    AS $$
declare
    v_user_id 			int;
    v_password_hash 	text;
    v_is_admin 			boolean;
	v_point_id			int;	
begin
	select
		s.user_id
	,	s.password_hash
	,	s.is_admin
	,	case 
			when s.is_admin = True 
			then 1 else p.point_id 
		end as point_id
	into
		v_user_id
	,	v_password_hash
	,	v_is_admin
	,	v_point_id
	from
		bulochkin_staffs s
		left join staff_points p
			on s.user_id = p.user_id
	where
		lower(s.login) = lower(p_login)
		and is_active = True
	limit
		1;

    if v_user_id is null then
        return query select 1, null::int, null::boolean;
        return;
    end if;

    if v_password_hash <> crypt(p_password, v_password_hash) then
        return query select 2, null::int, null::boolean;
        return; -- Добавлена точка с запятой
    end if; -- Добавлен закрывающий end if

    if v_point_id is null then
        return query select 3, null::int, null::boolean;
        return;
    end if;
	
    return query select 0, v_user_id, v_is_admin;

end;
$$;


ALTER FUNCTION public.auth_login(p_login text, p_password text) OWNER TO flask_user;

--
-- Name: get_current_disposal_products(integer); Type: FUNCTION; Schema: public; Owner: flask_user
--

CREATE FUNCTION public.get_current_disposal_products(p_disposal_id integer) RETURNS TABLE(product_id integer, quantity numeric)
    LANGUAGE plpgsql
    AS $$
begin
    return query
    select
    	oi.product_id
    ,	oi.quantity
	from 
		disposal_items as oi
	where 
		disposal_id = p_disposal_id;

end;
$$;


ALTER FUNCTION public.get_current_disposal_products(p_disposal_id integer) OWNER TO flask_user;

--
-- Name: get_current_order_products(integer); Type: FUNCTION; Schema: public; Owner: flask_user
--

CREATE FUNCTION public.get_current_order_products(p_order_id integer) RETURNS TABLE(product_id integer, quantity numeric)
    LANGUAGE plpgsql
    AS $$
begin
    return query
    select
    	oi.product_id
    ,	oi.quantity
	
	from 
		order_items as oi
	where 
		order_id = p_order_id;

end;
$$;


ALTER FUNCTION public.get_current_order_products(p_order_id integer) OWNER TO flask_user;

--
-- Name: get_disposal_status_id(integer); Type: FUNCTION; Schema: public; Owner: flask_user
--

CREATE FUNCTION public.get_disposal_status_id(p_disposal_id integer) RETURNS TABLE(status_id smallint)
    LANGUAGE plpgsql
    AS $$
begin
	return query 
	select
		d.status_id
	from
		disposals as d
	where
		d.disposal_id = p_disposal_id;
end;
$$;


ALTER FUNCTION public.get_disposal_status_id(p_disposal_id integer) OWNER TO flask_user;

--
-- Name: get_or_create_disposal(integer, integer); Type: FUNCTION; Schema: public; Owner: flask_user
--

CREATE FUNCTION public.get_or_create_disposal(p_point_id integer, p_user_id integer) RETURNS TABLE(disposal_id integer, status_id smallint)
    LANGUAGE plpgsql
    AS $$
declare
    v_disposal_id int;
    v_status_id smallint;
begin

	select
         o.disposal_id
    ,    o.status_id
    into
        v_disposal_id
    ,   v_status_id
    from 
		disposals o
    where 
		o.point_id = p_point_id
		and disposal_date = current_date;

	if v_disposal_id is null then

        insert into disposals
        (
            point_id,
            disposal_date,
            user_id,
            status_id
        )
        values
        (
            p_point_id,
            current_date,
            p_user_id,
            1
        )
        returning disposals.disposal_id, disposals.status_id
        into v_disposal_id, v_status_id;

    end if;

    return query
    select v_disposal_id, v_status_id;

end;
$$;


ALTER FUNCTION public.get_or_create_disposal(p_point_id integer, p_user_id integer) OWNER TO flask_user;

--
-- Name: get_or_create_order(integer, integer); Type: FUNCTION; Schema: public; Owner: flask_user
--

CREATE FUNCTION public.get_or_create_order(p_point_id integer, p_user_id integer) RETURNS TABLE(order_id integer, status_id smallint, order_date date)
    LANGUAGE plpgsql
    AS $$
declare
    v_order_id int;
    v_status_id smallint;
	v_order_date date;
begin
	select
         o.order_id
    ,    o.status_id
	,	 o.order_date
    into
        v_order_id
    ,   v_status_id
	,	v_order_date
    from 
		orders o
    where 
		o.point_id = p_point_id
    --and o.status_id in  (1,2,3,4,5,6)
	and o.order_date = current_date;

	if v_order_id is null then

        insert into orders
        (
            point_id,
            order_date,
            user_id,
            status_id
        )
        values
        (
            p_point_id,
            current_date,
            p_user_id,
            1
        )
        returning 
			orders.order_id
		, 	orders.status_id
		,	orders.order_date
        into v_order_id, v_status_id, v_order_date;

    end if;

    return query
    select v_order_id, v_status_id, v_order_date;

end;
$$;


ALTER FUNCTION public.get_or_create_order(p_point_id integer, p_user_id integer) OWNER TO flask_user;

--
-- Name: get_order_items(integer); Type: FUNCTION; Schema: public; Owner: flask_user
--

CREATE FUNCTION public.get_order_items(p_order_id integer) RETURNS TABLE(product_id integer, product_name text, quantity numeric, delivered_quantity numeric, measure_name text, is_extra_item boolean, product_category_id integer, category_name text)
    LANGUAGE plpgsql
    AS $$
begin
    return query
    select
        oi.product_id
	,	p.name 					as product_name
    ,   oi.quantity
    ,   oi.delivered_quantity
    ,   u.name 					as measure_name
	,	oi.is_extra_item		as is_extra_item
	,	c.product_category_id
	,	c.name 					as category_name
    from 
        orders o
        join order_items oi on o.order_id = oi.order_id
        join products p on oi.product_id = p.product_id
        join public.unit_of_measure u on u.measure_id = p.measure_id
		join public.product_categories c on p.product_category_id = c.product_category_id
    where 
        o.order_id = p_order_id
	order by	
		c.name, p.sort_order
	;
end;
$$;


ALTER FUNCTION public.get_order_items(p_order_id integer) OWNER TO flask_user;

--
-- Name: get_order_products(integer); Type: FUNCTION; Schema: public; Owner: flask_user
--

CREATE FUNCTION public.get_order_products(p_order_id integer) RETURNS TABLE(product_id integer, quantity numeric, delivered_quantity numeric, mesuare_name text)
    LANGUAGE plpgsql
    AS $$
begin
    return query
    select
    	oi.product_id
    ,	oi.quantity
	,	oi.delivered_quantity
	,	u.name 					as mesuare_name
	from 
				orders 					as o 
		join 	order_items 			as oi on o.order_id 	= oi.order_id
		join 	products 				as p on oi.product_id 	= p.product_id
		join 	public.unit_of_measure 	as u on u.measure_id 	= p.measure_id
	where 
			order_id = p_order_id
		and o.status_id >= 3;

end;
$$;


ALTER FUNCTION public.get_order_products(p_order_id integer) OWNER TO flask_user;

--
-- Name: get_order_status_id(integer); Type: FUNCTION; Schema: public; Owner: flask_user
--

CREATE FUNCTION public.get_order_status_id(p_order_id integer) RETURNS TABLE(status_id smallint)
    LANGUAGE plpgsql
    AS $$
begin
	return query 
	select
		o.status_id
	from
		orders as o
	where
		o.order_id = p_order_id;
end;
$$;


ALTER FUNCTION public.get_order_status_id(p_order_id integer) OWNER TO flask_user;

--
-- Name: get_user_points(integer); Type: FUNCTION; Schema: public; Owner: flask_user
--

CREATE FUNCTION public.get_user_points(p_user_id integer) RETURNS TABLE(point_id integer, point_name text)
    LANGUAGE plpgsql
    AS $$
begin
	return query
	select
		sp.point_id
	,	p.name
	from
			public.staff_points as sp
	join	points as p on sp.point_id = p.point_id
	where
			sp.user_id = p_user_id
		and	p.is_Active = true
	order by 
		p.name;
end;
$$;


ALTER FUNCTION public.get_user_points(p_user_id integer) OWNER TO flask_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bulochkin_staffs; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.bulochkin_staffs (
    user_id integer NOT NULL,
    login text NOT NULL,
    password_hash text NOT NULL,
    full_name text,
    is_admin boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.bulochkin_staffs OWNER TO flask_user;

--
-- Name: bulochkin_staffs_user_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.bulochkin_staffs_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bulochkin_staffs_user_id_seq OWNER TO flask_user;

--
-- Name: bulochkin_staffs_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.bulochkin_staffs_user_id_seq OWNED BY public.bulochkin_staffs.user_id;


--
-- Name: disposal_items; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.disposal_items (
    disposal_item_id integer NOT NULL,
    disposal_id integer,
    product_id integer,
    quantity numeric(10,3) NOT NULL,
    CONSTRAINT disposal_items_quantity_check CHECK ((quantity >= (0)::numeric))
);


ALTER TABLE public.disposal_items OWNER TO flask_user;

--
-- Name: disposal_items_archive; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.disposal_items_archive (
    archive_item_id integer NOT NULL,
    disposal_id integer NOT NULL,
    product_name text NOT NULL,
    category_name text NOT NULL,
    measure_name text NOT NULL,
    point_name text NOT NULL,
    quantity numeric(10,3) NOT NULL,
    disposal_date date NOT NULL,
    created_at integer NOT NULL,
    CONSTRAINT disposal_items_archive_quantity_check CHECK ((quantity >= (0)::numeric))
);


ALTER TABLE public.disposal_items_archive OWNER TO flask_user;

--
-- Name: disposal_items_archive_archive_item_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.disposal_items_archive_archive_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.disposal_items_archive_archive_item_id_seq OWNER TO flask_user;

--
-- Name: disposal_items_archive_archive_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.disposal_items_archive_archive_item_id_seq OWNED BY public.disposal_items_archive.archive_item_id;


--
-- Name: disposal_items_disposal_item_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.disposal_items_disposal_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.disposal_items_disposal_item_id_seq OWNER TO flask_user;

--
-- Name: disposal_items_disposal_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.disposal_items_disposal_item_id_seq OWNED BY public.disposal_items.disposal_item_id;


--
-- Name: disposals; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.disposals (
    disposal_id integer NOT NULL,
    point_id integer,
    disposal_date date NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id integer NOT NULL,
    status_id smallint DEFAULT 2 NOT NULL
);


ALTER TABLE public.disposals OWNER TO flask_user;

--
-- Name: disposals_disposal_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.disposals_disposal_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.disposals_disposal_id_seq OWNER TO flask_user;

--
-- Name: disposals_disposal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.disposals_disposal_id_seq OWNED BY public.disposals.disposal_id;


--
-- Name: disposals_status; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.disposals_status (
    status_id smallint,
    name text
);


ALTER TABLE public.disposals_status OWNER TO flask_user;

--
-- Name: order_items; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.order_items (
    order_item_id integer NOT NULL,
    order_id integer,
    product_id integer,
    quantity numeric(10,3) NOT NULL,
    delivered_quantity numeric(10,3),
    is_extra_item boolean,
    CONSTRAINT order_items_quantity_check CHECK ((quantity >= (0)::numeric))
);


ALTER TABLE public.order_items OWNER TO flask_user;

--
-- Name: order_items_archive; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.order_items_archive (
    archive_item_id integer NOT NULL,
    order_id integer NOT NULL,
    product_name text NOT NULL,
    category_name text NOT NULL,
    point_name text NOT NULL,
    measure_name text NOT NULL,
    quantity numeric(10,3) NOT NULL,
    order_date date NOT NULL,
    created_at integer NOT NULL,
    CONSTRAINT order_items_archive_quantity_check CHECK ((quantity >= (0)::numeric))
);


ALTER TABLE public.order_items_archive OWNER TO flask_user;

--
-- Name: order_items_archive_archive_item_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.order_items_archive_archive_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.order_items_archive_archive_item_id_seq OWNER TO flask_user;

--
-- Name: order_items_archive_archive_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.order_items_archive_archive_item_id_seq OWNED BY public.order_items_archive.archive_item_id;


--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.order_items_order_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.order_items_order_item_id_seq OWNER TO flask_user;

--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.order_items_order_item_id_seq OWNED BY public.order_items.order_item_id;


--
-- Name: order_status; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.order_status (
    status_id smallint NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.order_status OWNER TO flask_user;

--
-- Name: order_status_status_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.order_status_status_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.order_status_status_id_seq OWNER TO flask_user;

--
-- Name: order_status_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.order_status_status_id_seq OWNED BY public.order_status.status_id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.orders (
    order_id integer NOT NULL,
    point_id integer,
    order_date date NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id integer NOT NULL,
    status_id smallint NOT NULL
);


ALTER TABLE public.orders OWNER TO flask_user;

--
-- Name: orders_order_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.orders_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_order_id_seq OWNER TO flask_user;

--
-- Name: orders_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.orders_order_id_seq OWNED BY public.orders.order_id;


--
-- Name: points; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.points (
    point_id integer NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    sort_order integer
);


ALTER TABLE public.points OWNER TO flask_user;

--
-- Name: points_point_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.points_point_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.points_point_id_seq OWNER TO flask_user;

--
-- Name: points_point_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.points_point_id_seq OWNED BY public.points.point_id;


--
-- Name: product_categories; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.product_categories (
    product_category_id integer NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer
);


ALTER TABLE public.product_categories OWNER TO flask_user;

--
-- Name: product_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.product_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_categories_id_seq OWNER TO flask_user;

--
-- Name: product_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.product_categories_id_seq OWNED BY public.product_categories.product_category_id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.products (
    product_id integer NOT NULL,
    product_category_id integer,
    name text NOT NULL,
    is_active boolean DEFAULT true,
    measure_id smallint,
    sort_order integer DEFAULT 0
);


ALTER TABLE public.products OWNER TO flask_user;

--
-- Name: products_product_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.products_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_product_id_seq OWNER TO flask_user;

--
-- Name: products_product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.products_product_id_seq OWNED BY public.products.product_id;


--
-- Name: staff_points; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.staff_points (
    user_id integer NOT NULL,
    point_id integer NOT NULL
);


ALTER TABLE public.staff_points OWNER TO flask_user;

--
-- Name: unit_of_measure; Type: TABLE; Schema: public; Owner: flask_user
--

CREATE TABLE public.unit_of_measure (
    measure_id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.unit_of_measure OWNER TO flask_user;

--
-- Name: unit_of_measure_measure_id_seq; Type: SEQUENCE; Schema: public; Owner: flask_user
--

CREATE SEQUENCE public.unit_of_measure_measure_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.unit_of_measure_measure_id_seq OWNER TO flask_user;

--
-- Name: unit_of_measure_measure_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: flask_user
--

ALTER SEQUENCE public.unit_of_measure_measure_id_seq OWNED BY public.unit_of_measure.measure_id;


--
-- Name: v_get_products; Type: VIEW; Schema: public; Owner: flask_user
--

CREATE VIEW public.v_get_products AS
 SELECT c.product_category_id,
    c.name AS category_name,
    p.product_id,
    p.name AS product_name,
    u.name AS measure_name,
    p.is_active,
    p.sort_order,
    c.sort_order AS category_order
   FROM ((public.products p
     JOIN public.product_categories c ON ((c.product_category_id = p.product_category_id)))
     JOIN public.unit_of_measure u ON ((u.measure_id = p.measure_id)))
  WHERE (c.is_active = true)
  ORDER BY c.name, p.sort_order;


ALTER VIEW public.v_get_products OWNER TO flask_user;

--
-- Name: bulochkin_staffs user_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.bulochkin_staffs ALTER COLUMN user_id SET DEFAULT nextval('public.bulochkin_staffs_user_id_seq'::regclass);


--
-- Name: disposal_items disposal_item_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposal_items ALTER COLUMN disposal_item_id SET DEFAULT nextval('public.disposal_items_disposal_item_id_seq'::regclass);


--
-- Name: disposal_items_archive archive_item_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposal_items_archive ALTER COLUMN archive_item_id SET DEFAULT nextval('public.disposal_items_archive_archive_item_id_seq'::regclass);


--
-- Name: disposals disposal_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposals ALTER COLUMN disposal_id SET DEFAULT nextval('public.disposals_disposal_id_seq'::regclass);


--
-- Name: order_items order_item_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_items ALTER COLUMN order_item_id SET DEFAULT nextval('public.order_items_order_item_id_seq'::regclass);


--
-- Name: order_items_archive archive_item_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_items_archive ALTER COLUMN archive_item_id SET DEFAULT nextval('public.order_items_archive_archive_item_id_seq'::regclass);


--
-- Name: order_status status_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_status ALTER COLUMN status_id SET DEFAULT nextval('public.order_status_status_id_seq'::regclass);


--
-- Name: orders order_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.orders ALTER COLUMN order_id SET DEFAULT nextval('public.orders_order_id_seq'::regclass);


--
-- Name: points point_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.points ALTER COLUMN point_id SET DEFAULT nextval('public.points_point_id_seq'::regclass);


--
-- Name: product_categories product_category_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.product_categories ALTER COLUMN product_category_id SET DEFAULT nextval('public.product_categories_id_seq'::regclass);


--
-- Name: products product_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.products ALTER COLUMN product_id SET DEFAULT nextval('public.products_product_id_seq'::regclass);


--
-- Name: unit_of_measure measure_id; Type: DEFAULT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.unit_of_measure ALTER COLUMN measure_id SET DEFAULT nextval('public.unit_of_measure_measure_id_seq'::regclass);


--
-- Data for Name: bulochkin_staffs; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.bulochkin_staffs (user_id, login, password_hash, full_name, is_admin, created_at, is_active) FROM stdin;
1	boss	$2a$06$ZgWE0/ibPxmS34Oz0eg2luZ3ftwFgcqep/asM2OGCOAbdjuRkjYTe	Смирнова Елена Владимировна	t	2026-03-13 20:29:56.613621+00	t
2	sav	$2a$06$FD7mnhq6Rs1xvyVfIANYMuU1It3DoKQykgiVMfgdt3x4p6rR2j92q	Смирнов Артём Владимирович	f	2026-03-15 07:57:27.939813+00	t
4	ivs	$2a$06$txvRAOy1KvNoMuRfNuFWXen3uBUe7TfVke7IXkY/HOcmcOzqjdNsG	Игорь Владимирович Смирнов	f	2026-04-13 19:55:08.540118+00	t
3	see	$2a$06$q0cqz/pSOPRxZtmMIGoM1uPFtoXV23I7M4JEUHM8jkOhSKu.DrTNS	Смирнова Евгения Евгеньевна	f	2026-03-15 07:57:42.544517+00	t
\.


--
-- Data for Name: disposal_items; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.disposal_items (disposal_item_id, disposal_id, product_id, quantity) FROM stdin;
19	7	18	2.000
22	7	20	1.000
23	7	72	0.123
21	7	90	0.440
\.


--
-- Data for Name: disposal_items_archive; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.disposal_items_archive (archive_item_id, disposal_id, product_name, category_name, measure_name, point_name, quantity, disposal_date, created_at) FROM stdin;
\.


--
-- Data for Name: disposals; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.disposals (disposal_id, point_id, disposal_date, created_at, user_id, status_id) FROM stdin;
7	17	2026-04-19	2026-04-19 16:01:36.641145+00	2	4
\.


--
-- Data for Name: disposals_status; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.disposals_status (status_id, name) FROM stdin;
1	Новый пустое списание
2	Списание в  процессе создания
3	Списание отправлено на утверждение
4	Списание подтверждено
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.order_items (order_item_id, order_id, product_id, quantity, delivered_quantity, is_extra_item) FROM stdin;
458	57	18	123.000	123.000	\N
459	57	19	1.000	1.000	\N
460	57	20	3.000	3.000	\N
461	57	21	1.000	1.000	\N
462	57	22	12.000	12.000	\N
463	57	23	34.000	34.000	\N
464	57	24	123.000	123.000	\N
465	57	25	2.000	2.000	\N
466	57	26	12.000	12.000	\N
467	57	27	4.000	4.000	\N
468	57	28	123.000	123.000	\N
469	57	29	1.000	1.000	\N
470	57	30	12.000	12.000	\N
471	57	31	23.000	23.000	\N
472	57	32	23.000	23.000	\N
473	57	33	3.000	3.000	\N
474	57	34	1.000	1.000	\N
475	57	35	34.000	34.000	\N
476	57	36	12.000	12.000	\N
477	57	37	12.000	12.000	\N
478	57	38	12.000	12.000	\N
479	57	39	3.000	3.000	\N
480	57	40	123.000	123.000	\N
481	57	41	1.000	1.000	\N
482	57	42	13.000	13.000	\N
483	57	43	123.000	123.000	\N
484	57	44	13.000	13.000	\N
485	57	45	1.000	1.000	\N
486	57	46	1.000	1.000	\N
487	57	47	45.000	45.000	\N
488	57	48	6.000	6.000	\N
489	57	49	324.000	324.000	\N
490	57	50	6.000	6.000	\N
491	57	51	623.000	623.000	\N
492	57	52	34.000	34.000	\N
493	57	53	23.000	23.000	\N
494	57	54	0.343	0.343	\N
495	57	71	2.000	2.000	\N
496	57	72	0.456	0.456	\N
497	57	74	0.456	0.456	\N
498	57	76	0.456	0.456	\N
499	57	77	0.456	0.456	\N
500	57	79	2.000	2.000	\N
501	57	80	0.456	0.456	\N
502	57	82	0.456	0.456	\N
503	57	98	1.000	1.000	\N
504	57	99	3.000	3.000	\N
505	57	100	23.000	23.000	\N
506	57	101	123.000	123.000	\N
507	57	102	4.000	4.000	\N
508	57	103	21.000	21.000	\N
509	57	104	3.000	3.000	\N
510	57	105	123.000	123.000	\N
511	57	106	1.000	1.000	\N
512	57	107	3.000	3.000	\N
513	57	108	23.000	23.000	\N
514	57	109	1.000	1.000	\N
515	57	110	1.000	1.000	\N
516	57	111	31.000	31.000	\N
517	57	112	12.000	12.000	\N
518	57	113	3.000	3.000	\N
519	57	114	1.000	1.000	\N
520	57	115	21.000	21.000	\N
521	58	18	123.000	123.000	\N
522	58	19	4.000	4.000	\N
523	58	20	13.000	13.000	\N
524	58	21	25.000	25.000	\N
525	58	22	6.000	6.000	\N
526	58	23	4.000	4.000	\N
527	58	24	34.000	34.000	\N
528	58	25	3.000	3.000	\N
529	58	26	2.000	2.000	\N
530	58	27	45.000	45.000	\N
531	58	28	12.000	12.000	\N
532	58	29	3.000	3.000	\N
533	58	30	13.000	13.000	\N
534	58	31	13.000	13.000	\N
535	58	32	345.000	345.000	\N
536	58	33	2.000	2.000	\N
537	58	34	3.000	3.000	\N
538	58	35	5.000	5.000	\N
539	58	36	4.000	4.000	\N
540	58	37	34.000	34.000	\N
541	58	38	5.000	5.000	\N
542	58	39	23.000	23.000	\N
543	58	40	1.000	1.000	\N
544	58	41	2.000	2.000	\N
545	58	42	123.000	123.000	\N
546	58	43	23.000	23.000	\N
547	58	44	14.000	14.000	\N
548	58	45	23.000	23.000	\N
549	58	46	1.000	1.000	\N
550	58	47	123.000	123.000	\N
551	58	48	41.000	41.000	\N
552	58	49	14.000	14.000	\N
553	58	50	12.000	12.000	\N
554	58	51	1.000	1.000	\N
555	58	52	426.000	426.000	\N
556	58	53	64.000	64.000	\N
557	58	54	12.123	12.123	\N
558	58	55	12.000	12.000	\N
559	58	56	13.000	13.000	\N
560	58	57	3.000	3.000	\N
561	58	58	433.000	433.000	\N
562	58	59	45.000	45.000	\N
563	58	60	23.000	23.000	\N
564	58	61	45.000	45.000	\N
565	58	62	433.000	433.000	\N
566	58	63	23.000	23.000	\N
567	58	64	21.000	21.000	\N
568	58	65	1.000	1.000	\N
569	58	66	24.000	24.000	\N
570	58	67	4.000	4.000	\N
571	58	68	6.000	6.000	\N
572	58	69	5.000	5.000	\N
573	58	70	123.000	123.000	\N
574	58	71	2.000	2.000	\N
575	58	72	0.567	0.567	\N
576	58	74	0.567	0.567	\N
577	58	76	0.567	0.567	\N
578	58	78	0.567	0.567	\N
579	58	79	231.000	231.000	\N
580	58	84	0.567	0.567	\N
581	58	98	23.000	23.000	\N
582	58	99	1.000	1.000	\N
583	58	100	23.000	23.000	\N
584	58	101	23.000	23.000	\N
585	58	102	1.000	1.000	\N
586	58	103	23.000	23.000	\N
587	58	104	434.000	434.000	\N
588	58	105	1.000	1.000	\N
589	58	106	12.000	12.000	\N
590	58	107	2.000	2.000	\N
591	58	108	31.000	31.000	\N
592	58	109	31.000	31.000	\N
593	58	110	13.000	13.000	\N
594	58	111	2.000	2.000	\N
595	58	112	25.000	25.000	\N
596	58	113	12.000	12.000	\N
597	58	114	4.000	4.000	\N
598	58	115	12.000	12.000	\N
599	59	18	12.000	12.000	\N
600	59	19	12.000	12.000	\N
602	59	20	13.000	13.000	\N
601	59	21	12.000	12.000	\N
\.


--
-- Data for Name: order_items_archive; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.order_items_archive (archive_item_id, order_id, product_name, category_name, point_name, measure_name, quantity, order_date, created_at) FROM stdin;
\.


--
-- Data for Name: order_status; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.order_status (status_id, name) FROM stdin;
1	Новый пустой заказ
2	Заказ в процессе создания
3	Заказ отправлен на утверждение
4	Заказ утвержден
5	Заказ проверяется точкой
6	Заказ принят
7	Заказ исполнен
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.orders (order_id, point_id, order_date, created_at, user_id, status_id) FROM stdin;
58	25	2026-04-25	2026-04-25 10:29:42.775201+00	2	4
59	24	2026-04-26	2026-04-26 09:04:03.256721+00	2	3
57	24	2026-04-25	2026-04-25 10:28:21.079539+00	2	5
60	23	2026-04-26	2026-04-26 09:35:18.068005+00	3	1
\.


--
-- Data for Name: points; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.points (point_id, name, is_active, created_at, sort_order) FROM stdin;
17	Ленина	t	2026-04-19 07:35:56.789912+00	17
18	Магнит	t	2026-04-19 07:35:56.789912+00	18
19	Катюшки	t	2026-04-19 07:35:56.789912+00	19
20	Химки1	t	2026-04-19 07:35:56.789912+00	20
21	Химки2	t	2026-04-19 07:35:56.789912+00	21
22	Мелодия	t	2026-04-19 07:35:56.789912+00	22
23	ХимкиНовые	t	2026-04-19 07:35:56.789912+00	23
24	Фермер	t	2026-04-19 07:35:56.789912+00	24
25	Химки5	t	2026-04-19 07:35:56.789912+00	25
26	Долгопрудный	t	2026-04-19 07:35:56.789912+00	26
27	Булочная	t	2026-04-19 07:35:56.789912+00	27
28	Поляна	t	2026-04-25 12:01:37.95946+00	1
29	Южный	t	2026-04-25 12:01:51.891775+00	2
\.


--
-- Data for Name: product_categories; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.product_categories (product_category_id, name, is_active, sort_order) FROM stdin;
6	Выпечка	t	1
7	Сладкая Выпечка	t	2
8	Сдоба	t	3
9	Хлеб	t	5
10	Кондитерка	t	4
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.products (product_id, product_category_id, name, is_active, measure_id, sort_order) FROM stdin;
18	6	Бублик	t	2	18
19	6	Векошник	t	2	20
20	6	Курник	t	2	20
21	6	Беляш	t	2	21
22	6	Кулебяка	t	2	22
23	6	Минипица	t	2	23
24	6	Пирог осетинский с мяс.	t	2	24
25	6	Пирожок с вишней	t	2	25
26	6	Пирожок с капустой	t	2	26
27	6	Пирожок с карт.жареные	t	2	27
28	6	Пирожок с карт.печёные	t	2	28
29	6	Пирожок с кр.смородиной	t	2	29
30	6	Пирожок с луком яйцом	t	2	30
31	6	Пирожок с мясом	t	2	31
32	6	Пирожок с печенью	t	2	32
33	6	Пирожок с черникой	t	2	33
34	6	Пирожок с яблоком	t	2	34
35	6	Слива	t	2	35
36	6	Самса с кур.	t	2	36
37	6	Слойка ветчина сыр	t	2	37
38	6	Сосиска в тесте	t	2	38
39	6	Сытенка	t	2	39
40	6	Хачапури	t	2	40
41	6	Чебурек	t	2	41
42	6	Эчпочмак	t	2	42
43	7	Cухари	t	2	43
44	7	Кекс англ.цукаты	t	2	44
45	7	Кекс англ.какао	t	2	45
46	7	Кекс верона	t	2	46
47	7	Кекс с творогом	t	2	47
48	7	Кекс столичный	t	2	48
49	7	Печенье диетическое	t	2	49
50	7	Печенье курабье	t	2	50
51	7	Печенье миндальное	t	2	51
52	7	Пирог невский	t	2	52
53	7	Чак-чак	t	2	53
54	8	Тесто для пирожков	t	1	54
55	8	Ватрушка венгерская	t	2	55
56	8	Ватрушка с творогом	t	2	56
86	10	Торт Королевский	t	1	86
87	10	Торт Ленинградский	t	1	87
88	10	Торт Маковка ореховая	t	1	88
89	10	Торт Малинка	t	1	89
90	10	Торт Медовик	t	1	90
91	10	Торт Молочная  девочка	t	1	91
92	10	Торт Наполеон	t	1	92
93	10	Торт Прага	t	1	93
94	10	Торт Прелесть	t	1	94
95	10	Торт Рыжик	t	1	95
96	10	Торт Смородинка	t	1	96
97	10	Торт Трюфельный	t	1	97
57	8	Гребешок с малиной	t	2	57
58	8	Колосок	t	2	58
59	8	Кольцо	t	2	59
60	8	Круассан со сгущёнкой	t	2	60
61	8	Плюшка Московская	t	2	61
62	8	Пончик	t	2	62
63	8	Ромовая баба	t	2	63
64	8	Ромашка	t	2	64
65	8	Рулетик с маком	t	2	65
66	8	Сдоба с изюмом	t	2	66
67	8	Сдоба с корицей	t	2	67
68	8	Сдоба с помадкой	t	2	68
69	8	Сочник с творогом	t	2	69
70	8	Язычок	t	2	70
71	10	Пироженое корзиночка	t	3	71
72	10	Рулет меренговый	t	1	72
73	10	Пироженое Йогуртовое	t	1	73
74	10	Пироженое Картошка	t	1	74
75	10	Пироженое Птичье молоко	t	1	75
76	10	Пирожные	t	1	76
77	10	нап.кг	t	1	77
78	10	кор.кг	t	1	78
79	10	Профитроли	t	2	79
80	10	Рулет вишнёвый	t	1	80
81	10	Рулет пломбир	t	1	81
82	10	Пироженое Черничка	t	1	82
83	10	Эклер с творогом	t	1	83
84	10	Торт Праздничный	t	1	84
85	10	Торт Клубника со сливками	t	1	85
98	9	Монастырский	t	2	98
99	9	Пеклеванный	t	2	99
100	9	Саечка	t	2	100
101	9	Багет французский	t	2	101
102	9	Батон	t	2	102
103	9	Хлеб Жито	t	2	103
104	9	Лепёшка тандырная	t	2	104
105	9	Минибагет	t	2	105
106	9	Хлеб фруктовый	t	2	106
107	9	Халла	t	2	107
108	9	Хлеб Ароматный	t	2	108
109	9	Хлеб Бородино	t	2	109
110	9	Хлеб дарницкий	t	2	110
111	9	Хлеб кукурузный	t	2	111
112	9	Хлеб купеческий	t	2	112
113	9	Хлеб Ситный	t	2	113
114	9	Хлеб Славянский	t	2	114
115	9	Чиабатта	t	2	115
\.


--
-- Data for Name: staff_points; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.staff_points (user_id, point_id) FROM stdin;
2	24
2	25
3	23
\.


--
-- Data for Name: unit_of_measure; Type: TABLE DATA; Schema: public; Owner: flask_user
--

COPY public.unit_of_measure (measure_id, name) FROM stdin;
1	кг
2	шт
3	упак
\.


--
-- Name: bulochkin_staffs_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.bulochkin_staffs_user_id_seq', 4, true);


--
-- Name: disposal_items_archive_archive_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.disposal_items_archive_archive_item_id_seq', 1, false);


--
-- Name: disposal_items_disposal_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.disposal_items_disposal_item_id_seq', 24, true);


--
-- Name: disposals_disposal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.disposals_disposal_id_seq', 7, true);


--
-- Name: order_items_archive_archive_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.order_items_archive_archive_item_id_seq', 1, false);


--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.order_items_order_item_id_seq', 602, true);


--
-- Name: order_status_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.order_status_status_id_seq', 4, true);


--
-- Name: orders_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.orders_order_id_seq', 60, true);


--
-- Name: points_point_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.points_point_id_seq', 29, true);


--
-- Name: product_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.product_categories_id_seq', 10, true);


--
-- Name: products_product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.products_product_id_seq', 115, true);


--
-- Name: unit_of_measure_measure_id_seq; Type: SEQUENCE SET; Schema: public; Owner: flask_user
--

SELECT pg_catalog.setval('public.unit_of_measure_measure_id_seq', 3, true);


--
-- Name: bulochkin_staffs bulochkin_staffs_login_key; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.bulochkin_staffs
    ADD CONSTRAINT bulochkin_staffs_login_key UNIQUE (login);


--
-- Name: bulochkin_staffs bulochkin_staffs_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.bulochkin_staffs
    ADD CONSTRAINT bulochkin_staffs_pkey PRIMARY KEY (user_id);


--
-- Name: disposal_items_archive disposal_items_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposal_items_archive
    ADD CONSTRAINT disposal_items_archive_pkey PRIMARY KEY (archive_item_id);


--
-- Name: disposal_items disposal_items_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposal_items
    ADD CONSTRAINT disposal_items_pkey PRIMARY KEY (disposal_item_id);


--
-- Name: disposals disposals_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposals
    ADD CONSTRAINT disposals_pkey PRIMARY KEY (disposal_id);


--
-- Name: order_items_archive order_items_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_items_archive
    ADD CONSTRAINT order_items_archive_pkey PRIMARY KEY (archive_item_id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_item_id);


--
-- Name: order_status order_status_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_status
    ADD CONSTRAINT order_status_pkey PRIMARY KEY (status_id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- Name: points points_name_key; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.points
    ADD CONSTRAINT points_name_key UNIQUE (name);


--
-- Name: points points_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.points
    ADD CONSTRAINT points_pkey PRIMARY KEY (point_id);


--
-- Name: product_categories product_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_pkey PRIMARY KEY (product_category_id);


--
-- Name: products products_name_unique; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_name_unique UNIQUE (name);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- Name: staff_points staff_points_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.staff_points
    ADD CONSTRAINT staff_points_pkey PRIMARY KEY (user_id, point_id);


--
-- Name: order_status ui_order_status_name; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_status
    ADD CONSTRAINT ui_order_status_name UNIQUE (name);


--
-- Name: bulochkin_staffs un_login_bulochkin_staffs; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.bulochkin_staffs
    ADD CONSTRAINT un_login_bulochkin_staffs UNIQUE (login);


--
-- Name: unit_of_measure unit_of_measure_pkey; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.unit_of_measure
    ADD CONSTRAINT unit_of_measure_pkey PRIMARY KEY (measure_id);


--
-- Name: order_items ux_order_product; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT ux_order_product UNIQUE (order_id, product_id);


--
-- Name: orders ux_orders_point_id,order_date; Type: CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT "ux_orders_point_id,order_date" UNIQUE (point_id, order_date);


--
-- Name: fki_disposals_items_created_at; Type: INDEX; Schema: public; Owner: flask_user
--

CREATE INDEX fki_disposals_items_created_at ON public.disposal_items_archive USING btree (created_at);


--
-- Name: fki_order_items_archive_created_at; Type: INDEX; Schema: public; Owner: flask_user
--

CREATE INDEX fki_order_items_archive_created_at ON public.order_items_archive USING btree (created_at);


--
-- Name: fki_orders_status_id_fkey; Type: INDEX; Schema: public; Owner: flask_user
--

CREATE INDEX fki_orders_status_id_fkey ON public.orders USING btree (status_id);


--
-- Name: fki_orders_user_id; Type: INDEX; Schema: public; Owner: flask_user
--

CREATE INDEX fki_orders_user_id ON public.orders USING btree (user_id);


--
-- Name: disposal_items_archive disposal_items_archive_disposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposal_items_archive
    ADD CONSTRAINT disposal_items_archive_disposal_id_fkey FOREIGN KEY (disposal_id) REFERENCES public.disposals(disposal_id) ON DELETE CASCADE;


--
-- Name: disposal_items disposal_items_disposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposal_items
    ADD CONSTRAINT disposal_items_disposal_id_fkey FOREIGN KEY (disposal_id) REFERENCES public.disposals(disposal_id) ON DELETE CASCADE;


--
-- Name: disposal_items disposal_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposal_items
    ADD CONSTRAINT disposal_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id);


--
-- Name: disposal_items_archive disposals_items_created_at; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposal_items_archive
    ADD CONSTRAINT disposals_items_created_at FOREIGN KEY (created_at) REFERENCES public.bulochkin_staffs(user_id) NOT VALID;


--
-- Name: disposals disposals_point_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.disposals
    ADD CONSTRAINT disposals_point_id_fkey FOREIGN KEY (point_id) REFERENCES public.points(point_id);


--
-- Name: order_items_archive order_items_archive_created_at; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_items_archive
    ADD CONSTRAINT order_items_archive_created_at FOREIGN KEY (created_at) REFERENCES public.bulochkin_staffs(user_id) NOT VALID;


--
-- Name: order_items_archive order_items_archive_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_items_archive
    ADD CONSTRAINT order_items_archive_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id);


--
-- Name: orders orders_point_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_point_id_fkey FOREIGN KEY (point_id) REFERENCES public.points(point_id);


--
-- Name: orders orders_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.order_status(status_id) MATCH FULL;


--
-- Name: orders orders_user_id; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_user_id FOREIGN KEY (user_id) REFERENCES public.bulochkin_staffs(user_id);


--
-- Name: products products_measure_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_measure_id_fkey FOREIGN KEY (measure_id) REFERENCES public.unit_of_measure(measure_id);


--
-- Name: products products_product_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_product_category_id_fkey FOREIGN KEY (product_category_id) REFERENCES public.product_categories(product_category_id);


--
-- Name: staff_points staff_points_point_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.staff_points
    ADD CONSTRAINT staff_points_point_id_fkey FOREIGN KEY (point_id) REFERENCES public.points(point_id) ON DELETE CASCADE;


--
-- Name: staff_points staff_points_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: flask_user
--

ALTER TABLE ONLY public.staff_points
    ADD CONSTRAINT staff_points_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.bulochkin_staffs(user_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict d4iKl83Zdy6mhtlgknNiGhvBVhFd26yVUchLjYvDk0fFJdagxxjeqtYZiNlvQBO

