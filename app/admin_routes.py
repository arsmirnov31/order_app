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


@admin.route('/products')
@login_required
def products():
    search = (request.args.get("search") or "").strip()
    category_id = request.args.get("category_id")
    active_only = request.args.get("active_only")

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    query = """
    select
        v.product_category_id 
    ,   v.category_name
    ,   v.product_name
    ,   v.is_active
    ,   v.measure_name
    ,   v.product_id
    from v_get_products as v
    where 1=1
    """
    print(request.args)
    params = []

    if category_id:
        query += " and v.product_category_id = %s"
        params.append(category_id)

    print(f"Active only --- {active_only}")
    if active_only == "1":
        query += " and v.is_active = true"
  
    if search:
        query += " and v.product_name ilike %s"
        params.append(f"%{search}%")


    ##query += " order by c.name, v.product_name" 

    cur.execute(query, params)
    products = cur.fetchall()


    # категории для фильтра и формы
    cur.execute("""
        select product_category_id as id, name, is_active
        from product_categories
        --where is_active = true
        order by name
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


@admin.route('/products/add', methods=['POST'])
@login_required
def add_product():

    category_id = request.form.get("category_id")
    name = (request.form.get("name") or "").strip()
    measure = request.form.get("measure")
    is_active = request.form.get("is_active") == "on"

    search = request.form.get("search")
    category_id = request.form.get("category_id_filter")
    active_only = request.form.get("active_only_filter")
    if not name:
        flash("Введите название товара", "danger")
        return redirect(url_for(
            "admin.products",
            search=request.args.get("search"),
            category_id=request.args.get("category_id"),
            active_only=request.args.get("active_only")
        ))

    if not category_id:
        flash("Выберите категорию", "danger")
        return redirect(url_for(
            "admin.products",
            search=request.args.get("search"),
            category_id=request.args.get("category_id"),
            active_only=request.args.get("active_only")
        ))

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # проверка дубля
    cur.execute("""
        select 1
        from products
        where lower(name) = lower(%s)
          and product_category_id = %s
        limit 1
    """, (name, category_id))

    if cur.fetchone():
        cur.close()
        conn.close()
        flash("Такой товар уже существует", "warning")
        return redirect(url_for(
        "admin.products",
        search=request.args.get("search"),
        category_id=request.args.get("category_id"),
        active_only=request.args.get("active_only")
))

    # вставка
    cur.execute("""
        insert into products (product_category_id, name, measure_id, is_active)
        select  
            %s 
        ,   %s
        ,   (select measure_id from unit_of_measure where name = %s) as measure_id
        ,   %s     
    """, (category_id, name, measure, is_active))

    conn.commit()
    cur.close()
    conn.close()

    flash("Товар добавлен", "success")

    return redirect(url_for(
        "admin.products",
        search=search,
        category_id=category_id,
        active_only=active_only
    ))


@admin.route('/products/toggle/<int:product_id>', methods=['POST'])
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

    flash("Статус товара обновлён", "success")

    return redirect(request.referrer or url_for("admin.products"))


@admin.route('/products/update', methods=['POST'])
@login_required
def update_product():

    product_id = request.form.get("product_id")
    category_id = request.form.get("category_id")
    name = (request.form.get("name") or "").strip()
    measure = request.form.get("measure")
    is_active = request.form.get("is_active") == "on"

    search = request.form.get("search")
    category_id = request.form.get("category_id_filter")
    active_only = request.form.get("active_only_filter")
    
    print(f"Категория при обновлениеии {category_id}")
    if not product_id:
        flash("Ошибка: не передан ID товара", "danger")
        return redirect(url_for(
            "admin.products",
            search=request.args.get("search"),
            category_id=request.args.get("category_id"),
            active_only=request.args.get("active_only")
        ))

    conn = get_db_connection()
    cur = conn.cursor()

    # проверка дубля (кроме самого себя)
    cur.execute("""
        select 1
        from products
        where lower(name) = lower(%s)
          and product_category_id = %s
          and product_id != %s
        limit 1
    """, (name, category_id, product_id))

    if cur.fetchone():
        cur.close()
        conn.close()
        flash("Такой товар уже существует", "warning")
        return redirect(url_for(
            "admin.products",
            search=request.args.get("search"),
            category_id=request.args.get("category_id"),
            active_only=request.args.get("active_only")
        ))

    cur.execute("""
        update products
        set product_category_id = %s,
            name = %s,
            measure_id = (select measure_id from unit_of_measure where name = %s),
            is_active = %s
        where product_id = %s
    """, (category_id, name, measure, is_active, product_id))

    conn.commit()
    cur.close()
    conn.close()

    flash("Товар обновлён", "success")

    return redirect(url_for(
        "admin.products",
        search=search,
        category_id=category_id,
        active_only=active_only
    ))

@admin.route('/categories/add', methods=['POST'])
@login_required
def add_category():

    name = (request.form.get("name") or "").strip()
    is_active = request.form.get("is_active") == "on"

    if not name:
        flash("Введите название категории", "danger")
        return redirect(url_for(
            "admin.products",
            search=request.args.get("search"),
            category_id=request.args.get("category_id"),
            active_only=request.args.get("active_only")
        ))

    conn = get_db_connection()
    cur = conn.cursor()

    # проверка дубля
    cur.execute("""
        select 1
        from product_categories
        where lower(name) = lower(%s)
        limit 1
    """, (name,))

    if cur.fetchone():
        cur.close()
        conn.close()
        flash("Такая категория уже существует", "warning")
        return redirect(url_for(
            "admin.products",
            search=request.args.get("search"),
            category_id=request.args.get("category_id"),
            active_only=request.args.get("active_only")
        ))

    # вставка
    cur.execute("""
        insert into product_categories (name, is_active)
        values (%s, %s)
    """, (name, is_active))

    conn.commit()
    cur.close()
    conn.close()

    flash("Категория добавлена", "success")

    return redirect(url_for(
        "admin.products",
        search=request.args.get("search"),
        category_id=request.args.get("category_id"),
        active_only=request.args.get("active_only")
    ))


@admin.route('/categories/update', methods=['POST'])
@login_required
def update_category():

    category_id = request.form.get("category_id")
    name = (request.form.get("name") or "").strip()
    is_active = request.form.get("is_active") == "on"

    if not category_id:
        flash("Ошибка: нет ID категории", "danger")
        return redirect(url_for(
            "admin.products",
            search=request.args.get("search"),
            category_id=request.args.get("category_id"),
            active_only=request.args.get("active_only")
        ))

    conn = get_db_connection()
    cur = conn.cursor()

    # проверка дубля
    cur.execute("""
        select 1
        from product_categories
        where lower(name) = lower(%s)
          and product_category_id != %s
        limit 1
    """, (name, category_id))

    if cur.fetchone():
        cur.close()
        conn.close()
        flash("Такая категория уже существует", "warning")
        return redirect(url_for(
            "admin.products",
            search=request.args.get("search"),
            category_id=request.args.get("category_id"),
            active_only=request.args.get("active_only")
        ))

    cur.execute("""
        update product_categories
        set name = %s,
            is_active = %s
        where product_category_id = %s
    """, (name, is_active, category_id))

    conn.commit()
    cur.close()
    conn.close()

    flash("Категория обновлена", "success")

    return redirect(url_for(
        "admin.products",
        search=request.args.get("search"),
        category_id=request.args.get("category_id"),
        active_only=request.args.get("active_only")
    ))


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