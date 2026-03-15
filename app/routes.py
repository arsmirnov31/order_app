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
    else:
        return redirect(url_for("main.orders"))

    # if "user_id" in session:

    #     if session.get("is_admin"):
    #         return redirect(url_for("main.admin"))
    #     else:
    #         return redirect(url_for("main.select_point"))
    # return render_template("login.html")


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

    print("LOGIN:", login)
    print("PASSWORD:", password)

    # редирект
    if is_admin:
        return redirect("/admin")
    else:
        return redirect("/select-point")


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
    return "Select orders page"

@main.route("/disposals")
@login_required
@point_required
def disposals():
    return "Select disposals page"


@login_required
@main.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("main.index"))