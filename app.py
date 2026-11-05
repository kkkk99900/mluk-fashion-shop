"""Fashion Management - Flask + Microsoft SQL Server (11 bảng SQL gốc)."""
import os
import re
import secrets
import uuid
from datetime import datetime, date, timedelta
from decimal import Decimal
from functools import wraps
from pathlib import Path

import click
from dotenv import load_dotenv
from flask import (Flask, abort, flash, g, redirect, render_template, request,
                   session, url_for)
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.utils import secure_filename

from db import all_rows, connect, one_row, scalar, transaction, dict_row

load_dotenv()
app = Flask(__name__)
app.config.update(
    SECRET_KEY=os.getenv('SECRET_KEY') or secrets.token_hex(32),
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE='Lax',
    SESSION_COOKIE_SECURE=os.getenv('COOKIE_SECURE', '0') == '1',
    MAX_CONTENT_LENGTH=3 * 1024 * 1024,
)
ROOT = Path(__file__).resolve().parent
UPLOAD_DIR = ROOT / 'static' / 'uploads'
UPLOAD_DIR.mkdir(exist_ok=True, parents=True)
ORDER_STATUSES = ['ChoXacNhan', 'DangXuLy', 'DangGiao', 'DaGiao', 'DaHuy']
ORDER_LABELS = dict(zip(ORDER_STATUSES, ['Chờ xác nhận', 'Đang xử lý', 'Đang giao', 'Đã giao', 'Đã hủy']))
PRODUCT_STATUSES = ['DangKinhDoanh', 'NgungKinhDoanh', 'HetHang']
ALLOWED_TRANSITIONS = {
    'ChoXacNhan': ['DangXuLy', 'DaHuy'],
    'DangXuLy': ['DangGiao', 'DaHuy'],
    'DangGiao': ['DaGiao', 'DaHuy'],
    'DaGiao': [], 'DaHuy': [],
}


def clean_str(v, max_len=255):
    return (v or '').strip()[:max_len]


def get_positive_int(v, default=None):
    try:
        value = int(v)
        return value if value > 0 else default
    except (TypeError, ValueError):
        return default


def get_nonnegative_int(v, default=None):
    try:
        value = int(v)
        return value if value >= 0 else default
    except (TypeError, ValueError):
        return default


def image_for_product(p):
    name = (p.get('HinhAnh') or '').strip()
    if name and (ROOT / 'static' / 'uploads' / Path(name).name).is_file():
        return url_for('static', filename='uploads/' + Path(name).name)
    if name and (ROOT / 'static' / 'img' / 'products' / Path(name).name).is_file():
        return url_for('static', filename='img/products/' + Path(name).name)
    category = (p.get('TenDM') or '').lower()
    if 'váy' in category or 'đầm' in category:
        kind = 'dress'
    elif 'quần' in category:
        kind = 'pants'
    elif 'khoác' in category:
        kind = 'jacket'
    elif 'phụ kiện' in category:
        kind = 'accessory'
    else:
        kind = 'shirt'
    return url_for('static', filename=f'img/{kind}.svg')


@app.template_filter('vnd')
def vnd(value):
    return f"{int(value or 0):,}".replace(',', '.') + ' ₫'


@app.template_filter('datevn')
def datevn(value):
    return value.strftime('%d/%m/%Y %H:%M') if hasattr(value, 'strftime') else '—'


@app.context_processor
def templates_shared():
    return {'me': getattr(g, 'user', None), 'csrf_token': session.get('_csrf', ''),
            'status_labels': ORDER_LABELS, 'product_image': image_for_product,
            'now_year': datetime.now().year}


@app.before_request
def before():
    if '_csrf' not in session:
        session['_csrf'] = secrets.token_urlsafe(32)
    if request.method == 'POST':
        supplied = request.form.get('_csrf') or request.headers.get('X-CSRF-Token', '')
        if not secrets.compare_digest(supplied, session['_csrf']):
            abort(400, 'Yêu cầu không hợp lệ (CSRF). Tải lại trang và thử lại.')
    g.user = None
    uid = session.get('uid')
    if uid:
        g.user = one_row('''SELECT tk.MaTK, tk.TenDangNhap, tk.VaiTro, tk.TrangThai,
                                   tk.Email, kh.MaKH, kh.HoTen, kh.SDT
                            FROM TaiKhoan tk LEFT JOIN KhachHang kh ON kh.MaTK=tk.MaTK
                            WHERE tk.MaTK=?''', (uid,))
        if not g.user or g.user['TrangThai'] != 'HoatDong':
            session.pop('uid', None)
            g.user = None


def login_required(fn):
    @wraps(fn)
    def decorated(*args, **kwargs):
        if not g.user:
            flash('Vui lòng đăng nhập để sử dụng chức năng này.', 'info')
            return redirect(url_for('login'))
        return fn(*args, **kwargs)
    return decorated


def customer_required(fn):
    @wraps(fn)
    @login_required
    def decorated(*args, **kwargs):
        if not g.user.get('MaKH'):
            flash('Hãy đăng nhập bằng tài khoản khách hàng.', 'error')
            return redirect(url_for('home'))
        return fn(*args, **kwargs)
    return decorated


def admin_required(fn):
    @wraps(fn)
    @login_required
    def decorated(*args, **kwargs):
        if g.user['VaiTro'] not in ('Admin', 'NhanVien'):
            abort(403)
        return fn(*args, **kwargs)
    return decorated


def only_admin(fn):
    @wraps(fn)
    @admin_required
    def decorated(*args, **kwargs):
        if g.user['VaiTro'] != 'Admin':
            abort(403)
        return fn(*args, **kwargs)
    return decorated


def categories(active=True):
    return all_rows('SELECT MaDM, TenDM, MoTa, TrangThai FROM DanhMuc '
                    + ("WHERE TrangThai=N'HoatDong' " if active else '') + 'ORDER BY MaDM')


def products(limit=None, category=None, keyword='', order='new'):
    cond = ['1=1']
    args = []
    if category:
        cond.append('sp.MaDM=?')
        args.append(category)
    if keyword:
        cond.append('(v.TenSP LIKE ? OR v.TenDM LIKE ?)')
        args += [f'%{keyword}%', f'%{keyword}%']
    order_by = {'new':'v.MaSP DESC', 'low':'v.GiaBan ASC', 'high':'v.GiaBan DESC',
                'name':'v.TenSP ASC'}.get(order, 'v.MaSP DESC')
    top = f'TOP {int(limit)}' if limit else ''
    query = f'''SELECT {top} v.*, sp.MaDM, sp.MoTa
        FROM v_SanPhamHienThiWeb v JOIN SanPham sp ON v.MaSP=sp.MaSP
        JOIN DanhMuc dm ON dm.MaDM=sp.MaDM
        WHERE dm.TrangThai=N'HoatDong' AND {' AND '.join(cond)} ORDER BY {order_by}'''
    return all_rows(query, args)


@app.route('/')
def home():
    return render_template('home.html', featured=products(limit=8), cats=categories())


@app.route('/cua-hang')
def shop():
    cat = get_positive_int(request.args.get('danh_muc'))
    q = clean_str(request.args.get('q'), 100)
    order = request.args.get('sap_xep', 'new')
    if order not in ('new', 'low', 'high', 'name'):
        order = 'new'
    return render_template('shop.html', items=products(category=cat, keyword=q, order=order),
                           cats=categories(), selected_cat=cat, search=q, selected_sort=order)


@app.route('/san-pham/<int:pid>')
def product_detail(pid):
    p = one_row('''SELECT sp.*, dm.TenDM FROM SanPham sp JOIN DanhMuc dm ON dm.MaDM=sp.MaDM
                   WHERE sp.MaSP=? AND sp.TrangThai=N'DangKinhDoanh'
                   AND dm.TrangThai=N'HoatDong' ''', (pid,))
    if not p:
        abort(404)
    variants = all_rows('''SELECT * FROM dbo.fn_TimKiemBienTheTheoSanPham(?) ORDER BY KichCo, MauSac''', (pid,))
    reviews = all_rows('''SELECT dg.SoSao, dg.NoiDung, dg.NgayDanhGia, kh.HoTen
                    FROM DanhGia dg JOIN KhachHang kh ON kh.MaKH=dg.MaKH
                    WHERE dg.MaSP=? AND dg.TrangThai=N'HienThi' ORDER BY dg.NgayDanhGia DESC''', (pid,))
    return render_template('product.html', p=p, variants=variants, reviews=reviews)


@app.route('/dang-ky', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = clean_str(request.form.get('username'), 50)
        name = clean_str(request.form.get('fullname'), 100)
        email = clean_str(request.form.get('email'), 100)
        phone = clean_str(request.form.get('phone'), 15)
        password = request.form.get('password', '')
        if not re.fullmatch(r'[a-zA-Z0-9_]{4,50}', username):
            flash('Tên đăng nhập 4–50 ký tự, chỉ gồm chữ, số và dấu gạch dưới.', 'error')
        elif not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email):
            flash('Email không hợp lệ.', 'error')
        elif not name or len(password) < 8 or len(password) > 128:
            flash('Vui lòng nhập tên và mật khẩu từ 8 đến 128 ký tự.', 'error')
        elif not re.fullmatch(r'0[0-9]{9,10}', phone):
            flash('Số điện thoại phải có 10–11 chữ số và bắt đầu bằng 0.', 'error')
        elif one_row('SELECT MaTK FROM TaiKhoan WHERE TenDangNhap=? OR Email=?', (username, email)):
            flash('Tên đăng nhập hoặc email đã được sử dụng.', 'error')
        else:
            try:
                with transaction() as cur:
                    cur.execute('''INSERT INTO TaiKhoan(TenDangNhap,MatKhau,Email,VaiTro)
                                   OUTPUT INSERTED.MaTK VALUES(?,?,?,N'KhachHang')''',
                                username, generate_password_hash(password), email)
                    ma_tk = int(cur.fetchone()[0])
                    cur.execute('''INSERT INTO KhachHang(MaTK,HoTen,SDT)
                                   OUTPUT INSERTED.MaKH VALUES(?,?,?)''', ma_tk, name, phone)
                    ma_kh = int(cur.fetchone()[0])
                    cur.execute('INSERT INTO GioHang(MaKH) VALUES(?)', ma_kh)
                session.clear()
                session['uid'] = ma_tk
                flash('Đăng ký thành công! Chào mừng đến với MLUK.', 'success')
                return redirect(url_for('shop'))
            except Exception:
                app.logger.exception('Đăng ký không thành công')
                flash('Không thể tạo tài khoản; kiểm tra email/tên đăng nhập rồi thử lại.', 'error')
    return render_template('register.html')


@app.route('/dang-nhap', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = clean_str(request.form.get('username'), 100)
        password = request.form.get('password', '')
        acc = one_row('''SELECT MaTK, MatKhau, VaiTro, TrangThai FROM TaiKhoan
                         WHERE TenDangNhap=? OR Email=?''', (username, username))
        valid = False
        if acc and acc['MatKhau'] and acc['MatKhau'] != 'hash_pass_123':
            try:
                valid = check_password_hash(acc['MatKhau'], password)
            except (ValueError, TypeError):
                valid = False
        if not acc or not valid or acc['TrangThai'] != 'HoatDong':
            flash('Tài khoản hoặc mật khẩu không đúng, hoặc tài khoản bị khóa.', 'error')
        else:
            session.clear()
            session['uid'] = acc['MaTK']
            flash('Đăng nhập thành công.', 'success')
            return redirect(url_for('dashboard' if acc['VaiTro'] in ('Admin','NhanVien') else 'home'))
    return render_template('login.html')


@app.post('/dang-xuat')
@login_required
def logout():
    session.clear()
    flash('Đã đăng xuất.', 'success')
    return redirect(url_for('home'))


def get_cart_items(kh_id):
    return all_rows('''SELECT gh.MaGH, bt.MaBienThe, bt.MaSKU, bt.KichCo, bt.MauSac,
                      bt.SoLuongTon, ct.SoLuong, sp.MaSP, sp.TenSP, sp.GiaBan, sp.HinhAnh,
                      sp.TrangThai, dm.TenDM, (ct.SoLuong * sp.GiaBan) AS ThanhTien
                      FROM GioHang gh JOIN ChiTietGioHang ct ON ct.MaGH=gh.MaGH
                      JOIN BienTheSanPham bt ON bt.MaBienThe=ct.MaBienThe
                      JOIN SanPham sp ON sp.MaSP=bt.MaSP
                      JOIN DanhMuc dm ON dm.MaDM=sp.MaDM WHERE gh.MaKH=?
                      ORDER BY sp.TenSP''', (kh_id,))


@app.route('/gio-hang')
@customer_required
def cart():
    items = get_cart_items(g.user['MaKH'])
    return render_template('cart.html', items=items,
                           total=sum((x['ThanhTien'] for x in items), Decimal('0')))


@app.post('/gio-hang/them')
@customer_required
def cart_add():
    var_id = get_positive_int(request.form.get('variant_id'))
    qty = get_positive_int(request.form.get('quantity'))
    if not var_id or not qty or qty > 100:
        flash('Số lượng mua phải từ 1 đến 100.', 'error')
        return redirect(url_for('shop'))
    try:
        with transaction() as cur:
            cur.execute('''SELECT bt.SoLuongTon FROM BienTheSanPham bt
                           JOIN SanPham sp ON sp.MaSP=bt.MaSP
                           JOIN DanhMuc dm ON dm.MaDM=sp.MaDM
                           WHERE bt.MaBienThe=? AND sp.TrangThai=N'DangKinhDoanh'
                           AND dm.TrangThai=N'HoatDong' ''', var_id)
            row = cur.fetchone()
            if not row:
                raise ValueError('Sản phẩm không tồn tại hoặc đã ngừng kinh doanh.')
            available = int(row[0])
            cur.execute('SELECT MaGH FROM GioHang WHERE MaKH=?', g.user['MaKH'])
            row = cur.fetchone()
            if not row:
                cur.execute('INSERT INTO GioHang(MaKH) OUTPUT INSERTED.MaGH VALUES(?)', g.user['MaKH'])
                gh_id = int(cur.fetchone()[0])
            else:
                gh_id = int(row[0])
            cur.execute('SELECT SoLuong FROM ChiTietGioHang WHERE MaGH=? AND MaBienThe=?', gh_id, var_id)
            old = cur.fetchone()
            new_qty = qty + (int(old[0]) if old else 0)
            if new_qty > available:
                raise ValueError(f'Tồn kho chỉ còn {available} sản phẩm.')
            if old:
                cur.execute('UPDATE ChiTietGioHang SET SoLuong=? WHERE MaGH=? AND MaBienThe=?',
                            new_qty, gh_id, var_id)
            else:
                cur.execute('INSERT INTO ChiTietGioHang(MaGH,MaBienThe,SoLuong) VALUES(?,?,?)',
                            gh_id, var_id, qty)
            cur.execute('UPDATE GioHang SET NgayCapNhat=GETDATE() WHERE MaGH=?', gh_id)
        flash('Đã thêm sản phẩm vào giỏ hàng.', 'success')
    except ValueError as exc:
        flash(str(exc), 'error')
    except Exception:
        app.logger.exception('Không thể thêm giỏ hàng')
        flash('Lỗi khi thêm sản phẩm vào giỏ hàng.', 'error')
    return redirect(url_for('cart'))


@app.post('/gio-hang/cap-nhat/<int:var_id>')
@customer_required
def cart_update(var_id):
    qty = get_nonnegative_int(request.form.get('quantity'))
    if qty is None or qty > 100:
        flash('Số lượng không hợp lệ.', 'error')
        return redirect(url_for('cart'))
    try:
        with transaction() as cur:
            cur.execute('''SELECT ct.SoLuong, bt.SoLuongTon, gh.MaGH FROM ChiTietGioHang ct
                           JOIN GioHang gh ON gh.MaGH=ct.MaGH
                           JOIN BienTheSanPham bt ON bt.MaBienThe=ct.MaBienThe
                           WHERE gh.MaKH=? AND ct.MaBienThe=?''', g.user['MaKH'], var_id)
            item = cur.fetchone()
            if not item:
                raise ValueError('Sản phẩm không tồn tại trong giỏ hàng.')
            if qty > int(item[1]):
                raise ValueError(f'Chỉ còn {item[1]} sản phẩm trong kho.')
            if qty == 0:
                cur.execute('DELETE FROM ChiTietGioHang WHERE MaGH=? AND MaBienThe=?', item[2], var_id)
            else:
                cur.execute('UPDATE ChiTietGioHang SET SoLuong=? WHERE MaGH=? AND MaBienThe=?',
                            qty, item[2], var_id)
            cur.execute('UPDATE GioHang SET NgayCapNhat=GETDATE() WHERE MaGH=?', item[2])
        flash('Đã cập nhật giỏ hàng.', 'success')
    except ValueError as exc:
        flash(str(exc), 'error')
    except Exception:
        app.logger.exception('Không thể cập nhật giỏ hàng')
        flash('Không thể cập nhật giỏ hàng.', 'error')
    return redirect(url_for('cart'))


@app.route('/thanh-toan', methods=['GET', 'POST'])
@customer_required
def checkout():
    items = get_cart_items(g.user['MaKH'])
    if not items:
        flash('Giỏ hàng đang trống.', 'info')
        return redirect(url_for('shop'))
    if request.method == 'POST':
        addr = clean_str(request.form.get('address'), 255)
        phone = clean_str(request.form.get('phone'), 15)
        method = request.form.get('payment')
        if len(addr) < 10 or not re.fullmatch(r'0[0-9]{9,10}', phone) or method not in ('COD', 'ChuyenKhoan'):
            flash('Kiểm tra lại địa chỉ, số điện thoại và phương thức thanh toán.', 'error')
        else:
            try:
                # Một transaction tạo MỘT đơn hàng nhiều biến thể; dùng lock tránh oversell.
                with transaction() as cur:
                    cur.execute('SELECT MaGH FROM GioHang WITH (UPDLOCK, HOLDLOCK) WHERE MaKH=?',
                                g.user['MaKH'])
                    row = cur.fetchone()
                    if not row:
                        raise ValueError('Giỏ hàng không tồn tại.')
                    gh_id = int(row[0])
                    cur.execute('''SELECT ct.MaBienThe, ct.SoLuong, bt.SoLuongTon, sp.GiaBan,
                                          sp.TrangThai, sp.TenSP, dm.TrangThai AS DMTrangThai
                                   FROM ChiTietGioHang ct
                                   JOIN BienTheSanPham bt WITH (UPDLOCK, HOLDLOCK) ON bt.MaBienThe=ct.MaBienThe
                                   JOIN SanPham sp ON sp.MaSP=bt.MaSP
                                   JOIN DanhMuc dm ON dm.MaDM=sp.MaDM
                                   WHERE ct.MaGH=? ORDER BY ct.MaBienThe''', gh_id)
                    locked = cur.fetchall()
                    if not locked:
                        raise ValueError('Giỏ hàng đang trống.')
                    total = Decimal('0')
                    for it in locked:
                        if it[1] <= 0 or it[2] < it[1] or it[4] != 'DangKinhDoanh' or it[6] != 'HoatDong':
                            raise ValueError(f'Sản phẩm "{it[5]}" đã hết hàng hoặc không đủ tồn kho.')
                        total += Decimal(it[1]) * Decimal(it[3])
                    cur.execute('''INSERT INTO DonHang(MaKH,DiaChiNhan,SDTNhanHang,TongTien,TrangThai)
                                   OUTPUT INSERTED.MaDH VALUES(?,?,?,?,N'ChoXacNhan')''',
                                g.user['MaKH'], addr, phone, total)
                    order_id = int(cur.fetchone()[0])
                    for it in locked:
                        cur.execute('''INSERT INTO ChiTietDonHang(MaDH,MaBienThe,SoLuong,DonGiaBan)
                                       VALUES(?,?,?,?)''', order_id, it[0], it[1], it[3])
                        cur.execute('''UPDATE BienTheSanPham SET SoLuongTon=SoLuongTon-?
                                       WHERE MaBienThe=? AND SoLuongTon>=?''', it[1], it[0], it[1])
                        if cur.rowcount != 1:
                            raise ValueError('Số lượng tồn kho vừa thay đổi. Hãy thử lại.')
                    cur.execute('''INSERT INTO ThanhToan(MaDH,PhuongThuc,SoTien,TrangThai)
                                   VALUES(?,?,?,N'ChuaThanhToan')''', order_id, method, total)
                    cur.execute('DELETE FROM ChiTietGioHang WHERE MaGH=?', gh_id)
                    cur.execute('UPDATE GioHang SET NgayCapNhat=GETDATE() WHERE MaGH=?', gh_id)
                flash(f'Đặt hàng thành công! Mã đơn hàng #{order_id}.', 'success')
                return redirect(url_for('order_detail', oid=order_id))
            except ValueError as exc:
                flash(str(exc), 'error')
            except Exception:
                app.logger.exception('Đặt hàng thất bại')
                flash('Không thể đặt hàng. Đơn hàng chưa được ghi, vui lòng thử lại.', 'error')
    return render_template('checkout.html', items=items, total=sum((x['ThanhTien'] for x in items), Decimal('0')))


@app.route('/don-hang')
@customer_required
def my_orders():
    rows = all_rows('''SELECT dh.*, tt.PhuongThuc, tt.TrangThai AS ThanhToanTrangThai
                       FROM DonHang dh OUTER APPLY
                       (SELECT TOP 1 PhuongThuc, TrangThai FROM ThanhToan
                        WHERE MaDH=dh.MaDH ORDER BY MaTT DESC) tt
                       WHERE dh.MaKH=? ORDER BY dh.NgayDat DESC, dh.MaDH DESC''', (g.user['MaKH'],))
    return render_template('my_orders.html', orders=rows)


@app.route('/don-hang/<int:oid>')
@customer_required
def order_detail(oid):
    order = one_row('''SELECT dh.*, tt.PhuongThuc, tt.TrangThai AS ThanhToanTrangThai
                      FROM DonHang dh OUTER APPLY
                      (SELECT TOP 1 PhuongThuc, TrangThai FROM ThanhToan WHERE MaDH=dh.MaDH ORDER BY MaTT DESC) tt
                      WHERE dh.MaDH=? AND dh.MaKH=?''', (oid, g.user['MaKH']))
    if not order:
        abort(404)
    lines = all_rows('SELECT * FROM v_ChiTietDonHang WHERE MaDH=?', (oid,))
    return render_template('order_detail.html', order=order, lines=lines)


@app.post('/san-pham/<int:pid>/danh-gia')
@customer_required
def rate(pid):
    stars = get_positive_int(request.form.get('stars'))
    text = clean_str(request.form.get('content'), 500)
    if stars not in (1, 2, 3, 4, 5):
        flash('Số sao phải từ 1 đến 5.', 'error')
    elif not scalar('''SELECT COUNT(*) FROM DonHang dh
                JOIN ChiTietDonHang ct ON ct.MaDH=dh.MaDH
                JOIN BienTheSanPham bt ON bt.MaBienThe=ct.MaBienThe
                WHERE dh.MaKH=? AND bt.MaSP=? AND dh.TrangThai=N'DaGiao' ''',
                (g.user['MaKH'], pid)):
        flash('Chỉ có thể đánh giá sản phẩm đã mua và được giao.', 'error')
    else:
        try:
            with transaction() as cur:
                cur.execute('SELECT MaDG FROM DanhGia WHERE MaKH=? AND MaSP=?', g.user['MaKH'], pid)
                if cur.fetchone():
                    cur.execute('''UPDATE DanhGia SET SoSao=?, NoiDung=?, NgayDanhGia=GETDATE(),TrangThai=N'HienThi'
                                   WHERE MaKH=? AND MaSP=?''', stars, text, g.user['MaKH'], pid)
                else:
                    cur.execute('''INSERT INTO DanhGia(MaKH,MaSP,SoSao,NoiDung)
                                   VALUES(?,?,?,?)''', g.user['MaKH'], pid, stars, text)
            flash('Cảm ơn bạn đã đánh giá!', 'success')
        except Exception:
            app.logger.exception('Lỗi đánh giá')
            flash('Không thể lưu đánh giá.', 'error')
    return redirect(url_for('product_detail', pid=pid))


# ------------------------- ADMIN / NHÂN VIÊN -------------------------
@app.route('/quan-tri')
@admin_required
def dashboard():
    stats = one_row('''SELECT
            (SELECT COUNT(*) FROM SanPham) AS total_products,
            (SELECT COUNT(*) FROM KhachHang) AS total_customers,
            (SELECT COUNT(*) FROM DonHang) AS total_orders,
            (SELECT ISNULL(SUM(TongTien),0) FROM DonHang WHERE TrangThai=N'DaGiao') AS revenue,
            (SELECT COUNT(*) FROM BienTheSanPham WHERE SoLuongTon <= 10) AS low_stock''')
    latest = all_rows('''SELECT TOP 7 dh.MaDH, dh.NgayDat, dh.TongTien, dh.TrangThai, kh.HoTen
                          FROM DonHang dh JOIN KhachHang kh ON kh.MaKH=dh.MaKH ORDER BY dh.MaDH DESC''')
    low = all_rows('''SELECT TOP 6 sp.TenSP, bt.MaSKU, bt.KichCo, bt.SoLuongTon
                       FROM BienTheSanPham bt JOIN SanPham sp ON sp.MaSP=bt.MaSP
                       ORDER BY bt.SoLuongTon ASC''')
    months = all_rows('''SELECT TOP 6 Nam, Thang, TongDoanhThu FROM v_BaoCaoDoanhThuTheoThang
                         ORDER BY Nam DESC, Thang DESC''')
    return render_template('admin_dashboard.html', stats=stats, latest=latest, low=low,
                           months=list(reversed(months)), page='dashboard')


@app.route('/quan-tri/san-pham')
@admin_required
def admin_products():
    q = clean_str(request.args.get('q'), 100)
    rows = all_rows('''SELECT sp.*, dm.TenDM, ISNULL(inv.TonKho,0) AS TonKho,
                             ISNULL(inv.SoBienThe,0) AS SoBienThe
                      FROM SanPham sp JOIN DanhMuc dm ON dm.MaDM=sp.MaDM
                      OUTER APPLY (SELECT SUM(bt.SoLuongTon) AS TonKho, COUNT(*) AS SoBienThe
                                   FROM BienTheSanPham bt WHERE bt.MaSP=sp.MaSP) inv
                      WHERE sp.TenSP LIKE ?
                      ORDER BY sp.MaSP DESC''', (f'%{q}%',))
    return render_template('admin_products.html', rows=rows, q=q, page='products')


def saved_image(existing=None):
    f = request.files.get('image')
    if f and f.filename:
        ext = Path(secure_filename(f.filename)).suffix.lower()
        if ext not in ('.jpg', '.jpeg', '.png', '.webp', '.gif'):
            raise ValueError('Chỉ nhận ảnh JPG, PNG, WEBP hoặc GIF.')
        fname = uuid.uuid4().hex + ext
        f.save(UPLOAD_DIR / fname)
        return fname
    return existing


@app.route('/quan-tri/san-pham/them', methods=['GET', 'POST'])
@admin_required
def admin_product_add():
    if request.method == 'POST':
        return save_product()
    return render_template('admin_product_form.html', p=None, cats=categories(False),
                           page='products', heading='Thêm sản phẩm')


@app.route('/quan-tri/san-pham/<int:pid>/sua', methods=['GET', 'POST'])
@admin_required
def admin_product_edit(pid):
    p = one_row('SELECT * FROM SanPham WHERE MaSP=?', (pid,))
    if not p:
        abort(404)
    if request.method == 'POST':
        return save_product(pid, p)
    return render_template('admin_product_form.html', p=p, cats=categories(False),
                           page='products', heading='Chỉnh sửa sản phẩm')


def save_product(pid=None, old=None):
    cat = get_positive_int(request.form.get('category'))
    name = clean_str(request.form.get('name'), 200)
    desc = clean_str(request.form.get('description'), 10000)
    status = request.form.get('status')
    try:
        price = Decimal(request.form.get('price', '-1'))
        if not price.is_finite() or price < 0 or price > Decimal('9999999999999999.99'):
            raise ValueError()
        price = price.quantize(Decimal('0.01'))
    except Exception:
        flash('Giá bán phải là số không âm hợp lệ.', 'error')
        return redirect(request.path)
    if not cat or not name or status not in PRODUCT_STATUSES:
        flash('Nhập đầy đủ tên, danh mục và trạng thái.', 'error')
        return redirect(request.path)
    if not one_row('SELECT MaDM FROM DanhMuc WHERE MaDM=?', (cat,)):
        flash('Danh mục không tồn tại.', 'error')
        return redirect(request.path)
    try:
        image_name = saved_image(old['HinhAnh'] if old else None)
        with transaction() as cur:
            if pid:
                cur.execute('''UPDATE SanPham SET MaDM=?, TenSP=?, MoTa=?, GiaBan=?, HinhAnh=?, TrangThai=?
                               WHERE MaSP=?''', cat, name, desc, price, image_name, status, pid)
            else:
                cur.execute('''INSERT INTO SanPham(MaDM,TenSP,MoTa,GiaBan,HinhAnh,TrangThai)
                               VALUES(?,?,?,?,?,?)''', cat, name, desc, price, image_name, status)
        flash('Đã lưu sản phẩm.', 'success')
        return redirect(url_for('admin_products'))
    except ValueError as exc:
        flash(str(exc), 'error')
    except Exception:
        app.logger.exception('Không thể lưu sản phẩm')
        flash('Không lưu được sản phẩm. Kiểm tra dữ liệu.', 'error')
    return redirect(request.path)


@app.post('/quan-tri/san-pham/<int:pid>/xoa')
@only_admin
def admin_product_delete(pid):
    try:
        with transaction() as cur:
            # Không xóa sản phẩm/biến thể đã có lịch sử đặt hàng.
            cur.execute('''SELECT COUNT(*) FROM ChiTietDonHang ct JOIN BienTheSanPham bt
                           ON ct.MaBienThe=bt.MaBienThe WHERE bt.MaSP=?''', pid)
            if cur.fetchone()[0]:
                raise ValueError('Sản phẩm đã có đơn hàng. Hãy chuyển sang "Ngừng kinh doanh" để giữ lịch sử.')
            cur.execute('DELETE FROM SanPham WHERE MaSP=?', pid)
            if cur.rowcount == 0:
                raise ValueError('Không tìm thấy sản phẩm.')
        flash('Đã xóa sản phẩm.', 'success')
    except ValueError as exc:
        flash(str(exc), 'error')
    except Exception:
        app.logger.exception('Không thể xóa sản phẩm')
        flash('Không thể xóa: sản phẩm đang được tham chiếu bởi dữ liệu khác.', 'error')
    return redirect(url_for('admin_products'))


@app.route('/quan-tri/danh-muc', methods=['GET', 'POST'])
@admin_required
def admin_categories():
    if request.method == 'POST':
        name = clean_str(request.form.get('name'), 100)
        desc = clean_str(request.form.get('description'), 500)
        if not name:
            flash('Vui lòng nhập tên danh mục.', 'error')
        else:
            try:
                with transaction() as cur:
                    cur.execute('INSERT INTO DanhMuc(TenDM,MoTa) VALUES(?,?)', name, desc)
                flash('Đã tạo danh mục.', 'success')
            except Exception:
                flash('Danh mục đã tồn tại hoặc không hợp lệ.', 'error')
        return redirect(url_for('admin_categories'))
    rows = all_rows('''SELECT dm.*, (SELECT COUNT(*) FROM SanPham sp WHERE sp.MaDM=dm.MaDM) AS SoSanPham
                      FROM DanhMuc dm ORDER BY dm.MaDM''')
    return render_template('admin_categories.html', rows=rows, page='categories')


@app.post('/quan-tri/danh-muc/<int:cid>/sua')
@admin_required
def admin_category_edit(cid):
    name = clean_str(request.form.get('name'), 100)
    desc = clean_str(request.form.get('description'), 500)
    status = request.form.get('status')
    if not name or status not in ('HoatDong', 'TamAn'):
        flash('Thông tin danh mục không hợp lệ.', 'error')
    else:
        try:
            with transaction() as cur:
                cur.execute('UPDATE DanhMuc SET TenDM=?,MoTa=?,TrangThai=? WHERE MaDM=?',
                            name, desc, status, cid)
            flash('Đã cập nhật danh mục.', 'success')
        except Exception:
            flash('Không thể cập nhật danh mục (có thể bị trùng tên).', 'error')
    return redirect(url_for('admin_categories'))


@app.post('/quan-tri/danh-muc/<int:cid>/xoa')
@only_admin
def admin_category_delete(cid):
    try:
        with transaction() as cur:
            cur.execute('DELETE FROM DanhMuc WHERE MaDM=?', cid)
        flash('Đã xóa danh mục.', 'success')
    except Exception:
        flash('Không thể xóa danh mục đang chứa sản phẩm.', 'error')
    return redirect(url_for('admin_categories'))


@app.route('/quan-tri/kho', methods=['GET', 'POST'])
@admin_required
def admin_inventory():
    if request.method == 'POST':
        pid = get_positive_int(request.form.get('product'))
        size = clean_str(request.form.get('size'), 10)
        color = clean_str(request.form.get('color'), 30)
        sku = clean_str(request.form.get('sku'), 50)
        stock = get_nonnegative_int(request.form.get('stock'))
        if not pid or not size or not color or not sku or stock is None:
            flash('Nhập đủ sản phẩm, size, màu, SKU và số tồn kho.', 'error')
        else:
            try:
                with transaction() as cur:
                    cur.execute('''INSERT INTO BienTheSanPham(MaSP,KichCo,MauSac,MaSKU,SoLuongTon)
                                   VALUES(?,?,?,?,?)''', pid, size, color, sku, stock)
                flash('Đã thêm biến thể sản phẩm.', 'success')
            except Exception:
                flash('Không tạo được biến thể. Có thể trùng SKU hoặc size/màu.', 'error')
        return redirect(url_for('admin_inventory'))
    q = clean_str(request.args.get('q'), 100)
    rows = all_rows('''SELECT bt.*, sp.TenSP, dm.TenDM FROM BienTheSanPham bt
                       JOIN SanPham sp ON sp.MaSP=bt.MaSP
                       JOIN DanhMuc dm ON dm.MaDM=sp.MaDM
                       WHERE sp.TenSP LIKE ? OR bt.MaSKU LIKE ?
                       ORDER BY bt.SoLuongTon ASC, bt.MaBienThe DESC''', (f'%{q}%', f'%{q}%'))
    ps = all_rows('SELECT MaSP,TenSP FROM SanPham ORDER BY TenSP')
    return render_template('admin_inventory.html', rows=rows, ps=ps, q=q, page='inventory')


@app.post('/quan-tri/kho/<int:vid>/cap-nhat')
@admin_required
def admin_inventory_edit(vid):
    stock = get_nonnegative_int(request.form.get('stock'))
    if stock is None:
        flash('Tồn kho phải là số nguyên không âm.', 'error')
    else:
        try:
            with transaction() as cur:
                cur.execute('UPDATE BienTheSanPham SET SoLuongTon=? WHERE MaBienThe=?', stock, vid)
            flash('Đã cập nhật số lượng tồn kho.', 'success')
        except Exception:
            flash('Không thể cập nhật kho.', 'error')
    return redirect(url_for('admin_inventory'))


@app.post('/quan-tri/kho/<int:vid>/xoa')
@only_admin
def admin_inventory_delete(vid):
    try:
        with transaction() as cur:
            cur.execute('DELETE FROM BienTheSanPham WHERE MaBienThe=?', vid)
        flash('Đã xóa biến thể.', 'success')
    except Exception:
        flash('Không thể xóa biến thể đã có trong đơn hàng hoặc giỏ hàng.', 'error')
    return redirect(url_for('admin_inventory'))


@app.route('/quan-tri/don-hang')
@admin_required
def admin_orders():
    status = request.args.get('status', '')
    if status not in ORDER_STATUSES:
        status = ''
    rows = all_rows('''SELECT dh.*, kh.HoTen, tt.PhuongThuc, tt.TrangThai AS TTTrangThai
                      FROM DonHang dh JOIN KhachHang kh ON kh.MaKH=dh.MaKH
                      OUTER APPLY (SELECT TOP 1 PhuongThuc, TrangThai FROM ThanhToan
                                   WHERE MaDH=dh.MaDH ORDER BY MaTT DESC) tt
                      WHERE (?='' OR dh.TrangThai=?) ORDER BY dh.MaDH DESC''', (status, status))
    return render_template('admin_orders.html', rows=rows, status=status, page='orders')


@app.route('/quan-tri/don-hang/<int:oid>')
@admin_required
def admin_order_detail(oid):
    order = one_row('''SELECT dh.*, kh.HoTen, kh.SDT, tk.Email,
                             tt.MaTT, tt.PhuongThuc, tt.TrangThai AS TTTrangThai
                      FROM DonHang dh JOIN KhachHang kh ON kh.MaKH=dh.MaKH
                      JOIN TaiKhoan tk ON tk.MaTK=kh.MaTK
                      OUTER APPLY (SELECT TOP 1 MaTT,PhuongThuc,TrangThai FROM ThanhToan
                                   WHERE MaDH=dh.MaDH ORDER BY MaTT DESC) tt
                      WHERE dh.MaDH=?''', (oid,))
    if not order:
        abort(404)
    lines = all_rows('SELECT * FROM v_ChiTietDonHang WHERE MaDH=?', (oid,))
    return render_template('admin_order_detail.html', order=order, lines=lines,
                           options=ALLOWED_TRANSITIONS.get(order['TrangThai'], []), page='orders')


@app.post('/quan-tri/don-hang/<int:oid>/trang-thai')
@admin_required
def admin_order_status(oid):
    new = request.form.get('status')
    try:
        with transaction() as cur:
            cur.execute('SELECT TrangThai FROM DonHang WITH (UPDLOCK, HOLDLOCK) WHERE MaDH=?', oid)
            row = cur.fetchone()
            if not row:
                abort(404)
            if new not in ALLOWED_TRANSITIONS.get(row[0], []):
                raise ValueError('Chuyển trạng thái không hợp lệ.')
            cur.execute('EXEC sp_CapNhatTrangThaiDonHang @MaDH=?, @TrangThaiMoi=?', oid, new)
        flash('Đã cập nhật trạng thái bằng stored procedure.', 'success')
    except ValueError as exc:
        flash(str(exc), 'error')
    except Exception:
        app.logger.exception('Không thể cập nhật đơn hàng')
        flash('Không cập nhật được trạng thái đơn hàng.', 'error')
    return redirect(url_for('admin_order_detail', oid=oid))


@app.post('/quan-tri/don-hang/<int:oid>/xac-nhan-thanh-toan')
@only_admin
def admin_payment_confirm(oid):
    # Dùng cho nghiệp vụ thu tiền thực tế/đã xác minh, KHÔNG tự gọi cổng thanh toán.
    try:
        with transaction() as cur:
            cur.execute('''UPDATE ThanhToan SET TrangThai=N'ThanhCong',NgayThanhToan=GETDATE()
                           WHERE MaDH=? AND TrangThai=N'ChuaThanhToan' ''', oid)
            count = cur.rowcount
            if not count:
                raise ValueError('Không có khoản thanh toán chờ xác nhận.')
        flash('Đã ghi nhận thanh toán do quản trị viên xác nhận.', 'success')
    except ValueError as exc:
        flash(str(exc), 'error')
    except Exception:
        app.logger.exception('Lỗi xác nhận thanh toán')
        flash('Không thể xác nhận thanh toán.', 'error')
    return redirect(url_for('admin_order_detail', oid=oid))


@app.route('/quan-tri/khach-hang')
@admin_required
def admin_customers():
    q = clean_str(request.args.get('q'), 100)
    rows = all_rows('''SELECT kh.MaKH,kh.HoTen,kh.SDT,tk.TenDangNhap,tk.Email,tk.TrangThai,
                      COUNT(dh.MaDH) AS SoDon,
                      ISNULL(SUM(CASE WHEN dh.TrangThai=N'DaGiao' THEN dh.TongTien ELSE 0 END),0) AS ChiTieu
                      FROM KhachHang kh JOIN TaiKhoan tk ON tk.MaTK=kh.MaTK
                      LEFT JOIN DonHang dh ON dh.MaKH=kh.MaKH
                      WHERE kh.HoTen LIKE ? OR kh.SDT LIKE ? OR tk.Email LIKE ?
                      GROUP BY kh.MaKH,kh.HoTen,kh.SDT,tk.TenDangNhap,tk.Email,tk.TrangThai
                      ORDER BY kh.MaKH DESC''', (f'%{q}%', f'%{q}%', f'%{q}%'))
    return render_template('admin_customers.html', rows=rows, q=q, page='customers')


@app.route('/quan-tri/bao-cao')
@admin_required
def admin_reports():
    start = request.args.get('from', '2026-01-01')
    end = request.args.get('to', date.today().isoformat())
    try:
        start_dt = date.fromisoformat(start)
        end_dt = date.fromisoformat(end)
        if end_dt < start_dt:
            raise ValueError()
    except ValueError:
        flash('Khoảng ngày không hợp lệ.', 'error')
        start_dt, end_dt = date(2026, 1, 1), date.today()
        start, end = start_dt.isoformat(), end_dt.isoformat()
    # Dùng khoảng [from, to+1) để không bỏ sót đơn cuối ngày.
    until = end_dt + timedelta(days=1)
    summary = one_row('''SELECT COUNT(*) AS SoDon,
        ISNULL(SUM(TongTien),0) AS DoanhThu,
        ISNULL(AVG(CAST(TongTien AS DECIMAL(18,2))),0) AS GiaTriTB
        FROM DonHang WHERE TrangThai=N'DaGiao' AND NgayDat>=? AND NgayDat<?''', (start_dt, until))
    by_cat = all_rows('''SELECT dm.TenDM, ISNULL(SUM(ct.SoLuong),0) AS SoLuong,
                        ISNULL(SUM(ct.SoLuong*ct.DonGiaBan),0) AS DoanhThu
                        FROM DanhMuc dm JOIN SanPham sp ON sp.MaDM=dm.MaDM
                        JOIN BienTheSanPham bt ON bt.MaSP=sp.MaSP
                        JOIN ChiTietDonHang ct ON ct.MaBienThe=bt.MaBienThe
                        JOIN DonHang dh ON dh.MaDH=ct.MaDH
                        WHERE dh.TrangThai=N'DaGiao' AND dh.NgayDat>=? AND dh.NgayDat<?
                        GROUP BY dm.TenDM ORDER BY DoanhThu DESC''', (start_dt, until))
    top = all_rows('''SELECT TOP 6 sp.TenSP, SUM(ct.SoLuong) AS SoLuong,
                      SUM(ct.SoLuong*ct.DonGiaBan) AS DoanhThu FROM ChiTietDonHang ct
                      JOIN BienTheSanPham bt ON bt.MaBienThe=ct.MaBienThe
                      JOIN SanPham sp ON sp.MaSP=bt.MaSP
                      JOIN DonHang dh ON dh.MaDH=ct.MaDH
                      WHERE dh.TrangThai=N'DaGiao' AND dh.NgayDat>=? AND dh.NgayDat<?
                      GROUP BY sp.MaSP, sp.TenSP ORDER BY SoLuong DESC, DoanhThu DESC''',
                   (start_dt, until))
    monthly = all_rows('SELECT * FROM v_BaoCaoDoanhThuTheoThang ORDER BY Nam DESC, Thang DESC')
    return render_template('admin_reports.html', start=start, end=end, summary=summary,
                           by_cat=by_cat, top=top, monthly=monthly, page='reports')


@app.route('/quan-tri/danh-gia')
@admin_required
def admin_reviews():
    rows = all_rows('''SELECT dg.*, kh.HoTen, sp.TenSP FROM DanhGia dg
                      JOIN KhachHang kh ON kh.MaKH=dg.MaKH
                      JOIN SanPham sp ON sp.MaSP=dg.MaSP ORDER BY dg.NgayDanhGia DESC''')
    return render_template('admin_reviews.html', rows=rows, page='reviews')


@app.post('/quan-tri/danh-gia/<int:rid>/trang-thai')
@admin_required
def admin_review_status(rid):
    status = request.form.get('status')
    if status not in ('An', 'HienThi'):
        abort(400)
    with transaction() as cur:
        cur.execute('UPDATE DanhGia SET TrangThai=? WHERE MaDG=?', status, rid)
    flash('Đã cập nhật trạng thái đánh giá.', 'success')
    return redirect(url_for('admin_reviews'))


@app.cli.command('create-admin')
@click.option('--username', default='admin_thoitrang', show_default=True)
def create_admin(username):
    """Đặt mật khẩu đã hash cho tài khoản quản trị (dữ liệu SQL mẫu chỉ là placeholder)."""
    password = click.prompt('Mật khẩu quản trị mới (ít nhất 8 ký tự)', hide_input=True,
                            confirmation_prompt=True)
    if len(password) < 8:
        raise click.ClickException('Mật khẩu cần có ít nhất 8 ký tự.')
    username = clean_str(username, 50)
    with transaction() as cur:
        cur.execute('SELECT MaTK, VaiTro FROM TaiKhoan WHERE TenDangNhap=?', username)
        row = cur.fetchone()
        hashed = generate_password_hash(password)
        if row:
            if row[1] != 'Admin':
                raise click.ClickException('Tên tài khoản đã tồn tại và không phải Admin.')
            cur.execute("UPDATE TaiKhoan SET MatKhau=?,TrangThai=N'HoatDong' WHERE MaTK=?", hashed, row[0])
        else:
            cur.execute('''INSERT INTO TaiKhoan(TenDangNhap,MatKhau,Email,VaiTro)
                           VALUES(?,?,?,N'Admin')''', username, hashed, f'{username}@example.local')
    click.echo(f'Đã thiết lập mật khẩu Admin cho: {username}')


@app.cli.command('set-password')
@click.option('--username', required=True, help='Tên tài khoản SQL đã tồn tại, ví dụ nhanvien_kho01')
def set_password(username):
    """Thiết lập mật khẩu cho một tài khoản mẫu không có mật khẩu thật."""
    username = clean_str(username, 50)
    password = click.prompt('Mật khẩu mới (ít nhất 8 ký tự)', hide_input=True,
                            confirmation_prompt=True)
    if len(password) < 8:
        raise click.ClickException('Mật khẩu cần ít nhất 8 ký tự.')
    with transaction() as cur:
        cur.execute('SELECT MaTK FROM TaiKhoan WHERE TenDangNhap=?', username)
        row = cur.fetchone()
        if not row:
            raise click.ClickException('Tài khoản không tồn tại trong bảng TaiKhoan.')
        cur.execute('UPDATE TaiKhoan SET MatKhau=? WHERE MaTK=?',
                    generate_password_hash(password), row[0])
    click.echo(f'Đã cập nhật mật khẩu cho {username}.')


@app.errorhandler(403)
def forbidden(error):
    return render_template('error.html', code=403, message='Bạn không có quyền truy cập trang này.'), 403


@app.errorhandler(404)
def notfound(error):
    return render_template('error.html', code=404, message='Không tìm thấy trang hoặc dữ liệu bạn cần.'), 404


@app.errorhandler(413)
def too_large(error):
    flash('Ảnh quá lớn, tối đa 3 MB.', 'error')
    return redirect(url_for('admin_products'))


if __name__ == '__main__':
    app.run(debug=os.getenv('FLASK_DEBUG', '0') == '1', host='127.0.0.1', port=5000)
