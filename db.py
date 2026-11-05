"""Kết nối trực tiếp Microsoft SQL Server, giữ nguyên schema bài tập lớn."""
import os
from contextlib import contextmanager
from dotenv import load_dotenv

load_dotenv()


def _pyodbc():
    import pyodbc
    return pyodbc


def connect():
    pyodbc = _pyodbc()
    available = pyodbc.drivers()
    driver = os.getenv('SQL_DRIVER', '').strip()
    if not driver:
        driver = next((d for d in reversed(available) if 'ODBC Driver 18 for SQL Server' in d), None)
        if not driver:
            driver = next((d for d in reversed(available) if 'ODBC Driver 17 for SQL Server' in d), None)
    if not driver:
        raise RuntimeError('Chưa cài Microsoft ODBC Driver 17/18 for SQL Server. Xem README.md.')

    server = os.getenv('SQL_SERVER', r'localhost\SQLEXPRESS')
    database = os.getenv('SQL_DATABASE', 'QL_ThoiTrang')
    parts = [f'DRIVER={{{driver}}}', f'SERVER={server}', f'DATABASE={database}',
             'Encrypt=yes', 'TrustServerCertificate=yes', 'Connection Timeout=8']
    if os.getenv('SQL_AUTH', 'windows').lower() == 'windows':
        parts.append('Trusted_Connection=yes')
    else:
        parts.extend([f"UID={os.getenv('SQL_USER', '')}", f"PWD={os.getenv('SQL_PASSWORD', '')}"])
    return pyodbc.connect(';'.join(parts), autocommit=False)


def dict_row(cursor, row):
    if row is None:
        return None
    return dict(zip([d[0] for d in cursor.description], row))


@contextmanager
def transaction():
    conn = connect()
    try:
        yield conn.cursor()
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def all_rows(query, args=()):
    conn = connect()
    try:
        cursor = conn.cursor()
        cursor.execute(query, *tuple(args))
        return [dict_row(cursor, row) for row in cursor.fetchall()]
    finally:
        conn.close()


def one_row(query, args=()):
    conn = connect()
    try:
        cursor = conn.cursor()
        cursor.execute(query, *tuple(args))
        return dict_row(cursor, cursor.fetchone())
    finally:
        conn.close()


def scalar(query, args=(), default=0):
    row = one_row(query, args)
    return next(iter(row.values())) if row else default
