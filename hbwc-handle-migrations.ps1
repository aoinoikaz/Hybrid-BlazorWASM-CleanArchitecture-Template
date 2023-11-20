param(
    [string]$projectName
)


function ModifyPaginationStoredProcedure {
    $migrationsDirectory = "src\Infrastructure\Persistence\Migrations"
    $specificMigrationName = "AddPaginationStoredProcedure"  # The specific name of the migration
    $migrationFiles = Get-ChildItem -Path $migrationsDirectory -Filter "*_$specificMigrationName.cs"

    if ($migrationFiles.Count -eq 0) {
        Write-Host "Migration file $specificMigrationName not found."
        return
    }

    $migrationFile = $migrationFiles | Select-Object -First 1
    $filePath = Join-Path -Path $migrationsDirectory -ChildPath $migrationFile.Name

    $content = @"
using Microsoft.EntityFrameworkCore.Migrations;

namespace $projectName.Infrastructure.Persistence.Migrations;

public partial class $specificMigrationName : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        var sql = @"
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GenericPaginator]') AND type in (N'P', N'PC'))
BEGIN
    EXEC('CREATE PROCEDURE [dbo].[GenericPaginator]
    @SchemaName NVARCHAR(128),
    @TableName NVARCHAR(128),
    @SelectColumns NVARCHAR(MAX),
    @WhereCondition NVARCHAR(MAX) = NULL,
    @JoinCondition NVARCHAR(MAX) = NULL,
    @OrderByColumn NVARCHAR(128),
    @OrderByDirection NVARCHAR(4) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @KnownIndexes NVARCHAR(MAX) = NULL,
	@FetchTotalCount BIT = 1,
    @TotalCountOut INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SqlQuery NVARCHAR(MAX);
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Constructing the FROM clause with separate QUOTENAME calls for schema and table
    SET @SqlQuery = 'SELECT ' + @SelectColumns + 
                    ' FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) +
                    ISNULL(' WITH (INDEX(' + @KnownIndexes + ')) ', '') +
                    ISNULL(@JoinCondition, '') +
                    ' WHERE 1=1 ' + 
                    ISNULL(' AND (' + @WhereCondition + ')', '') +
                    ' ORDER BY ' + QUOTENAME(@OrderByColumn) + ' ' + ISNULL(@OrderByDirection, 'ASC') +
                    ' OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS' +
                    ' FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

	PRINT @SqlQuery

    BEGIN TRY
        EXEC sp_executesql @SqlQuery;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH

	IF @FetchTotalCount = 1
	BEGIN
		-- Constructing the COUNT query with separate QUOTENAME calls for schema and table
		SET @SqlQuery = 'SELECT @TotalCountOut = COUNT(*) FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) +
						ISNULL(@JoinCondition, '') +
						' WHERE 1=1 ' + 
						ISNULL(' AND (' + @WhereCondition + ')', '');


		PRINT @SqlQuery

		BEGIN TRY
			EXEC sp_executesql @SqlQuery, N'@TotalCountOut INT OUTPUT', @TotalCountOut=@TotalCountOut OUTPUT;
		END TRY
		BEGIN CATCH
			THROW;
		END CATCH
	END
END')
END";
        migrationBuilder.Sql(sql);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DROP PROCEDURE IF EXISTS [dbo].[GenericPaginator]");
    }
}
"@ 
    Set-Content -Path $filePath -Value $content -Force
}


$infrastructureProjectPath = "src/Infrastructure/Infrastructure.csproj"
$serverProjectPath = "src/$projectName/Server/$projectName.Server.csproj"
$migrationsOutputPath = "Persistence/Migrations"

dotnet ef migrations add "InitialCreate" -c "ApplicationDbContext" -p $infrastructureProjectPath -s $serverProjectPath -o $migrationsOutputPath
dotnet ef migrations add "AddPaginationStoredProcedure" -c "ApplicationDbContext" -p $infrastructureProjectPath -s $serverProjectPath -o $migrationsOutputPath

ModifyPaginationStoredProcedure

dotnet build $infrastructureProjectPath
dotnet ef database update -c ApplicationDbContext -p $infrastructureProjectPath -s $serverProjectPath --verbose