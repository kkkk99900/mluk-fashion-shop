"""Kiểm tra nhanh cấu hình ODBC và các đối tượng SQL bắt buộc."""
import sys
from db import connect

TABLES = ('TaiKhoan', 'KhachHang', 'DanhMuc', 'SanPham', 'BienTheSanPham',
          'GioHang', 'ChiTietGioHang', 'DonHang', 'ChiTietDonHang', 'ThanhToan', 'DanhGia')
VIEWS = ('v_SanPhamHienThiWeb', 'v_ChiTietDonHang', 'v_DanhMucDangHoatDong',
         'v_BaoCaoDoanhThuTheoThang')
PROCS = ('sp_TaoDonHang', 'sp_CapNhatTrangThaiDonHang', 'sp_BaoCaoDoanhThuTheoKhoangNgay')
FUNCTIONS = ('fn_TinhTongTienDonHang', 'fn_TimKiemBienTheTheoSanPham')


def main():
    try:
        conn = connect()
        try:
            cur = conn.cursor()
            cur.execute('SELECT DB_NAME(), @@SERVERNAME')
            db, server = cur.fetchone()
            print(f'✓ Kết nối OK → server: {server}; database: {db}')
            missing = []
            for category, objects in [('U', TABLES), ('V', VIEWS), ('P', PROCS)]:
                for obj in objects:
                    cur.execute('SELECT OBJECT_ID(?, ?)', 'dbo.' + obj, category)
                    if cur.fetchone()[0] is None:
                        missing.append(obj)
            for obj in FUNCTIONS:
                cur.execute('SELECT OBJECT_ID(?)', 'dbo.' + obj)
                if cur.fetchone()[0] is None:
                    missing.append(obj)
            if missing:
                print('✗ Thiếu đối tượng:', ', '.join(missing))
                print('  Hãy chạy SQL khởi tạo bằng SSMS trước.')
                return 1
            for table in ('DanhMuc', 'SanPham', 'BienTheSanPham', 'KhachHang', 'DonHang'):
                cur.execute('SELECT COUNT(*) FROM dbo.' + table)
                print(f'✓ {table}: {cur.fetchone()[0]} bản ghi')
            cur.execute('SELECT TOP 1 MaSP, TenSP FROM dbo.v_SanPhamHienThiWeb')
            print('✓ Tất cả 11 bảng, 4 view, 3 procedure và 2 function đều có mặt')
            return 0
        finally:
            conn.close()
    except Exception as exc:
        print('✗ Không thể kết nối SQL Server:', exc)
        print('  Kiểm tra SQL Server service, ODBC Driver, .env và quyền đăng nhập.')
        return 1


if __name__ == '__main__':
    sys.exit(main())
