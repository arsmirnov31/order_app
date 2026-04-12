from .auth import login_required, point_required, admin_required
from flask import Blueprint, render_template, request, redirect, url_for, session, flash
from .db import get_db_connection
import psycopg2.extras


admin = Blueprint('admin', __name__, url_prefix='/admin')


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
@login_required
@admin_required
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
@login_required
@admin_required
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
@login_required
@admin_required
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
@login_required
@admin_required
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


@admin.route('/orders')
@admin_required
@login_required
def orders():
    return render_template('admin/orders.html')


@admin.route('/disposals')
@admin_required
@login_required
def disposals():
    return render_template('admin/disposals.html')

@admin.route('/history')
@admin_required
@login_required
def history():
    return render_template('admin/history.html')