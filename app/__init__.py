from flask import Flask

def create_app():
    app = Flask(__name__)

    # подключаем конфиг
    app.config.from_object("app.config")

    # нужен для session
    app.secret_key = "d8c2e5f7c3a1a3c9e4b0f2d8c7e9a1b4"

    from .routes import main
    app.register_blueprint(main)

    return app