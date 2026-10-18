/* =====================================================================
   PaperCraft - Bổ sung: xác nhận đã nhận chuyển khoản
   Chạy SAU database.sql. Có thể gọi thủ công (Admin) hoặc từ webhook
   của dịch vụ đối soát ngân hàng (SePay, Casso...).
   ===================================================================== */
USE PaperCraftDB;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MarkOrderPaid
    @OrderCode VARCHAR(20),
    @Amount    DECIMAL(18,0) = NULL,      -- số tiền thực nhận (nếu có) để đối chiếu
    @Note      NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @OrderId INT, @Total DECIMAL(18,0), @PayStatus VARCHAR(10), @Status VARCHAR(12), @Method VARCHAR(15);
        SELECT @OrderId = OrderId, @Total = Total, @PayStatus = PaymentStatus, @Status = Status, @Method = PaymentMethod
        FROM dbo.Orders WITH (UPDLOCK) WHERE OrderCode = @OrderCode;

        IF @OrderId IS NULL               THROW 50050, N'Không tìm thấy đơn hàng.', 1;
        IF @Method <> 'BankTransfer'      THROW 50052, N'Đơn hàng không thanh toán bằng chuyển khoản.', 1;
        IF @Status = 'Cancelled'          THROW 50053, N'Đơn hàng đã huỷ.', 1;
        IF @Amount IS NOT NULL AND @Amount < @Total
                                          THROW 50054, N'Số tiền chuyển khoản chưa đủ.', 1;

        IF @PayStatus = 'Paid' BEGIN COMMIT; RETURN; END     -- đã ghi nhận trước đó

        DECLARE @NewStatus VARCHAR(12) = CASE WHEN @Status = 'Pending' THEN 'Confirmed' ELSE @Status END;

        UPDATE dbo.Orders SET PaymentStatus = 'Paid', Status = @NewStatus WHERE OrderId = @OrderId;

        INSERT dbo.OrderStatusHistory (OrderId, OldStatus, NewStatus, Note)
        VALUES (@OrderId, @Status, @NewStatus, ISNULL(@Note, N'Đã nhận chuyển khoản'));

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* Ví dụ: EXEC dbo.sp_MarkOrderPaid @OrderCode = 'PC2610180001', @Amount = 450000; */
