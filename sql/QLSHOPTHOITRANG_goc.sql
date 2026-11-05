CREATE DATABASE QL_ThoiTrang;
GO

USE QL_ThoiTrang;
GO

-- ============================================================
-- PHẦN 1: TẠO 11 BẢNG (DDL)
-- ============================================================

-- 1. TaiKhoan
CREATE TABLE TaiKhoan (
    MaTK INT IDENTITY(1,1),
    TenDangNhap VARCHAR(50) NOT NULL,
    MatKhau VARCHAR(255) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    VaiTro NVARCHAR(20) NOT NULL CONSTRAINT DF_TaiKhoan_VaiTro DEFAULT N'KhachHang',
    TrangThai NVARCHAR(20) NOT NULL CONSTRAINT DF_TaiKhoan_TrangThai DEFAULT N'HoatDong',
    NgayTao DATETIME NOT NULL CONSTRAINT DF_TaiKhoan_NgayTao DEFAULT GETDATE(),

    CONSTRAINT PK_TaiKhoan PRIMARY KEY (MaTK),
    CONSTRAINT UQ_TaiKhoan_TenDangNhap UNIQUE (TenDangNhap),
    CONSTRAINT UQ_TaiKhoan_Email UNIQUE (Email),
    CONSTRAINT CK_TaiKhoan_VaiTro CHECK (VaiTro IN (N'Admin', N'NhanVien', N'KhachHang')),
    CONSTRAINT CK_TaiKhoan_TrangThai CHECK (TrangThai IN (N'HoatDong', N'BiKhoa', N'ChoKichHoat'))
);
GO

-- 2. KhachHang
CREATE TABLE KhachHang (
    MaKH INT IDENTITY(1,1),
    MaTK INT NOT NULL,
    HoTen NVARCHAR(100) NOT NULL,
    SDT VARCHAR(15) NULL,
    NgaySinh DATE NULL,

    CONSTRAINT PK_KhachHang PRIMARY KEY (MaKH),
    CONSTRAINT UQ_KhachHang_MaTK UNIQUE (MaTK),
    CONSTRAINT FK_KhachHang_TaiKhoan FOREIGN KEY (MaTK) REFERENCES TaiKhoan(MaTK)
        ON DELETE CASCADE ON UPDATE CASCADE
);
GO

-- 3. DanhMuc
CREATE TABLE DanhMuc (
    MaDM INT IDENTITY(1,1),
    TenDM NVARCHAR(100) NOT NULL,
    MoTa NVARCHAR(500) NULL,
    TrangThai NVARCHAR(20) NOT NULL CONSTRAINT DF_DanhMuc_TrangThai DEFAULT N'HoatDong',

    CONSTRAINT PK_DanhMuc PRIMARY KEY (MaDM),
    CONSTRAINT UQ_DanhMuc_TenDM UNIQUE (TenDM),
    CONSTRAINT CK_DanhMuc_TrangThai CHECK (TrangThai IN (N'HoatDong', N'TamAn'))
);
GO

-- 4. SanPham
CREATE TABLE SanPham (
    MaSP INT IDENTITY(1,1),
    MaDM INT NOT NULL,
    TenSP NVARCHAR(200) NOT NULL,
    MoTa NVARCHAR(MAX) NULL,
    GiaBan DECIMAL(18,2) NOT NULL,
    HinhAnh NVARCHAR(255) NULL,
    TrangThai NVARCHAR(20) NOT NULL CONSTRAINT DF_SanPham_TrangThai DEFAULT N'DangKinhDoanh',
    NgayTao DATETIME NOT NULL CONSTRAINT DF_SanPham_NgayTao DEFAULT GETDATE(),

    CONSTRAINT PK_SanPham PRIMARY KEY (MaSP),
    CONSTRAINT FK_SanPham_DanhMuc FOREIGN KEY (MaDM) REFERENCES DanhMuc(MaDM)
        ON UPDATE CASCADE,
    CONSTRAINT CK_SanPham_GiaBan CHECK (GiaBan >= 0),
    CONSTRAINT CK_SanPham_TrangThai CHECK (TrangThai IN (N'DangKinhDoanh', N'NgungKinhDoanh', N'HetHang'))
);
GO

-- 5. BienTheSanPham (ĐÃ ĐỔI TÊN CHUẨN CỘT KichCo)
CREATE TABLE BienTheSanPham (
    MaBienThe INT IDENTITY(1,1),
    MaSP INT NOT NULL,
    KichCo VARCHAR(10) NOT NULL,
    MauSac NVARCHAR(30) NOT NULL,
    SoLuongTon INT NOT NULL CONSTRAINT DF_BienThe_SoLuongTon DEFAULT 0,
    MaSKU VARCHAR(50) NOT NULL,

    CONSTRAINT PK_BienTheSanPham PRIMARY KEY (MaBienThe),
    CONSTRAINT FK_BienThe_SanPham FOREIGN KEY (MaSP) REFERENCES SanPham(MaSP)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT CK_BienThe_SoLuongTon CHECK (SoLuongTon >= 0),
    CONSTRAINT UQ_BienThe_MaSKU UNIQUE (MaSKU),
    CONSTRAINT UQ_BienThe_SP_KichCo_MauSac UNIQUE (MaSP, KichCo, MauSac)
);
GO

-- 6. GioHang
CREATE TABLE GioHang (
    MaGH INT IDENTITY(1,1),
    MaKH INT NOT NULL,
    NgayTao DATETIME NOT NULL CONSTRAINT DF_GioHang_NgayTao DEFAULT GETDATE(),
    NgayCapNhat DATETIME NOT NULL CONSTRAINT DF_GioHang_NgayCapNhat DEFAULT GETDATE(),

    CONSTRAINT PK_GioHang PRIMARY KEY (MaGH),
    CONSTRAINT UQ_GioHang_MaKH UNIQUE (MaKH),
    CONSTRAINT FK_GioHang_KhachHang FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH)
        ON DELETE CASCADE ON UPDATE CASCADE
);
GO

-- 7. ChiTietGioHang
CREATE TABLE ChiTietGioHang (
    MaGH INT NOT NULL,
    MaBienThe INT NOT NULL,
    SoLuong INT NOT NULL CONSTRAINT DF_ChiTietGH_SoLuong DEFAULT 1,

    CONSTRAINT PK_ChiTietGioHang PRIMARY KEY (MaGH, MaBienThe),
    CONSTRAINT FK_ChiTietGH_GioHang FOREIGN KEY (MaGH) REFERENCES GioHang(MaGH)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_ChiTietGH_BienThe FOREIGN KEY (MaBienThe) REFERENCES BienTheSanPham(MaBienThe)
        ON UPDATE CASCADE,
    CONSTRAINT CK_ChiTietGH_SoLuong CHECK (SoLuong > 0)
);
GO

-- 8. DonHang
CREATE TABLE DonHang (
    MaDH INT IDENTITY(1,1),
    MaKH INT NOT NULL,
    NgayDat DATETIME NOT NULL CONSTRAINT DF_DonHang_NgayDat DEFAULT GETDATE(),
    DiaChiNhan NVARCHAR(255) NOT NULL,
    SDTNhanHang VARCHAR(15) NOT NULL,
    TongTien DECIMAL(18,2) NOT NULL CONSTRAINT DF_DonHang_TongTien DEFAULT 0,
    TrangThai NVARCHAR(30) NOT NULL CONSTRAINT DF_DonHang_TrangThai DEFAULT N'ChoXacNhan',

    CONSTRAINT PK_DonHang PRIMARY KEY (MaDH),
    CONSTRAINT FK_DonHang_KhachHang FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH)
        ON UPDATE CASCADE,
    CONSTRAINT CK_DonHang_TongTien CHECK (TongTien >= 0),
    CONSTRAINT CK_DonHang_TrangThai CHECK (TrangThai IN (N'ChoXacNhan', N'DangXuLy', N'DangGiao', N'DaGiao', N'DaHuy'))
);
GO

-- 9. ChiTietDonHang
CREATE TABLE ChiTietDonHang (
    MaDH INT NOT NULL,
    MaBienThe INT NOT NULL,
    SoLuong INT NOT NULL,
    DonGiaBan DECIMAL(18,2) NOT NULL,

    CONSTRAINT PK_ChiTietDonHang PRIMARY KEY (MaDH, MaBienThe),
    CONSTRAINT FK_ChiTietDH_DonHang FOREIGN KEY (MaDH) REFERENCES DonHang(MaDH)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_ChiTietDH_BienThe FOREIGN KEY (MaBienThe) REFERENCES BienTheSanPham(MaBienThe)
        ON UPDATE CASCADE,
    CONSTRAINT CK_ChiTietDH_SoLuong CHECK (SoLuong > 0),
    CONSTRAINT CK_ChiTietDH_DonGiaBan CHECK (DonGiaBan >= 0)
);
GO

-- 10. ThanhToan
CREATE TABLE ThanhToan (
    MaTT INT IDENTITY(1,1),
    MaDH INT NOT NULL,
    PhuongThuc NVARCHAR(50) NOT NULL,
    SoTien DECIMAL(18,2) NOT NULL,
    NgayThanhToan DATETIME NULL,
    TrangThai NVARCHAR(30) NOT NULL CONSTRAINT DF_ThanhToan_TrangThai DEFAULT N'ChuaThanhToan',
    MaGiaoDich VARCHAR(100) NULL,

    CONSTRAINT PK_ThanhToan PRIMARY KEY (MaTT),
    CONSTRAINT FK_ThanhToan_DonHang FOREIGN KEY (MaDH) REFERENCES DonHang(MaDH)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT CK_ThanhToan_SoTien CHECK (SoTien >= 0),
    CONSTRAINT CK_ThanhToan_PhuongThuc CHECK (PhuongThuc IN (N'COD', N'VNPAY', N'MOMO', N'ChuyenKhoan')),
    CONSTRAINT CK_ThanhToan_TrangThai CHECK (TrangThai IN (N'ChuaThanhToan', N'ThanhCong', N'ThatBai', N'HoanTien'))
);
GO

-- 11. DanhGia
CREATE TABLE DanhGia (
    MaDG INT IDENTITY(1,1),
    MaKH INT NOT NULL,
    MaSP INT NOT NULL,
    SoSao INT NOT NULL,
    NoiDung NVARCHAR(500) NULL,
    NgayDanhGia DATETIME NOT NULL CONSTRAINT DF_DanhGia_NgayDanhGia DEFAULT GETDATE(),
    TrangThai NVARCHAR(20) NOT NULL CONSTRAINT DF_DanhGia_TrangThai DEFAULT N'HienThi',

    CONSTRAINT PK_DanhGia PRIMARY KEY (MaDG),
    CONSTRAINT FK_DanhGia_KhachHang FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH)
        ON UPDATE CASCADE,
    CONSTRAINT FK_DanhGia_SanPham FOREIGN KEY (MaSP) REFERENCES SanPham(MaSP)
        ON UPDATE CASCADE,
    CONSTRAINT CK_DanhGia_SoSao CHECK (SoSao BETWEEN 1 AND 5),
    CONSTRAINT CK_DanhGia_TrangThai CHECK (TrangThai IN (N'HienThi', N'An')),
    CONSTRAINT UQ_DanhGia_Khach_SP UNIQUE (MaKH, MaSP)
);
GO

-- ============================================================
-- PHẦN 2: CHÈN DỮ LIỆU MẪU (DML)
-- ============================================================

-- 1. TaiKhoan (35 dòng)
INSERT INTO TaiKhoan (TenDangNhap, MatKhau, Email, VaiTro, TrangThai) VALUES
('admin_thoitrang', 'hash_pass_123', 'admin@fashion.vn', N'Admin', N'HoatDong'),
('nhanvien_kho01', 'hash_pass_123', 'kho01@fashion.vn', N'NhanVien', N'HoatDong'),
('nhanvien_sale01', 'hash_pass_123', 'sale01@fashion.vn', N'NhanVien', N'HoatDong'),
('nguyenvan_a', 'hash_pass_123', 'nguyenvana@gmail.com', N'KhachHang', N'HoatDong'),
('tranthi_b', 'hash_pass_123', 'tranthib@gmail.com', N'KhachHang', N'HoatDong'),
('le_van_c', 'hash_pass_123', 'levanc@gmail.com', N'KhachHang', N'HoatDong'),
('pham_thi_d', 'hash_pass_123', 'phamthid@gmail.com', N'KhachHang', N'HoatDong'),
('hoang_anh_e', 'hash_pass_123', 'hoanganhe@gmail.com', N'KhachHang', N'HoatDong'),
('vu_tuan_f', 'hash_pass_123', 'vutuanf@gmail.com', N'KhachHang', N'HoatDong'),
('dang_minh_g', 'hash_pass_123', 'dangminhg@gmail.com', N'KhachHang', N'HoatDong'),
('bui_huong_h', 'hash_pass_123', 'buihuongh@gmail.com', N'KhachHang', N'HoatDong'),
('do_quang_i', 'hash_pass_123', 'doquangi@gmail.com', N'KhachHang', N'HoatDong'),
('ngo_thu_k', 'hash_pass_123', 'ngothuk@gmail.com', N'KhachHang', N'HoatDong'),
('duong_thanh_l', 'hash_pass_123', 'duongthanhl@gmail.com', N'KhachHang', N'HoatDong'),
('ly_kim_m', 'hash_pass_123', 'lykimm@gmail.com', N'KhachHang', N'HoatDong'),
('dinh_tien_n', 'hash_pass_123', 'dinhtienn@gmail.com', N'KhachHang', N'HoatDong'),
('mai_thuy_o', 'hash_pass_123', 'maithuyo@gmail.com', N'KhachHang', N'HoatDong'),
('dao_tuan_p', 'hash_pass_123', 'daotuanp@gmail.com', N'KhachHang', N'HoatDong'),
('ha_linh_q', 'hash_pass_123', 'halinhq@gmail.com', N'KhachHang', N'HoatDong'),
('luu_hai_r', 'hash_pass_123', 'luuhair@gmail.com', N'KhachHang', N'HoatDong'),
('chu_hoa_s', 'hash_pass_123', 'chuhoas@gmail.com', N'KhachHang', N'HoatDong'),
('phan_loc_t', 'hash_pass_123', 'phanloct@gmail.com', N'KhachHang', N'HoatDong'),
('vo_lan_u', 'hash_pass_123', 'volanu@gmail.com', N'KhachHang', N'HoatDong'),
('cao_son_v', 'hash_pass_123', 'caosonv@gmail.com', N'KhachHang', N'HoatDong'),
('truong_nga_w', 'hash_pass_123', 'truongngaw@gmail.com', N'KhachHang', N'HoatDong'),
('to_nam_x', 'hash_pass_123', 'tonamx@gmail.com', N'KhachHang', N'HoatDong'),
('thai_diep_y', 'hash_pass_123', 'thaidiepy@gmail.com', N'KhachHang', N'HoatDong'),
('quach_long_z', 'hash_pass_123', 'quachlongz@gmail.com', N'KhachHang', N'HoatDong'),
('lam_phuc_aa', 'hash_pass_123', 'lamphucaa@gmail.com', N'KhachHang', N'HoatDong'),
('khong_mai_bb', 'hash_pass_123', 'khongmaibb@gmail.com', N'KhachHang', N'HoatDong'),
('nhan_tam_cc', 'hash_pass_123', 'nhantamcc@gmail.com', N'KhachHang', N'HoatDong'),
('on_vinh_dd', 'hash_pass_123', 'onvinhdd@gmail.com', N'KhachHang', N'HoatDong'),
('tang_phong_ee', 'hash_pass_123', 'tangphongee@gmail.com', N'KhachHang', N'HoatDong'),
('mac_tuyen_ff', 'hash_pass_123', 'mactuyenff@gmail.com', N'KhachHang', N'BiKhoa'),
('van_khanh_gg', 'hash_pass_123', 'vankhanhgg@gmail.com', N'KhachHang', N'HoatDong');
GO

-- 2. KhachHang (32 dòng)
INSERT INTO KhachHang (MaTK, HoTen, SDT, NgaySinh) VALUES
(4, N'Nguyễn Văn A', '0912345601', '1995-02-15'),
(5, N'Trần Thị B', '0912345602', '1998-07-20'),
(6, N'Lê Văn C', '0912345603', '1992-11-05'),
(7, N'Phạm Thị D', '0912345604', '2000-01-25'),
(8, N'Hoàng Anh E', '0912345605', '1997-04-12'),
(9, N'Vũ Tuấn F', '0912345606', '1994-09-30'),
(10, N'Đặng Minh G', '0912345607', '1996-03-18'),
(11, N'Bùi Hương H', '0912345608', '1999-08-22'),
(12, N'Đỗ Quang I', '0912345609', '1991-12-14'),
(13, N'Ngô Thu K', '0912345610', '2001-05-19'),
(14, N'Dương Thành L', '0912345611', '1993-10-09'),
(15, N'Lý Kim M', '0912345612', '1998-06-27'),
(16, N'Đinh Tiến N', '0912345613', '1995-08-01'),
(17, N'Mai Thùy O', '0912345614', '2002-02-11'),
(18, N'Đào Tuấn P', '0912345615', '1990-04-04'),
(19, N'Hà Linh Q', '0912345616', '1997-12-30'),
(20, N'Lưu Hải R', '0912345617', '1994-07-07'),
(21, N'Chu Hoa S', '0912345618', '2000-09-15'),
(22, N'Phan Lộc T', '0912345619', '1993-01-28'),
(23, N'Võ Lan U', '0912345620', '1999-10-21'),
(24, N'Cao Sơn V', '0912345621', '1992-05-13'),
(25, N'Trương Nga W', '0912345622', '1996-08-08'),
(26, N'Tô Nam X', '0912345623', '1991-03-03'),
(27, N'Thái Diệp Y', '0912345624', '1998-11-17'),
(28, N'Quách Long Z', '0912345625', '1995-06-29'),
(29, N'Lâm Phúc AA', '0912345626', '2001-07-14'),
(30, N'Khổng Mai BB', '0912345627', '1994-12-02'),
(31, N'Nhan Tâm CC', '0912345628', '1997-05-05'),
(32, N'Ôn Vĩnh DD', '0912345629', '1993-09-24'),
(33, N'Tăng Phong EE', '0912345630', '2000-04-18'),
(34, N'Mạc Tuyền FF', '0912345631', '1996-10-10'),
(35, N'Văn Khánh GG', '0912345632', '1999-01-01');
GO

-- 3. DanhMuc (6 dòng)
INSERT INTO DanhMuc (TenDM, MoTa, TrangThai) VALUES
(N'Áo Nam', N'Áo sơ mi, áo thun, áo polo nam tính hiện đại', N'HoatDong'),
(N'Quần Nam', N'Quần jean, quần tây, quần kaki thanh lịch', N'HoatDong'),
(N'Váy Đầm Nữ', N'Váy dạ hội, váy xòe, váy công sở duyên dáng', N'HoatDong'),
(N'Áo Nữ', N'Áo kiểu, croptop, sơ mi lụa phong cách', N'HoatDong'),
(N'Áo Khoác', N'Áo khoác gió, blazer, áo dạ ấm áp', N'HoatDong'),
(N'Phụ Kiện Thời Trang', N'Thắt lưng, cà vạt, mũ nón thời thượng', N'HoatDong');
GO

-- 4. SanPham (30 dòng)
INSERT INTO SanPham (MaDM, TenSP, MoTa, GiaBan, HinhAnh, TrangThai) VALUES
(1, N'Áo Thun Nam Cotton Compact', N'Chất vải cotton 100% thoáng mát, co giãn 4 chiều', 199000, 'ao_thun_01.jpg', N'DangKinhDoanh'),
(1, N'Áo Polo Nam Pique Cao Cấp', N'Form Regular Fit, cổ bo dệt tinh tế', 299000, 'ao_polo_02.jpg', N'DangKinhDoanh'),
(1, N'Áo Sơ Mi Nam Oxford Dài Tay', N'Vải Oxford dệt dày dặn, chống nhăn tự nhiên', 389000, 'ao_somi_03.jpg', N'DangKinhDoanh'),
(1, N'Áo Sơ Mi Nam Cổ Tàu Cộc Tay', N'Phong cách trẻ trung lãng tử mùa hè', 320000, 'ao_somi_04.jpg', N'DangKinhDoanh'),
(1, N'Áo Tanktop Nam Thể Thao', N'Chất liệu thấm hút mồ hôi cực nhanh', 149000, 'ao_tank_05.jpg', N'DangKinhDoanh'),
(2, N'Quần Jean Nam Slimfit Co Giãn', N'Vải denim mềm mại, tôn dáng', 450000, 'quan_jean_01.jpg', N'DangKinhDoanh'),
(2, N'Quần Tây Nam Hàn Quốc Xếp Ly', N'Đứng form, phù hợp môi trường văn phòng', 420000, 'quan_tay_02.jpg', N'DangKinhDoanh'),
(2, N'Quần Khaki Nam Ống Đứng', N'Chất kaki chải kỹ, không xù lông', 390000, 'quan_kaki_03.jpg', N'DangKinhDoanh'),
(2, N'Quần Short Nam Vải Đũi Thoáng', N'Thoải mái dạo phố, đi biển cuối tuần', 210000, 'quan_short_04.jpg', N'DangKinhDoanh'),
(2, N'Quần Jogger Nam Túi Hộp', N'Phong cách đường phố Streetwear năng động', 350000, 'quan_jog_05.jpg', N'DangKinhDoanh'),
(3, N'Váy Hoa Nhí Vintage Dáng Xòe', N'Họa tiết hoa nhí nữ tính, chiết eo nhẹ', 480000, 'vay_hoa_01.jpg', N'DangKinhDoanh'),
(3, N'Đầm Dự Tiệc Body Lệch Vai', N'Chất thun tuyết nhung ôm sát quyến rũ', 650000, 'dam_body_02.jpg', N'DangKinhDoanh'),
(3, N'Chân Váy Chữ A Công Sở', N'Có quần bảo hộ bên trong tiện lợi', 280000, 'chan_vay_03.jpg', N'DangKinhDoanh'),
(3, N'Váy Suông Linen Thêu Họa Tiết', N'Vải đũi linen tự nhiên, mộc mạc thanh lịch', 520000, 'vay_linen_04.jpg', N'DangKinhDoanh'),
(3, N'Chân Váy Xếp Ly Tennis', N'Năng động, dễ phối cùng áo thun, croptop', 240000, 'vay_tennis_05.jpg', N'DangKinhDoanh'),
(4, N'Áo Sơ Mi Nữ Lụa Satin', N'Bề mặt lụa óng ả mềm mượt sang trọng', 360000, 'ao_lua_01.jpg', N'DangKinhDoanh'),
(4, N'Áo Croptop Nữ Cổ Vuông', N'Khoe khéo xương quai xanh và vòng eo thon', 180000, 'croptop_02.jpg', N'DangKinhDoanh'),
(4, N'Áo Thun Nữ In Hình Pastel', N'Màu sắc tươi trẻ, phong cách Hàn Quốc', 160000, 'ao_thun_nu_03.jpg', N'DangKinhDoanh'),
(4, N'Áo Kiểu Nữ Tay Phồng Voan', N'Tay bồng cánh tiên dịu dàng, tiểu thư', 320000, 'ao_kieu_04.jpg', N'DangKinhDoanh'),
(4, N'Áo Len Dệt Kim Mỏng Tay Dài', N'Mặc đẹp trong tiết trời se lạnh đầu thu', 290000, 'ao_len_nu_05.jpg', N'DangKinhDoanh'),
(5, N'Áo Blazer Nam 2 Lớp Form Rộng', N'Phong cách thời thượng, chuẩn quý ông', 850000, 'blazer_nam_01.jpg', N'DangKinhDoanh'),
(5, N'Áo Blazer Nữ Chiết Eo Sang Trọng', N'Đệm vai đứng form, nâng tầm trang phục', 790000, 'blazer_nu_02.jpg', N'DangKinhDoanh'),
(5, N'Áo Khoác Gió Bomber 2 Mặt', N'Chống nước nhẹ, cản gió tuyệt đối', 490000, 'bomber_03.jpg', N'DangKinhDoanh'),
(5, N'Áo Khoác Jean Denim Unisex', N'Hiệu ứng wash cào rách thời trang cá tính', 550000, 'khoac_jean_04.jpg', N'DangKinhDoanh'),
(5, N'Áo Phao Lông Vũ Siêu Nhẹ', N'Giữ nhiệt cực tốt, gấp gọn bỏ túi tiện lợi', 950000, 'phao_longvu_05.jpg', N'DangKinhDoanh'),
(6, N'Thắt Lưng Nam Da Bò Khóa Tự Động', N'Mặt khóa kim loại không rỉ sét sáng bóng', 280000, 'that_lung_01.jpg', N'DangKinhDoanh'),
(6, N'Cà Vạt Lụa Bản Nhỏ Trơn', N'Phù hợp áo sơ mi đi sự kiện, phỏng vấn', 120000, 'ca_vat_02.jpg', N'DangKinhDoanh'),
(6, N'Mũ Lưỡi Trai Unisex Thêu Chữ', N'Chất kaki wash bền màu, form cứng cáp', 150000, 'mu_03.jpg', N'DangKinhDoanh'),
(6, N'Khăn Lụa Vuông Quàng Cổ Nữ', N'Họa tiết baroque cổ điển quý phái', 190000, 'khan_lua_04.jpg', N'DangKinhDoanh'),
(6, N'Tất Cổ Cao Cotton Khử Mùi', N'Combo 5 đôi êm chân, thoáng khí', 110000, 'tat_05.jpg', N'DangKinhDoanh');
GO

-- 5. BienTheSanPham (35 dòng - CỘT KichCo)
INSERT INTO BienTheSanPham (MaSP, KichCo, MauSac, SoLuongTon, MaSKU) VALUES
(1, 'M', N'Trắng', 50, 'TSHIRT-WHT-M'),
(1, 'L', N'Trắng', 45, 'TSHIRT-WHT-L'),
(1, 'L', N'Đen', 60, 'TSHIRT-BLK-L'),
(2, 'M', N'Xanh Navy', 35, 'POLO-NAV-M'),
(2, 'L', N'Xanh Navy', 40, 'POLO-NAV-L'),
(2, 'XL', N'Đen', 25, 'POLO-BLK-XL'),
(3, '39', N'Trắng', 30, 'OXFORD-WHT-39'),
(3, '40', N'Xanh Nhạt', 28, 'OXFORD-BLU-40'),
(4, 'M', N'Be', 20, 'COTAY-BEI-M'),
(5, 'L', N'Xám', 50, 'TANK-GRY-L'),
(6, '30', N'Xanh Đậm', 40, 'JEAN-BLUD-30'),
(6, '31', N'Xanh Đậm', 38, 'JEAN-BLUD-31'),
(6, '32', N'Đen', 25, 'JEAN-BLK-32'),
(7, '30', N'Đen', 35, 'TAY-BLK-30'),
(7, '31', N'Xám Tro', 22, 'TAY-GRY-31'),
(8, '31', N'Vàng Khaki', 30, 'KAKI-YEL-31'),
(9, 'L', N'Nâu Nhạt', 45, 'SHORT-BRN-L'),
(10, 'XL', N'Rêu', 18, 'JOG-GRN-XL'),
(11, 'S', N'Hoa Vàng', 20, 'VAYHOA-YEL-S'),
(11, 'M', N'Hoa Vàng', 25, 'VAYHOA-YEL-M'),
(12, 'S', N'Đỏ Mận', 15, 'BODY-RED-S'),
(12, 'M', N'Đen', 12, 'BODY-BLK-M'),
(13, 'S', N'Đen', 30, 'CVCHU-A-S'),
(14, 'M', N'Trắng Kem', 18, 'LINEN-CRM-M'),
(15, 'M', N'Trắng', 40, 'TENNIS-WHT-M'),
(16, 'S', N'Hồng Nude', 22, 'SATIN-PNK-S'),
(17, 'Freesize', N'Trắng', 50, 'CROP-WHT-FS'),
(18, 'M', N'Xanh Bơ', 35, 'THUNNU-GRN-M'),
(19, 'S', N'Trắng', 20, 'VOAN-WHT-S'),
(20, 'M', N'Be', 25, 'LEN-BEI-M'),
(21, 'L', N'Xám Kẻ', 15, 'BLAZERNAM-L'),
(22, 'M', N'Đen', 20, 'BLAZERNU-M'),
(23, 'L', N'Xanh Rêu', 30, 'BOMBER-L'),
(24, 'L', N'Xanh Nhạt', 25, 'JEANJK-L'),
(25, 'XL', N'Đen', 10, 'LONGVU-XL');
GO

-- 6. GioHang (32 dòng)
INSERT INTO GioHang (MaKH)
SELECT MaKH FROM KhachHang;
GO

-- 7. ChiTietGioHang (5 dòng)
INSERT INTO ChiTietGioHang (MaGH, MaBienThe, SoLuong) VALUES
(1, 1, 2),
(1, 4, 1),
(2, 19, 1),
(3, 11, 1),
(4, 21, 1);
GO

-- 8. DonHang (30 dòng)
INSERT INTO DonHang (MaKH, NgayDat, DiaChiNhan, SDTNhanHang, TongTien, TrangThai) VALUES
(1, '2026-01-05 09:30:00', N'123 Nguyễn Trãi, Q.1, TP.HCM', '0912345601', 398000, N'DaGiao'),
(2, '2026-01-08 14:15:00', N'45 Hai Bà Trưng, Hoàn Kiếm, Hà Nội', '0912345602', 480000, N'DaGiao'),
(3, '2026-01-10 11:00:00', N'78 Lê Lợi, Hải Châu, Đà Nẵng', '0912345603', 450000, N'DaGiao'),
(4, '2026-01-12 16:45:00', N'89 Cầu Giấy, Hà Nội', '0912345604', 650000, N'DaGiao'),
(5, '2026-01-15 10:20:00', N'12 Trần Hưng Đạo, Q.5, TP.HCM', '0912345605', 850000, N'DaGiao'),
(6, '2026-01-18 19:10:00', N'34 Quang Trung, Gò Vấp, TP.HCM', '0912345606', 299000, N'DaGiao'),
(7, '2026-01-20 08:50:00', N'56 Bạch Đằng, Bình Thạnh, TP.HCM', '0912345607', 420000, N'DaGiao'),
(8, '2026-01-22 13:40:00', N'67 Trần Phú, Nha Trang', '0912345608', 360000, N'DaGiao'),
(9, '2026-01-25 17:00:00', N'23 Hùng Vương, Huế', '0912345609', 790000, N'DaGiao'),
(10, '2026-01-28 15:30:00', N'90 Lý Tự Trọng, Cần Thơ', '0912345610', 550000, N'DaGiao'),
(11, '2026-02-01 10:00:00', N'11 Nguyễn Huệ, Q.1, TP.HCM', '0912345611', 450000, N'DaGiao'),
(12, '2026-02-03 12:25:00', N'44 Phố Huế, Hai Bà Trưng, Hà Nội', '0912345612', 389000, N'DaGiao'),
(13, '2026-02-05 14:10:00', N'88 Hoàng Diệu, Đà Nẵng', '0912345613', 480000, N'DaGiao'),
(14, '2026-02-08 09:15:00', N'35 Điện Biên Phủ, Bình Thạnh, TP.HCM', '0912345614', 950000, N'DaGiao'),
(15, '2026-02-10 16:35:00', N'99 Võ Văn Tần, Q.3, TP.HCM', '0912345615', 390000, N'DaGiao'),
(16, '2026-02-12 11:50:00', N'50 Đinh Tiên Hoàng, Q.1, TP.HCM', '0912345616', 320000, N'DaGiao'),
(17, '2026-02-15 18:00:00', N'15 Kim Mã, Ba Đình, Hà Nội', '0912345617', 280000, N'DaGiao'),
(18, '2026-02-18 10:30:00', N'76 Lạc Long Quân, Tây Hồ, Hà Nội', '0912345618', 520000, N'DaGiao'),
(19, '2026-02-20 15:00:00', N'63 CMT8, Q.10, TP.HCM', '0912345619', 240000, N'DaGiao'),
(20, '2026-02-22 17:45:00', N'18 Nam Kỳ Khởi Nghĩa, Q.3, TP.HCM', '0912345620', 490000, N'DaGiao'),
(21, '2026-02-25 09:40:00', N'31 Lê Duẩn, Đà Nẵng', '0912345621', 199000, N'DaGiao'),
(22, '2026-02-27 14:05:00', N'82 Xã Đàn, Đống Đa, Hà Nội', '0912345622', 180000, N'DaGiao'),
(23, '2026-03-01 11:20:00', N'105 Tây Sơn, Đống Đa, Hà Nội', '0912345623', 290000, N'DangGiao'),
(24, '2026-03-02 16:15:00', N'47 Phạm Ngũ Lão, Q.1, TP.HCM', '0912345624', 450000, N'DangGiao'),
(25, '2026-03-03 10:10:00', N'62 Chu Văn An, Bình Thạnh, TP.HCM', '0912345625', 850000, N'DangXuLy'),
(26, '2026-03-04 13:50:00', N'79 Trường Chinh, Thanh Xuân, Hà Nội', '0912345626', 420000, N'ChoXacNhan'),
(27, '2026-03-05 08:30:00', N'22 Lê Thánh Tôn, Bến Nghé, TP.HCM', '0912345627', 389000, N'ChoXacNhan'),
(28, '2026-03-05 09:15:00', N'95 Tôn Đức Thắng, Q.1, TP.HCM', '0912345628', 199000, N'DaHuy'),
(29, '2026-03-05 10:45:00', N'103 Nguyễn Thị Minh Khai, Q.3, TP.HCM', '0912345629', 299000, N'ChoXacNhan'),
(30, '2026-03-05 14:00:00', N'55 Hoàng Hoa Thám, Ba Đình, Hà Nội', '0912345630', 650000, N'ChoXacNhan');
GO

-- 9. ChiTietDonHang (30 dòng)
INSERT INTO ChiTietDonHang (MaDH, MaBienThe, SoLuong, DonGiaBan) VALUES
(1, 1, 2, 199000),
(2, 19, 1, 480000),
(3, 11, 1, 450000),
(4, 21, 1, 650000),
(5, 31, 1, 850000),
(6, 4, 1, 299000),
(7, 14, 1, 420000),
(8, 26, 1, 360000),
(9, 32, 1, 790000),
(10, 34, 1, 550000),
(11, 12, 1, 450000),
(12, 7, 1, 389000),
(13, 20, 1, 480000),
(14, 35, 1, 950000),
(15, 16, 1, 390000),
(16, 9, 1, 320000),
(17, 23, 1, 280000),
(18, 24, 1, 520000),
(19, 25, 1, 240000),
(20, 33, 1, 490000),
(21, 2, 1, 199000),
(22, 27, 1, 180000),
(23, 30, 1, 290000),
(24, 13, 1, 450000),
(25, 31, 1, 850000),
(26, 15, 1, 420000),
(27, 8, 1, 389000),
(28, 3, 1, 199000),
(29, 5, 1, 299000),
(30, 22, 1, 650000);
GO

-- 10. ThanhToan (8 dòng)
INSERT INTO ThanhToan (MaDH, PhuongThuc, SoTien, NgayThanhToan, TrangThai, MaGiaoDich) VALUES
(1, N'COD', 398000, '2026-01-07 10:00:00', N'ThanhCong', 'COD-20260105-01'),
(2, N'VNPAY', 480000, '2026-01-08 14:16:00', N'ThanhCong', 'VNP2026010884920'),
(3, N'MOMO', 450000, '2026-01-10 11:05:00', N'ThanhCong', 'MOMO202601103321'),
(4, N'ChuyenKhoan', 650000, '2026-01-12 17:00:00', N'ThanhCong', 'VCB992817283'),
(5, N'VNPAY', 850000, '2026-01-15 10:25:00', N'ThanhCong', 'VNP202601150291'),
(23, N'COD', 290000, NULL, N'ChuaThanhToan', NULL),
(24, N'MOMO', 450000, '2026-03-02 16:16:00', N'ThanhCong', 'MOMO202603029981'),
(28, N'COD', 199000, NULL, N'ThatBai', NULL);
GO

-- 11. DanhGia (9 dòng)
INSERT INTO DanhGia (MaKH, MaSP, SoSao, NoiDung, NgayDanhGia, TrangThai) VALUES
(1, 1, 5, N'Chất thun dày dặn, mặc mát mẻ, giao hàng nhanh chóng!', '2026-01-08', N'HienThi'),
(2, 11, 5, N'Váy xinh xắn, chuẩn phong cách Hàn Quốc hoa nhí.', '2026-01-10', N'HienThi'),
(3, 6, 4, N'Quần jean co giãn tốt, form ống rất đẹp.', '2026-01-12', N'HienThi'),
(4, 12, 5, N'Đầm ôm dáng đẹp lắm, mặc đi tiệc sang trọng.', '2026-01-14', N'HienThi'),
(5, 21, 5, N'Áo blazer 2 lớp vải xịn, đường may tỉ mỉ.', '2026-01-17', N'HienThi'),
(6, 2, 4, N'Polo mặc vừa vặn, cổ áo cứng cáp.', '2026-01-20', N'HienThi'),
(7, 7, 5, N'Quần tây mặc đi làm rất lịch sự.', '2026-01-23', N'HienThi'),
(8, 16, 4, N'Lụa mềm mát, màu hồng nhã nhặn.', '2026-01-25', N'HienThi'),
(9, 22, 5, N'Blazer nữ hack dáng siêu đỉnh.', '2026-01-30', N'HienThi');
GO

-- ============================================================
-- PHẦN 3: CÁC TRUY VẤN
-- ============================================================

USE QL_ThoiTrang;
GO

-- ------------------------------------------------------------
-- TRUY VẤN 1: Tìm kiếm sản phẩm theo từ khóa (LIKE, WHERE)
-- Nghiệp vụ: Khách hàng tìm các sản phẩm áo sơ mi hoặc áo thun đang kinh doanh
-- ------------------------------------------------------------
SELECT MaSP, TenSP, GiaBan, HinhAnh, TrangThai
FROM SanPham
WHERE TrangThai = N'DangKinhDoanh' 
  AND (TenSP LIKE N'%Áo Sơ Mi%' OR TenSP LIKE N'%Áo Thun%')
ORDER BY GiaBan ASC;

-- ------------------------------------------------------------
-- TRUY VẤN 2: Lấy thông tin biến thể kèm sản phẩm & danh mục (INNER JOIN nhiều bảng)
-- Nghiệp vụ: Quản trị kho kiểm tra size, màu, mã SKU và tồn kho của từng sản phẩm
-- ------------------------------------------------------------
SELECT 
    dm.TenDM,
    sp.TenSP,
    bt.MaSKU,
    bt.KichCo,
    bt.MauSac,
    sp.GiaBan,
    bt.SoLuongTon
FROM BienTheSanPham bt
INNER JOIN SanPham sp ON bt.MaSP = sp.MaSP
INNER JOIN DanhMuc dm ON sp.MaDM = dm.MaDM
ORDER BY dm.TenDM, sp.TenSP;

-- ------------------------------------------------------------
-- TRUY VẤN 3: Thống kê số lượng đơn và tổng chi tiêu của tất cả khách hàng (LEFT JOIN)
-- Nghiệp vụ: Tìm cả những khách hàng chưa từng phát sinh đơn hàng nào (COUNT = 0)
-- ------------------------------------------------------------
SELECT 
    kh.MaKH,
    kh.HoTen,
    kh.SDT,
    COUNT(dh.MaDH) AS TongSoDonHang,
    ISNULL(SUM(dh.TongTien), 0) AS TongTienDaMua
FROM KhachHang kh
LEFT JOIN DonHang dh ON kh.MaKH = dh.MaKH AND dh.TrangThai = N'DaGiao'
GROUP BY kh.MaKH, kh.HoTen, kh.SDT
ORDER BY TongTienDaMua DESC;

-- ------------------------------------------------------------
-- TRUY VẤN 4: Đối chiếu toàn diện giữa Danh mục và Sản phẩm (FULL OUTER JOIN)
-- Nghiệp vụ: Kiểm tra xem có danh mục nào chưa có sản phẩm, hoặc sản phẩm chưa gán danh mục
-- ------------------------------------------------------------
SELECT 
    dm.MaDM,
    dm.TenDM,
    sp.MaSP,
    sp.TenSP,
    sp.GiaBan
FROM DanhMuc dm
FULL OUTER JOIN SanPham sp ON dm.MaDM = sp.MaDM
ORDER BY dm.MaDM, sp.MaSP;

-- ------------------------------------------------------------
-- TRUY VẤN 5: Thống kê doanh thu theo danh mục lọc điều kiện (GROUP BY + HAVING)
-- Nghiệp vụ: Lấy những danh mục có tổng doanh thu bán ra đạt trên 1.000.000 VNĐ
-- ------------------------------------------------------------
SELECT 
    dm.MaDM,
    dm.TenDM,
    COUNT(DISTINCT ctdh.MaDH) AS SoLuongDonChuaSanPham,
    SUM(ctdh.SoLuong) AS TongSoLuongBan,
    SUM(ctdh.SoLuong * ctdh.DonGiaBan) AS DoanhThu
FROM DanhMuc dm
INNER JOIN SanPham sp ON dm.MaDM = sp.MaDM
INNER JOIN BienTheSanPham bt ON sp.MaSP = bt.MaSP
INNER JOIN ChiTietDonHang ctdh ON bt.MaBienThe = ctdh.MaBienThe
INNER JOIN DonHang dh ON ctdh.MaDH = dh.MaDH
WHERE dh.TrangThai = N'DaGiao'
GROUP BY dm.MaDM, dm.TenDM
HAVING SUM(ctdh.SoLuong * ctdh.DonGiaBan) >= 1000000
ORDER BY DoanhThu DESC;

-- ------------------------------------------------------------
-- TRUY VẤN 6: Tìm sản phẩm có giá bán cao hơn giá bán trung bình (Scalar Subquery)
-- Nghiệp vụ: Bộ phận Marketing phân loại sản phẩm thuộc phân khúc giá cao
-- ------------------------------------------------------------
SELECT 
    sp.MaSP,
    sp.TenSP,
    sp.GiaBan,
    (SELECT AVG(GiaBan) FROM SanPham) AS GiaTrungBinhToanCuaHang,
    sp.GiaBan - (SELECT AVG(GiaBan) FROM SanPham) AS ChenhLechSoVoiTB
FROM SanPham sp
WHERE sp.GiaBan > (SELECT AVG(GiaBan) FROM SanPham)
ORDER BY sp.GiaBan DESC;

-- ------------------------------------------------------------
-- TRUY VẤN 7: Tìm khách hàng từng mua sản phẩm thuộc danh mục 'Áo Khoác' (EXISTS - Table Subquery)
-- Nghiệp vụ: Chạy chiến dịch gửi voucher giảm giá đồ mùa đông cho khách hàng mục tiêu
-- ------------------------------------------------------------
SELECT kh.MaKH, kh.HoTen, kh.SDT
FROM KhachHang kh
WHERE EXISTS (
    SELECT 1 
    FROM DonHang dh
    INNER JOIN ChiTietDonHang ctdh ON dh.MaDH = ctdh.MaDH
    INNER JOIN BienTheSanPham bt ON ctdh.MaBienThe = bt.MaBienThe
    INNER JOIN SanPham sp ON bt.MaSP = sp.MaSP
    INNER JOIN DanhMuc dm ON sp.MaDM = dm.MaDM
    WHERE dh.MaKH = kh.MaKH 
      AND dm.TenDM = N'Áo Khoác'
      AND dh.TrangThai <> N'DaHuy'
);

-- ------------------------------------------------------------
-- TRUY VẤN 8: Toán tử tập hợp (EXCEPT & INTERSECT)
-- Nghiệp vụ A: Tìm các biến thể sản phẩm chưa từng bán được cái nào (EXCEPT)
-- Nghiệp vụ B: Tìm khách hàng vừa có đơn giao thành công, vừa viết đánh giá (INTERSECT)
-- ------------------------------------------------------------
-- A. Biến thể chưa từng bán được
SELECT MaBienThe FROM BienTheSanPham
EXCEPT
SELECT DISTINCT MaBienThe FROM ChiTietDonHang;

-- B. Khách hàng vừa mua hàng vừa đánh giá
SELECT MaKH FROM DonHang WHERE TrangThai = N'DaGiao'
INTERSECT
SELECT MaKH FROM DanhGia;

-- ------------------------------------------------------------
-- TRUY VẤN 9: Tra cứu đơn hàng theo khoảng ngày và giá trị (BETWEEN)
-- Nghiệp vụ: Kế toán kiểm tra các đơn hàng phát sinh trong Tháng 01/2026 có giá trị từ 300.000 đến 1.000.000
-- ------------------------------------------------------------
SELECT 
    dh.MaDH,
    kh.HoTen,
    dh.NgayDat,
    dh.TongTien,
    dh.TrangThai
FROM DonHang dh
INNER JOIN KhachHang kh ON dh.MaKH = kh.MaKH
WHERE dh.NgayDat BETWEEN '2026-01-01' AND '2026-01-31 23:59:59'
  AND dh.TongTien BETWEEN 300000 AND 1000000
ORDER BY dh.NgayDat DESC;

-- ------------------------------------------------------------
-- TRUY VẤN 10: Lấy TOP 5 sản phẩm bán chạy nhất & TOP 20 PERCENT khách hàng chi tiêu nhiều nhất (TOP / PERCENT)
-- Nghiệp vụ: Vinh danh sản phẩm Best-Seller và Tri ân khách hàng VIP
-- ------------------------------------------------------------
-- 10A. TOP 5 sản phẩm bán chạy nhất theo số lượng
SELECT TOP 5
    sp.MaSP,
    sp.TenSP,
    SUM(ctdh.SoLuong) AS TongSoLuongBan,
    SUM(ctdh.SoLuong * ctdh.DonGiaBan) AS TongDoanhThu
FROM ChiTietDonHang ctdh
INNER JOIN BienTheSanPham bt ON ctdh.MaBienThe = bt.MaBienThe
INNER JOIN SanPham sp ON bt.MaSP = sp.MaSP
INNER JOIN DonHang dh ON ctdh.MaDH = dh.MaDH
WHERE dh.TrangThai = N'DaGiao'
GROUP BY sp.MaSP, sp.TenSP
ORDER BY TongSoLuongBan DESC;

-- 10B. TOP 20 PERCENT khách hàng chi tiêu nhiều nhất
SELECT TOP 20 PERCENT
    kh.MaKH,
    kh.HoTen,
    kh.SDT,
    SUM(dh.TongTien) AS TongChiTieu
FROM KhachHang kh
INNER JOIN DonHang dh ON kh.MaKH = dh.MaKH
WHERE dh.TrangThai = N'DaGiao'
GROUP BY kh.MaKH, kh.HoTen, kh.SDT
ORDER BY TongChiTieu DESC;

-- ============================================================
-- PHẦN 4: TẠO CÁC VIEW
-- ============================================================

USE QL_ThoiTrang;
GO

-- ============================================================
-- VIEW 1: Hiển thị sản phẩm lên Web kèm tồn kho & danh mục
-- ============================================================
IF OBJECT_ID('v_SanPhamHienThiWeb', 'V') IS NOT NULL
    DROP VIEW v_SanPhamHienThiWeb;
GO

CREATE VIEW v_SanPhamHienThiWeb
AS
SELECT 
    sp.MaSP,
    sp.TenSP,
    dm.TenDM,
    sp.GiaBan,
    sp.HinhAnh,
    sp.TrangThai,
    ISNULL(SUM(bt.SoLuongTon), 0) AS TongSoLuongTonKho,
    COUNT(bt.MaBienThe) AS SoBienThe
FROM SanPham sp
INNER JOIN DanhMuc dm ON sp.MaDM = dm.MaDM
LEFT JOIN BienTheSanPham bt ON sp.MaSP = bt.MaSP
WHERE sp.TrangThai = N'DangKinhDoanh'
GROUP BY 
    sp.MaSP, sp.TenSP, dm.TenDM, sp.GiaBan, sp.HinhAnh, sp.TrangThai;
GO

-- ============================================================
-- VIEW 2: Chi tiết đơn hàng cho Khách hàng & Nhân viên tra cứu
-- ============================================================
IF OBJECT_ID('v_ChiTietDonHang', 'V') IS NOT NULL
    DROP VIEW v_ChiTietDonHang;
GO

CREATE VIEW v_ChiTietDonHang
AS
SELECT 
    dh.MaDH,
    kh.HoTen AS TenKhachHang,
    dh.SDTNhanHang,
    dh.DiaChiNhan,
    dh.NgayDat,
    dh.TrangThai AS TrangThaiDonHang,
    sp.TenSP,
    bt.KichCo,
    bt.MauSac,
    bt.MaSKU,
    ctdh.SoLuong,
    ctdh.DonGiaBan,
    (ctdh.SoLuong * ctdh.DonGiaBan) AS ThanhTien
FROM DonHang dh
INNER JOIN KhachHang kh ON dh.MaKH = kh.MaKH
INNER JOIN ChiTietDonHang ctdh ON dh.MaDH = ctdh.MaDH
INNER JOIN BienTheSanPham bt ON ctdh.MaBienThe = bt.MaBienThe
INNER JOIN SanPham sp ON bt.MaSP = sp.MaSP;
GO

-- ============================================================
-- VIEW 3: View Cập nhật danh mục đang hoạt động kèm WITH CHECK OPTION
-- Đảm bảo khi UPDATE/INSERT qua View thì TrangThai luôn là 'HoatDong'
-- ============================================================
IF OBJECT_ID('v_DanhMucDangHoatDong', 'V') IS NOT NULL
    DROP VIEW v_DanhMucDangHoatDong;
GO

CREATE VIEW v_DanhMucDangHoatDong
AS
SELECT 
    MaDM,
    TenDM,
    MoTa,
    TrangThai
FROM DanhMuc
WHERE TrangThai = N'HoatDong'
WITH CHECK OPTION;
GO

-- ============================================================
-- VIEW 4: Báo cáo doanh thu theo Tháng/Năm
-- ============================================================
IF OBJECT_ID('v_BaoCaoDoanhThuTheoThang', 'V') IS NOT NULL
    DROP VIEW v_BaoCaoDoanhThuTheoThang;
GO

CREATE VIEW v_BaoCaoDoanhThuTheoThang
AS
SELECT 
    YEAR(NgayDat) AS Nam,
    MONTH(NgayDat) AS Thang,
    COUNT(MaDH) AS SoDonThanhCong,
    SUM(TongTien) AS TongDoanhThu,
    AVG(TongTien) AS GiaTriDonTrungBinh
FROM DonHang
WHERE TrangThai = N'DaGiao'
GROUP BY YEAR(NgayDat), MONTH(NgayDat);
GO

-- ============================================================
-- PHẦN 5: Stored Procedures & Functions
-- ============================================================

USE QL_ThoiTrang;
GO

-- =========================================================================
-- MỤC 7.1: STORED PROCEDURES (3 THỦ TỤC NGHIỆP VỤ)
-- =========================================================================

-- -------------------------------------------------------------------------
-- PROC 1: sp_TaoDonHang
-- Nghiệp vụ: Tạo đơn hàng, kiểm tra & trừ tồn kho, tính tổng tiền,
--            thêm thanh toán. Dùng TRANSACTION để đảm bảo an toàn dữ liệu.
-- Có tham số OUTPUT: @MaDH_Output
-- -------------------------------------------------------------------------
IF OBJECT_ID('sp_TaoDonHang', 'P') IS NOT NULL
    DROP PROCEDURE sp_TaoDonHang;
GO

CREATE PROCEDURE sp_TaoDonHang
    @MaKH INT,
    @DiaChiNhan NVARCHAR(255),
    @SDTNhanHang VARCHAR(15),
    @MaBienThe INT,
    @SoLuongMua INT,
    @PhuongThucTT NVARCHAR(50),
    @MaDH_Output INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Kiểm tra biến thể và số lượng tồn kho
        DECLARE @TonKhoHienTai INT;
        DECLARE @GiaBan DECIMAL(18,2);

        SELECT 
            @TonKhoHienTai = bt.SoLuongTon,
            @GiaBan = sp.GiaBan
        FROM BienTheSanPham bt
        INNER JOIN SanPham sp ON bt.MaSP = sp.MaSP
        WHERE bt.MaBienThe = @MaBienThe;

        IF @TonKhoHienTai IS NULL
        BEGIN
            RAISERROR(N'Biến thể sản phẩm không tồn tại!', 16, 1);
        END

        IF @TonKhoHienTai < @SoLuongMua
        BEGIN
            RAISERROR(N'Số lượng tồn kho không đủ để đáp ứng đơn hàng!', 16, 1);
        END

        -- 2. Tính tổng tiền đơn hàng
        DECLARE @TongTien DECIMAL(18,2) = @GiaBan * @SoLuongMua;

        -- 3. Tạo bản ghi đơn hàng mới
        INSERT INTO DonHang (MaKH, NgayDat, DiaChiNhan, SDTNhanHang, TongTien, TrangThai)
        VALUES (@MaKH, GETDATE(), @DiaChiNhan, @SDTNhanHang, @TongTien, N'ChoXacNhan');

        SET @MaDH_Output = SCOPE_IDENTITY();

        -- 4. Thêm chi tiết đơn hàng
        INSERT INTO ChiTietDonHang (MaDH, MaBienThe, SoLuong, DonGiaBan)
        VALUES (@MaDH_Output, @MaBienThe, @SoLuongMua, @GiaBan);

        -- 5. Trừ số lượng tồn kho của biến thể
        UPDATE BienTheSanPham
        SET SoLuongTon = SoLuongTon - @SoLuongMua
        WHERE MaBienThe = @MaBienThe;

        -- 6. Tạo bản ghi thanh toán
        INSERT INTO ThanhToan (MaDH, PhuongThuc, SoTien, NgayThanhToan, TrangThai, MaGiaoDich)
        VALUES (
            @MaDH_Output, 
            @PhuongThucTT, 
            @TongTien, 
            CASE WHEN @PhuongThucTT = N'COD' THEN NULL ELSE GETDATE() END,
            CASE WHEN @PhuongThucTT = N'COD' THEN N'ChuaThanhToan' ELSE N'ThanhCong' END,
            CONCAT('TXN-', DATEDIFF(SECOND, '1970-01-01', GETDATE()))
        );

        COMMIT TRANSACTION;
        PRINT N'>> Tạo đơn hàng thành công! Mã đơn hàng: ' + CAST(@MaDH_Output AS NVARCHAR(20));
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- -------------------------------------------------------------------------
-- PROC 2: sp_CapNhatTrangThaiDonHang
-- Nghiệp vụ: Cập nhật trạng thái đơn hàng. Nếu chuyển sang 'DaHuy' thì tự động
--            cộng hoàn lại số lượng tồn kho và cập nhật hoàn tiền.
-- -------------------------------------------------------------------------
IF OBJECT_ID('sp_CapNhatTrangThaiDonHang', 'P') IS NOT NULL
    DROP PROCEDURE sp_CapNhatTrangThaiDonHang;
GO

CREATE PROCEDURE sp_CapNhatTrangThaiDonHang
    @MaDH INT,
    @TrangThaiMoi NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TrangThaiCu NVARCHAR(30);
        SELECT @TrangThaiCu = TrangThai FROM DonHang WHERE MaDH = @MaDH;

        IF @TrangThaiCu IS NULL
        BEGIN
            RAISERROR(N'Không tìm thấy mã đơn hàng cần cập nhật!', 16, 1);
        END

        IF @TrangThaiCu = N'DaHuy'
        BEGIN
            RAISERROR(N'Đơn hàng này đã bị hủy trước đó, không thể thay đổi trạng thái!', 16, 1);
        END

        -- Nếu chuyển sang 'DaHuy': Tự động hoàn kho cho các biến thể
        IF @TrangThaiMoi = N'DaHuy' AND @TrangThaiCu <> N'DaHuy'
        BEGIN
            UPDATE bt
            SET bt.SoLuongTon = bt.SoLuongTon + ctdh.SoLuong
            FROM BienTheSanPham bt
            INNER JOIN ChiTietDonHang ctdh ON bt.MaBienThe = ctdh.MaBienThe
            WHERE ctdh.MaDH = @MaDH;

            -- Cập nhật thanh toán sang HoanTien nếu trước đó đã thanh toán
            UPDATE ThanhToan
            SET TrangThai = N'HoanTien'
            WHERE MaDH = @MaDH AND TrangThai = N'ThanhCong';
        END

        -- Cập nhật trạng thái mới cho đơn hàng
        UPDATE DonHang
        SET TrangThai = @TrangThaiMoi
        WHERE MaDH = @MaDH;

        COMMIT TRANSACTION;
        PRINT N'>> Đã cập nhật trạng thái đơn hàng thành công sang: ' + @TrangThaiMoi;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END;
GO

-- -------------------------------------------------------------------------
-- PROC 3: sp_BaoCaoDoanhThuTheoKhoangNgay
-- Nghiệp vụ: Báo cáo tổng doanh thu và số đơn thành công trong một khoảng ngày
-- Có 2 tham số OUTPUT: @TongDoanhThu, @TongSoDon
-- -------------------------------------------------------------------------
IF OBJECT_ID('sp_BaoCaoDoanhThuTheoKhoangNgay', 'P') IS NOT NULL
    DROP PROCEDURE sp_BaoCaoDoanhThuTheoKhoangNgay;
GO

CREATE PROCEDURE sp_BaoCaoDoanhThuTheoKhoangNgay
    @TuNgay DATETIME,
    @DenNgay DATETIME,
    @TongDoanhThu DECIMAL(18,2) OUTPUT,
    @TongSoDon INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Tính toán gán vào 2 biến OUTPUT
    SELECT 
        @TongDoanhThu = ISNULL(SUM(TongTien), 0),
        @TongSoDon = COUNT(MaDH)
    FROM DonHang
    WHERE TrangThai = N'DaGiao'
      AND NgayDat BETWEEN @TuNgay AND @DenNgay;

    -- Trả thêm danh sách chi tiết các đơn hàng thành công ra lưới kết quả
    SELECT 
        dh.MaDH,
        kh.HoTen AS TenKhachHang,
        dh.NgayDat,
        dh.TongTien,
        tt.PhuongThuc
    FROM DonHang dh
    INNER JOIN KhachHang kh ON dh.MaKH = kh.MaKH
    LEFT JOIN ThanhToan tt ON dh.MaDH = tt.MaDH
    WHERE dh.TrangThai = N'DaGiao'
      AND dh.NgayDat BETWEEN @TuNgay AND @DenNgay
    ORDER BY dh.NgayDat DESC;
END;
GO

-- =========================================================================
-- MỤC 7.2: USER-DEFINED FUNCTIONS (2 HÀM NGHIỆP VỤ)
-- =========================================================================

-- -------------------------------------------------------------------------
-- FUNCTION 1: fn_TinhTongTienDonHang (Scalar Function)
-- Nghiệp vụ: Tính tổng tiền chi tiết đơn hàng từ bảng ChiTietDonHang
-- -------------------------------------------------------------------------
IF OBJECT_ID('fn_TinhTongTienDonHang', 'FN') IS NOT NULL
    DROP FUNCTION fn_TinhTongTienDonHang;
GO

CREATE FUNCTION fn_TinhTongTienDonHang (@MaDH INT)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @TongTien DECIMAL(18,2);

    SELECT @TongTien = ISNULL(SUM(SoLuong * DonGiaBan), 0)
    FROM ChiTietDonHang
    WHERE MaDH = @MaDH;

    RETURN @TongTien;
END;
GO

-- -------------------------------------------------------------------------
-- FUNCTION 2: fn_TimKiemBienTheTheoSanPham (Inline Table-Valued Function)
-- Nghiệp vụ: Truy vấn danh sách biến thể (kích cỡ, màu sắc, tồn kho, tình trạng)
--            của một sản phẩm cụ thể
-- -------------------------------------------------------------------------
IF OBJECT_ID('fn_TimKiemBienTheTheoSanPham', 'IF') IS NOT NULL
    DROP FUNCTION fn_TimKiemBienTheTheoSanPham;
GO

CREATE FUNCTION fn_TimKiemBienTheTheoSanPham (@MaSP INT)
RETURNS TABLE
AS
RETURN (
    SELECT 
        sp.MaSP,
        sp.TenSP,
        bt.MaBienThe,
        bt.MaSKU,
        bt.KichCo,
        bt.MauSac,
        bt.SoLuongTon,
        sp.GiaBan,
        CASE 
            WHEN bt.SoLuongTon > 0 THEN N'Còn hàng'
            ELSE N'Hết hàng'
        END AS TinhTrangHang
    FROM BienTheSanPham bt
    INNER JOIN SanPham sp ON bt.MaSP = sp.MaSP
    WHERE sp.MaSP = @MaSP
);
GO

-- 1. Test Function 1 (Tính tổng tiền đơn số 1):
SELECT dbo.fn_TinhTongTienDonHang(1) AS TongTienDonHang1;
-- 2. Test Function 2 (Xem các biến thể của sản phẩm 1 - Áo thun):
SELECT * FROM dbo.fn_TimKiemBienTheTheoSanPham(1);
-- 3. Test Proc 3 (Báo cáo doanh thu tháng 01/2026 kèm Output):
DECLARE @DoanhThu DECIMAL(18,2), @SoDon INT;
EXEC sp_BaoCaoDoanhThuTheoKhoangNgay
    @TuNgay = '2026-01-01',
    @DenNgay = '2026-01-31 23:59:59',
    @TongDoanhThu = @DoanhThu OUTPUT,
    @TongSoDon = @SoDon OUTPUT;
SELECT @DoanhThu AS TongDoanhThuThang1, @SoDon AS TongSoDonThang1;

-- ============================================================
-- PHẦN 6: KIỂM THỬ VÀ TỐI ƯU CƠ BẢN
-- ============================================================


USE QL_ThoiTrang;
GO

PRINT '====================================================================';
PRINT 'MỤC 8.1: KIỂM THỬ CÁC RÀNG BUỘC TOÀN VẸN (CONSTRAINTS)';
PRINT '====================================================================';

-- -----------------------------------------------------------------
-- TEST 1: Thử vi phạm ràng buộc UNIQUE (Email trùng lặp trong TaiKhoan)
-- Kết quả mong muốn: Bị chặn bởi UQ_TaiKhoan_Email
-- -----------------------------------------------------------------
PRINT '--- [TEST 1] Thử chèn trùng Email đã tồn tại ---';
BEGIN TRY
    INSERT INTO TaiKhoan (TenDangNhap, MatKhau, Email, VaiTro)
    VALUES ('user_test_unique', 'pass123', 'nguyenvana@gmail.com', N'KhachHang');
    PRINT N'[LỖI]: Ràng buộc UNIQUE không hoạt động!';
END TRY
BEGIN CATCH
    PRINT N'[THÀNH CÔNG] Đã chặn vi phạm UNIQUE Email: ' + ERROR_MESSAGE();
END CATCH;
GO

-- -----------------------------------------------------------------
-- TEST 2: Thử vi phạm ràng buộc CHECK (SoSao đánh giá ngoài khoảng 1 - 5)
-- Kết quả mong muốn: Bị chặn bởi CK_DanhGia_SoSao
-- -----------------------------------------------------------------
PRINT '--- [TEST 2] Thử đánh giá 6 sao ---';
BEGIN TRY
    INSERT INTO DanhGia (MaKH, MaSP, SoSao, NoiDung)
    VALUES (1, 2, 6, N'Sản phẩm cho 6 sao luôn');
    PRINT N'[LỖI]: Ràng buộc CHECK số sao không hoạt động!';
END TRY
BEGIN CATCH
    PRINT N'[THÀNH CÔNG] Đã chặn vi phạm CHECK số sao (1-5): ' + ERROR_MESSAGE();
END CATCH;
GO

-- -----------------------------------------------------------------
-- TEST 3: Thử vi phạm ràng buộc CHECK (Số lượng tồn kho âm)
-- Kết quả mong muốn: Bị chặn bởi CK_BienThe_SoLuongTon
-- -----------------------------------------------------------------
PRINT '--- [TEST 3] Thử cập nhật số lượng tồn kho thành số âm (-5) ---';
BEGIN TRY
    UPDATE BienTheSanPham
    SET SoLuongTon = -5
    WHERE MaBienThe = 1;
    PRINT N'[LỖI]: Ràng buộc CHECK tồn kho không hoạt động!';
END TRY
BEGIN CATCH
    PRINT N'[THÀNH CÔNG] Đã chặn vi phạm CHECK tồn kho âm: ' + ERROR_MESSAGE();
END CATCH;
GO

-- -----------------------------------------------------------------
-- TEST 4: Thử vi phạm UNIQUE tổ hợp (MaSP, KichCo, MauSac) trong BienTheSanPham
-- Kết quả mong muốn: Bị chặn bởi UQ_BienThe_SP_KichCo_MauSac
-- -----------------------------------------------------------------
PRINT '--- [TEST 4] Thử tạo biến thể trùng lặp (SP 1 - Size M - Màu Trắng) ---';
BEGIN TRY
    INSERT INTO BienTheSanPham (MaSP, KichCo, MauSac, SoLuongTon, MaSKU)
    VALUES (1, 'M', N'Trắng', 10, 'SKU-TRUNG-LAP-999');
    PRINT N'[LỖI]: Ràng buộc UNIQUE tổ hợp không hoạt động!';
END TRY
BEGIN CATCH
    PRINT N'[THÀNH CÔNG] Đã chặn trùng lặp tổ hợp (Sản phẩm + Size + Màu): ' + ERROR_MESSAGE();
END CATCH;
GO

-- -----------------------------------------------------------------
-- TEST 5: Thử vi phạm FOREIGN KEY (Tạo đơn hàng với MaKH không tồn tại)
-- Kết quả mong muốn: Bị chặn bởi FK_DonHang_KhachHang
-- -----------------------------------------------------------------
PRINT '--- [TEST 5] Thử tạo đơn hàng cho Khách hàng ảo (MaKH = 99999) ---';
BEGIN TRY
    INSERT INTO DonHang (MaKH, DiaChiNhan, SDTNhanHang, TongTien)
    VALUES (99999, N'Địa chỉ ảo', '0999999999', 500000);
    PRINT N'[LỖI]: Khóa ngoại FK không hoạt động!';
END TRY
BEGIN CATCH
    PRINT N'[THÀNH CÔNG] Đã chặn vi phạm Khóa ngoại (Mã khách hàng không tồn tại): ' + ERROR_MESSAGE();
END CATCH;
GO


PRINT '';
PRINT '====================================================================';
PRINT 'MỤC 8.2: THỬ NGHIỆM GIAO DỊCH (TRANSACTION) & THỦ TỤC NGHIỆP VỤ';
PRINT '====================================================================';

-- -----------------------------------------------------------------
-- KỊCH BẢN 1: Đặt hàng thành công -> Kiểm tra COMMIT & Trừ kho tự động
-- -----------------------------------------------------------------
PRINT '--- [KỊCH BẢN 1] Đặt hàng bình thường (Số lượng = 2) ---';
DECLARE @TonKhoTruoc INT;
SELECT @TonKhoTruoc = SoLuongTon FROM BienTheSanPham WHERE MaBienThe = 1;
PRINT N'Tồn kho mã biến thể 1 TRƯỚC khi đặt: ' + CAST(@TonKhoTruoc AS NVARCHAR(10));

DECLARE @MaDonMoi INT;
EXEC sp_TaoDonHang
    @MaKH = 1,
    @DiaChiNhan = N'Số 1 Đại Cồ Việt, Hai Bà Trưng, Hà Nội',
    @SDTNhanHang = '0912345601',
    @MaBienThe = 1,
    @SoLuongMua = 2,
    @PhuongThucTT = N'COD',
    @MaDH_Output = @MaDonMoi OUTPUT;

DECLARE @TonKhoSau INT;
SELECT @TonKhoSau = SoLuongTon FROM BienTheSanPham WHERE MaBienThe = 1;
PRINT N'Tồn kho mã biến thể 1 SAU khi đặt: ' + CAST(@TonKhoSau AS NVARCHAR(10));
PRINT N'Kiểm tra trừ kho: ' + CASE WHEN @TonKhoSau = @TonKhoTruoc - 2 THEN N'CHÍNH XÁC (Đã trừ 2)' ELSE N'SAI SỐ' END;

-- Xem chi tiết đơn hàng vừa tạo
SELECT MaDH, MaKH, NgayDat, TongTien, TrangThai FROM DonHang WHERE MaDH = @MaDonMoi;
SELECT MaDH, MaBienThe, SoLuong, DonGiaBan FROM ChiTietDonHang WHERE MaDH = @MaDonMoi;
SELECT MaTT, MaDH, PhuongThuc, SoTien, TrangThai FROM ThanhToan WHERE MaDH = @MaDonMoi;
GO

-- -----------------------------------------------------------------
-- KỊCH BẢN 2: Đặt hàng thất bại do mua vượt quá tồn kho -> Tự động ROLLBACK
-- -----------------------------------------------------------------
PRINT '--- [KỊCH BẢN 2] Đặt hàng vượt quá tồn kho (Mua 9999 chiếc) ---';
BEGIN TRY
    DECLARE @MaDonLoi INT;
    EXEC sp_TaoDonHang
        @MaKH = 2,
        @DiaChiNhan = N'99 Cầu Giấy, Hà Nội',
        @SDTNhanHang = '0912345602',
        @MaBienThe = 1,
        @SoLuongMua = 9999, -- Quá số lượng tồn kho
        @PhuongThucTT = N'VNPAY',
        @MaDH_Output = @MaDonLoi OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'[ROLLBACK AN TOÀN] Giao dịch đã bị hủy và hoàn tác toàn bộ: ' + ERROR_MESSAGE();
END CATCH;
GO

-- -----------------------------------------------------------------
-- KỊCH BẢN 3: Hủy đơn hàng -> Tự động HOÀN LẠI số lượng tồn kho
-- -----------------------------------------------------------------
PRINT '--- [KỊCH BẢN 3] Hủy đơn hàng và tự động hoàn trả tồn kho ---';
-- Lấy mã đơn hàng mới nhất vừa đặt ở Kịch bản 1
DECLARE @MaDHCanHuy INT = (SELECT MAX(MaDH) FROM DonHang);
DECLARE @TonTruocHuy INT;
SELECT @TonTruocHuy = SoLuongTon FROM BienTheSanPham WHERE MaBienThe = 1;
PRINT N'Tồn kho TRƯỚC khi hủy đơn ' + CAST(@MaDHCanHuy AS NVARCHAR(10)) + N': ' + CAST(@TonTruocHuy AS NVARCHAR(10));

-- Gọi thủ tục cập nhật sang DaHuy
EXEC sp_CapNhatTrangThaiDonHang 
    @MaDH = @MaDHCanHuy, 
    @TrangThaiMoi = N'DaHuy';

DECLARE @TonSauHuy INT;
SELECT @TonSauHuy = SoLuongTon FROM BienTheSanPham WHERE MaBienThe = 1;
PRINT N'Tồn kho SAU khi hủy đơn: ' + CAST(@TonSauHuy AS NVARCHAR(10));
PRINT N'Kiểm tra hoàn kho: ' + CASE WHEN @TonSauHuy = @TonTruocHuy + 2 THEN N'CHÍNH XÁC (Đã hoàn lại 2 sản phẩm)' ELSE N'CHƯA HOÀN KHO' END;
GO


PRINT '';
PRINT '====================================================================';
PRINT 'MỤC 8.3: TỐI ƯU HÓA HIỆU SUẤT BẰNG CHỈ MỤC (NON-CLUSTERED INDEXES)';
PRINT '====================================================================';

-- 1. Index trên Khóa ngoại Danh mục của bảng SanPham
-- Giải thích: Tối ưu khi khách hàng bấm xem danh mục sản phẩm (Áo nam, Váy nữ...)
IF EXISTS (SELECT name FROM sys.indexes WHERE name = N'IX_SanPham_MaDM')
    DROP INDEX IX_SanPham_MaDM ON SanPham;
GO
CREATE NONCLUSTERED INDEX IX_SanPham_MaDM
ON SanPham (MaDM)
INCLUDE (TenSP, GiaBan, TrangThai);
PRINT N'>> Đã tạo Index: IX_SanPham_MaDM';
GO

-- 2. Index trên Sản phẩm của bảng BienTheSanPham
-- Giải thích: Tối ưu khi khách mở trang chi tiết sản phẩm, hệ thống cần tải ngay các size, màu và tồn kho
IF EXISTS (SELECT name FROM sys.indexes WHERE name = N'IX_BienThe_MaSP')
    DROP INDEX IX_BienThe_MaSP ON BienTheSanPham;
GO
CREATE NONCLUSTERED INDEX IX_BienThe_MaSP
ON BienTheSanPham (MaSP)
INCLUDE (KichCo, MauSac, SoLuongTon, MaSKU);
PRINT N'>> Đã tạo Index: IX_BienThe_MaSP';
GO

-- 3. Composite Index trên Khách hàng và Ngày đặt của bảng DonHang
-- Giải thích: Tối ưu tính năng xem "Lịch sử mua hàng" sắp xếp theo đơn mới nhất
IF EXISTS (SELECT name FROM sys.indexes WHERE name = N'IX_DonHang_MaKH_NgayDat')
    DROP INDEX IX_DonHang_MaKH_NgayDat ON DonHang;
GO
CREATE NONCLUSTERED INDEX IX_DonHang_MaKH_NgayDat
ON DonHang (MaKH, NgayDat DESC)
INCLUDE (TongTien, TrangThai);
PRINT N'>> Đã tạo Index: IX_DonHang_MaKH_NgayDat';
GO

-- 4. Index trên Số điện thoại Khách hàng
-- Giải thích: Tối ưu khi nhân viên tìm kiếm thông tin khách hàng bằng số điện thoại
IF EXISTS (SELECT name FROM sys.indexes WHERE name = N'IX_KhachHang_SDT')
    DROP INDEX IX_KhachHang_SDT ON KhachHang;
GO
CREATE NONCLUSTERED INDEX IX_KhachHang_SDT
ON KhachHang (SDT);
PRINT N'>> Đã tạo Index: IX_KhachHang_SDT';
GO

-- 5. Index trên MaDH trong bảng ChiTietDonHang
-- Giải thích: Tối ưu phép JOIN giữa bảng DonHang và ChiTietDonHang khi in hóa đơn
IF EXISTS (SELECT name FROM sys.indexes WHERE name = N'IX_ChiTietDonHang_MaDH')
    DROP INDEX IX_ChiTietDonHang_MaDH ON ChiTietDonHang;
GO
CREATE NONCLUSTERED INDEX IX_ChiTietDonHang_MaDH
ON ChiTietDonHang (MaDH);
PRINT N'>> Đã tạo Index: IX_ChiTietDonHang_MaDH';
GO

PRINT '====================================================================';
PRINT 'HOÀN THÀNH TOÀN BỘ KIỂM THỬ VÀ TỐI ƯU HỆ THỐNG!';
PRINT '====================================================================';