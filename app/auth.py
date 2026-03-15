from functools import wraps
from flask import session, redirect, url_for


def login_required(view):

    @wraps(view)
    def wrapped_view(*args, **kwargs):

        if "user_id" not in session:
            return redirect(url_for("main.index"))

        return view(*args, **kwargs)

    return wrapped_view

def point_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):

        if "point_id" not in session:
            return redirect(url_for("main.select_point"))

        return f(*args, **kwargs)

    return decorated_function