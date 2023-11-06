USE [DemoAppV2]
GO

/****** Object:  StoredProcedure [dbo].[GenericPaginator]    Script Date: 06/11/2023 10:27:48 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER     PROCEDURE [dbo].[GenericPaginator]
    @TableName NVARCHAR(128),
    @SelectColumns NVARCHAR(MAX),
    @WhereCondition NVARCHAR(MAX) = NULL,
    @JoinCondition NVARCHAR(MAX) = NULL,
    @OrderByColumn NVARCHAR(128) = 'ID',
    @OrderByDirection NVARCHAR(4) = 'ASC',
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @FetchTotalCount BIT = 0,
    @KnownIndexes NVARCHAR(MAX) = NULL,
    @TotalCountOut INT OUTPUT
AS
BEGIN
    -- Disable count of rows affected message
    SET NOCOUNT ON;
    
    -- Declare variables
    DECLARE @SqlQuery NVARCHAR(MAX);
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Initialize dynamic SQL query
    SET @SqlQuery = 'SELECT ' + @SelectColumns + 
                    ' FROM ' + QUOTENAME(@TableName) +
                    ISNULL(' WITH (INDEX(' + @KnownIndexes + ')) ', '') +
                    ISNULL(@JoinCondition, '') +
                    ' WHERE 1=1 ' + 
                    ISNULL(' AND (' + @WhereCondition + ')', '') +
                    ' ORDER BY ' + QUOTENAME(@OrderByColumn) + ' ' + @OrderByDirection +
                    ' OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS' +
                    ' FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';
    
    -- Try executing the main query and capture any errors
    BEGIN TRY
        EXEC sp_executesql @SqlQuery;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
    
    -- Conditionally fetch the total count
    IF @FetchTotalCount = 1
    BEGIN
        SET @SqlQuery = 'SELECT @TotalCountOut = COUNT(*) FROM ' + QUOTENAME(@TableName) +
                       ISNULL(@JoinCondition, '') +
                       ' WHERE 1=1 ' + 
                       ISNULL(' AND (' + @WhereCondition + ')', '');

        -- Try executing the total count query and capture any errors
        BEGIN TRY
            EXEC sp_executesql @SqlQuery, N'@TotalCountOut INT OUTPUT', @TotalCountOut=@TotalCountOut OUTPUT;
        END TRY
        BEGIN CATCH
            THROW;
        END CATCH
    END
    ELSE
    BEGIN
	-- Indicator that total count was not fetched
        SET @TotalCountOut = -1; 
    END
END

GO


