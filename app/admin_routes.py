from .auth import login_required, admin_required
from flask import Blueprint, render_template, request, redirect, url_for, session, flash
from .db import get_db_connection
import psycopg2.extras
from psycopg2 import Error
from werkzeug.utils import secure_filename
import os
import uuid
import tempfile
from datetime import date


#ALLOWED_EXCEL_EXTENSIONS = {".xlsx", ".xlsm", ".xltx", ".xltm", ".xls"}
admin = Blueprint('admin', __name__, url_prefix='/admin')


# def allowed_excel_file(filename):
#     _, ext = os.path.splitext(filename.lower())
#     return ext in ALLOWED_EXCEL_EXTENSIONS

# def cleanup_temp_excel():
#     """
#     Удаляет временный Excel-файл, если он был сохранен ранее.
#     """
#     temp_excel_path = session.get("order_export_temp_excel_path")

#     if temp_excel_path and os.path.exists(temp_excel_path):
#         try:
#             os.remove(temp_excel_path)
#         except OSError:
#             pass

#     session.pop("order_export_temp_excel_path", None)
#     session.pop("order_export_temp_excel_name", None)

# def get_points_for_filter():
#     """
#     Возвращает список активных точек для фильтра.
#     """
#     conn = get_db_connection()
#     cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

#     cur.execute("""
#         select
#             point_id,
#             name
#         from points
#         where is_active = true
#         order by sort_order
#     """)
#     points = cur.fetchall()

#     cur.close()
#     conn.close()

#     return points

# def get_selected_point_ids():
#     """
#     Читает point_id из query string.
#     При multiple-select request.args.getlist('point_ids') вернет список строк.
#     """
#     raw_ids = request.args.getlist("point_ids")
#     result = []

#     for value in raw_ids:
#         try:
#             result.append(int(value))
#         except (TypeError, ValueError):
#             continue

#     return result



# def get_export_rows_from_db(order_date, selected_point_ids):
#     """
#     Возвращает нормализованные строки из БД для выгрузки.

#     Формат строки:
#     {
#         "category_name": ...,
#         "product_id": ...,
#         "product_name": ...,
#         "unit_name": ...,
#         "point_id": ...,
#         "point_name": ...,
#         "quantity": ...
#     }

#     Используем только утвержденные заказы (status_id = 4).
#     """
#     if not order_date:
#         return []

#     conn = get_db_connection()
#     cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

#     params = [order_date]


#     point_filter_sql = ""
#     if selected_point_ids:
#         point_filter_sql = "and o.point_id = any(%s)"
#         params.append(selected_point_ids)





@admin.route('/')
@admin_required
@login_required
def dashboard():

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    cur.execute("""
        select
            count(*) as orders_today,
            count(*) filter (where status_id = 2) as drafts_count,
            count(*) filter (where status_id = 4) as approved_count,
            (
                select count(*)
                from disposals
                where status_id = 4
            ) as disposals_today
        from orders
    """)

    result = cur.fetchone()

    cur.close()
    conn.close()

    return render_template(
        "admin/dashboard.html",
        orders_today=result['orders_today'],
        drafts_count=result['drafts_count'],
        approved_count=result['approved_count'],
        disposals_today=result['disposals_today']
    )


#=========================
# PRODUCTS PAGE
# =========================
@admin.route('/products')
@admin_required
@login_required
def products():
    search = (request.args.get("search") or "").strip()
    category_id = request.args.get("category_id")
    active_only = request.args.get("active_only")

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    query = """
    select
        v.product_id,
        v.product_category_id,
        v.category_name,
        v.product_name,
        v.measure_name,
        v.is_active,
        coalesce(v.sort_order, 9999) as sort_order
    from v_get_products v
    where 1=1
    """

    params = []

    if category_id:
        query += " and v.product_category_id = %s"
        params.append(category_id)

    if active_only == "1":
        query += " and v.is_active = true"

    if search:
        query += " and v.product_name ilike %s"
        params.append(f"%{search}%")

    query += """
    order by
        v.category_order,
        coalesce(v.sort_order, 9999),
        v.product_name
    """

    cur.execute(query, params)
    products = cur.fetchall()

    cur.execute("""
        select 
            product_category_id as id,
            name,
            is_active,
            coalesce(sort_order, 9999) as sort_order
        from product_categories
        order by coalesce(sort_order, 9999), name
    """)
    categories = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "admin/products.html",
        products=products,
        categories=categories,
        active_only=active_only
    )


# =========================
# ADD PRODUCT
# =========================
@admin.route('/products/add', methods=['POST'])
@admin_required
@login_required
def add_product():
    category_id = request.form.get("category_id")
    name = (request.form.get("name") or "").strip()
    measure = request.form.get("measure")
    is_active = request.form.get("is_active") == "on"

    search = request.form.get("search")
    category_filter = request.form.get("category_id_filter")
    active_only = request.form.get("active_only_filter")

    if not name:
        flash("Введите название товара", "danger")
        return redirect(url_for("admin.products"))

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        insert into products (product_category_id, name, measure_id, is_active, sort_order)
        select  
            %s,
            %s,
            (select measure_id from unit_of_measure where name = %s),
            %s,
            coalesce((select max(sort_order)+1 from products where product_category_id = %s), 1)
    """, (category_id, name, measure, is_active, category_id))

    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for(
        "admin.products",
        search=search,
        category_id=category_filter,
        active_only=active_only
    ))


# =========================
# UPDATE PRODUCT
# =========================
@admin.route('/products/update', methods=['POST'])
@admin_required
@login_required
def update_product():
    product_id = request.form.get("product_id")
    category_id = request.form.get("category_id")
    name = (request.form.get("name") or "").strip()
    measure = request.form.get("measure")
    sort_order = request.form.get("sort_order")
    is_active = request.form.get("is_active") == "on"

    search = request.form.get("search")
    category_filter = request.form.get("category_id_filter")
    active_only = request.form.get("active_only_filter")

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        update products
        set product_category_id = %s,
            name = %s,
            measure_id = (select measure_id from unit_of_measure where name = %s),
            is_active = %s,
            sort_order = %s
        where product_id = %s
    """, (category_id, name, measure, is_active, sort_order, product_id))

    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for(
        "admin.products",
        search=search,
        category_id=category_filter,
        active_only=active_only
    ))


# =========================
# TOGGLE
# =========================
@admin.route('/products/toggle/<int:product_id>', methods=['POST'])
@admin_required
@login_required
def toggle_product(product_id):
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        update products
        set is_active = not is_active
        where product_id = %s
    """, (product_id,))

    conn.commit()
    cur.close()
    conn.close()

    return redirect(request.referrer or url_for("admin.products"))


# =========================
# ADD CATEGORY
# =========================
@admin.route('/categories/add', methods=['POST'])
@admin_required
@login_required
def add_category():
    name = (request.form.get("name") or "").strip()
    is_active = request.form.get("is_active") == "on"

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        insert into product_categories (name, is_active, sort_order)
        values (
            %s,
            %s,
            coalesce((select max(sort_order)+1 from product_categories), 1)
        )
    """, (name, is_active))

    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for("admin.products"))


# =========================
# UPDATE CATEGORY
# =========================
@admin.route('/categories/update', methods=['POST'])
@admin_required
@login_required
def update_category():
    category_id = request.form.get("category_id")
    name = (request.form.get("name") or "").strip()
    sort_order = request.form.get("sort_order")
    is_active = request.form.get("is_active") == "on"

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        update product_categories
        set name = %s,
            is_active = %s,
            sort_order = %s
        where product_category_id = %s
    """, (name, is_active, sort_order, category_id))

    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for("admin.products"))


@admin.route('/products/reorder', methods=['POST'])
@admin_required
@login_required
def reorder_product():
    product_id = request.form.get("product_id")
    direction = request.form.get("direction")  # up / down

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # текущий продукт
    cur.execute("""
        select product_id, product_category_id, sort_order
        from products
        where product_id = %s
    """, (product_id,))
    current = cur.fetchone()

    if not current:
        return redirect(request.referrer)

    if direction == "up":
        cur.execute("""
            select product_id, sort_order
            from products
            where product_category_id = %s
              and sort_order < %s
            order by sort_order desc
            limit 1
        """, (current["product_category_id"], current["sort_order"]))
    else:
        cur.execute("""
            select product_id, sort_order
            from products
            where product_category_id = %s
              and sort_order > %s
            order by sort_order asc
            limit 1
        """, (current["product_category_id"], current["sort_order"]))

    swap = cur.fetchone()

    if swap:
        # меняем местами
        cur.execute("""
            update products
            set sort_order = %s
            where product_id = %s
        """, (swap["sort_order"], current["product_id"]))

        cur.execute("""
            update products
            set sort_order = %s
            where product_id = %s
        """, (current["sort_order"], swap["product_id"]))

    conn.commit()
    cur.close()
    conn.close()

    return redirect(request.referrer)




@admin.route('/categories/reorder', methods=['POST'])
@admin_required
@login_required
def reorder_category():
    category_id = request.form.get("category_id")
    direction = request.form.get("direction")  # up / down

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    cur.execute("""
        select product_category_id, sort_order
        from product_categories
        where product_category_id = %s
    """, (category_id,))
    current = cur.fetchone()

    if not current:
        cur.close()
        conn.close()
        return redirect(request.referrer or url_for("admin.products"))

    if direction == "up":
        cur.execute("""
            select product_category_id, sort_order
            from product_categories
            where coalesce(sort_order, 999999) < coalesce(%s, 999999)
            order by coalesce(sort_order, 999999) desc, product_category_id desc
            limit 1
        """, (current["sort_order"],))
    else:
        cur.execute("""
            select product_category_id, sort_order
            from product_categories
            where coalesce(sort_order, 999999) > coalesce(%s, 999999)
            order by coalesce(sort_order, 999999) asc, product_category_id asc
            limit 1
        """, (current["sort_order"],))

    swap = cur.fetchone()

    if swap:
        cur.execute("""
            update product_categories
            set sort_order = %s
            where product_category_id = %s
        """, (swap["sort_order"], current["product_category_id"]))

        cur.execute("""
            update product_categories
            set sort_order = %s
            where product_category_id = %s
        """, (current["sort_order"], swap["product_category_id"]))

        conn.commit()

    cur.close()
    conn.close()

    return redirect(request.referrer or url_for("admin.products"))

# =========================
# СПИСОК ТОЧЕК
# =========================
@admin.route('/points')
@admin_required
@login_required
def points():
    search = request.args.get("search", "")
    active_only = request.args.get("active_only") == "on"

    conn = get_db_connection()
    cur = conn.cursor()

    query = """
        select point_id, name, is_active
        from points
        where 1=1
    """
    params = []

    if active_only:
        query += " and is_active = true"

    if search:
        query += " and lower(name) like lower(%s)"
        params.append(f"%{search}%")

    query += " order by name"

    cur.execute(query, params)
    points = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "admin/points.html",
        points=points,
        search=search,
        active_only=active_only
    )


# =========================
# TOGGLE
# =========================
@admin.route('/points/toggle/<int:point_id>', methods=['POST'])
@admin_required
@login_required
def toggle_point(point_id):
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        update points
        set is_active = not is_active
        where point_id = %s
    """, (point_id,))

    conn.commit()
    cur.close()
    conn.close()

    flash("Статус точки обновлён", "success")

    return redirect(url_for("admin.points", **request.args))


# =========================
# СОЗДАНИЕ
# =========================
@admin.route('/points/create', methods=['GET', 'POST'])
@admin_required
@login_required
def create_point():
    if request.method == 'POST':
        name = request.form.get("name")

        conn = get_db_connection()
        cur = conn.cursor()

        try:
            cur.execute("""
                insert into points (name)
                values (%s)
            """, (name,))
            conn.commit()

            flash("Точка добавлена", "success")
            return redirect(url_for("admin.points"))

        except Exception:
            conn.rollback()
            flash("Точка с таким именем уже существует", "danger")

        finally:
            cur.close()
            conn.close()

    return render_template("admin/point_form.html", point=None)


# =========================
# РЕДАКТИРОВАНИЕ
# =========================
@admin.route('/points/edit/<int:point_id>', methods=['GET', 'POST'])
@admin_required
@login_required
def edit_point(point_id):
    conn = get_db_connection()
    cur = conn.cursor()

    if request.method == 'POST':
        name = request.form.get("name")

        try:
            cur.execute("""
                update points
                set name = %s
                where point_id = %s
            """, (name, point_id))
            conn.commit()

            flash("Точка обновлена", "success")
            return redirect(url_for("admin.points"))

        except Exception:
            conn.rollback()
            flash("Точка с таким именем уже существует", "danger")

    cur.execute("""
        select point_id, name, is_active
        from points
        where point_id = %s
    """, (point_id,))

    point = cur.fetchone()

    cur.close()
    conn.close()

    return render_template("admin/point_form.html", point=point)


@admin.route('/users')
@admin_required
@login_required
def users():
    search = request.args.get("search", "")
    active_only = request.args.get("active_only") == "on"

    print(f"От пользователя приходит следующий serach {search}")
    print(f"Показываем ли мы удаленные объекты  {active_only}")

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    query = """
        select
            user_id
        ,	login
        ,	full_name
        ,	is_admin
        ,	is_active
        from
            bulochkin_staffs
        where
            1=1
    """
    params = []

    if active_only:
        query += " and is_active = true"

    if search:
        query += " and lower(login) like lower(%s)"
        params.append(f"%{search}%")

    query += " order by login"

    cur.execute(query, params)
    users = cur.fetchall()

    cur.close()
    conn.close()   

    return render_template(
        "admin/users.html",
        users=users,
        search=search,
        active_only=active_only
    )



@admin.route('/users/toggle/<int:user_id>', methods=['POST'])
@admin_required
@login_required
def toggle_users(user_id):
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        update bulochkin_staffs
        set is_active = not is_active
        where user_id = %s
    """, (user_id,))

    conn.commit()
    cur.close()
    conn.close()

    flash("Статус пользователя обновлён", "success")

    return redirect(url_for("admin.users", **request.args))

@admin.route('/users/toggle_admin/<int:user_id>', methods=['POST'])
@admin_required
@login_required
def toggle_admin_users(user_id):
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        update bulochkin_staffs
        set is_admin = not is_admin
        where user_id = %s
    """, (user_id,))

    conn.commit()
    cur.close()
    conn.close()

    flash("Права пользователя обновлены", "success")

    return redirect(url_for("admin.users", **request.args))



@admin.route('/user/create', methods=['GET', 'POST'])
@admin_required
@login_required
def create_user():
    if request.method == 'POST':
        login               = request.form.get("login")
        full_name           = request.form.get("full_name")
        admin_right         = request.form.get("admin_right")
        password            = request.form.get("password")
        password_confirm    = request.form.get("password_confirm")

        conn = get_db_connection()
        cur = conn.cursor()
        

        if password != password_confirm:
             flash("Пароль должен совпадать", "danger")
             return render_template("admin/user_form.html", 
                                   user=None, 
                                   form_data=request.form)

        try:
            cur.execute(
                "call add_user(%(p_login)s, %(p_full_name)s, %(p_password_text)s, %(p_is_admin)s)",
                {'p_login': login, 'p_full_name': full_name, 'p_password_text': password, 'p_is_admin': False if not admin_right else True}
            )
            conn.commit()

            flash("Новый пользователь создан", "success")
            return redirect(url_for("admin.users", **request.args))


        except Error as e:
            conn.rollback()
            flash(f"Ошибка из PostgreSQL: {e.pgerror}", "danger")

        finally:
            cur.close()
            conn.close()

    return render_template("admin/user_form.html", user=None)


@admin.route('/user/edit/<int:user_id>', methods=['GET', 'POST'])
@admin_required
@login_required
def edit_user(user_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    if request.method == 'POST':
        login               = request.form.get("login")
        full_name           = request.form.get("full_name")
        password            = request.form.get("password")
        password_confirm    = request.form.get("password_confirm")
        admin_right         = request.form.get("admin_right")
        try:
            if password: 
                if password != password_confirm:
                    flash("Пароль должен совпадать", "danger")
                    return render_template("admin/user_form.html", 
                                    user=None, 
                                    form_data=request.form)
                else:
                    cur.execute("""
                        update bulochkin_staffs
                        set 
                            login = %s
                        ,   full_name = %s
                        ,   password_hash = md5(%s)
                        ,   is_admin = %s
                        ,   is_active = True
                        where user_id = %s
                    """, (login, full_name, password, False if not admin_right else True, user_id))
                    conn.commit()
            else:
                cur.execute("""
                    update bulochkin_staffs
                    set 
                        login = %s
                    ,   full_name = %s
                    ,   is_admin = %s
                    ,   is_active = True
                    where user_id = %s
                """, (login, full_name,  False if not admin_right else True, user_id))
                conn.commit()

            flash("Пользователь отредактирован", "success")
            return redirect(url_for("admin.users"))   
          
        except Exception:
            conn.rollback()
            flash("Пользователь с таким именем уже существует", "danger")
            return render_template("admin/user_form.html", 
                       user=None, 
                       form_data=request.form)


    cur.execute("""
        select login, full_name, is_admin
        from bulochkin_staffs
        where user_id = %s
    """, (user_id,))

    user = cur.fetchone()

    cur.close()
    conn.close()
    return render_template("admin/user_form.html", user=user)


@admin.route('/users/points/<int:user_id>', methods=['GET', 'POST'])
@admin_required
@login_required
def user_points(user_id):

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    if request.method == 'POST':
        selected_points = request.form.getlist("points")  # ['1', '3', '5']

        # 1. удаляем старые связи
        cur.execute("""
            delete from staff_points
            where user_id = %s
        """, (user_id,))

        # 2. вставляем новые
        for point_id in selected_points:
            cur.execute("""
                insert into staff_points (user_id, point_id)
                values (%s, %s)
            """, (user_id, point_id))

        conn.commit()

        cur.close()
        conn.close()

        flash("Точки пользователя обновлены", "success")
        return redirect(url_for("admin.users"))

    # --- GET часть ---

    # пользователь
    cur.execute("""
        select login, full_name
        from bulochkin_staffs
        where user_id = %s
    """, (user_id,))
    user = cur.fetchone()

    # все точки
    cur.execute("""
        select point_id, name
        from points
        order by name
    """)
    points = cur.fetchall()

    # выбранные точки
    cur.execute("""
        select point_id
        from staff_points
        where user_id = %s
    """, (user_id,))
    user_points = [row["point_id"] for row in cur.fetchall()]

    cur.close()
    conn.close()

    return render_template(
        "admin/user_points.html",
        user=user,
        user_id=user_id,
        points=points,
        user_points=user_points
    )



@admin.route("/orders")
@login_required
@admin_required
def orders():

    status_filter = request.args.get("status", "").strip()
    point_filter = request.args.get("point", "").strip()
    hide_completed = request.args.get("hide_completed", "0").strip()
    date_from = request.args.get("date_from", "").strip()
    date_to = request.args.get("date_to", "").strip()

    conn = get_db_connection()
    cur = conn.cursor()

    sql = """
        select
            o.order_id,
            o.point_id,
            p.name as point_name,
            o.order_date,
            o.status_id,
            os.name as status_name,
            o.user_id,
            count(oi.order_item_id) as items_count,
            coalesce(sum(oi.quantity), 0) as total_quantity,
            current_date - o.order_date as order_age
        from orders o
        join points p
            on p.point_id = o.point_id
        join order_status os
            on os.status_id = o.status_id
        left join order_items oi
            on oi.order_id = o.order_id
        where p.is_active = true
    """

    params = []

    if status_filter:
        sql += " and o.status_id = %s"
        params.append(status_filter)

    if point_filter:
        sql += " and p.name ilike %s"
        params.append(f"%{point_filter}%")

    if hide_completed == "1":
        sql += " and lower(os.name) not in ('заказ исполнен', 'исполнен')"

    if date_from:
        sql += " and o.order_date >= %s"
        params.append(date_from)

    if date_to:
        sql += " and o.order_date <= %s"
        params.append(date_to)

    sql += """
        group by
            o.order_id,
            o.point_id,
            p.name,
            o.order_date,
            o.status_id,
            os.name,
            o.user_id
        order by
            o.order_date desc,
            p.name asc
    """

    cur.execute(sql, params)
    orders_rows = cur.fetchall()
    
    no_order_sql = """
        select
            p.point_id,
            p.name as point_name
        from points p
        where p.is_active = true
          and not exists (
              select 1
              from orders o
              where o.point_id = p.point_id
          )
    """

    no_order_params = []

    if point_filter:
        no_order_sql += " and p.name ilike %s"
        no_order_params.append(f"%{point_filter}%")

    no_order_sql += " order by p.name asc"

    cur.execute(no_order_sql, no_order_params)
    no_order_rows = cur.fetchall()

    status_sql = """
        select
            status_id,
            name
        from order_status
        order by status_id
    """
    cur.execute(status_sql)
    statuses = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "admin/orders.html",
        orders_rows=orders_rows,
        no_order_rows=no_order_rows,
        statuses=statuses,
        status_filter=status_filter,
        point_filter=point_filter,
        hide_completed=hide_completed,
        date_from=date_from,
        date_to=date_to
    )



@admin.route("/orders/<int:order_id>", methods=['GET', 'POST'])
@login_required
@admin_required
def order_edit(order_id):

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # =========================
    # POST (СОХРАНЕНИЕ)
    # =========================
    if request.method == "POST":

        # Получаем статус заказа
        cur.execute("""
            select status_id
            from orders
            where order_id = %s
        """, (order_id,))

        current_status = cur.fetchone()

        print(f"Текущий статус заказа {current_status['status_id']}")

        # Получаем все продукты (чтобы знать product_id)
        cur.execute("""
            select product_id
            from products
            where is_active = true
        """)
        products = cur.fetchall()

        for p in products:
            product_id = p["product_id"]

            quantity = request.form.get(f"quantity_{product_id}", "0")
            delivered = request.form.get(f"delivered_{product_id}", "0")

            try:
                quantity = float(quantity)
            except:
                quantity = 0

            try:
                delivered = float(delivered)
            except:
                delivered = 0

            if int(current_status['status_id']) <= 4:
                delivered = quantity

            # Проверяем есть ли запись
            cur.execute("""
                select order_item_id
                from order_items
                where order_id = %s and product_id = %s
            """, (order_id, product_id))

            existing = cur.fetchone()


            if existing:
                # Обновляем
                if quantity == 0 and delivered == 0:
                    # Удаляем если всё 0
                    cur.execute("""
                        delete from order_items
                        where order_id = %s and product_id = %s
                    """, (order_id, product_id))
                else:
                    cur.execute("""
                        update order_items
                        set quantity = %s,
                            delivered_quantity = %s
                        where order_id = %s and product_id = %s
                    """, (quantity, delivered, order_id, product_id))
            else:
                # Вставляем если есть значение
                if quantity > 0 or delivered > 0:
                    cur.execute("""
                        insert into order_items (
                            order_id,
                            product_id,
                            quantity,
                            delivered_quantity,
                            is_extra_item
                        )
                        values (%s, %s, %s, %s, false)
                    """, (order_id, product_id, quantity, delivered))

        conn.commit()
        flash("Заказ сохранён", "success")

        return redirect(url_for("admin.order_edit", order_id=order_id))

    # =========================
    # GET (ОТКРЫТИЕ)
    # =========================

    # --- ШАПКА ---
    cur.execute("""
        select
            o.order_id,
            o.order_date,
            o.status_id,
            os.name as status_name,
            p.name as point_name
        from orders o
        join points p on p.point_id = o.point_id
        join order_status os on os.status_id = o.status_id
        where o.order_id = %s
    """, (order_id,))

    order = cur.fetchone()

    if not order:
        cur.close()
        conn.close()
        return "Заказ не найден", 404

    # --- ВСЕ ТОВАРЫ + ДАННЫЕ ЗАКАЗА ---
    cur.execute("""
        select
            p.product_id,
            p.name as product_name,

            pc.product_category_id,
            pc.name as category_name,

            coalesce(oi.order_item_id, 0) as order_item_id,
            coalesce(oi.quantity, 0) as quantity,
            coalesce(oi.delivered_quantity, 0) as delivered_quantity,
            um.name as measure_name ,
            is_extra_item

        from products p
        join product_categories pc
            on pc.product_category_id = p.product_category_id
        join unit_of_measure um on um.measure_id = p.measure_id

        left join order_items oi
            on oi.product_id = p.product_id
           and oi.order_id = %s

        where p.is_active = true
          and pc.is_active = true

        order by
            pc.sort_order,
            p.sort_order
    """, (order_id,))

    items_raw = cur.fetchall()

    categories = {}
    ordered_categories = []

    for item in items_raw:
        cat_id = item["product_category_id"]

        if cat_id not in categories:
            categories[cat_id] = {
                "name": item["category_name"],
                "items": []
            }
            ordered_categories.append(cat_id)

        categories[cat_id]["items"].append(item)

    cur.close()
    conn.close()

    return render_template(
        "admin/order_edit.html",
        order=order,
        categories=categories,
        ordered_categories=ordered_categories
    )


@admin.route("/orders/<int:order_id>/set_status/<int:status_id>", methods=["POST"])
@login_required
@admin_required
def set_order_status(order_id, status_id):

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        update orders
        set status_id = %s
        where order_id = %s
    """, (status_id, order_id))

    conn.commit()

    cur.close()
    conn.close()

    flash("Статус обновлен", "success")

    return redirect(url_for("admin.order_edit", order_id=order_id))



@admin.route('/disposals')
@admin_required
@login_required
def disposals():
    status_filter = request.args.get("status", "").strip()
    point_filter = request.args.get("point", "").strip()
    hide_completed = request.args.get("hide_completed", "0").strip()
    date_from = request.args.get("date_from", "").strip()
    date_to = request.args.get("date_to", "").strip()

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    sql = """
        select 
            d.disposal_id
        ,	d.point_id
        ,	p.name 					        as point_name
        ,	d.disposal_date
        ,	d.status_id
        ,	ds.name					        as status_name
        ,	d.user_id
        ,	count(di.disposal_item_id)      as items_count
        ,	current_date -  d.disposal_date as disposal_age 
        from
                disposals as d
            join points p on d.point_id = p.point_id
            join disposals_status as ds on d.status_id = ds.status_id
            join disposal_items as di on di.disposal_id = d.disposal_id
            """

    params = []

    if status_filter:
        sql += " and d.status_id = %s"
        params.append(status_filter)

    if point_filter:
        sql += " and p.name ilike %s"
        params.append(f"%{point_filter}%")

    if hide_completed == "1":
        sql += " and lower(os.name) not in ('заказ исполнен', 'исполнен')"

    if date_from:
        sql += " and o.disposal_date >= %s"
        params.append(date_from)

    if date_to:
        sql += " and o.disposal_date <= %s"
        params.append(date_to)

    sql += """
        group by
            d.disposal_id,
            d.point_id,
            p.name,
            d.disposal_date,
            d.status_id,
            ds.name,
            d.user_id
        order by
            d.disposal_date desc,
            p.name asc
    """

    cur.execute(sql, params)
    disposals_rows = cur.fetchall()
    
    no_disposal_sql = """
        select
            p.point_id,
            p.name as point_name
        from points p
        where p.is_active = true
          and not exists (
              select 1
              from disposals d
              where d.point_id = p.point_id
          )
    """


    no_disposal_params = []

    if point_filter:
        no_disposal_sql += " and p.name ilike %s"
        no_disposal_params.append(f"%{point_filter}%")

    no_disposal_sql += " order by p.name asc"

    cur.execute(no_disposal_sql, no_disposal_params)
    no_disposal_rows = cur.fetchall()

    status_sql = """
            select
                status_id,
                name
            from disposals_status
            order by status_id
        """
    cur.execute(status_sql)
    statuses = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "admin/disposals.html",
        disposals_rows=disposals_rows,
        no_disposal_rows=no_disposal_rows,
        statuses=statuses,
        status_filter=status_filter,
        point_filter=point_filter,
        hide_completed=hide_completed,
        date_from=date_from,
        date_to=date_to
    )



@admin.route('/disposal_edit/<int:disposal_id>', methods=['GET', 'POST'])
@admin_required
@login_required
def disposal_edit(disposal_id):

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    if request.method == "POST":

        print("FORM:", request.form)

        items = []

        # =========================
        # СУЩЕСТВУЮЩИЕ ТОВАРЫ
        # =========================
        for key, value in request.form.items():
            if key.startswith("quantity_"):

                product_id = key.replace("quantity_", "")

                try:
                    product_id = int(product_id)
                    quantity = float(value)
                except:
                    continue

                items.append({
                    "product_id": product_id,
                    "quantity": quantity
                })

        # =========================
        # НОВЫЕ ТОВАРЫ
        # =========================
        for key in request.form:
            if key.startswith("new_product_id_"):

                index = key.replace("new_product_id_", "")

                product_id = request.form.get(f"new_product_id_{index}")
                quantity = request.form.get(f"new_quantity_{index}", "0")

                try:
                    product_id = int(product_id)
                    quantity = float(quantity)
                except:
                    continue

                items.append({
                    "product_id": product_id,
                    "quantity": quantity
                })

        print("ITEMS:", items)

        # =========================
        # UPSERT ЛОГИКА
        # =========================
        for item in items:

            product_id = item["product_id"]
            quantity = item["quantity"]

            cur.execute("""
                select disposal_item_id
                from disposal_items
                where disposal_id = %s and product_id = %s
            """, (disposal_id, product_id))

            existing = cur.fetchone()

            if quantity <= 0:
                if existing:
                    cur.execute("""
                        delete from disposal_items
                        where disposal_id = %s and product_id = %s
                    """, (disposal_id, product_id))
                continue

            if existing:
                cur.execute("""
                    update disposal_items
                    set quantity = %s
                    where disposal_id = %s and product_id = %s
                """, (quantity, disposal_id, product_id))
            else:
                cur.execute("""
                    insert into disposal_items (
                        disposal_id,
                        product_id,
                        quantity
                    )
                    values (%s, %s, %s)
                """, (disposal_id, product_id, quantity))

        conn.commit()

        cur.close()
        conn.close()

        flash("Списание сохранено", "success")
        return redirect(url_for("admin.disposal_edit", disposal_id=disposal_id))

    # =========================
    # GET (ОТКРЫТИЕ)
    # =========================

    cur.execute("""
        select
            d.disposal_id,
            d.disposal_date,
            d.status_id,
            ds.name as status_name,
            p.name as point_name
        from disposals d
        join points p on p.point_id = d.point_id
        join disposals_status ds on ds.status_id = d.status_id
        where d.disposal_id = %s
    """, (disposal_id,))

    disposal = cur.fetchone()

    if not disposal:
        cur.close()
        conn.close()
        return "Списание не найдено", 404

    cur.execute("""
        select
            p.product_id,
            p.name as product_name,
            di.quantity,
            pc.product_category_id,
            pc.name as category_name,
            um.name as measure_name
        from disposal_items di
        join products p on di.product_id = p.product_id
        join product_categories pc on p.product_category_id = pc.product_category_id
        join unit_of_measure um on um.measure_id = p.measure_id
        where di.disposal_id = %s
        order by pc.sort_order, p.sort_order
    """, (disposal_id,))

    items_raw = cur.fetchall()

    categories = {}
    disposal_categories = []

    for item in items_raw:
        cat_id = item["product_category_id"]

        if cat_id not in categories:
            categories[cat_id] = {
                "name": item["category_name"],
                "items": []
            }
            disposal_categories.append(cat_id)

        categories[cat_id]["items"].append(item)

    cur.close()
    conn.close()

    return render_template(
        "admin/disposal_edit.html",
        disposal=disposal,
        categories=categories,
        disposal_categories=disposal_categories
    )


@admin.route("/api/products")
@admin_required
@login_required
def search_products():

    query = request.args.get("q", "")
    print(f"Пользователь пытается добавить новый товар в заказ")
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        select product_id, name
        from products
        where is_active = true
          and lower(name) like lower(%s)
        order by name
        limit 20
    """, (f"%{query}%",))

    products = cur.fetchall()

    cur.close()
    conn.close()

    result = [
        {"id": p[0], "name": p[1]}
        for p in products
    ]

    return result

@admin.route("/disposal/<int:disposal_id>/set_status/<int:status_id>", methods=["POST"])
@login_required
@admin_required
def set_disposal_status(disposal_id, status_id):

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        update disposals
        set status_id = %s
        where disposal_id = %s
    """, (status_id, disposal_id))

    conn.commit()

    cur.close()
    conn.close()

    flash("Статус обновлен", "success")

    return redirect(url_for("admin.disposal_edit", disposal_id=disposal_id))


@admin.route('/orders_export', methods=['GET'])
@admin_required
@login_required
def orders_export():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # -------------------------
    # 1. Получаем фильтры из GET
    # -------------------------
    report_date = request.args.get("report_date", "")
    all_points = request.args.get("all_points") == "1"

    report_date = report_date if report_date else date.today()

    # -------------------------
    # 2. Загружаем список точек
    # -------------------------
    cur.execute("""
        select
            point_id,
            name
        from points
        where is_active = true
        order by sort_order
    """)
    points = cur.fetchall()

    # -------------------------
    # 3. Обрабатываем выбор точек
    # -------------------------
    if all_points:
        selected_point_ids = [p["point_id"] for p in points]
    else:
        
        selected_point_ids = []
        for value in request.args.getlist("point_ids"):
            print(f"Выбираем конкретную точки {value}")
            try:
                selected_point_ids.append(int(value))
            except (TypeError, ValueError):
                pass

    # -------------------------
    # 4. Флаг "ничего не выбрано"
    # -------------------------

    no_points_selected = not all_points and not selected_point_ids
    print(no_points_selected)
    # -------------------------
    # 5. Обрабатываем данные из таблицы
    # -------------------------
    cur.execute("""
        select
            pc.name                    as product_category_name
            ,p.product_id
            ,p.name                    as product_name
            ,u.name                    as unit_name
            ,pt.point_id
            ,pt.name                   as point_name
            ,oi.quantity               as quantity
        from orders o
        join order_items oi
            on oi.order_id = o.order_id
        join products p
            on p.product_id = oi.product_id
        left join product_categories pc
            on pc.product_category_id = p.product_category_id
        left join public.unit_of_measure u
            on u.measure_id = p.measure_id
        join points pt
            on pt.point_id = o.point_id
        where
            o.status_id = 4
            and o.order_date::date = %(report_date)s
            and (
                %(all_points)s = true
                or o.point_id = any(%(selected_point_ids)s)
            )
        order by
            pt.sort_order nulls last,
            pc.sort_order,
            p.sort_order
    """, {
        "report_date": report_date,
        "all_points": all_points,
        "selected_point_ids": selected_point_ids
    })

    rows = cur.fetchall()
    for row in rows:
        print(row)

    # -------------------------
    # 5. Заглушки (пока нет логики)
    # -------------------------
    preview_data = None
    uploaded_file_name = None
    has_excel_file = False





    cur.close()
    conn.close()

    return render_template(
        "admin/orders_export.html",
        report_date=report_date,
        points=points,
        selected_point_ids=selected_point_ids,
        all_points=all_points,
        no_points_selected=no_points_selected,
        preview_data=preview_data,
        uploaded_file_name=uploaded_file_name,
        has_excel_file=has_excel_file
    )


@admin.route('/orders_export/upload_excel', methods=['POST'])
@admin_required
@login_required
def upload_excel():
    return redirect(url_for("admin.orders_export"))


@admin.route('/orders_export/remove_excel', methods=['POST'])
@admin_required
@login_required
def remove_excel():
    return redirect(url_for("admin.orders_export"))



@admin.route('/history')
@admin_required
@login_required
def history():
    return render_template('admin/history.html')