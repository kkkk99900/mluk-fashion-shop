FROM python:3.13-slim-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && curl -fsSLo /tmp/microsoft-prod.deb https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb \
    && dpkg -i /tmp/microsoft-prod.deb \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 \
    && rm -rf /var/lib/apt/lists/* /tmp/microsoft-prod.deb

WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt 'gunicorn>=23,<24' \
    && useradd --system --create-home mluk

COPY --chown=mluk:mluk app.py db.py ./
COPY --chown=mluk:mluk templates/ ./templates/
COPY --chown=mluk:mluk static/ ./static/

ENV PORT=10000 \
    SQL_AUTH=sql \
    SQL_CONNECT_TIMEOUT=45 \
    SQL_TRUST_SERVER_CERTIFICATE=no \
    COOKIE_SECURE=1 \
    FLASK_DEBUG=0 \
    PYTHONDONTWRITEBYTECODE=1

USER mluk
EXPOSE 10000
CMD ["sh", "-c", "exec gunicorn --workers 1 --threads 4 --timeout 75 --bind 0.0.0.0:${PORT} app:app"]
