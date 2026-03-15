import psycopg2
from flask import current_app


def get_db_connection():

    db = current_app.config["DATABASE"]

    conn = psycopg2.connect(
        host=db["host"],
        database=db["database"],
        user=db["user"],
        password=db["password"]
    )

    return conn