/* =====================================================================
   PaperCraft - Văn Phòng Phẩm
   SQL Server database script (SQL Server 2016 SP1+)
   Bao gồm: Tables, Constraints, Indexes, Functions, Views,
            Stored Procedures, Triggers, Seed Data, Sample Queries
   Chạy toàn bộ file trong SSMS / Azure Data Studio.
   ===================================================================== */

USE master;
GO

IF DB_ID(N'PaperCraftDB') IS NULL
    CREATE DATABASE PaperCraftDB COLLATE Vietnamese_CI_AS;
GO

USE PaperCraftDB;
GO

/* =====================================================================
   1. TABLES
   ===================================================================== */

-- Cấu hình website (ngưỡng freeship, phí ship...)
CREATE TABLE dbo.SiteSettings (
    SettingKey   NVARCHAR(50)   NOT NULL CONSTRAINT PK_SiteSettings PRIMARY KEY,
    SettingValue NVARCHAR(500)  NOT NULL,
    Description  NVARCHAR(200)  NULL
);
GO

-- Danh mục (Bút & Mực, Sổ & Vở, Dụng Cụ Vẽ, Tổ Chức Bàn)
CREATE TABLE dbo.Categories (
    CategoryId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Categories PRIMARY KEY,
    Slug         VARCHAR(100)   NOT NULL CONSTRAINT UQ_Categories_Slug UNIQUE,
    Name         NVARCHAR(100)  NOT NULL,
    Description  NVARCHAR(500)  NULL,
    ImageUrl     VARCHAR(255)   NULL,
    DisplayOrder INT            NOT NULL CONSTRAINT DF_Categories_Order DEFAULT 0,
    IsActive     BIT            NOT NULL CONSTRAINT DF_Categories_Active DEFAULT 1,
    CreatedAt    DATETIME2(0)   NOT NULL CONSTRAINT DF_Categories_Created DEFAULT SYSDATETIME()
);
GO

-- Sản phẩm
CREATE TABLE dbo.Products (
    ProductId       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Products PRIMARY KEY,
    Code            VARCHAR(20)    NOT NULL CONSTRAINT UQ_Products_Code UNIQUE,   -- sp1, sp2... (data-id trên web)
    CategoryId      INT            NOT NULL CONSTRAINT FK_Products_Categories REFERENCES dbo.Categories(CategoryId),
    Name            NVARCHAR(200)  NOT NULL,
    ProductType     NVARCHAR(50)   NULL,                  -- "Bút viết", "Sổ tay"... (prod-cat trên web)
    Description     NVARCHAR(MAX)  NULL,
    Price           DECIMAL(18,0)  NOT NULL CONSTRAINT CK_Products_Price CHECK (Price >= 0),
    OldPrice        DECIMAL(18,0)  NULL,                  -- giá gốc (hiển thị gạch ngang)
    DiscountPercent AS (CASE WHEN OldPrice IS NOT NULL AND OldPrice > Price
                             THEN CAST(ROUND((OldPrice - Price) * 100.0 / OldPrice, 0) AS INT)
                             ELSE 0 END) PERSISTED,
    ImageUrl        VARCHAR(255)   NULL,
    Badge           VARCHAR(10)    NULL CONSTRAINT CK_Products_Badge CHECK (Badge IN ('new','sale') OR Badge IS NULL),
    StockQty        INT            NOT NULL CONSTRAINT DF_Products_Stock DEFAULT 0 CONSTRAINT CK_Products_Stock CHECK (StockQty >= 0),
    SoldCount       INT            NOT NULL CONSTRAINT DF_Products_Sold DEFAULT 0,
    IsBestSeller    BIT            NOT NULL CONSTRAINT DF_Products_Best DEFAULT 0,
    IsActive        BIT            NOT NULL CONSTRAINT DF_Products_Active DEFAULT 1,
    CreatedAt       DATETIME2(0)   NOT NULL CONSTRAINT DF_Products_Created DEFAULT SYSDATETIME(),
    UpdatedAt       DATETIME2(0)   NOT NULL CONSTRAINT DF_Products_Updated DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Products_OldPrice CHECK (OldPrice IS NULL OR OldPrice >= Price)
);
GO
CREATE INDEX IX_Products_Category ON dbo.Products(CategoryId) INCLUDE (Name, Price, ImageUrl, IsActive);
CREATE INDEX IX_Products_Best     ON dbo.Products(IsBestSeller, SoldCount DESC) WHERE IsActive = 1;
GO

-- Ảnh phụ của sản phẩm
CREATE TABLE dbo.ProductImages (
    ImageId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProductImages PRIMARY KEY,
    ProductId  INT           NOT NULL CONSTRAINT FK_ProductImages_Products REFERENCES dbo.Products(ProductId) ON DELETE CASCADE,
    ImageUrl   VARCHAR(255)  NOT NULL,
    SortOrder  INT           NOT NULL CONSTRAINT DF_ProductImages_Sort DEFAULT 0
);
GO

-- Khách hàng / tài khoản
CREATE TABLE dbo.Customers (
    CustomerId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
    Email        VARCHAR(150)   NOT NULL CONSTRAINT UQ_Customers_Email UNIQUE,
    PasswordHash VARCHAR(255)   NOT NULL,              -- băm bằng bcrypt/argon2 ở backend, KHÔNG lưu mật khẩu thô
    FullName     NVARCHAR(100)  NOT NULL,
    Phone        VARCHAR(20)    NULL,
    Role         VARCHAR(10)    NOT NULL CONSTRAINT DF_Customers_Role DEFAULT 'Customer'
                                CONSTRAINT CK_Customers_Role CHECK (Role IN ('Customer','Admin')),
    IsVip        BIT            NOT NULL CONSTRAINT DF_Customers_Vip DEFAULT 0,
    IsActive     BIT            NOT NULL CONSTRAINT DF_Customers_Active DEFAULT 1,
    CreatedAt    DATETIME2(0)   NOT NULL CONSTRAINT DF_Customers_Created DEFAULT SYSDATETIME(),
    LastLoginAt  DATETIME2(0)   NULL
);
GO

-- Địa chỉ giao hàng
CREATE TABLE dbo.Addresses (
    AddressId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Addresses PRIMARY KEY,
    CustomerId   INT            NOT NULL CONSTRAINT FK_Addresses_Customers REFERENCES dbo.Customers(CustomerId) ON DELETE CASCADE,
    ReceiverName NVARCHAR(100)  NOT NULL,
    Phone        VARCHAR(20)    NOT NULL,
    Province     NVARCHAR(100)  NOT NULL,
    District     NVARCHAR(100)  NOT NULL,
    Ward         NVARCHAR(100)  NULL,
    AddressLine  NVARCHAR(255)  NOT NULL,
    IsDefault    BIT            NOT NULL CONSTRAINT DF_Addresses_Default DEFAULT 0
);
GO

-- Mã giảm giá
CREATE TABLE dbo.Coupons (
    CouponId       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Coupons PRIMARY KEY,
    Code           VARCHAR(30)   NOT NULL CONSTRAINT UQ_Coupons_Code UNIQUE,
    Description    NVARCHAR(200) NULL,
    DiscountType   VARCHAR(10)   NOT NULL CONSTRAINT CK_Coupons_Type CHECK (DiscountType IN ('percent','amount','freeship')),
    DiscountValue  DECIMAL(18,0) NOT NULL CONSTRAINT DF_Coupons_Value DEFAULT 0,
    MinOrderValue  DECIMAL(18,0) NOT NULL CONSTRAINT DF_Coupons_Min DEFAULT 0,
    MaxDiscount    DECIMAL(18,0) NULL,
    StartDate      DATETIME2(0)  NOT NULL CONSTRAINT DF_Coupons_Start DEFAULT SYSDATETIME(),
    EndDate        DATETIME2(0)  NULL,
    UsageLimit     INT           NULL,
    UsedCount      INT           NOT NULL CONSTRAINT DF_Coupons_Used DEFAULT 0,
    IsActive       BIT           NOT NULL CONSTRAINT DF_Coupons_Active DEFAULT 1
);
GO

-- Giỏ hàng (khách chưa đăng nhập dùng SessionId)
CREATE TABLE dbo.Carts (
    CartId      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Carts PRIMARY KEY,
    CustomerId  INT            NULL CONSTRAINT FK_Carts_Customers REFERENCES dbo.Customers(CustomerId),
    SessionId   VARCHAR(100)   NULL,
    Status      VARCHAR(12)    NOT NULL CONSTRAINT DF_Carts_Status DEFAULT 'Active'
                               CONSTRAINT CK_Carts_Status CHECK (Status IN ('Active','CheckedOut','Abandoned')),
    CreatedAt   DATETIME2(0)   NOT NULL CONSTRAINT DF_Carts_Created DEFAULT SYSDATETIME(),
    UpdatedAt   DATETIME2(0)   NOT NULL CONSTRAINT DF_Carts_Updated DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Carts_Owner CHECK (CustomerId IS NOT NULL OR SessionId IS NOT NULL)
);
GO
CREATE UNIQUE INDEX UX_Carts_ActiveSession  ON dbo.Carts(SessionId)  WHERE Status = 'Active' AND SessionId  IS NOT NULL;
CREATE UNIQUE INDEX UX_Carts_ActiveCustomer ON dbo.Carts(CustomerId) WHERE Status = 'Active' AND CustomerId IS NOT NULL;
GO

CREATE TABLE dbo.CartItems (
    CartItemId  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CartItems PRIMARY KEY,
    CartId      INT NOT NULL CONSTRAINT FK_CartItems_Carts    REFERENCES dbo.Carts(CartId) ON DELETE CASCADE,
    ProductId   INT NOT NULL CONSTRAINT FK_CartItems_Products REFERENCES dbo.Products(ProductId),
    Quantity    INT NOT NULL CONSTRAINT CK_CartItems_Qty CHECK (Quantity BETWEEN 1 AND 99),
    AddedAt     DATETIME2(0) NOT NULL CONSTRAINT DF_CartItems_Added DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_CartItems_CartProduct UNIQUE (CartId, ProductId)
);
GO

-- Đơn hàng
CREATE SEQUENCE dbo.seq_OrderNumber AS INT START WITH 1 INCREMENT BY 1 CYCLE MAXVALUE 9999;
GO

CREATE TABLE dbo.Orders (
    OrderId        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
    OrderCode      VARCHAR(20)    NOT NULL CONSTRAINT UQ_Orders_Code UNIQUE,
    CustomerId     INT            NULL CONSTRAINT FK_Orders_Customers REFERENCES dbo.Customers(CustomerId),
    CouponId       INT            NULL CONSTRAINT FK_Orders_Coupons   REFERENCES dbo.Coupons(CouponId),
    ReceiverName   NVARCHAR(100)  NOT NULL,
    Phone          VARCHAR(20)    NOT NULL,
    Email          VARCHAR(150)   NULL,
    ShippingAddress NVARCHAR(400) NOT NULL,
    Subtotal       DECIMAL(18,0)  NOT NULL,
    ShippingFee    DECIMAL(18,0)  NOT NULL CONSTRAINT DF_Orders_Ship DEFAULT 0,
    DiscountAmount DECIMAL(18,0)  NOT NULL CONSTRAINT DF_Orders_Disc DEFAULT 0,
    Total          DECIMAL(18,0)  NOT NULL,
    PaymentMethod  VARCHAR(15)    NOT NULL CONSTRAINT DF_Orders_PayM DEFAULT 'COD'
                                  CONSTRAINT CK_Orders_PayM CHECK (PaymentMethod IN ('COD','BankTransfer','Momo','VNPay')),
    PaymentStatus  VARCHAR(10)    NOT NULL CONSTRAINT DF_Orders_PayS DEFAULT 'Unpaid'
                                  CONSTRAINT CK_Orders_PayS CHECK (PaymentStatus IN ('Unpaid','Paid','Refunded')),
    Status         VARCHAR(12)    NOT NULL CONSTRAINT DF_Orders_Status DEFAULT 'Pending'
                                  CONSTRAINT CK_Orders_Status CHECK (Status IN ('Pending','Confirmed','Shipping','Delivered','Cancelled')),
    Note           NVARCHAR(500)  NULL,
    CreatedAt      DATETIME2(0)   NOT NULL CONSTRAINT DF_Orders_Created DEFAULT SYSDATETIME(),
    UpdatedAt      DATETIME2(0)   NOT NULL CONSTRAINT DF_Orders_Updated DEFAULT SYSDATETIME()
);
GO
CREATE INDEX IX_Orders_Customer ON dbo.Orders(CustomerId, CreatedAt DESC);
CREATE INDEX IX_Orders_Status   ON dbo.Orders(Status, CreatedAt DESC);
GO

CREATE TABLE dbo.OrderItems (
    OrderItemId  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderItems PRIMARY KEY,
    OrderId      INT            NOT NULL CONSTRAINT FK_OrderItems_Orders   REFERENCES dbo.Orders(OrderId) ON DELETE CASCADE,
    ProductId    INT            NOT NULL CONSTRAINT FK_OrderItems_Products REFERENCES dbo.Products(ProductId),
    ProductName  NVARCHAR(200)  NOT NULL,          -- snapshot tại thời điểm mua
    UnitPrice    DECIMAL(18,0)  NOT NULL,
    Quantity     INT            NOT NULL CONSTRAINT CK_OrderItems_Qty CHECK (Quantity > 0),
    LineTotal    AS (UnitPrice * Quantity) PERSISTED
);
GO
CREATE INDEX IX_OrderItems_Order ON dbo.OrderItems(OrderId);
GO

CREATE TABLE dbo.OrderStatusHistory (
    HistoryId  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderStatusHistory PRIMARY KEY,
    OrderId    INT           NOT NULL CONSTRAINT FK_OSH_Orders REFERENCES dbo.Orders(OrderId) ON DELETE CASCADE,
    OldStatus  VARCHAR(12)   NULL,
    NewStatus  VARCHAR(12)   NOT NULL,
    Note       NVARCHAR(300) NULL,
    ChangedAt  DATETIME2(0)  NOT NULL CONSTRAINT DF_OSH_Changed DEFAULT SYSDATETIME()
);
GO

-- Đánh giá / "Khách hàng nói gì"
CREATE TABLE dbo.Reviews (
    ReviewId     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Reviews PRIMARY KEY,
    ProductId    INT            NULL CONSTRAINT FK_Reviews_Products  REFERENCES dbo.Products(ProductId) ON DELETE SET NULL,
    CustomerId   INT            NULL CONSTRAINT FK_Reviews_Customers REFERENCES dbo.Customers(CustomerId) ON DELETE SET NULL,
    AuthorName   NVARCHAR(100)  NOT NULL,
    AuthorRole   NVARCHAR(100)  NULL,
    AvatarEmoji  NVARCHAR(10)   NULL,
    AvatarBg     VARCHAR(10)    NULL,
    Rating       TINYINT        NOT NULL CONSTRAINT CK_Reviews_Rating CHECK (Rating BETWEEN 1 AND 5),
    Content      NVARCHAR(1000) NOT NULL,
    IsFeatured   BIT            NOT NULL CONSTRAINT DF_Reviews_Feat DEFAULT 0,   -- hiện ở trang chủ
    IsApproved   BIT            NOT NULL CONSTRAINT DF_Reviews_Appr DEFAULT 0,
    CreatedAt    DATETIME2(0)   NOT NULL CONSTRAINT DF_Reviews_Created DEFAULT SYSDATETIME()
);
GO

-- Đăng ký nhận tin (form Newsletter)
CREATE TABLE dbo.NewsletterSubscribers (
    SubscriberId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Newsletter PRIMARY KEY,
    Email        VARCHAR(150)  NOT NULL CONSTRAINT UQ_Newsletter_Email UNIQUE,
    IsActive     BIT           NOT NULL CONSTRAINT DF_Newsletter_Active DEFAULT 1,
    SubscribedAt DATETIME2(0)  NOT NULL CONSTRAINT DF_Newsletter_At DEFAULT SYSDATETIME(),
    UnsubscribedAt DATETIME2(0) NULL
);
GO

-- Liên hệ
CREATE TABLE dbo.ContactMessages (
    MessageId  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ContactMessages PRIMARY KEY,
    FullName   NVARCHAR(100)  NOT NULL,
    Email      VARCHAR(150)   NOT NULL,
    Phone      VARCHAR(20)    NULL,
    Subject    NVARCHAR(200)  NULL,
    Message    NVARCHAR(2000) NOT NULL,
    IsRead     BIT            NOT NULL CONSTRAINT DF_Contact_Read DEFAULT 0,
    CreatedAt  DATETIME2(0)   NOT NULL CONSTRAINT DF_Contact_Created DEFAULT SYSDATETIME()
);
GO

-- Banner / khuyến mãi (Ticker + banner "Ưu đãi cuối tháng")
CREATE TABLE dbo.Banners (
    BannerId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Banners PRIMARY KEY,
    Position    VARCHAR(20)    NOT NULL CONSTRAINT CK_Banners_Pos CHECK (Position IN ('ticker','promo')),
    Title       NVARCHAR(200)  NOT NULL,
    SubTitle    NVARCHAR(400)  NULL,
    LinkUrl     VARCHAR(255)   NULL,
    SortOrder   INT            NOT NULL CONSTRAINT DF_Banners_Sort DEFAULT 0,
    IsActive    BIT            NOT NULL CONSTRAINT DF_Banners_Active DEFAULT 1
);
GO

/* =====================================================================
   2. FUNCTIONS
   ===================================================================== */

-- Phí ship: miễn phí nếu tạm tính >= ngưỡng (mặc định 300.000đ), ngược lại 30.000đ
CREATE OR ALTER FUNCTION dbo.fn_CalcShippingFee (@Subtotal DECIMAL(18,0))
RETURNS DECIMAL(18,0)
AS
BEGIN
    DECLARE @Threshold DECIMAL(18,0) = ISNULL((SELECT TRY_CAST(SettingValue AS DECIMAL(18,0)) FROM dbo.SiteSettings WHERE SettingKey = 'FreeShipThreshold'), 300000);
    DECLARE @Fee       DECIMAL(18,0) = ISNULL((SELECT TRY_CAST(SettingValue AS DECIMAL(18,0)) FROM dbo.SiteSettings WHERE SettingKey = 'ShippingFee'), 30000);
    RETURN CASE WHEN @Subtotal <= 0 THEN 0 WHEN @Subtotal >= @Threshold THEN 0 ELSE @Fee END;
END;
GO

/* =====================================================================
   3. VIEWS
   ===================================================================== */

-- Danh sách sản phẩm cho trang chủ
CREATE OR ALTER VIEW dbo.vw_ProductList
AS
SELECT p.ProductId, p.Code, p.Name, p.ProductType, c.CategoryId, c.Name AS CategoryName, c.Slug AS CategorySlug,
       p.Price, p.OldPrice, p.DiscountPercent, p.ImageUrl, p.Badge,
       p.StockQty, p.SoldCount, p.IsBestSeller, p.CreatedAt
FROM dbo.Products p
JOIN dbo.Categories c ON c.CategoryId = p.CategoryId
WHERE p.IsActive = 1 AND c.IsActive = 1;
GO

-- Danh mục + số sản phẩm ("230 sản phẩm")
CREATE OR ALTER VIEW dbo.vw_CategoryList
AS
SELECT c.CategoryId, c.Slug, c.Name, c.ImageUrl, c.DisplayOrder,
       COUNT(p.ProductId) AS ProductCount
FROM dbo.Categories c
LEFT JOIN dbo.Products p ON p.CategoryId = c.CategoryId AND p.IsActive = 1
WHERE c.IsActive = 1
GROUP BY c.CategoryId, c.Slug, c.Name, c.ImageUrl, c.DisplayOrder;
GO

-- Sản phẩm bán chạy
CREATE OR ALTER VIEW dbo.vw_BestSellers
AS
SELECT TOP (100) PERCENT *
FROM dbo.vw_ProductList
WHERE IsBestSeller = 1
ORDER BY SoldCount DESC, ProductId;
GO

-- Thống kê hiển thị mục STATS
CREATE OR ALTER VIEW dbo.vw_SiteStats
AS
SELECT
    (SELECT COUNT(*) FROM dbo.Products  WHERE IsActive = 1)                                   AS TotalProducts,
    (SELECT COUNT(*) FROM dbo.Customers WHERE Role = 'Customer' AND IsActive = 1)             AS TotalCustomers,
    (SELECT COUNT(*) FROM dbo.Orders    WHERE Status <> 'Cancelled')                          AS TotalOrders,
    (SELECT ISNULL(SUM(Total),0) FROM dbo.Orders WHERE Status = 'Delivered')                  AS TotalRevenue,
    (SELECT TRY_CAST(SettingValue AS INT) FROM dbo.SiteSettings WHERE SettingKey = 'FoundedYear') AS FoundedYear;
GO

-- Testimonials trang chủ
CREATE OR ALTER VIEW dbo.vw_FeaturedReviews
AS
SELECT ReviewId, AuthorName, AuthorRole, AvatarEmoji, AvatarBg, Rating, Content, CreatedAt
FROM dbo.Reviews
WHERE IsApproved = 1 AND IsFeatured = 1;
GO

-- Tổng hợp đơn hàng cho admin
CREATE OR ALTER VIEW dbo.vw_OrderSummary
AS
SELECT o.OrderId, o.OrderCode, o.CreatedAt, o.Status, o.PaymentMethod, o.PaymentStatus,
       o.ReceiverName, o.Phone, o.ShippingAddress,
       o.Subtotal, o.ShippingFee, o.DiscountAmount, o.Total,
       (SELECT SUM(Quantity) FROM dbo.OrderItems oi WHERE oi.OrderId = o.OrderId) AS TotalItems,
       cu.Email AS CustomerEmail
FROM dbo.Orders o
LEFT JOIN dbo.Customers cu ON cu.CustomerId = o.CustomerId;
GO

-- Doanh thu theo tháng
CREATE OR ALTER VIEW dbo.vw_RevenueByMonth
AS
SELECT YEAR(CreatedAt) AS [Year], MONTH(CreatedAt) AS [Month],
       COUNT(*) AS Orders, SUM(Total) AS Revenue
FROM dbo.Orders
WHERE Status IN ('Confirmed','Shipping','Delivered')
GROUP BY YEAR(CreatedAt), MONTH(CreatedAt);
GO

-- Sản phẩm sắp hết hàng
CREATE OR ALTER VIEW dbo.vw_LowStock
AS
SELECT ProductId, Code, Name, StockQty
FROM dbo.Products
WHERE IsActive = 1 AND StockQty <= 10;
GO

/* =====================================================================
   4. TRIGGERS
   ===================================================================== */

CREATE OR ALTER TRIGGER dbo.trg_Products_UpdatedAt ON dbo.Products
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    UPDATE p SET UpdatedAt = SYSDATETIME()
    FROM dbo.Products p JOIN inserted i ON i.ProductId = p.ProductId;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Orders_UpdatedAt ON dbo.Orders
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    UPDATE o SET UpdatedAt = SYSDATETIME()
    FROM dbo.Orders o JOIN inserted i ON i.OrderId = o.OrderId;
END;
GO

-- Khi Admin sửa giá/hàng, tự bật badge sale nếu có OldPrice > Price
CREATE OR ALTER TRIGGER dbo.trg_Products_AutoBadge ON dbo.Products
AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    UPDATE p SET Badge = 'sale'
    FROM dbo.Products p JOIN inserted i ON i.ProductId = p.ProductId
    WHERE p.OldPrice IS NOT NULL AND p.OldPrice > p.Price AND ISNULL(p.Badge,'') <> 'sale';
END;
GO

-- Tự cập nhật trạng thái "Đã đọc" cho liên hệ trống / chuẩn hoá email
CREATE OR ALTER TRIGGER dbo.trg_Newsletter_Normalize ON dbo.NewsletterSubscribers
AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    UPDATE n SET Email = LOWER(LTRIM(RTRIM(n.Email)))
    FROM dbo.NewsletterSubscribers n JOIN inserted i ON i.SubscriberId = n.SubscriberId;
END;
GO

/* =====================================================================
   5. STORED PROCEDURES
   ===================================================================== */

/* ---------- 5.1 Sản phẩm / danh mục ---------- */

-- Lấy danh sách sản phẩm: lọc theo danh mục, từ khoá, giá, sắp xếp, phân trang
CREATE OR ALTER PROCEDURE dbo.sp_GetProducts
    @CategorySlug VARCHAR(100)  = NULL,
    @Keyword      NVARCHAR(100) = NULL,
    @MinPrice     DECIMAL(18,0) = NULL,
    @MaxPrice     DECIMAL(18,0) = NULL,
    @OnlyBestSeller BIT         = 0,
    @SortBy       VARCHAR(20)   = 'newest',   -- newest | price_asc | price_desc | bestseller
    @PageNumber   INT           = 1,
    @PageSize     INT           = 12
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize   < 1 SET @PageSize   = 12;

    SELECT *, COUNT(*) OVER() AS TotalRows
    FROM dbo.vw_ProductList
    WHERE (@CategorySlug IS NULL OR CategorySlug = @CategorySlug)
      AND (@Keyword IS NULL OR Name LIKE N'%' + @Keyword + N'%' OR ProductType LIKE N'%' + @Keyword + N'%')
      AND (@MinPrice IS NULL OR Price >= @MinPrice)
      AND (@MaxPrice IS NULL OR Price <= @MaxPrice)
      AND (@OnlyBestSeller = 0 OR IsBestSeller = 1)
    ORDER BY
        CASE WHEN @SortBy = 'price_asc'  THEN Price END ASC,
        CASE WHEN @SortBy = 'price_desc' THEN Price END DESC,
        CASE WHEN @SortBy = 'bestseller' THEN SoldCount END DESC,
        CASE WHEN @SortBy = 'newest'     THEN CreatedAt END DESC,
        ProductId
    OFFSET (@PageNumber - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetProductByCode
    @Code VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_ProductList WHERE Code = @Code;
    SELECT ImageUrl, SortOrder FROM dbo.ProductImages pi
    JOIN dbo.Products p ON p.ProductId = pi.ProductId WHERE p.Code = @Code ORDER BY SortOrder;
    SELECT TOP (20) AuthorName, Rating, Content, CreatedAt
    FROM dbo.Reviews r JOIN dbo.Products p ON p.ProductId = r.ProductId
    WHERE p.Code = @Code AND r.IsApproved = 1 ORDER BY r.CreatedAt DESC;
END;
GO

-- Thêm / sửa sản phẩm (Admin)
CREATE OR ALTER PROCEDURE dbo.sp_UpsertProduct
    @Code VARCHAR(20), @CategoryId INT, @Name NVARCHAR(200), @ProductType NVARCHAR(50) = NULL,
    @Description NVARCHAR(MAX) = NULL, @Price DECIMAL(18,0), @OldPrice DECIMAL(18,0) = NULL,
    @ImageUrl VARCHAR(255) = NULL, @Badge VARCHAR(10) = NULL, @StockQty INT = 0,
    @IsBestSeller BIT = 0, @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.Products WHERE Code = @Code)
        UPDATE dbo.Products
           SET CategoryId=@CategoryId, Name=@Name, ProductType=@ProductType, Description=@Description,
               Price=@Price, OldPrice=@OldPrice, ImageUrl=@ImageUrl, Badge=@Badge, StockQty=@StockQty,
               IsBestSeller=@IsBestSeller, IsActive=@IsActive
         WHERE Code=@Code;
    ELSE
        INSERT dbo.Products (Code, CategoryId, Name, ProductType, Description, Price, OldPrice, ImageUrl, Badge, StockQty, IsBestSeller, IsActive)
        VALUES (@Code, @CategoryId, @Name, @ProductType, @Description, @Price, @OldPrice, @ImageUrl, @Badge, @StockQty, @IsBestSeller, @IsActive);
    SELECT ProductId FROM dbo.Products WHERE Code = @Code;
END;
GO

/* ---------- 5.2 Khách hàng ---------- */

CREATE OR ALTER PROCEDURE dbo.sp_RegisterCustomer
    @Email VARCHAR(150), @PasswordHash VARCHAR(255), @FullName NVARCHAR(100), @Phone VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Email = LOWER(LTRIM(RTRIM(@Email)));
    IF EXISTS (SELECT 1 FROM dbo.Customers WHERE Email = @Email)
        THROW 50010, N'Email đã được đăng ký.', 1;
    INSERT dbo.Customers (Email, PasswordHash, FullName, Phone) VALUES (@Email, @PasswordHash, @FullName, @Phone);
    SELECT SCOPE_IDENTITY() AS CustomerId;
END;
GO

-- Backend lấy hash theo email để so sánh mật khẩu
CREATE OR ALTER PROCEDURE dbo.sp_GetCustomerForLogin
    @Email VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CustomerId, Email, PasswordHash, FullName, Role, IsActive
    FROM dbo.Customers WHERE Email = LOWER(LTRIM(RTRIM(@Email)));
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MarkLogin @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Customers SET LastLoginAt = SYSDATETIME() WHERE CustomerId = @CustomerId;
END;
GO

/* ---------- 5.3 Giỏ hàng ---------- */

CREATE OR ALTER PROCEDURE dbo.sp_GetOrCreateCart
    @SessionId VARCHAR(100) = NULL, @CustomerId INT = NULL, @CartId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @SessionId IS NULL AND @CustomerId IS NULL
        THROW 50020, N'Thiếu SessionId hoặc CustomerId.', 1;

    SELECT TOP 1 @CartId = CartId FROM dbo.Carts
    WHERE Status = 'Active'
      AND ((@CustomerId IS NOT NULL AND CustomerId = @CustomerId) OR (@CustomerId IS NULL AND SessionId = @SessionId));

    IF @CartId IS NULL
    BEGIN
        INSERT dbo.Carts (CustomerId, SessionId) VALUES (@CustomerId, CASE WHEN @CustomerId IS NULL THEN @SessionId END);
        SET @CartId = SCOPE_IDENTITY();
    END
END;
GO

-- Gộp giỏ guest vào giỏ của khách sau khi đăng nhập
CREATE OR ALTER PROCEDURE dbo.sp_MergeGuestCart
    @SessionId VARCHAR(100), @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @GuestCart INT = (SELECT CartId FROM dbo.Carts WHERE SessionId=@SessionId AND Status='Active' AND CustomerId IS NULL);
    IF @GuestCart IS NULL RETURN;
    DECLARE @UserCart INT;
    EXEC dbo.sp_GetOrCreateCart @SessionId=NULL, @CustomerId=@CustomerId, @CartId=@UserCart OUTPUT;

    BEGIN TRAN;
        MERGE dbo.CartItems AS t
        USING (SELECT ProductId, Quantity FROM dbo.CartItems WHERE CartId=@GuestCart) AS s
           ON t.CartId=@UserCart AND t.ProductId=s.ProductId
        WHEN MATCHED THEN UPDATE SET Quantity = CASE WHEN t.Quantity + s.Quantity > 99 THEN 99 ELSE t.Quantity + s.Quantity END
        WHEN NOT MATCHED THEN INSERT (CartId, ProductId, Quantity) VALUES (@UserCart, s.ProductId, s.Quantity);
        DELETE FROM dbo.Carts WHERE CartId=@GuestCart;
    COMMIT;
END;
GO

-- Nút "+" trên thẻ sản phẩm
CREATE OR ALTER PROCEDURE dbo.sp_AddToCart
    @ProductCode VARCHAR(20), @Quantity INT = 1,
    @SessionId VARCHAR(100) = NULL, @CustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @Quantity < 1 THROW 50021, N'Số lượng không hợp lệ.', 1;

    DECLARE @ProductId INT, @Stock INT;
    SELECT @ProductId = ProductId, @Stock = StockQty FROM dbo.Products WHERE Code=@ProductCode AND IsActive=1;
    IF @ProductId IS NULL THROW 50022, N'Sản phẩm không tồn tại hoặc đã ngừng bán.', 1;

    DECLARE @CartId INT;
    EXEC dbo.sp_GetOrCreateCart @SessionId, @CustomerId, @CartId OUTPUT;

    DECLARE @Current INT = ISNULL((SELECT Quantity FROM dbo.CartItems WHERE CartId=@CartId AND ProductId=@ProductId),0);
    IF @Current + @Quantity > @Stock
        THROW 50023, N'Số lượng vượt quá tồn kho.', 1;

    IF @Current = 0
        INSERT dbo.CartItems (CartId, ProductId, Quantity) VALUES (@CartId, @ProductId, @Quantity);
    ELSE
        UPDATE dbo.CartItems SET Quantity = Quantity + @Quantity WHERE CartId=@CartId AND ProductId=@ProductId;

    UPDATE dbo.Carts SET UpdatedAt = SYSDATETIME() WHERE CartId=@CartId;
    SELECT @CartId AS CartId;
END;
GO

-- Đặt số lượng cụ thể (nút +/- trong giỏ). Quantity = 0 => xoá dòng
CREATE OR ALTER PROCEDURE dbo.sp_UpdateCartItem
    @CartId INT, @ProductCode VARCHAR(20), @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ProductId INT, @Stock INT;
    SELECT @ProductId = ProductId, @Stock = StockQty FROM dbo.Products WHERE Code=@ProductCode;
    IF @ProductId IS NULL THROW 50022, N'Sản phẩm không tồn tại.', 1;

    IF @Quantity <= 0
        DELETE FROM dbo.CartItems WHERE CartId=@CartId AND ProductId=@ProductId;
    ELSE
    BEGIN
        IF @Quantity > @Stock THROW 50023, N'Số lượng vượt quá tồn kho.', 1;
        UPDATE dbo.CartItems SET Quantity=@Quantity WHERE CartId=@CartId AND ProductId=@ProductId;
    END
    UPDATE dbo.Carts SET UpdatedAt = SYSDATETIME() WHERE CartId=@CartId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RemoveCartItem
    @CartId INT, @ProductCode VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE ci FROM dbo.CartItems ci JOIN dbo.Products p ON p.ProductId=ci.ProductId
    WHERE ci.CartId=@CartId AND p.Code=@ProductCode;
END;
GO

-- Nút "Xóa hết"
CREATE OR ALTER PROCEDURE dbo.sp_ClearCart @CartId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.CartItems WHERE CartId=@CartId;
END;
GO

-- Dữ liệu cho cart drawer: danh sách + tạm tính + phí ship + thanh freeship
CREATE OR ALTER PROCEDURE dbo.sp_GetCart @CartId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.Code, p.Name, p.ImageUrl, p.ProductType, p.Price, ci.Quantity, p.Price * ci.Quantity AS LineTotal, p.StockQty
    FROM dbo.CartItems ci JOIN dbo.Products p ON p.ProductId = ci.ProductId
    WHERE ci.CartId = @CartId
    ORDER BY ci.AddedAt;

    DECLARE @Subtotal DECIMAL(18,0) = ISNULL((SELECT SUM(p.Price * ci.Quantity) FROM dbo.CartItems ci JOIN dbo.Products p ON p.ProductId=ci.ProductId WHERE ci.CartId=@CartId),0);
    DECLARE @Threshold DECIMAL(18,0) = ISNULL((SELECT TRY_CAST(SettingValue AS DECIMAL(18,0)) FROM dbo.SiteSettings WHERE SettingKey='FreeShipThreshold'),300000);
    DECLARE @Ship DECIMAL(18,0) = dbo.fn_CalcShippingFee(@Subtotal);

    SELECT ISNULL((SELECT SUM(Quantity) FROM dbo.CartItems WHERE CartId=@CartId),0) AS TotalItems,
           @Subtotal AS Subtotal,
           @Ship     AS ShippingFee,
           @Subtotal + @Ship AS Total,
           CASE WHEN @Subtotal >= @Threshold THEN 0 ELSE @Threshold - @Subtotal END AS RemainingForFreeShip,
           CASE WHEN @Threshold = 0 THEN 100 WHEN @Subtotal >= @Threshold THEN 100
                ELSE CAST(@Subtotal * 100.0 / @Threshold AS INT) END AS FreeShipPercent;
END;
GO

/* ---------- 5.4 Mã giảm giá ---------- */

CREATE OR ALTER PROCEDURE dbo.sp_ValidateCoupon
    @Code VARCHAR(30), @Subtotal DECIMAL(18,0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Id INT, @Type VARCHAR(10), @Val DECIMAL(18,0), @Min DECIMAL(18,0), @Max DECIMAL(18,0);
    SELECT @Id=CouponId, @Type=DiscountType, @Val=DiscountValue, @Min=MinOrderValue, @Max=MaxDiscount
    FROM dbo.Coupons
    WHERE Code=@Code AND IsActive=1 AND StartDate<=SYSDATETIME() AND (EndDate IS NULL OR EndDate>=SYSDATETIME())
      AND (UsageLimit IS NULL OR UsedCount<UsageLimit);

    IF @Id IS NULL THROW 50030, N'Mã giảm giá không hợp lệ hoặc đã hết hạn.', 1;
    IF @Subtotal < @Min THROW 50031, N'Đơn hàng chưa đạt giá trị tối thiểu để dùng mã.', 1;

    DECLARE @Discount DECIMAL(18,0) = CASE @Type
        WHEN 'percent'  THEN ROUND(@Subtotal * @Val / 100.0, 0)
        WHEN 'amount'   THEN @Val
        ELSE 0 END;
    IF @Max IS NOT NULL AND @Discount > @Max SET @Discount = @Max;
    IF @Discount > @Subtotal SET @Discount = @Subtotal;

    SELECT @Id AS CouponId, @Type AS DiscountType, @Discount AS DiscountAmount,
           CASE WHEN @Type='freeship' THEN 1 ELSE 0 END AS FreeShip;
END;
GO

/* ---------- 5.5 Thanh toán / Đặt hàng ---------- */

CREATE OR ALTER PROCEDURE dbo.sp_Checkout
    @CartId          INT,
    @ReceiverName    NVARCHAR(100),
    @Phone           VARCHAR(20),
    @Email           VARCHAR(150) = NULL,
    @ShippingAddress NVARCHAR(400),
    @PaymentMethod   VARCHAR(15)  = 'COD',
    @CouponCode      VARCHAR(30)  = NULL,
    @Note            NVARCHAR(500)= NULL,
    @CustomerId      INT          = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM dbo.Carts WHERE CartId=@CartId AND Status='Active')
            THROW 50040, N'Giỏ hàng không hợp lệ.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.CartItems WHERE CartId=@CartId)
            THROW 50041, N'Giỏ hàng đang trống.', 1;

        -- Khoá & kiểm tra tồn kho
        IF EXISTS (SELECT 1
                   FROM dbo.CartItems ci
                   JOIN dbo.Products p WITH (UPDLOCK, ROWLOCK) ON p.ProductId = ci.ProductId
                   WHERE ci.CartId=@CartId AND (p.IsActive=0 OR p.StockQty < ci.Quantity))
            THROW 50042, N'Có sản phẩm hết hàng hoặc không đủ số lượng.', 1;

        DECLARE @Subtotal DECIMAL(18,0) =
            (SELECT SUM(p.Price * ci.Quantity) FROM dbo.CartItems ci JOIN dbo.Products p ON p.ProductId=ci.ProductId WHERE ci.CartId=@CartId);
        DECLARE @Ship DECIMAL(18,0) = dbo.fn_CalcShippingFee(@Subtotal);
        DECLARE @Discount DECIMAL(18,0) = 0, @CouponId INT = NULL;

        IF @CouponCode IS NOT NULL
        BEGIN
            DECLARE @CV TABLE (CouponId INT, DiscountType VARCHAR(10), DiscountAmount DECIMAL(18,0), FreeShip BIT);
            INSERT @CV EXEC dbo.sp_ValidateCoupon @Code=@CouponCode, @Subtotal=@Subtotal;
            SELECT @CouponId=CouponId, @Discount=DiscountAmount, @Ship = CASE WHEN FreeShip=1 THEN 0 ELSE @Ship END FROM @CV;
            UPDATE dbo.Coupons SET UsedCount = UsedCount + 1 WHERE CouponId=@CouponId;
        END

        DECLARE @Total DECIMAL(18,0) = @Subtotal + @Ship - @Discount;
        DECLARE @Code VARCHAR(20) = 'PC' + FORMAT(SYSDATETIME(),'yyMMdd') + RIGHT('0000' + CAST(NEXT VALUE FOR dbo.seq_OrderNumber AS VARCHAR(4)), 4);

        INSERT dbo.Orders (OrderCode, CustomerId, CouponId, ReceiverName, Phone, Email, ShippingAddress,
                           Subtotal, ShippingFee, DiscountAmount, Total, PaymentMethod, Note)
        VALUES (@Code, @CustomerId, @CouponId, @ReceiverName, @Phone, @Email, @ShippingAddress,
                @Subtotal, @Ship, @Discount, @Total, @PaymentMethod, @Note);
        DECLARE @OrderId INT = SCOPE_IDENTITY();

        INSERT dbo.OrderItems (OrderId, ProductId, ProductName, UnitPrice, Quantity)
        SELECT @OrderId, p.ProductId, p.Name, p.Price, ci.Quantity
        FROM dbo.CartItems ci JOIN dbo.Products p ON p.ProductId=ci.ProductId WHERE ci.CartId=@CartId;

        -- Trừ kho, cộng đã bán
        UPDATE p SET StockQty = p.StockQty - ci.Quantity, SoldCount = p.SoldCount + ci.Quantity
        FROM dbo.Products p JOIN dbo.CartItems ci ON ci.ProductId = p.ProductId
        WHERE ci.CartId = @CartId;

        INSERT dbo.OrderStatusHistory (OrderId, OldStatus, NewStatus, Note) VALUES (@OrderId, NULL, 'Pending', N'Khách đặt hàng');

        UPDATE dbo.Carts SET Status='CheckedOut', UpdatedAt=SYSDATETIME() WHERE CartId=@CartId;

        COMMIT;
        SELECT @OrderId AS OrderId, @Code AS OrderCode, @Subtotal AS Subtotal, @Ship AS ShippingFee,
               @Discount AS DiscountAmount, @Total AS Total;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Admin cập nhật trạng thái đơn (hoàn kho khi huỷ)
CREATE OR ALTER PROCEDURE dbo.sp_UpdateOrderStatus
    @OrderId INT, @NewStatus VARCHAR(12), @Note NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Old VARCHAR(12), @PayMethod VARCHAR(15), @CouponId INT;
        SELECT @Old=Status, @PayMethod=PaymentMethod, @CouponId=CouponId FROM dbo.Orders WITH (UPDLOCK) WHERE OrderId=@OrderId;
        IF @Old IS NULL THROW 50050, N'Không tìm thấy đơn hàng.', 1;
        IF @Old IN ('Delivered','Cancelled') AND @Old <> @NewStatus
            THROW 50051, N'Đơn hàng đã kết thúc, không thể đổi trạng thái.', 1;

        UPDATE dbo.Orders
           SET Status = @NewStatus,
               PaymentStatus = CASE WHEN @NewStatus='Delivered' AND @PayMethod='COD' THEN 'Paid'
                                    WHEN @NewStatus='Cancelled' AND PaymentStatus='Paid' THEN 'Refunded'
                                    ELSE PaymentStatus END
         WHERE OrderId=@OrderId;

        IF @NewStatus='Cancelled' AND @Old <> 'Cancelled'
        BEGIN
            UPDATE p SET StockQty = p.StockQty + oi.Quantity, SoldCount = CASE WHEN p.SoldCount >= oi.Quantity THEN p.SoldCount - oi.Quantity ELSE 0 END
            FROM dbo.Products p JOIN dbo.OrderItems oi ON oi.ProductId=p.ProductId WHERE oi.OrderId=@OrderId;
            IF @CouponId IS NOT NULL UPDATE dbo.Coupons SET UsedCount = CASE WHEN UsedCount>0 THEN UsedCount-1 ELSE 0 END WHERE CouponId=@CouponId;
        END

        INSERT dbo.OrderStatusHistory (OrderId, OldStatus, NewStatus, Note) VALUES (@OrderId, @Old, @NewStatus, @Note);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- Khách theo dõi đơn hàng ("Theo dõi đơn hàng" ở footer)
CREATE OR ALTER PROCEDURE dbo.sp_TrackOrder
    @OrderCode VARCHAR(20), @Phone VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OrderId INT = (SELECT OrderId FROM dbo.Orders WHERE OrderCode=@OrderCode AND Phone=@Phone);
    IF @OrderId IS NULL THROW 50060, N'Không tìm thấy đơn hàng.', 1;
    SELECT * FROM dbo.vw_OrderSummary WHERE OrderId=@OrderId;
    SELECT ProductName, UnitPrice, Quantity, LineTotal FROM dbo.OrderItems WHERE OrderId=@OrderId;
    SELECT OldStatus, NewStatus, Note, ChangedAt FROM dbo.OrderStatusHistory WHERE OrderId=@OrderId ORDER BY ChangedAt;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetCustomerOrders
    @CustomerId INT, @PageNumber INT = 1, @PageSize INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_OrderSummary
    WHERE OrderId IN (SELECT OrderId FROM dbo.Orders WHERE CustomerId=@CustomerId)
    ORDER BY CreatedAt DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO

/* ---------- 5.6 Newsletter / Liên hệ / Đánh giá ---------- */

CREATE OR ALTER PROCEDURE dbo.sp_SubscribeNewsletter @Email VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Email = LOWER(LTRIM(RTRIM(@Email)));
    IF @Email NOT LIKE '%_@_%._%' THROW 50070, N'Email không hợp lệ.', 1;

    IF EXISTS (SELECT 1 FROM dbo.NewsletterSubscribers WHERE Email=@Email)
        UPDATE dbo.NewsletterSubscribers SET IsActive=1, UnsubscribedAt=NULL WHERE Email=@Email;
    ELSE
        INSERT dbo.NewsletterSubscribers (Email) VALUES (@Email);
    SELECT N'Đăng ký thành công!' AS Message;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Unsubscribe @Email VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.NewsletterSubscribers SET IsActive=0, UnsubscribedAt=SYSDATETIME() WHERE Email=LOWER(LTRIM(RTRIM(@Email)));
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AddContactMessage
    @FullName NVARCHAR(100), @Email VARCHAR(150), @Phone VARCHAR(20)=NULL, @Subject NVARCHAR(200)=NULL, @Message NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.ContactMessages (FullName, Email, Phone, Subject, Message) VALUES (@FullName, @Email, @Phone, @Subject, @Message);
    SELECT SCOPE_IDENTITY() AS MessageId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AddReview
    @ProductCode VARCHAR(20) = NULL, @CustomerId INT = NULL,
    @AuthorName NVARCHAR(100), @AuthorRole NVARCHAR(100) = NULL,
    @Rating TINYINT, @Content NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ProductId INT = (SELECT ProductId FROM dbo.Products WHERE Code=@ProductCode);
    INSERT dbo.Reviews (ProductId, CustomerId, AuthorName, AuthorRole, Rating, Content)   -- chờ admin duyệt
    VALUES (@ProductId, @CustomerId, @AuthorName, @AuthorRole, @Rating, @Content);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ApproveReview @ReviewId INT, @Featured BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Reviews SET IsApproved=1, IsFeatured=@Featured WHERE ReviewId=@ReviewId;
END;
GO

/* ---------- 5.7 Báo cáo cho Admin ---------- */

CREATE OR ALTER PROCEDURE dbo.sp_Report_TopProducts @Top INT = 10, @FromDate DATE = NULL, @ToDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Top) oi.ProductId, oi.ProductName, SUM(oi.Quantity) AS QtySold, SUM(oi.LineTotal) AS Revenue
    FROM dbo.OrderItems oi JOIN dbo.Orders o ON o.OrderId=oi.OrderId
    WHERE o.Status <> 'Cancelled'
      AND (@FromDate IS NULL OR o.CreatedAt >= @FromDate)
      AND (@ToDate   IS NULL OR o.CreatedAt <  DATEADD(DAY,1,@ToDate))
    GROUP BY oi.ProductId, oi.ProductName
    ORDER BY QtySold DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Report_RevenueByDay @FromDate DATE, @ToDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(CreatedAt AS DATE) AS [Date], COUNT(*) AS Orders, SUM(Total) AS Revenue
    FROM dbo.Orders
    WHERE Status IN ('Confirmed','Shipping','Delivered')
      AND CreatedAt >= @FromDate AND CreatedAt < DATEADD(DAY,1,@ToDate)
    GROUP BY CAST(CreatedAt AS DATE) ORDER BY [Date];
END;
GO

/* =====================================================================
   6. SEED DATA (khớp với trang web hiện tại)
   ===================================================================== */

INSERT dbo.SiteSettings (SettingKey, SettingValue, Description) VALUES
 ('FreeShipThreshold', '300000', N'Miễn phí giao hàng từ (đ)'),
 ('ShippingFee',       '30000',  N'Phí vận chuyển mặc định (đ)'),
 ('ReturnDays',        '30',     N'Số ngày đổi trả'),
 ('FoundedYear',       '2014',   N'Năm thành lập (12 năm kinh nghiệm)'),
 ('Hotline',           '1900 1234', NULL),
 ('ContactEmail',      'hello@papercraft.vn', NULL),
 ('Address',           N'Hà Nội, Việt Nam', NULL),
 ('WorkingHours',      N'8:00 – 20:00', NULL);
GO

INSERT dbo.Categories (Slug, Name, ImageUrl, DisplayOrder) VALUES
 ('but-muc',      N'Bút & Mực',   'butmay.png', 1),
 ('so-vo',        N'Sổ & Vở',     'sotay.png',  2),
 ('dung-cu-ve',   N'Dụng Cụ Vẽ',  'thuoc.png',  3),
 ('to-chuc-ban',  N'Tổ Chức Bàn', 'banhoc.png', 4);
GO

INSERT dbo.Products (Code, CategoryId, Name, ProductType, Price, OldPrice, ImageUrl, Badge, StockQty, SoldCount, IsBestSeller)
SELECT v.Code, c.CategoryId, v.Name, v.ProductType, v.Price, v.OldPrice, v.ImageUrl, v.Badge, v.StockQty, v.SoldCount, 1
FROM (VALUES
 ('sp1', 'but-muc',     N'Bút Máy Cao Cấp Platinum',            N'Bút viết', 450000, NULL,   'butmay.png',  'new',  120, 340),
 ('sp2', 'so-vo',       N'Sổ Da Thủ Công Handmade',             N'Sổ tay',   280000, 350000, 'sotay.png',   'sale',  80, 520),
 ('sp3', 'dung-cu-ve',  N'Bộ Bút Chì Vẽ Faber-Castell 12 Cây',  N'Bút chì',  195000, NULL,   'butchi.png',  NULL,   200, 410),
 ('sp4', 'dung-cu-ve',  N'Bộ Thước Kỹ Thuật Đa Năng',           N'Dụng cụ',  120000, NULL,   'thuoc.png',   'new',  150, 275),
 ('sp5', 'dung-cu-ve',  N'Màu Nước Chuyên Nghiệp 24 Màu',       N'Màu vẽ',   340000, 400000, 'bangmau.png', 'sale',  60, 198),
 ('sp6', 'to-chuc-ban', N'Kệ Bàn Làm Việc Gỗ Tự Nhiên',        N'Tổ chức',  620000, NULL,   'banhoc.png',  NULL,    40, 112)
) AS v(Code, CatSlug, Name, ProductType, Price, OldPrice, ImageUrl, Badge, StockQty, SoldCount)
JOIN dbo.Categories c ON c.Slug = v.CatSlug;
GO

INSERT dbo.Reviews (AuthorName, AuthorRole, AvatarEmoji, AvatarBg, Rating, Content, IsFeatured, IsApproved) VALUES
 (N'Nguyễn Thị Lan', N'Giám đốc Marketing', N'👩‍💼', '#e8e0d4', 5, N'Sổ tay da thủ công chất lượng tuyệt vời, giấy mịn và không thấm mực. Tôi đã mua tặng cả phòng làm việc!', 1, 1),
 (N'Trần Văn Hùng',  N'Họa sĩ tự do',       N'👨‍🎨', '#d4dfe0', 5, N'Bộ bút chì Faber-Castell tôi mua ở đây chính hãng, giá cả hợp lý. Giao hàng nhanh và đóng gói cẩn thận.', 1, 1),
 (N'Phạm Minh Thu',  N'Giáo viên',          N'👩‍🏫', '#dcd4e0', 4, N'Văn phòng phẩm đa dạng, phong phú. Tôi thường xuyên đặt hàng cho cơ quan và luôn hài lòng với chất lượng.', 1, 1);
GO

INSERT dbo.Banners (Position, Title, SubTitle, LinkUrl, SortOrder) VALUES
 ('ticker', N'Giao hàng miễn phí từ 300k', NULL, NULL, 1),
 ('ticker', N'Hơn 400+ sản phẩm',          NULL, NULL, 2),
 ('ticker', N'Đổi trả trong 30 ngày',      NULL, NULL, 3),
 ('ticker', N'Bảo hành chính hãng',        NULL, NULL, 4),
 ('ticker', N'Ưu đãi thành viên VIP',      NULL, NULL, 5),
 ('promo',  N'Ưu Đãi Đặc Biệt Cuối Tháng', N'Giảm tới 30% toàn bộ sản phẩm sổ tay và bút cao cấp. Chỉ trong hôm nay!', '#products', 1);
GO

INSERT dbo.Coupons (Code, Description, DiscountType, DiscountValue, MinOrderValue, MaxDiscount, EndDate, UsageLimit) VALUES
 ('WELCOME10', N'Giảm 10% đơn đầu tiên',      'percent',  10, 200000, 100000, DATEADD(YEAR,1,SYSDATETIME()), 1000),
 ('GIAM30K',   N'Giảm 30.000đ đơn từ 250k',    'amount',   30000, 250000, NULL, DATEADD(MONTH,3,SYSDATETIME()), 500),
 ('FREESHIP',  N'Miễn phí vận chuyển',         'freeship', 0, 0, NULL, DATEADD(MONTH,6,SYSDATETIME()), NULL);
GO

-- Tài khoản admin mẫu (đổi PasswordHash bằng hash thật do backend tạo)
INSERT dbo.Customers (Email, PasswordHash, FullName, Role)
VALUES ('admin@papercraft.vn', 'REPLACE_WITH_BCRYPT_HASH', N'Quản trị viên', 'Admin');
GO

/* =====================================================================
   7. PHÂN QUYỀN KHUYẾN NGHỊ (tuỳ chọn - bỏ comment nếu cần)
   ===================================================================== */
/*
CREATE LOGIN papercraft_app WITH PASSWORD = 'Doi_Mat_Khau_Manh!123';
CREATE USER  papercraft_app FOR LOGIN papercraft_app;
GRANT SELECT ON SCHEMA::dbo TO papercraft_app;
GRANT EXECUTE ON SCHEMA::dbo TO papercraft_app;
DENY  DELETE  ON SCHEMA::dbo TO papercraft_app;
*/

/* =====================================================================
   8. VÍ DỤ SỬ DỤNG
   ===================================================================== */
/*
-- Trang chủ
SELECT * FROM dbo.vw_CategoryList ORDER BY DisplayOrder;
SELECT * FROM dbo.vw_BestSellers;
SELECT * FROM dbo.vw_FeaturedReviews;
SELECT * FROM dbo.vw_SiteStats;
SELECT Title FROM dbo.Banners WHERE Position='ticker' AND IsActive=1 ORDER BY SortOrder;

-- Tìm kiếm / lọc
EXEC dbo.sp_GetProducts @Keyword = N'bút', @SortBy = 'price_asc';

-- Giỏ hàng (khách chưa đăng nhập)
EXEC dbo.sp_AddToCart @ProductCode='sp1', @Quantity=1, @SessionId='abc-123';
EXEC dbo.sp_AddToCart @ProductCode='sp2', @Quantity=2, @SessionId='abc-123';
DECLARE @CartId INT;
EXEC dbo.sp_GetOrCreateCart @SessionId='abc-123', @CartId=@CartId OUTPUT;
EXEC dbo.sp_GetCart @CartId;

-- Đặt hàng
EXEC dbo.sp_Checkout @CartId=@CartId, @ReceiverName=N'Nguyễn Văn A', @Phone='0901234567',
     @ShippingAddress=N'12 Phố Huế, Hai Bà Trưng, Hà Nội', @PaymentMethod='COD', @CouponCode='WELCOME10';

-- Admin
EXEC dbo.sp_UpdateOrderStatus @OrderId=1, @NewStatus='Confirmed', @Note=N'Đã xác nhận';
EXEC dbo.sp_Report_TopProducts @Top=5;
SELECT * FROM dbo.vw_LowStock;

-- Newsletter
EXEC dbo.sp_SubscribeNewsletter @Email='ban@example.com';
*/
GO

PRINT N'PaperCraftDB đã được tạo thành công.';
GO
SELECT *FROM dbo.Products;
SELECT *FROM dbo.Customers;
SELECT *FROM dbo.Banners;


UPDATE dbo.Products
SET ImageUrl = 'butchi02.png'
WHERE Code = 'sp3';
GO
