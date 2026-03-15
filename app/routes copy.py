from flask import Blueprint, render_template, request, redirect, url_for, session
from .db import get_db_connection
from .auth import login_required, point_required

main = Blueprint("main", __name__)


@main.route("/")
def index():
    if "user_id" not in session:
        return render_template("login.html")

    if session.get("is_admin"):
        return redirect(url_for("main.admin"))

    if "point_id" not in session:
        return redirect(url_for("main.select_point"))

    return redirect(url_for("main.orders"))


@main.route("/login", methods=["POST"])
def login():
    login_value = request.form.get("login")
    password = request.form.get("password")

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute(
        "select * from auth_login(%s, %s)",
        (login_value, password)
    )

    result = cur.fetchone()

    cur.close()
    conn.close()

    if result is None:
        return render_template("login.html", error="Ошибка аутентификации")

    ret_code, user_id, is_admin = result

    if ret_code == 1:
        return render_template("login.html", error="Пользователь не найден")

    if ret_code == 2:
        return render_template("login.html", error="Неправильный пароль")

    if ret_code == 3:
        return render_template(
            "login.html",
            error="Пользователь не администратор или ему не назначена точка"
        )

    session["user_id"] = user_id
    session["is_admin"] = is_admin

    if is_admin:
        return redirect(url_for("main.admin"))

    return redirect(url_for("main.select_point"))


@main.route("/admin")
@login_required
def admin():
    return "Admin panel"


@main.route("/select-point")
@login_required
def select_point():
    user_id = session.get("user_id")

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute(
        "select * from get_user_points(%s)",
        (user_id,)
    )

    points = cur.fetchall()

    cur.close()
    conn.close()

    if len(points) == 1:
        point_id, point_name = points[0]

        session["point_id"] = point_id
        session["point_name"] = point_name

        return redirect(url_for("main.orders"))

    return render_template("select_point.html", points=points)


@main.route("/set-point", methods=["POST"])
@login_required
def set_point():
    user_id = session.get("user_id")
    point_id = request.form.get("point_id")

    if not point_id:
        return redirect(url_for("main.select_point"))

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute(
        "select * from get_user_points(%s)",
        (user_id,)
    )

    points = cur.fetchall()

    cur.close()
    conn.close()

    selected_point = None

    for point in points:
        if str(point[0]) == point_id:
            selected_point = point
            break

    if not selected_point:
        return redirect(url_for("main.select_point"))

    session["point_id"] = selected_point[0]
    session["point_name"] = selected_point[1]

    return redirect(url_for("main.orders"))


@main.route("/orders")
@login_required
@point_required
def orders():
    point_id = session["point_id"]
    user_id = session["user_id"]

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute(
        "select * from get_or_create_order(%s, %s)",
        (point_id, user_id)
    )

    row = cur.fetchone()

    if row is None:
        cur.close()
        conn.close()
        return "Не удалось получить или создать заказ", 500

    order_id, status_id = row

    conn.commit()

    cur.execute("select * from v_get_products")
    products = cur.fetchall()

    cur.execute(
        "select * from get_current_order_products(%s)",
        (order_id,)
    )
    quantities = dict(cur.fetchall())
    cur.close()
    conn.close()

    categories = {}

    for cat_id, cat_name, product_id, product_name, measure_name in products:
        if cat_id not in categories:
            categories[cat_id] = {
                "name": cat_name,
                "products": []
            }

        quantity = quantities.get(product_id, "")

        categories[cat_id]["products"].append({
            "product_id": product_id,
            "name": product_name,
            "measure": measure_name,
            "quantity": quantity
        })

    return render_template(
        "orders.html",
        categories=categories,
        order_id=order_id,
        status_id=status_id
    )


@main.route("/orders/save", methods=["POST"])
@login_required
@point_required
def save_orders():
    order_id_raw = request.form.get("order_id")

    if not order_id_raw:
        return redirect(url_for("main.orders"))

    order_id = int(order_id_raw)

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute(
        "select status_id from orders where order_id = %s",
        (order_id,)
    )

    row = cur.fetchone()

    if row is None:
        cur.close()
        conn.close()
        return redirect(url_for("main.orders"))

    status_id = row[0]

    if status_id == 3:
        cur.close()
        conn.close()
        return redirect(url_for("main.orders"))

    items = {}


    for key, value in request.form.items():
        print(key.startswith("product_"))
        if not key.startswith("product_"):
            continue

        product_id = int(key.split("_")[1])

        value = value.strip()

        if value == "":
            quantity = 0
        else:
            quantity = round(float(value), 2)

        items[product_id] = quantity

    for product_id, quantity in items.items():
        if quantity <= 0:
            cur.execute("""
                delete from order_items
                where order_id = %s
                  and product_id = %s
            """, (order_id, product_id))
        else:
            cur.execute("""
                insert into order_items
                (
                    order_id,
                    product_id,
                    quantity
                )
                values
                (
                    %s,
                    %s,
                    %s
                )
                on conflict (order_id, product_id)
                do update
                set quantity = excluded.quantity
            """, (order_id, product_id, quantity))

    cur.execute("""
        update orders
        set status_id = 2
        where order_id = %s
          and status_id = 1
    """, (order_id,))

    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for("main.orders"))


@main.route("/disposals")
@login_required
@point_required
def disposals():
    return "Select disposals page"


@main.route("/logout")
@login_required
def logout():
    session.clear()
    return redirect(url_for("main.index"))