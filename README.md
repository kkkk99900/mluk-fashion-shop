# MLUK Fashion — Web quản lý shop thời trang (Flask + SQL Server)

Đây là mã nguồn website đầy đủ dùng **chính cơ sở dữ liệu `QL_ThoiTrang` trong file SQL của nhóm**. Dự án môn Cơ sở dữ liệu: không đổi tên các bảng/khóa/cột, có kết nối SQL Server thực tế. Website gồm **trang mua hàng** và **trang quản trị**.

## 1. Công nghệ

- **Frontend:** HTML, CSS, JavaScript, Jinja2 (giao diện responsive, không cần React/Node.js).
- **Backend:** Python 3.10+ và Flask.
- **Database:** Microsoft SQL Server + ODBC Driver 17 hoặc 18 + `pyodbc`.
- **Cơ sở dữ liệu:** 11 bảng, 4 view, 3 stored procedure, 2 function như file gốc.

## 2. Chạy trên Windows từ đầu

### Bước 1 — Chuẩn bị SQL Server

Yêu cầu cài Microsoft **SQL Server** (bản Express/Developer đều được), SSMS, và Microsoft **ODBC Driver 18 for SQL Server** (hoặc 17). Chú ý: **SSMS là công cụ quản trị, không phải máy chủ cơ sở dữ liệu.** SQL Server Database Engine phải được cài và chạy.

1. Mở **SQL Server Management Studio (SSMS)**, kết nối tới máy chủ của bạn (ví dụ `DESKTOP-PC\SQLEXPRESS` hoặc `localhost\SQLEXPRESS`).
2. Nếu **chưa có database `QL_ThoiTrang`**, mở và chạy tệp `sql/01_khoi_tao_khong_kiem_thu.sql` bằng **Execute**. Script này gồm tạo bảng, thêm dữ liệu mẫu, view, stored procedure và function, nhưng không thực hiện các bài test có ghi dữ liệu.
3. Nếu **đã chạy file SQL gốc của nhóm**, **bỏ qua bước chạy SQL** để tránh lỗi `CREATE DATABASE`/trùng bảng và giữ dữ liệu hiện tại.
4. Kiểm tra trong SSMS: `SELECT TOP 10 * FROM QL_ThoiTrang.dbo.SanPham;`.

**Lưu ý về script gốc:** Tệp `sql/QLSHOPTHOITRANG_goc.sql` được giữ nguyên để tham khảo. Đoạn kiểm thử ở cuối script gốc có tạo và hủy đơn hàng; vì thế không cần chạy nó mỗi lần mở web.

### Bước 2 — Cài Python và thư viện

Mở terminal (PowerShell hoặc VS Code Terminal) **tại thư mục `fashion_shop_web`**:

```powershell
python --version
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Nếu PowerShell không cho kích hoạt virtualenv, mở Command Prompt và chạy `.venv\Scripts\activate.bat`, hoặc bỏ qua venv và chạy `python -m pip install -r requirements.txt`.

### Bước 3 — Tạo `.env`

Sao chép `.env.example` thành **`.env`** rồi đổi `SQL_SERVER` thành đúng **Server name** trong hộp kết nối SSMS:

```dotenv
SQL_SERVER=DESKTOP-ABC\SQLEXPRESS
SQL_DATABASE=QL_ThoiTrang
SQL_AUTH=windows
SQL_DRIVER=
SECRET_KEY=thay-bang-chuoi-ngau-nhien-du-dai
FLASK_DEBUG=1
```

Tên server trên đây **chỉ là ví dụ**, không dùng nguyên nếu SSMS của bạn có tên khác. Với Windows Authentication, để `SQL_AUTH=windows`. Nếu dùng SQL Server Authentication, cấu hình:

```dotenv
SQL_AUTH=sql
SQL_USER=your_sql_login
SQL_PASSWORD=your_sql_password
```

Tạo `SECRET_KEY` bằng lệnh:

```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

**Không đưa file `.env` lên GitHub.** Ứng dụng dùng `TrustServerCertificate=yes` để dễ làm việc với SQL Server **trên máy cá nhân**; cần thiết lập chứng chỉ TLS đúng khi triển khai thật.

### Bước 4 — Kiểm tra database

```powershell
python check_db.py
```

Kỳ vọng: kết nối OK; có đủ 11 bảng, 4 view, 3 procedure và 2 function, cùng số lượng bản ghi trong một số bảng.

### Bước 5 — Thiết lập mật khẩu cho Admin

Dữ liệu mẫu SQL đặt mật khẩu `hash_pass_123`, **đây chỉ là chuỗi giả**, không phải mật khẩu thật. Website **không cho đăng nhập với chuỗi đó**. Hãy chạy đúng một lệnh:

```powershell
python -m flask --app app create-admin
```

Nhập mật khẩu mới ít nhất 8 ký tự (không hiển thị khi gõ). Lệnh sẽ hash mật khẩu và cập nhật tài khoản `admin_thoitrang` sẵn có thành tài khoản Admin có thể đăng nhập.

**Đăng nhập Admin:**
- Tên đăng nhập: `admin_thoitrang`
- Mật khẩu: mật khẩu bạn vừa đặt ở bước trên.

**Tài khoản nhân viên mẫu (tùy chọn):** có thể đặt mật khẩu cho tài khoản `nhanvien_kho01` bằng:

```powershell
python -m flask --app app set-password --username nhanvien_kho01
```

**Đăng nhập khách hàng:** vào `/dang-ky` để tạo tài khoản mới; ứng dụng tự thêm vào `TaiKhoan`, `KhachHang`, `GioHang` bằng một transaction. Tài khoản khách mẫu trong SQL cũng chỉ có mật khẩu giả, nên không dùng trực tiếp.

### Bước 6 — Chạy web

```powershell
python app.py
```

Mở trình duyệt tại **http://127.0.0.1:5000/**.

- **Cửa hàng:** http://127.0.0.1:5000/
- **Danh sách sản phẩm:** http://127.0.0.1:5000/cua-hang
- **Đăng ký:** http://127.0.0.1:5000/dang-ky
- **Đăng nhập:** http://127.0.0.1:5000/dang-nhap
- **Quản trị:** http://127.0.0.1:5000/quan-tri (chỉ truy cập sau khi đăng nhập Admin/Nhân viên).

Tùy chọn: sau khi tạo `.env`, có thể nhấp đúp `run_windows.bat` nếu đã cài thư viện đúng môi trường Python.

## 3. Chức năng website

### Khách hàng

1. Xem bộ sưu tập và tìm kiếm theo tên, danh mục, giá.
2. Xem chi tiết sản phẩm, biến thể **size/màu/SKU/tồn kho**.
3. Đăng ký / đăng nhập tài khoản (mật khẩu được hash).
4. Giỏ hàng **lưu thật vào `GioHang` và `ChiTietGioHang`**, tăng/giảm/xóa số lượng.
5. Đặt **một đơn hàng có nhiều dòng sản phẩm**. Transaction kiểm tra số lượng tồn, lưu `DonHang` + `ChiTietDonHang` + `ThanhToan`, trừ kho, xóa giỏ. Thất bại thì **ROLLBACK toàn bộ**.
6. Xem lịch sử và chi tiết đơn hàng. Đánh giá sản phẩm sau khi đơn đã được giao.

### Admin và nhân viên

1. Dashboard: tổng sản phẩm, khách, đơn hàng, doanh thu giao thành công; biểu đồ theo tháng, cảnh báo sắp hết hàng.
2. Quản lý **sản phẩm** (thêm/sửa/xóa có kiểm tra liên kết, tải ảnh nếu có).
3. Quản lý **danh mục** (thêm/sửa/ẩn/xóa nếu không còn sản phẩm).
4. Quản lý **kho** và biến thể (SKU, size, màu, số lượng).
5. Quản lý **đơn hàng** (xem, đổi trạng thái bằng `sp_CapNhatTrangThaiDonHang`; hủy đơn hoàn kho).
6. Xem khách hàng, tổng số đơn và tổng giá trị đơn đã giao.
7. Báo cáo doanh thu theo khoảng ngày/danh mục/sản phẩm và view doanh thu tháng.
8. Duyệt/ẩn đánh giá; Admin có thể ghi nhận **thanh toán đã xác thực thủ công**.

Nhân viên được quản lý các mục nghiệp vụ nhưng không có quyền xóa danh mục/sản phẩm/biến thể, không có quyền xác nhận thanh toán. Admin có đủ quyền.

## 4. Cấu trúc file

```text
fashion_shop_web/
├── app.py                    # Routes, nghiệp vụ, phân quyền, form, transaction
├── db.py                     # Kết nối SQL Server bằng pyodbc
├── check_db.py               # Kiểm tra DB, bảng, view, proc, function
├── requirements.txt
├── .env.example              # Sao chép thành .env (không đưa lên GitHub)
├── run_windows.bat
├── templates/                # HTML/Jinja2: trang khách + trang Admin
├── static/
│   ├── css/style.css         # Toàn bộ giao diện responsive
│   ├── js/main.js
│   ├── img/                  # Hình SVG mặc định cho hàng mẫu
│   └── uploads/              # Ảnh upload từ trang Admin
└── sql/
    ├── 01_khoi_tao_khong_kiem_thu.sql
    └── QLSHOPTHOITRANG_goc.sql
```

## 5. Những chỗ liên kết với bài Cơ sở dữ liệu

| Chức năng | SQL được sử dụng |
|---|---|
| Danh sách sản phẩm | `v_SanPhamHienThiWeb` JOIN `SanPham`, `DanhMuc` |
| Chi tiết biến thể | `dbo.fn_TimKiemBienTheTheoSanPham(@MaSP)` |
| Giỏ hàng | `GioHang` JOIN `ChiTietGioHang` JOIN `BienTheSanPham` |
| Đặt hàng nhiều món | Transaction Python/SQL với `UPDLOCK, HOLDLOCK`, các bảng `DonHang`, `ChiTietDonHang`, `ThanhToan`, `BienTheSanPham` |
| Hủy đơn / hoàn kho | `sp_CapNhatTrangThaiDonHang` |
| Chi tiết đơn | `v_ChiTietDonHang` |
| Thống kê theo tháng | `v_BaoCaoDoanhThuTheoThang` |
| Thống kê danh mục | `GROUP BY`, `SUM`, `JOIN` có lọc `DaGiao` |

**Vì sao không gọi `sp_TaoDonHang` trong giỏ hàng?** Thủ tục SQL gốc chỉ nhận **1 `@MaBienThe`** mỗi lần, nên không thể tạo **một đơn nhiều món** bằng lời gọi đó. Website dùng transaction tương đương cho nhiều biến thể, nhưng vẫn dùng procedure gốc khi cập nhật trạng thái và function/view gốc khi xem hàng. Nếu bài tập yêu cầu dùng chính `sp_TaoDonHang`, nhóm có thể trình bày demo với một biến thể trực tiếp trong SSMS.

## 6. Lưu ý khi báo cáo và demo

- Ảnh sản phẩm trong SQL mẫu là các tên file (`ao_thun_01.jpg`, ...), **không kèm ảnh thật**. Website hiển thị ảnh SVG mẫu thay thế. Admin có thể **sửa sản phẩm → tải ảnh lên** để hiện ảnh thật.
- Dữ liệu mẫu có 30 sản phẩm nhưng chỉ có **35 biến thể**; một vài sản phẩm ở cuối chưa có size/màu, nên trang sản phẩm hiển thị “chưa có biến thể”. Có thể bổ sung trực tiếp ở Admin → Kho & biến thể.
- **COD và chuyển khoản là mô phỏng ghi nhận đơn hàng**, không có cổng thanh toán thật. Mặc định `ThanhToan.TrangThai=ChuaThanhToan`; Admin mới có thể xác nhận sau khi thực sự thu tiền. Trạng thái `HoanTien` khi hủy đơn trong stored procedure **là ghi nhận dữ liệu, không tự chuyển tiền**.
- Web có CSRF token, SQL tham số hóa, session cookie và hash mật khẩu; dự án này hướng tới học phần, **chưa phải hệ thống triển khai Internet thực tế** (còn cần HTTPS, hạn chế thử mật khẩu, upload kiểm tra nội dung, audit, backup, v.v.).
- Không chạy `FLASK_DEBUG=1` ở môi trường production. Demo ở `127.0.0.1` (trên máy cá nhân) là phù hợp.
- Cần thiết lập **ODBC Driver + Database Engine** đúng máy; phần mã đã được kiểm tra cú pháp và cấu trúc template nhưng **chưa chạy end-to-end với máy SQL Server của nhóm**.

## 7. Tình huống demo nên thử

1. Truy cập trang chủ, tìm `Áo Thun`, đổi sắp xếp theo giá.
2. Đăng ký một khách hàng mới → kiểm tra trong SSMS `TaiKhoan`, `KhachHang`, `GioHang`.
3. Chọn size/màu có tồn → thêm vào giỏ → tăng/giảm số lượng.
4. Chốt đơn → kiểm tra `DonHang`, `ChiTietDonHang`, `ThanhToan`, tồn kho giảm.
5. Đăng nhập Admin → xử lý đơn `Chờ xác nhận → Đang xử lý → Đang giao → Đã giao` → báo cáo tăng doanh thu.
6. Tạo **đơn mới khác** để thử `Hủy` → xem số tồn được hoàn; không thử hủy đơn đã giao.
7. Từ Admin: thêm một sản phẩm, thêm SKU/size/màu, vào trang mua hàng kiểm tra sản phẩm mới.

