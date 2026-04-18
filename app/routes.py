from flask import Blueprint, render_template, request, redirect, url_for, session, abort, flash
from .db import get_db_connection
from .auth import login_required, point_required


main = Blueprint("main", __name__)


@main.route("/")
def index():
    if "user_id" not in session:
        return render_template("login.html")
    
    if session.get("is_admin"):
        return redirect(url_for("admin.dashboard"))
    
    if "point_id" not in session:
        return redirect(url_for("main.select_point"))
    else:
        return redirect(url_for("main.orders"))

@main.route("/login", methods=["POST"])
def login():

    login = request.form.get("login")
    password = request.form.get("password")
    
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "select * from auth_login(%s,%s)",
        (login, password)
    )

    result = cur.fetchone()
    cur.close()
    conn.close()

    ret_code, user_id, is_admin = result

    # ошибка аутентификации
    if ret_code == 1:
        return render_template("login.html", error="Пользователь не найден")
    
    if ret_code == 2:
        return render_template("login.html", error="Неправильный пароль")
    
    if ret_code == 3:
        return render_template("login.html", error="Пользователь не администратор или ему не назначена точка")
    
    # создаем session
    session["user_id"] = user_id
    session["is_admin"] = is_admin


    # редирект
    if is_admin:
        return redirect("/admin")
    else:
        return redirect("/select-point")



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

    # если точка одна — выбираем автоматически
    if len(points) == 1:

        point_id, point_name = points[0]

        session["point_id"] = point_id
        session["point_name"] = point_name

        return redirect(url_for("main.orders"))

    # если несколько — показываем страницу выбора
    return render_template(
        "select_point.html",
        points=points
    )

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

    for p in points:
        if str(p[0]) == point_id:
            selected_point = p
            break

    # если точка не найдена среди доступных
    if not selected_point:
        return redirect(url_for("main.select_point"))

    session["point_id"] = selected_point[0]
    session["point_name"] = selected_point[1]

    return redirect(url_for("main.orders"))

@main.route("/orders")
@login_required
@point_required
def orders():

    # Получаем нужные идетификаторы из сессии
    point_id = session["point_id"]
    user_id = session["user_id"]

    conn = get_db_connection()
    cur = conn.cursor()
    print(f"Создаем или используем старый заказ для полльзователя {user_id} в точке {point_id}")

    ## В этой функции мы определяем, создается новый заказ или используется старый
    cur.execute(
        "select * from get_or_create_order(%s,%s)",
        (point_id, user_id )
    )
    ## Запоминаем заказ и его статус
    order_id, status_id, order_date = cur.fetchone()
    
    ## Получаем список всех продуктов
    conn.commit()
    cur.execute("""
        select
            product_category_id
        ,   category_name
        ,   product_id
        ,   product_name
        ,   measure_name    
        from v_get_products
    """)

    products = cur.fetchall()

    ## Получаем текущие позиции в заказе
    cur.execute(
        "select product_id,  quantity from get_current_order_products(%s)",
        (order_id,)
    )

    quantities = dict(cur.fetchall())

    categories = {}

    for cat_id, cat_name, prod_id, prod_name, measure in products:
        
        ## Добавляем только категории в словарь
        if cat_id not in categories:
            categories[cat_id] = {
                "name": cat_name,
                "products": []
            }

        ## Получаем количество уже учтенных товаров
        quantity = quantities.get(prod_id, "")

        ## Формирую результирующую выборку. 
        categories[cat_id]["products"].append({
            "product_id": prod_id,
            "name": prod_name,
            "measure": measure,
            "quantity": quantity
        })

    cur.close()
    
    conn.close()
    
    return render_template(
        "orders.html",
        categories=categories,
        order_id=order_id,
        status_id=status_id,
        order_date = order_date,
    )

@main.route("/orders/save", methods=["POST"])
@login_required
@point_required
def save_orders():

    ## Процедура сохранения заказа
    order_id = int(request.form.get("order_id"))
    is_approved = request.form.get("is_approved")  # галка

    conn = get_db_connection()
    cur = conn.cursor()

    ## Получаем текущий статус заказа
    cur.execute(
        "select status_id from get_order_status_id(%s)",
        (order_id,)
    )

    status_id = cur.fetchone()[0]


    if status_id  not in (1,2):
        cur.close()
        conn.close()
        return redirect(url_for("main.orders"))

    for key, value in request.form.items():
        
        ## Построково обрабатываем форму, нас интересуют те строки, которые начинаются с
        ## product_
        if not key.startswith("product_"):
            continue
        
        
        product_id = int(key.split("_")[1])  
        value = value.strip()

        if value == "":
            quantity = 0
        else:
            quantity = round(float(value), 2)

        quantity = round(quantity, 2)
        print(f"Для заказа {order_id}, отметили продукт с идетификатором {product_id} в количестве {quantity}")
        
        ## Если что то добавилось, мы это добавляем 
        if quantity > 0:
            print('Вызов процедуроы')
            cur.execute(
                "call add_info_product_order(%(order_id)s, %(product_id)s, %(quantity)s)",
                {'order_id': order_id, 'product_id': product_id, 'quantity': quantity}
            )
            conn.commit()
        else:
            cur.execute("""
                delete from order_items
                where order_id=%s
                and product_id=%s
            """, (order_id, product_id))

    # --- установка статуса ---
    if is_approved:
        new_status = 3  # Заказ отправлен на утверждение
    else:
        new_status = 2  # Заказ в процессе создания

    cur.execute("""
        update orders
        set status_id = %s
        where order_id = %s
    """, (new_status, order_id))
    
    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for("main.orders"))


@main.route("/disposals")
@login_required
@point_required
def disposals():
    # Получаем нужные идетификаторы из сессии
    point_id = session["point_id"]
    user_id = session["user_id"]
    conn = get_db_connection()
    cur = conn.cursor()
    print(f"Создаем или используем старую форму списаний для полльзователя в точке {point_id}")

        ## В этой функции мы определяем, создается новый заказ или используется старый
    cur.execute(
        "select * from get_or_create_disposal(%s,%s)",
        (point_id,user_id)
    )
    ## Запоминаем заказ и его статус
    disposal_id, status_id = cur.fetchone()
    

    conn.commit()

    ## Получаем список всех продуктов
    cur.execute("""
        select
            product_category_id
        ,   category_name
        ,   product_id
        ,   product_name
        ,   measure_name    
        from v_get_products
    """)

    products = cur.fetchall()

    ## Получаем текущие позиции в заказе
    cur.execute(
        "select product_id,  quantity from get_current_disposal_products(%s)",
        (disposal_id,)
    )

    quantities = dict(cur.fetchall())

    categories = {}

    for cat_id, cat_name, prod_id, prod_name, measure in products:
        
        ## Добавляем только категории в словарь
        if cat_id not in categories:
            categories[cat_id] = {
                "name": cat_name,
                "products": []
            }

        ## Получаем количество уже учтенных товаров
        quantity = quantities.get(prod_id, "")

        ## Формирую результирующую выборку. 
        categories[cat_id]["products"].append({
            "product_id": prod_id,
            "name": prod_name,
            "measure": measure,
            "quantity": quantity
        })

    cur.close()
    
    conn.close()

    return render_template(
        "disposals.html",
        categories=categories,
        disposal_id=disposal_id,
        status_id=status_id
    )

@main.route("/save_disposals", methods=["POST"])
@login_required
@point_required
def save_disposals():

    ## Процедура сохранения заказа
    disposal_id = int(request.form.get("disposal_id"))
    is_approved = request.form.get("is_approved")  # галка

    conn = get_db_connection()
    cur = conn.cursor()

    ## Получаем текущий статус заказа
    cur.execute(
        "select status_id from get_disposal_status_id(%s)",
        (disposal_id,)
    )

    status_id = cur.fetchone()[0]

    ## Статус = 3 это финальный статус. Возвращаем на страницу с заказами.
    if status_id  not in  (1,2):
        cur.close()
        conn.close()
        return redirect(url_for("main.disposals"))

    for key, value in request.form.items():
        
        ## Построково обрабатываем форму, нас интересуют те строки, которые начинаются с
        ## product_
        if not key.startswith("product_"):
            continue
        
        
        product_id = int(key.split("_")[1])  
        value = value.strip()

        if value == "":
            quantity = 0
        else:
            quantity = round(float(value), 2)

        quantity = round(quantity, 2)
        print(f"Для заказа {disposal_id}, отметили продукт с идетификатором {product_id} в количестве {quantity}")
        
        ## Если что то добавилось, мы это добавляем 
        if quantity > 0:
            print('Вызов процедуроы')
            cur.execute(
                "call add_info_product_disposal(%(disposal_id)s, %(product_id)s, %(quantity)s)",
                {'disposal_id': disposal_id, 'product_id': product_id, 'quantity': quantity}
            )
            conn.commit()
        else:
            cur.execute("""
                delete from disposal_items
                where disposal_id=%s
                and product_id=%s
            """, (disposal_id, product_id))

    # --- установка статуса ---
    if is_approved:
        new_status = 3  # Списание в  процессе создания
    else:
        new_status = 2  # Списание отправлено на утверждение

    cur.execute("""
        update disposals
        set status_id = %s
        where disposal_id = %s
    """, (new_status, disposal_id))
    
    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for("main.disposals"))


@login_required
@point_required
@main.route("/order_history")
def order_history():
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        select order_id, order_date, status_id
        from orders
        where point_id = %s
          and status_id not in (2,3)
        order by order_date desc
    """, (session["point_id"],))

    orders = cur.fetchall()

    result = []

    for o in orders:
        order_id, order_date, status_id = o

        # считаем через функцию
        cur.execute("""
            select count(*) 
            from get_order_items(%s)
        """, (order_id,))

        count = cur.fetchone()[0]

        result.append({
            "order_id": order_id,
            "order_date": order_date,
            "status_id": status_id,
            "items_count": count
        })

    cur.close()
    conn.close()

    return render_template(
        "order_history.html",
        orders=result
    )

@main.route("/order/<int:order_id>", methods=["GET", "POST"])
@login_required
@point_required
def order_view(order_id):

    conn = get_db_connection()
    cur = conn.cursor()

    # --- POST ---
    if request.method == "POST":
        print(f"Пользователь проверяет товар")
        cur.execute("""
            select status_id
            from orders
            where order_id = %s
              and point_id = %s
        """, (order_id, session["point_id"]))

        current_status = cur.fetchone()[0]

        if current_status != 5:
            flash("Редактирование запрещено", "danger")
            return redirect(url_for("main.order_view", order_id=order_id))

        action = request.form.get("action")

        print(f"Пользователь прошел проверку статуса")

        # --- обновление существующих ---
        for key, value in request.form.items():
            if key.startswith("delivered_"):

                product_id = int(key.replace("delivered_", ""))

                if not value:
                    continue

                try:
                    delivered = float(value)
                except:
                    continue

                cur.execute("""
                    update order_items
                    set delivered_quantity = %s
                    where order_id = %s
                      and product_id = %s
                """, (delivered, order_id, product_id,))

        print(f"Пользователь пытается изменить для заказа {order_id}, и продукты {product_id}, значение доставленного товара {delivered}")
        # --- новые ---
        new_items = {}

        for key, value in request.form.items():

            if key.startswith("new_product_id_"):
                idx = key.replace("new_product_id_", "")
                new_items[idx] = {"product_id": value}

            elif key.startswith("new_delivered_"):
                idx = key.replace("new_delivered_", "")
                if idx not in new_items:
                    new_items[idx] = {}
                new_items[idx]["delivered"] = value

        for item in new_items.values():

            product_id = item.get("product_id")
            delivered = item.get("delivered")

            if not product_id or not delivered:
                continue

            try:
                delivered = float(delivered)
            except:
                continue

            cur.execute("""
                insert into order_items
                    (order_id, product_id, quantity, delivered_quantity, is_extra_item)
                values (%s, %s, 0, %s, true)
                on conflict (order_id, product_id)
                do update set delivered_quantity = excluded.delivered_quantity
            """, (order_id, product_id, delivered))

        # --- удаление лишнего ---
        cur.execute("""
            delete from order_items
            where order_id = %s
              and delivered_quantity = 0
              and is_extra_item = true
        """, (order_id,))

        # --- принятие ---
        if action == "accept":
            cur.execute("""
                update orders
                set status_id = 6
                where order_id = %s
            """, (order_id,))

            conn.commit()
            flash("Заказ принят", "success")
            return redirect(url_for("main.order_history"))

        conn.commit()
        flash("Сохранено", "success")

    # --- GET ---
    cur.execute("""
        select order_id, order_date, status_id
        from orders
        where order_id = %s
          and point_id = %s
    """, (order_id, session["point_id"]))

    order = cur.fetchone()

    order_id, order_date, status_id = order

    cur.execute("""
        select 
            c.product_category_id,
            c.name,
            p.product_id,
            p.name,
            oi.quantity,
            oi.delivered_quantity,
            u.name,
            oi.is_extra_item
        from order_items oi
        join products p on oi.product_id = p.product_id
        join product_categories c on p.product_category_id = c.product_category_id
        join unit_of_measure u on p.measure_id = u.measure_id
        where oi.order_id = %s
        order by 
            c.sort_order nulls last,
            c.name,
            p.sort_order nulls last,
            p.name
    """, (order_id,))

    items = cur.fetchall()

    grouped = {}

    for i in items:
        cat_id = i[0]
        cat_name = i[1]

        if cat_id not in grouped:
            grouped[cat_id] = {
                "name": cat_name,
                "products": []
            }

        grouped[cat_id]["products"].append(i)

    cur.close()
    conn.close()

    return render_template(
        "order_view.html",
        order_id=order_id,
        order_date=order_date,
        status_id=status_id,
        grouped_items=grouped
    )


@main.route("/api/products")
@login_required
@point_required
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

@login_required
@main.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("main.index"))