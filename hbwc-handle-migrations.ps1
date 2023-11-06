param(
    [string]$projectName
)


function CreatePaginationStoredProcedureMigration {
    $migrationsDirectory = "src\Infrastructure\Persistence\Migrations"

    if (-Not (Test-Path $migrationsDirectory)) {
        New-Item -Path $migrationsDirectory -ItemType Directory
    }

    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $migrationName = "AddPaginationStoredProcedure"
    $migrationFileName = "$timestamp" + "_" + "$migrationName.cs"
    $filePath = Join-Path -Path $migrationsDirectory -ChildPath $migrationFileName

    $content = @"
using Microsoft.EntityFrameworkCore.Migrations;

namespace $($projectName).Infrastructure.Persistence.Migrations;

public partial class $migrationName : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        var sql = @"
            
SET ANSI_NULLS ON

SET QUOTED_IDENTIFIER ON

CREATE OR ALTER PROCEDURE [dbo].[GenericPaginator]
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
";

        migrationBuilder.Sql(sql);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DROP PROCEDURE IF EXISTS [dbo].[GenericPaginator]");
    }
}
"@

    New-Item -Path $filePath -ItemType File -Force
    Set-Content -Path $filePath -Value $content

    return $migrationFileName
}

$infrastructureProjectPath = "src/Infrastructure/Infrastructure.csproj"
$serverProjectPath = "src/$projectName/Server/$projectName.Server.csproj"
$migrationsOutputPath = "Persistence/Migrations"

dotnet ef migrations add "InitialCreate" -c "ApplicationDbContext" -p $infrastructureProjectPath -s $serverProjectPath -o $migrationsOutputPath

$migrationFileName = CreatePaginationStoredProcedureMigration
dotnet ef migrations add $migrationFileName -p $infrastructureProjectPath -s $serverProjectPath -o $migrationsOutputPath

dotnet ef database update -c ApplicationDbContext -p $infrastructureProjectPath -s $serverProjectPath