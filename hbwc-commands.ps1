param (
    [string]$projectName,
	[string]$databaseType,
	[string]$instanceName
)


function UpdateCurrentUserServiceNamespace 
{
    $filePath = "src\$projectName\Server\Services\CurrentUserService.cs"
    $content = Get-Content -Path $filePath -Raw
    $modifiedContent = $content -replace 'namespace .+\.WebUI\.Services;', "namespace $projectName.Server.Services;"
    Set-Content -Path $filePath -Value $modifiedContent
}


function UpdateControllerNamespaces 
{
    $files = Get-ChildItem -Path "src\$projectName\Server\Controllers\*.cs"
    
    foreach ($file in $files) {
        $content = Get-Content -Path $file.FullName -Raw
        $modifiedContent = $content -replace 'namespace .+\.WebUI\.Controllers;', "namespace $projectName.Server.Controllers;"
        Set-Content -Path $file.FullName -Value $modifiedContent
    }
}


function UpdateApiControllerBaseUsingStatement 
{
    $filePath = "src\$projectName\Server\Controllers\ApiControllerBase.cs"
    $content = Get-Content -Path $filePath -Raw
    $modifiedContent = $content -replace 'using .+\.WebUI\.Filters;', "using $projectName.Server.Filters;"
    Set-Content -Path $filePath -Value $modifiedContent
}


function UpdateApiExceptionFilterAttributeNamespace 
{
    $filePath = "src\$projectName\Server\Filters\ApiExceptionFilterAttribute.cs"
    $content = Get-Content -Path $filePath -Raw
    $modifiedContent = $content -replace 'namespace .+\.WebUI\.Filters;', "namespace $projectName.Server.Filters;"
    Set-Content -Path $filePath -Value $modifiedContent
}


function UpdateAppSettingsJson()
{
	if ($databaseType -eq "sql") 
	{
		$useInMemoryDatabase = $false
		$connectionString = "Server=$($instanceName); Database=$($projectName); Trusted_Connection=True; MultipleActiveResultSets=True; TrustServerCertificate=True;"
	} 
	else 
	{
		$useInMemoryDatabase = $true
		$connectionString = "Server=(localdb)\\mssqllocaldb; Database=$($projectName); Trusted_Connection=True; MultipleActiveResultSets=True;"
	}
	
	$useInMemoryDatabaseString = $useInMemoryDatabase.ToString().ToLower()

	$fullPath = "src\$($projectName)\Server\appsettings.json"

	$content = @"
{
 "UseInMemoryDatabase": "$($useInMemoryDatabaseString)",
  "ConnectionStrings": {
    "DefaultConnection": "$($connectionString)"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.Hosting.Lifetime": "Information"
    }
  },
  "IdentityServer": {
    "Clients": {
      "$($projectName).Client": {
        "Profile": "IdentityServerSPA"
      }
    }
  },
  "AllowedHosts": "*"
}
"@

	$appSettingsPath = ".\src\$($projectName)\Server\appsettings.json"

	Set-Content -Path $appSettingsPath -Value $content
}


function UpdateServerProgramCs() 
{
    $filePath = "src\$($projectName)\Server\Program.cs"
    $content = @"
using $($projectName).Server.Services;
using $($projectName).Application.Common.Interfaces;
using $($projectName).Infrastructure.Persistence;
using $($projectName).Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddScoped<ICurrentUserService, CurrentUserService>();
builder.Services.AddApplicationServices();
builder.Services.AddInfrastructureServices(builder.Configuration);

builder.Services.AddControllersWithViews();
builder.Services.AddRazorPages();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseWebAssemblyDebugging();

    using (var scope = app.Services.CreateScope())
    {
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<ApplicationDbContextInitialiser>>();

        var initialiser = new ApplicationDbContextInitialiser(logger, context, userManager, roleManager);
        // TODO: what kind of flow do we want here, for manual trigger of existing migration? if any
        //await initialiser.InitialiseAsync();
        await initialiser.SeedAsync();
    }
}
else
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseBlazorFrameworkFiles();
app.UseStaticFiles();

app.UseRouting();

app.MapRazorPages();
app.MapControllers();
app.MapFallbackToFile("index.html");

app.Run();
"@
    Set-Content -Path $filePath -Value $content
}


function UpdateClientProgramCs() 
{
    # Define the file path
    $filePath = "src\$projectName\Client\Program.cs"

    # Check if the file exists
    if (Test-Path $filePath) 
	{
        # Read the existing content into an array
        $content = Get-Content $filePath

        # Define the line to be added for services
        $lineToAdd = "builder.Services.AddClientServices(builder.Configuration, builder.HostEnvironment);"

        # Define the line that should come after
        $lineToFind = "await builder.Build().RunAsync();"

        # Add the namespace to the top
        $namespaceToAdd = "using $($projectName).Client.Common.Configuration;"
        $content = @($namespaceToAdd) + $content

        # Find the index of the line for builder.build
        $index = [array]::IndexOf($content, $lineToFind)

        if ($index -ne -1) 
		{
            # Insert the new line just before
            $newContent = @($content[0..($index - 1)], $lineToAdd, $content[$index..($content.Length - 1)])

            # Write the updated content back to the file
            Set-Content -Path $filePath -Value $newContent
        } 
		else 
		{
            Write-Host "Line to find '$lineToFind' not found in the file."
        }
    }
    else {
        Write-Host "File $filePath not found."
    }
}


function CreateIProductApi() 
{
    $directory = "src\$projectName\Client\Common\Interfaces"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "IProductApi.cs"

    $content = @"
using Refit;
using $($projectName).Shared.Common.Models;
using $($projectName).Shared.DTOs;

namespace $($projectName).Client.Common.Interfaces;

public interface IProductApi : IPaginate<ProductDto>
{
    [Get("/api/Products")]
    Task<IEnumerable<ProductDto>> GetProductsAsync();

    [Get("/api/Products/{id}")]
    Task<Result<ProductDto>> GetProductByIdAsync(int id);

    [Post("/api/Products")]
    Task<Result<int>> CreateProductAsync(ProductDto product);

    [Put("/api/Products/{id}")]
    Task<Result> UpdateProductAsync(int id, ProductDto product);

    [Delete("/api/Products/{id}")]
    Task<Result> DeleteProductAsync(int id);

    [Get("/api/Products/Categories")]
    Task<Result<List<string>>> GetAllCategoriesAsync();
}
"@
    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}


function CreatePaginatedList() 
{
    $directory = "src\Shared\Common\Models"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "PaginatedList.cs"

    $content = @"
namespace $($projectName).Shared.Common.Models;

public class PaginatedList<T>
{
    public IReadOnlyCollection<T> Items { get; }
    public int PageNumber { get; }
    public int PageSize { get; }
    public int TotalPages { get; }
    public int TotalCount { get; }

    public PaginatedList(IReadOnlyCollection<T> items, int totalCount, int pageNumber, int pageSize)
    {
        PageNumber = pageNumber;
        PageSize = pageSize;
        TotalCount = totalCount;
        TotalPages = (int)Math.Ceiling(totalCount / (double)pageSize);
        Items = items;
    }

    public bool HasPreviousPage => PageNumber > 1;
    public bool HasNextPage => PageNumber < TotalPages;
}
"@
    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}


function CreateIPaginate() 
{
    $directory = "src\$projectName\Client\Common\Interfaces"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "IPaginate.cs"

    $content = @"
using Refit;
using $($projectName).Shared.Common.Models;

namespace $($projectName).Client.Common.Interfaces;

public interface IPaginate<TDto>
{
    [Get("/api/Products/Paginated")]
    Task<PaginatedList<TDto>> GetPaginatedAsync(int pageNumber, int pageSize);
}
"@
    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}


function CreateIPaginationService() 
{
    $directory = "src\Application\Common\Interfaces"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "IPaginationService.cs"

    $content = @"
using $($projectName).Shared.Common.Models;

namespace $($projectName).Application.Common.Interfaces;

public interface IPaginationService
{
    Task<PaginatedList<T>> GetPaginatedDataAsync<T>(
        string tableName,
        string selectColumns,
        int pageNumber,
        int pageSize,
        string? whereCondition = null,
        string? joinCondition = null,
        string? orderByColumn = "ID",
        string? orderByDirection = "ASC",
        bool fetchTotalCount = false,
        string? knownIndexes = null) where T : new();
}
"@
    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}


function CreatePaginationService() 
{
    $directory = "src\Infrastructure\Services"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "PaginationService.cs"

    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Infrastructure.Persistence;
using $($projectName).Shared.Common.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;
using System.Linq.Expressions;
using System.Reflection;
using System.Collections.Concurrent;

namespace $($projectName).Infrastructure.Services;

public class PaginationService : IPaginationService
{
    private readonly ApplicationDbContext _dbContext;

 #pragma warning disable IDE1006 // Compiler complains about the lowercase p in propertySetterCache
    private static readonly ConcurrentDictionary<PropertyInfo, Delegate> propertySetterCache = new();

    public PaginationService(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<PaginatedList<T>> GetPaginatedDataAsync<T>(
            string tableName,
            string selectColumns,
            int pageNumber,
            int pageSize,
            string? whereCondition = null,
            string? joinCondition = null,
            string? orderByColumn = "ID",
            string? orderByDirection = "ASC",
            bool fetchTotalCount = true,
            string? knownIndexes = null) where T : new()
    {
        try
        {
            var items = new List<T>();

            using var command = _dbContext.Database.GetDbConnection().CreateCommand();
            command.CommandType = CommandType.StoredProcedure;
            command.CommandText = "GenericPaginator";

            command.Parameters.Add(new SqlParameter("@TableName", tableName));
            command.Parameters.Add(new SqlParameter("@SelectColumns", selectColumns));
            command.Parameters.Add(new SqlParameter("@WhereCondition", whereCondition ?? (object)DBNull.Value));
            command.Parameters.Add(new SqlParameter("@JoinCondition", joinCondition ?? (object)DBNull.Value));
            command.Parameters.Add(new SqlParameter("@OrderByColumn", orderByColumn));
            command.Parameters.Add(new SqlParameter("@OrderByDirection", orderByDirection));
            command.Parameters.Add(new SqlParameter("@PageNumber", pageNumber));
            command.Parameters.Add(new SqlParameter("@PageSize", pageSize));
            command.Parameters.Add(new SqlParameter("@FetchTotalCount", fetchTotalCount));
            command.Parameters.Add(new SqlParameter("@KnownIndexes", knownIndexes ?? (object)DBNull.Value));

            SqlParameter totalCountParam = new("@TotalCountOut", SqlDbType.Int) { Direction = ParameterDirection.Output };
            command.Parameters.Add(totalCountParam);

            if (_dbContext.Database.GetDbConnection().State != ConnectionState.Open)
            {
                await _dbContext.Database.GetDbConnection().OpenAsync();
            }

            using (var result = await command.ExecuteReaderAsync())
            {
                while (await result.ReadAsync())
                {
                    var item = new T();
                    for (var i = 0; i < result.FieldCount; i++)
                    {
                        var propertyName = result.GetName(i);
                        var property = typeof(T).GetProperty(propertyName);
                        if (property != null)
                        {
                            var propertySetter = GetCachedPropertySetter<T>(property);
                            var value = result.IsDBNull(i) ? null : result.GetValue(i);

                            if (item != null && value != null)
                            { 
                                propertySetter(item, value);
                            }
                        }
                    }
                    items.Add(item);
                }
            }

            int totalCount = totalCountParam.Value != DBNull.Value ? Convert.ToInt32(totalCountParam.Value) : -1;
            return new PaginatedList<T>(items, totalCount, pageNumber, pageSize);
        }
        catch (SqlException sqlEx)
        {
            Console.WriteLine($"SQL Error: {sqlEx.Message}");
            throw;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"An error occurred: {ex.Message}");
            throw;
        }
    }

    private static Action<T, object> CreatePropertySetter<T>(PropertyInfo propertyInfo)
    {
        var targetExp = Expression.Parameter(typeof(T), "target");
        var valueExp = Expression.Parameter(typeof(object), "value");
        var convertValueExp = Expression.Convert(valueExp, propertyInfo.PropertyType);
        var propertySetterExp = Expression.Lambda<Action<T, object>>(
            Expression.Assign(
                Expression.Property(targetExp, propertyInfo),
                convertValueExp
            ),
            targetExp,
            valueExp
        );
        return propertySetterExp.Compile();
    }

    public static Action<T, object> GetCachedPropertySetter<T>(PropertyInfo propertyInfo)
    {
        return (Action<T, object>)propertySetterCache.GetOrAdd(
            propertyInfo,
            (pi) => CreatePropertySetter<T>(pi)
        );
    }
}
"@
    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}


function CreateGenericPaginatorRazor() 
{
    $directory = "src\$($projectName)\Client\Pages"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "GenericPaginator.razor"

    $content = @"
@using $($projectName).Shared.Common.Models;

@namespace $($projectName).Client.Pages

@typeparam TItem

@code {
    [Parameter] public PaginatedList<TItem>? PaginatedData { get; set; }
    [Parameter] public EventCallback<int> OnPageChanged { get; set; }

    private async Task SetPage(int page)
    {
        if (PaginatedData != null && page >= 1 && page <= PaginatedData.TotalPages)
        {
            await OnPageChanged.InvokeAsync(page);
        }
    }
}

@if (PaginatedData != null && PaginatedData.TotalPages > 1)
{
    <nav aria-label="Page navigation">
        <ul class="pagination">
            <!-- First Page Button -->
            <li class="page-item @(PaginatedData.PageNumber == 1 ? "disabled" : "")">
                <button class="page-link" @onclick="() => SetPage(1)">First</button>
            </li>

            <!-- Previous Page Button -->
            <li class="page-item @(PaginatedData.HasPreviousPage ? "" : "disabled")">
                <button class="page-link" @onclick="() => SetPage(PaginatedData.PageNumber - 1)">Previous</button>
            </li>

            <!-- Page Numbers (here you might want to optimize the number of page numbers to show) -->
            <!-- ... -->
            <!-- Next Page Button -->
            <li class="page-item @(PaginatedData.HasNextPage ? "" : "disabled")">
                <button class="page-link" @onclick="() => SetPage(PaginatedData.PageNumber + 1)">Next</button>
            </li>

            <!-- Last Page Button -->
            <li class="page-item @(PaginatedData.PageNumber == PaginatedData.TotalPages ? "disabled" : "")">
                <button class="page-link" @onclick="() => SetPage(PaginatedData.TotalPages)">Last</button>
            </li>
        </ul>
    </nav>
}
"@
    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}



function GenerateICsvBuilder()
{
    $fullPath = "src\Application\Common\Interfaces\ICsvFileBuilder.cs"

	$newContent = @"
using $($projectName).Shared.DTOs;

namespace $($projectName).Application.Common.Interfaces;

public interface ICsvFileBuilder
{
    byte[] BuildFile<T>(IEnumerable<T> records);
}

"@

	Set-Content -Path $fullPath -Value $newContent
}


function GenerateCsvBuilder()
{
    $fullPath = "src\Infrastructure\Files\CsvFileBuilder.cs"

	$newContent = @"
using CsvHelper;
using System.Globalization;
using $($projectName).Application.Common.Interfaces;

namespace $($projectName).Infrastructure.Files;

public class CsvFileBuilder : ICsvFileBuilder
{
    public byte[] BuildFile<T>(IEnumerable<T> records)
    {
        using var memoryStream = new MemoryStream();
        using (var streamWriter = new StreamWriter(memoryStream))
        {
            using var csvWriter = new CsvWriter(streamWriter, CultureInfo.InvariantCulture);

            // If you have specific class maps for different entities, 
            // you might need a mechanism to determine and apply them here.

            csvWriter.WriteRecords(records);
        }

        return memoryStream.ToArray();
    }
}
"@

	Set-Content -Path $fullPath -Value $newContent
}



function CreateResultClass() 
{
    $directory = "src\Shared\Common\Models"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "Result.cs"

    $content = @"
namespace $($projectName).Shared.Common.Models;

public class Result<T>
{
    private IDictionary<string, IEnumerable<string>>? _fieldErrors;
    private IEnumerable<string>? _generalErrors;

    public T? Data { get; set; }
    public bool Succeeded { get; set; }

    public IDictionary<string, IEnumerable<string>>? FieldErrors 
    {
        get => _fieldErrors ??= new Dictionary<string, IEnumerable<string>>();
        set => _fieldErrors = value;
    }

    public IEnumerable<string>? GeneralErrors 
    {
        get => _generalErrors ??= new List<string>();
        set => _generalErrors = value;
    }

    public Result() { }

    public Result(T? data, bool succeeded)
    {
        Data = data;
        Succeeded = succeeded;
    }

    public static Result<T> Success(T data)
    {
        return new Result<T>(data, true);
    }

    public static Result<T> Failure(T? data, IDictionary<string, IEnumerable<string>>? fieldErrors = null, IEnumerable<string>? generalErrors = null)
    {
        return new Result<T>(data, false)
        {
            FieldErrors = fieldErrors,
            GeneralErrors = generalErrors
        };
    }
}


public class Result
{
	private IDictionary<string, IEnumerable<string>>? _fieldErrors;
	private IEnumerable<string>? _generalErrors;

	public bool Succeeded { get; set; }

	public IDictionary<string, IEnumerable<string>>? FieldErrors 
	{
		get => _fieldErrors ??= new Dictionary<string, IEnumerable<string>>();
		set => _fieldErrors = value;
	}

	public IEnumerable<string>? GeneralErrors 
	{
		get => _generalErrors ??= new List<string>();
		set => _generalErrors = value;
	}

	public Result() { }

	public Result(bool succeeded)
	{
		Succeeded = succeeded;
	}

	public static Result Success()
	{
		return new Result(true);
	}

	public static Result Failure(IDictionary<string, IEnumerable<string>>? fieldErrors = null, IEnumerable<string>? generalErrors = null)
	{
		return new Result(false)
		{
			FieldErrors = fieldErrors,
			GeneralErrors = generalErrors
		};
	}
}
"@

    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}



function CreateProductDtoClass() 
{
    $directory = "src\Shared\DTOs"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "ProductDto.cs"
	
    $content = @"
namespace $($projectName).Shared.DTOs;

public class ProductDto
{
    public int Id { get; set; }
    public string? Name { get; set; }
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public int StockQuantity { get; set; }
    public string? SKU { get; set; }
    public bool IsAvailable => StockQuantity > 0;
    public string? Category { get; set; }
    public string? Brand { get; set; }
    public DateTime? ReleaseDate { get; set; }
    public string? ImageUrl { get; set; }
}
"@
    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}


function CreateProductCreatedEvent() 
{
    $directory = "src\Domain\Events"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "ProductCreatedEvent.cs"
	
    $content = @"
namespace $($projectName).Domain.Events;

public class ProductCreatedEvent : BaseEvent
{
    public ProductCreatedEvent(Product product)
    {
        this.Product = product;
    }

    public Product Product { get; }
}
"@
    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}


function CreateConfigureClientServices() 
{
    $directory = "src\$projectName\Client\Common\Configuration"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "ConfigureClientServices.cs"

    $content = @"
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using System;
using $($projectName).Client.Common.Interfaces;
using Refit;

namespace $($projectName).Client.Common.Configuration;

public static class ConfigureClientServices
{
	public static IServiceCollection AddClientServices(this IServiceCollection services, IConfiguration configuration, IWebAssemblyHostEnvironment environment)
	{
		services.AddHttpClient("ServerAPI", client =>
		{
			client.BaseAddress = new Uri(environment.BaseAddress);
			client.Timeout = TimeSpan.FromMinutes(5);
		});

		services.AddRefitClient<IProductApi>()
			.ConfigureHttpClient(client =>
			{
				client.BaseAddress = new Uri(environment.BaseAddress);
				client.Timeout = TimeSpan.FromMinutes(5);
			});

		return services;
	}
}

"@
    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}



function CreateInfrastructureConfigureServices() 
{
    $directory = "src\Infrastructure"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "ConfigureServices.cs"

    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Infrastructure.Files;
using $($projectName).Infrastructure.Identity;
using $($projectName).Infrastructure.Persistence;
using $($projectName).Infrastructure.Persistence.Interceptors;
using $($projectName).Infrastructure.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Microsoft.Extensions.DependencyInjection;

public static class ConfigureServices
{
    public static IServiceCollection AddInfrastructureServices(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddScoped<AuditableEntitySaveChangesInterceptor>();

        if (configuration.GetValue<bool>("UseInMemoryDatabase"))
        {
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseInMemoryDatabase("DemoAppV2Db"));
        }
        else
        {
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseSqlServer(configuration.GetConnectionString("DefaultConnection"),
                    builder => builder.MigrationsAssembly(typeof(ApplicationDbContext).Assembly.FullName)));
        }

        services.AddScoped<IApplicationDbContext>(provider => provider.GetRequiredService<ApplicationDbContext>());

        services.AddScoped<ApplicationDbContextInitialiser>();

        services
            .AddDefaultIdentity<ApplicationUser>()
            .AddRoles<IdentityRole>()
            .AddEntityFrameworkStores<ApplicationDbContext>();

        services.AddIdentityServer()
            .AddApiAuthorization<ApplicationUser, ApplicationDbContext>();

        services.AddTransient<IDateTime, DateTimeService>();
        services.AddTransient<ICsvFileBuilder, CsvFileBuilder>();
        services.AddTransient<IIdentityService, IdentityService>();
        services.AddTransient<IPaginationService, PaginationService>();

        services.AddAuthentication()
            .AddIdentityServerJwt();

        services.AddAuthorization(options =>
            options.AddPolicy("CanPurge", policy => policy.RequireRole("Administrator")));

        return services;
    }
}
"@
    Set-Content -Path $filePath -Value $content
}


function CreateIIdentityService() 
{
    $directory = "src\Application\Common\Interfaces"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "IIdentityService.cs"

    $content = @"
using $($projectName).Shared.Common.Models;

namespace $($projectName).Application.Common.Interfaces;

public interface IIdentityService
{
    Task<string?> GetUserNameAsync(string userId);

    Task<bool> IsInRoleAsync(string userId, string role);

    Task<bool> AuthorizeAsync(string userId, string policyName);

    Task<(Result Result, string UserId)> CreateUserAsync(string userName, string password);

    Task<Result> DeleteUserAsync(string userId);
}
"@
    Set-Content -Path $filePath -Value $content
}


function CreateMappingExtensions() 
{
    $directory = "src\Application\Common\Mappings"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "MappingExtensions.cs"

    $content = @"
using AutoMapper;
using AutoMapper.QueryableExtensions;
using Microsoft.EntityFrameworkCore;

namespace $($projectName).Application.Common.Mappings;

public static class MappingExtensions
{
    /*
    public static Task<PaginatedList<TDestination>> PaginatedListAsync<TDestination>(this IQueryable<TDestination> queryable, int pageNumber, int pageSize) where TDestination : class
        => PaginatedList<TDestination>.CreateAsync(queryable.AsNoTracking(), pageNumber, pageSize);
    */
    public static Task<List<TDestination>> ProjectToListAsync<TDestination>(this IQueryable queryable, IConfigurationProvider configuration) where TDestination : class
        => queryable.ProjectTo<TDestination>(configuration).AsNoTracking().ToListAsync();
}
"@
    Set-Content -Path $filePath -Value $content
}


function CreateIdentityResultExtensions() 
{
    $directory = "src\Infrastructure\Identity"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "IdentityResultExtensions.cs"

    $content = @"
using Microsoft.AspNetCore.Identity;
using $($projectName).Shared.Common.Models;

namespace $($projectName).Infrastructure.Identity;

public static class IdentityResultExtensions
{
    public static Result ToApplicationResult(this IdentityResult result)
    {
        return result.Succeeded
            ? Result.Success()
            : Result.Failure(generalErrors: result.Errors.Select(e => e.Description));
    }
}
"@
    Set-Content -Path $filePath -Value $content
}


function CreateIdentityService() 
{
    $directory = "src\Infrastructure\Identity"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "IdentityService.cs"

    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Shared.Common.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace $($projectName).Infrastructure.Identity;

public class IdentityService : IIdentityService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IUserClaimsPrincipalFactory<ApplicationUser> _userClaimsPrincipalFactory;
    private readonly IAuthorizationService _authorizationService;

    public IdentityService(
        UserManager<ApplicationUser> userManager,
        IUserClaimsPrincipalFactory<ApplicationUser> userClaimsPrincipalFactory,
        IAuthorizationService authorizationService)
    {
        _userManager = userManager;
        _userClaimsPrincipalFactory = userClaimsPrincipalFactory;
        _authorizationService = authorizationService;
    }

    public async Task<string?> GetUserNameAsync(string userId)
    {
        var user = await _userManager.Users.FirstAsync(u => u.Id == userId);

        return user.UserName;
    }

    public async Task<(Result Result, string UserId)> CreateUserAsync(string userName, string password)
    {
        var user = new ApplicationUser
        {
            UserName = userName,
            Email = userName,
        };

        var result = await _userManager.CreateAsync(user, password);

        return (result.ToApplicationResult(), user.Id);
    }

    public async Task<bool> IsInRoleAsync(string userId, string role)
    {
        var user = _userManager.Users.SingleOrDefault(u => u.Id == userId);

        return user != null && await _userManager.IsInRoleAsync(user, role);
    }

    public async Task<bool> AuthorizeAsync(string userId, string policyName)
    {
        var user = _userManager.Users.SingleOrDefault(u => u.Id == userId);

        if (user == null)
        {
            return false;
        }

        var principal = await _userClaimsPrincipalFactory.CreateAsync(user);

        var result = await _authorizationService.AuthorizeAsync(principal, policyName);

        return result.Succeeded;
    }

    public async Task<Result> DeleteUserAsync(string userId)
    {
        var user = _userManager.Users.SingleOrDefault(u => u.Id == userId);

        return user != null ? await DeleteUserAsync(user) : Result.Success();
    }

    public async Task<Result> DeleteUserAsync(ApplicationUser user)
    {
        var result = await _userManager.DeleteAsync(user);

        return result.ToApplicationResult();
    }
}
"@
    Set-Content -Path $filePath -Value $content
}


function CreateProductsController() 
{
    $dirPath = "src\$($projectName)\Server\Controllers"
    $filePath = "$dirPath\ProductsController.cs"
    
    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }
    
    if (Test-Path $filePath) 
	{
        Write-Host "File $filePath already exists."
        return
    }

    $controllerContent = @"
using $($projectName).Application.Features.Products.Queries;
using $($projectName).Application.Features.Products.Commands;
using $($projectName).Application.Common.Exceptions;
using $($projectName).Shared.DTOs;
using $($projectName).Shared.Common.Models;
using $($projectName).Domain.Enums;
using Microsoft.AspNetCore.Mvc;

namespace $($projectName).Server.Controllers;

public class ProductsController : ApiControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IEnumerable<ProductDto>>> GetAll()
    {
        return Ok(await Mediator.Send(new GetAllProductsQuery()));
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ProductDto>> GetById(int id)
    {
        try
        {
            var product = await Mediator.Send(new GetProductByIdQuery { Id = id });

            return product != null ? (ActionResult<ProductDto>)Ok(product) : (ActionResult<ProductDto>)NotFound();
        }
        catch (NotFoundException)
        {
            return NotFound();
        }
    }


    [HttpPost]
    public async Task<ActionResult<Result<int>>> Create([FromBody] CreateProductCommand command)
    {
        var result = await Mediator.Send(command);

        return result.Succeeded
            ? (ActionResult<Result<int>>)Ok(result)
            : result.FieldErrors != null && result.FieldErrors.Any()
                ? (ActionResult<Result<int>>)BadRequest(result)
                : (ActionResult<Result<int>>)StatusCode(500, result.GeneralErrors);
    }
	

    [HttpPut("{id}")]
    public async Task<ActionResult<Result>> Update(int id, [FromBody] UpdateProductCommand command)
    {
        if (id != command.Id)
        {
            return BadRequest(new { Error = "Mismatched product ID" });
        }

        var result = await Mediator.Send(command);

        return result.Succeeded
            ? (ActionResult<Result>)Ok(result)
            : result.FieldErrors != null && result.FieldErrors.Any() ? (ActionResult<Result>)BadRequest(result)
                : (ActionResult<Result>)StatusCode(500, result.GeneralErrors);
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult<Result>> Delete(int id)
    {
        var result = await Mediator.Send(new DeleteProductCommand(id));

        return result.Succeeded
            ? (ActionResult<Result>)Ok(result)
            : result.FieldErrors != null && result.FieldErrors.Any()
                ? (ActionResult<Result>)BadRequest(result)
                : (ActionResult<Result>)StatusCode(500, result.GeneralErrors);
    }


    [HttpGet("Categories")]
    public ActionResult<Result<List<string>>> GetAllCategories()
    {
        var categories = Enum.GetNames(typeof(Category)).ToList();
        return Ok(new Result<List<string>> { Data = categories, Succeeded = true });
    }


    [HttpGet("Paginated")]
    public async Task<ActionResult<PaginatedList<ProductDto>>> GetPaginated([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10)
    {
        var paginatedProducts = await Mediator.Send(new GetProductsWithPaginationQuery
        {
            PageNumber = pageNumber,
            PageSize = pageSize
        });

        return paginatedProducts == null || !paginatedProducts.Items.Any()
            ? (ActionResult<PaginatedList<ProductDto>>)NotFound() 
            : (ActionResult<PaginatedList<ProductDto>>)Ok(paginatedProducts);
    }
}
"@

    $controllerContent | Set-Content -Path $filePath
}


function CreateProductCommandFile() 
{
    $dirPath = "src\Application\Features\Products\Commands"
    $filePath = "$dirPath\CreateProductCommand.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }

    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Domain.Entities;
using $($projectName).Domain.Enums;
using $($projectName).Shared.Common.Models;
using MediatR;

namespace $($projectName).Application.Features.Products.Commands;

public record CreateProductCommand(
    string Name,
    string Description,
    decimal Price,
    int StockQuantity,
    string SKU,
    string Category,
    string Brand,
    DateTime ReleaseDate,
    string ImageUrl
) : IRequest<Result<int>>;

public class CreateProductCommandHandler : IRequestHandler<CreateProductCommand, Result<int>>
{
    private readonly IApplicationDbContext _dbContext;

    public CreateProductCommandHandler(IApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }


    public async Task<Result<int>> Handle(CreateProductCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var product = new Product
            {
                Name = request.Name,
                Description = request.Description,
                Price = request.Price,
                StockQuantity = request.StockQuantity,
                SKU = request.SKU,
                Category = Enum.Parse<Category>(request.Category),
                Brand = request.Brand,
                ReleaseDate = request.ReleaseDate,
                ImageUrl = request.ImageUrl
            };

            _dbContext.Products.Add(product);
            await _dbContext.SaveChangesAsync(cancellationToken);
            return Result<int>.Success(product.Id);
        }
        catch (Exception ex)
        {
            return Result<int>.Failure(-1, generalErrors: new string[] { ex.Message });
        }
    }
}
"@
    $content | Set-Content -Path $filePath
}



function DeleteProductCommandFile() 
{
    $dirPath = "src\Application\Features\Products\Commands"
    $filePath = "$dirPath\DeleteProductCommand.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }

    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Shared.Common.Models;
using MediatR;

namespace $($projectName).Application.Features.Products.Commands;

public record DeleteProductCommand(int Id) : IRequest<Result>;

public class DeleteProductCommandHandler : IRequestHandler<DeleteProductCommand, Result>
{
    private readonly IApplicationDbContext _dbContext;

    public DeleteProductCommandHandler(IApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<Result> Handle(DeleteProductCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var product = await _dbContext.Products.FindAsync(new object?[] { request.Id }, cancellationToken: cancellationToken);
            if (product == null) return Result.Failure(generalErrors: new string[] { "Product not found." });

            _dbContext.Products.Remove(product);
            await _dbContext.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
        catch (Exception ex)
        {
            return Result.Failure(generalErrors: new string[] { ex.Message });
        }
    }
}
"@
    $content | Set-Content -Path $filePath
}


function UpdateProductCommandFile() 
{
    $dirPath = "src\Application\Features\Products\Commands"
    $filePath = "$dirPath\UpdateProductCommand.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }

    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Domain.Enums;
using $($projectName).Shared.Common.Models;
using MediatR;

namespace $($projectName).Application.Features.Products.Commands;

public record UpdateProductCommand(
    int Id,
    string? Name,
    string? Description,
    decimal Price,
    int StockQuantity,
    string? SKU,
    string? Category, // Remains a string
    string? Brand,
    DateTime? ReleaseDate,
    string? ImageUrl
) : IRequest<Result<int>>;

public class UpdateProductCommandHandler : IRequestHandler<UpdateProductCommand, Result<int>>
{
    private readonly IApplicationDbContext _dbContext;

    public UpdateProductCommandHandler(IApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<Result<int>> Handle(UpdateProductCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var product = await _dbContext.Products.FindAsync(new object?[] { request.Id }, cancellationToken: cancellationToken);
            if (product == null) return Result<int>.Failure(-1, generalErrors: new string[] { "Product not found." });

            product.Name = request.Name;
            product.Description = request.Description;
            product.Price = request.Price;
            product.StockQuantity = request.StockQuantity;
            product.SKU = request.SKU;

            // Convert the string category to the Category enum
            if (request.Category != null && Enum.TryParse(typeof(Category), request.Category, out var categoryEnum))
            {
                product.Category = (Category)categoryEnum;
            }

            product.Brand = request.Brand;
            product.ReleaseDate = request.ReleaseDate;
            product.ImageUrl = request.ImageUrl;

            await _dbContext.SaveChangesAsync(cancellationToken);

            return Result<int>.Success(product.Id);
        }
        catch (Exception ex)
        {
            return Result<int>.Failure(-1, generalErrors: new string[] { ex.Message });
        }
    }
}
"@
    $content | Set-Content -Path $filePath
}



function CreateGetAllProductsQueryFile()
{
    $dirPath = "src\Application\Features\Products\Queries"
    $filePath = "$dirPath\GetAllProductsQuery.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }

    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Shared.DTOs;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace $($projectName).Application.Features.Products.Queries;

public record GetAllProductsQuery : IRequest<IEnumerable<ProductDto>>;

public class GetAllProductsQueryHandler : IRequestHandler<GetAllProductsQuery, IEnumerable<ProductDto>>
{
    private readonly IApplicationDbContext _dbContext;

    public GetAllProductsQueryHandler(IApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<IEnumerable<ProductDto>> Handle(GetAllProductsQuery request, CancellationToken cancellationToken)
    {
        var products = await _dbContext.Products.ToListAsync(cancellationToken);

        return products.Select(product => new ProductDto
        {
            Id = product.Id,
            Name = product.Name,
            Description = product.Description,
            Price = product.Price,
            StockQuantity = product.StockQuantity,
            SKU = product.SKU,
            Category = product.Category.ToString(),
            Brand = product.Brand,
            ReleaseDate = product.ReleaseDate,
            ImageUrl = product.ImageUrl
        });
    }
}
"@
    $content | Set-Content -Path $filePath
}



function CreateGetProductByIdQueryFile() 
{
    $dirPath = "src\Application\Features\Products\Queries"
    $filePath = "$dirPath\GetProductByIdQuery.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }

    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Shared.DTOs;
using $($projectName).Shared.Common.Models;

using MediatR;

namespace $($projectName).Application.Features.Products.Queries;

public class GetProductByIdQuery : IRequest<Result<ProductDto>>
{
    public int Id { get; set; }
}

public class GetProductByIdQueryHandler : IRequestHandler<GetProductByIdQuery, Result<ProductDto>>
{
    private readonly IApplicationDbContext _context;

    public GetProductByIdQueryHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Result<ProductDto>> Handle(GetProductByIdQuery request, CancellationToken cancellationToken)
    {
        // Retrieve the product by its Id from the data source.
        var product = await _context.Products.FindAsync(new object?[] { request.Id }, cancellationToken: cancellationToken);

        if (product != null)
        {
            // Map the entity to a DTO or ViewModel as needed.
            var productDto = new ProductDto
            {
                Id = product.Id,
                Name = product.Name,
                Description = product.Description,
                Price = product.Price,
                StockQuantity = product.StockQuantity,
                SKU = product.SKU,
                Category = product.Category.ToString(), // Convert Enum to String
                Brand = product.Brand,
                ReleaseDate = product.ReleaseDate,
                ImageUrl = product.ImageUrl,
            };

            return Result<ProductDto>.Success(productDto);
        }

        // If the product is not found, return a failure Result.
        return Result<ProductDto>.Failure(null, generalErrors: new string[] { "Product not found." });
    }
}
"@
    $content | Set-Content -Path $filePath
}



function CreateProductCommandValidatorFile() 
{
    $dirPath = "src\Application\Features\Products\Validators"
    $filePath = "$dirPath\CreateProductCommandValidator.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }

    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Application.Features.Products.Commands;
using $($projectName).Shared.DTOs;
using $($projectName).Shared.Validators;
using FluentValidation;

namespace $($projectName).Application.Features.Products.Validators;

public class CreateProductCommandValidator : AbstractValidator<CreateProductCommand>
{
    private readonly IApplicationDbContext _context;

    public CreateProductCommandValidator(IApplicationDbContext context)
    {
        _context = context;

        RuleFor(command => new ProductDto
        {
            Name = command.Name,
            Price = command.Price,
            Description = command.Description,
            StockQuantity = command.StockQuantity,
            SKU = command.SKU,
            Category = command.Category,
            Brand = command.Brand,
            ReleaseDate = command.ReleaseDate,
            ImageUrl = command.ImageUrl,

        }).SetValidator(new ProductDtoValidator());

        RuleFor(command => command.Name).Must(IsNameUnique).WithMessage("Product name must be unique.");
    }

    private bool IsNameUnique(string name)
    {
        bool isUnique = !_context.Products.Any(product => product.Name == name);
        return isUnique;
    }
}
"@
    $content | Set-Content -Path $filePath
}



function DeleteProductCommandValidatorFile() 
{
    $dirPath = "src\Application\Features\Products\Validators"
    $filePath = "$dirPath\DeleteProductCommandValidator.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }
	
    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Application.Features.Products.Commands;
using FluentValidation;

namespace $($projectName).Application.Features.Products.Validators;

public class DeleteProductCommandValidator : AbstractValidator<DeleteProductCommand>
{
    private readonly IApplicationDbContext _context;

    public DeleteProductCommandValidator(IApplicationDbContext context)
    {
        _context = context;

        RuleFor(command => command.Id).Must(Exist).WithMessage("Product ID does not exist.");
    }

    private bool Exist(int id)
    {
        return _context.Products.Any(product => product.Id == id);
    }
}
"@
    $content | Set-Content -Path $filePath
}



function CreateGetProductByIdQueryValidatorFile() 
{
    $dirPath = "src\Application\Features\Products\Validators"
    $filePath = "$dirPath\GetProductByIdValidator.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }

    $content = @"
using $($projectName).Application.Features.Products.Queries;
using FluentValidation;

namespace $($projectName).Application.Features.Products.Validators;

public class GetProductByIdQueryValidator : AbstractValidator<GetProductByIdQuery>
{
    public GetProductByIdQueryValidator()
    {
        RuleFor(query => query.Id).GreaterThan(0).WithMessage("Product Id must be greater than 0.");
    }
}
"@
    $content | Set-Content -Path $filePath
}



function CreateUpdateProductCommandValidator() 
{
    $dirPath = "src\Application\Features\Products\Validators"
    $filePath = "$dirPath\UpdateProductCommandValidator.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }

    $content = @"
using $($projectName).Application.Common.Interfaces;
using $($projectName).Application.Features.Products.Commands;
using $($projectName).Shared.DTOs;
using $($projectName).Shared.Validators;
using FluentValidation;

namespace $($projectName).Application.Features.Products.Validators;

public class UpdateProductCommandValidator : AbstractValidator<UpdateProductCommand>
{
    private readonly IApplicationDbContext _context;

    public UpdateProductCommandValidator(IApplicationDbContext context)
    {
        _context = context;

        RuleFor(command => command.Id).Must(Exist).WithMessage("Product ID does not exist.");

        RuleFor(command => new ProductDto
        {
            Name = command.Name,
            Price = command.Price,
            Description = command.Description,
            StockQuantity = command.StockQuantity,
            SKU = command.SKU,
            Category = command.Category,
            Brand = command.Brand,
            ReleaseDate = command.ReleaseDate,
            ImageUrl = command.ImageUrl,
        }).SetValidator(new ProductDtoValidator());

        RuleFor(command => command.Name).Must(IsNameUnique).WithMessage("Product name must be unique.");
    }

    private bool Exist(int id)
    {
        return _context.Products.Any(product => product.Id == id);
    }

    private bool IsNameUnique(UpdateProductCommand command, string? name)
    {
        bool isUnique = !_context.Products.Any(product => product.Name == name && product.Id != command.Id);
        return isUnique;
    }
}
"@
    $content | Set-Content -Path $filePath
}



function CreateGetProductsWithPaginationQueryValidator() 
{
    $dirPath = "src\Application\Features\Products\Validators"
    $filePath = "$dirPath\GetProductsWithPaginationQueryValidator.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }

    $content = @"
using $($projectName).Application.Features.Products.Queries;
using FluentValidation;

namespace $($projectName).Application.Features.Products.Validators;

public class GetProductsWithPaginationQueryValidator : AbstractValidator<GetProductsWithPaginationQuery>
{
    public GetProductsWithPaginationQueryValidator()
    {
        RuleFor(x => x.PageNumber)
            .GreaterThanOrEqualTo(1).WithMessage("PageNumber must be greater than or equal to 1.");

        RuleFor(x => x.PageSize)
            .GreaterThanOrEqualTo(1).WithMessage("PageSize must be greater than or equal to 1.");
    }
}
"@
    $content | Set-Content -Path $filePath
}


function CreateGetProductsWithPaginationQuery() 
{
    $dirPath = "src\Application\Features\Products\Queries"
    $filePath = "$dirPath\GetProductsWithPaginationQuery.cs"

    if (-Not (Test-Path $dirPath)) 
	{
        New-Item -ItemType Directory -Force -Path $dirPath
    }

    $content = @"
using AutoMapper;
using $($projectName).Application.Common.Interfaces;
using $($projectName).Domain.Entities;
using $($projectName).Shared.Common.Models;
using $($projectName).Shared.DTOs;
using MediatR;

namespace $($projectName).Application.Features.Products.Queries;

public record GetProductsWithPaginationQuery : IRequest<PaginatedList<ProductDto>>
{
    public int PageNumber { get; init; } = 1;
    public int PageSize { get; init; } = 10;
}

public class GetProductsWithPaginationQueryHandler : IRequestHandler<GetProductsWithPaginationQuery, PaginatedList<ProductDto>>
{
    private readonly IPaginationService _paginationService;
    private readonly IMapper _mapper;

    public GetProductsWithPaginationQueryHandler(IPaginationService paginationService, IMapper mapper)
    {
        _paginationService = paginationService;
        _mapper = mapper;
    }


    public async Task<PaginatedList<ProductDto>> Handle(GetProductsWithPaginationQuery request, CancellationToken cancellationToken)
    {
        var products = await _paginationService.GetPaginatedDataAsync<Product>(
            tableName: "Products",
            selectColumns: "*",
            //whereCondition: "Price > 1.00",
            pageNumber: request.PageNumber,
            pageSize: request.PageSize,
            orderByColumn: "Id",
            fetchTotalCount: true
        );

        var productDtos = products.Items.Select(p => _mapper.Map<ProductDto>(p)).ToList();

        return new PaginatedList<ProductDto>(productDtos, products.TotalCount, products.PageNumber, products.PageSize);
    }
}
"@
    $content | Set-Content -Path $filePath
}



function CreateProductDtoValidator() 
{
    $filePath = "src\Shared\Validators\ProductDtoValidator.cs"
    $content = @"
using $($projectName).Shared.DTOs;
using FluentValidation;

namespace $($projectName).Shared.Validators;


public class ProductDtoValidator : AbstractValidator<ProductDto>
{
    public ProductDtoValidator()
    {
        RuleFor(product => product.Name)
            .NotEmpty().WithMessage("Name is required.")
            .Length(2, 50).WithMessage("Name must be between 2 and 50 characters.");

        RuleFor(product => product.Description)
            .NotEmpty().WithMessage("Description is required.")
            .Length(10, 500).WithMessage("Description must be between 10 and 500 characters.");

        RuleFor(product => product.Price)
            .NotEmpty().WithMessage("Price is required.")
            .GreaterThan(0).WithMessage("Price must be greater than 0.");

        RuleFor(product => product.StockQuantity)
            .NotEmpty().WithMessage("Stock Quantity is required.")
            .GreaterThan(0).WithMessage("Stock Quantity must be greater than 0.");

        RuleFor(product => product.SKU)
            .NotEmpty().WithMessage("SKU is required.")
            .Length(5, 20).WithMessage("SKU must be between 5 and 20 characters.");

        RuleFor(product => product.Category)
            .NotEmpty().WithMessage("Category is required.")
            .Length(2, 50).WithMessage("Category must be between 2 and 50 characters.");

        RuleFor(product => product.Brand)
            .NotEmpty().WithMessage("Brand is required.")
            .Length(2, 50).WithMessage("Brand must be between 2 and 50 characters.");

        RuleFor(product => product.ReleaseDate)
            .NotEmpty().WithMessage("Release Date is required.");

        RuleFor(product => product.ImageUrl)
            .NotEmpty().WithMessage("Image URL is required.")
            .Must(uri => Uri.IsWellFormedUriString(uri, UriKind.Absolute))
            .WithMessage("Please provide a valid Image URL.");
    }
}

"@
    # Write the content to the file
    Set-Content -Path $filePath -Value $content
}


function CreateCategoryEnum() 
{
    $filePath = "src\Domain\Enums\Category.cs"
    $content = @"
namespace $($projectName).Domain.Enums;

public enum Category
{
    Electronics = 1,
    Clothing = 2,
    HomeAppliances = 3,
    SportsAndFitness = 4,
    Books = 5,
    BeautyAndPersonalCare = 6,
    ToysAndGames = 7,
    Groceries = 8,
    HealthAndWellness = 9,
    Other = 10,
    VideoGames = 11
}

"@

    Set-Content -Path $filePath -Value $content
}


function CreateProductEntity() 
{
    $filePath = "src\Domain\Entities\Product.cs"
    $content = @"
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace $($projectName).Domain.Entities;

public class Product : BaseAuditableEntity
{
    public string? Name { get; set; }
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public int StockQuantity { get; set; }
    public string? SKU { get; set; }
    public bool IsAvailable => StockQuantity > 0;
    public Category Category { get; set; }
    public string? Brand { get; set; }
    public DateTime? ReleaseDate { get; set; }
    public string? ImageUrl { get; set; }
}
"@

    Set-Content -Path $filePath -Value $content
}



function CreateProductConfigurationFile() 
{
    $filePath = "src\Infrastructure\Persistence\Configurations\ProductConfiguration.cs"
    $content = @"
using $($projectName).Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace $($projectName).Infrastructure.Persistence.Configurations;

public class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        // You can add more property configurations as required.
        // Example: Configuring a string property to have a max length.
        // builder.Property(p => p.ProductName)
        //    .HasMaxLength(200)
        //    .IsRequired();

        // Configure the Price property to have a precision of 18 with 2 decimal places.
        builder.Property(p => p.Price)
            .HasColumnType("decimal(18,2)")
            .IsRequired();

        // Configure the Category property to map to an integer in the database.
        builder.Property(p => p.Category)
            .HasConversion<int>();
    }
}
"@
    Set-Content -Path $filePath -Value $content
}


function CreateProductProfile()
{
    $fullPath = "src\Application\Common\Models\ProductProfile.cs"

	$newContent = @"
using AutoMapper;
using $($projectName).Domain.Entities;
using $($projectName).Shared.DTOs;

namespace $($projectName).Application.Common.Models;

public class ProductProfile : Profile
{
    public ProductProfile()
    {
        CreateMap<Product, ProductDto>()
            .ForMember(dest => dest.Id, opt => opt.MapFrom(src => src.Id))
            .ForMember(dest => dest.Name, opt => opt.MapFrom(src => src.Name))
            .ForMember(dest => dest.Description, opt => opt.MapFrom(src => src.Description))
            .ForMember(dest => dest.Price, opt => opt.MapFrom(src => src.Price))
            .ForMember(dest => dest.StockQuantity, opt => opt.MapFrom(src => src.StockQuantity))
            .ForMember(dest => dest.SKU, opt => opt.MapFrom(src => src.SKU))
            .ForMember(dest => dest.IsAvailable, opt => opt.MapFrom(src => src.IsAvailable))
            .ForMember(dest => dest.Category, opt => opt.MapFrom(src => src.Category.ToString()))
            .ForMember(dest => dest.Brand, opt => opt.MapFrom(src => src.Brand))
            .ForMember(dest => dest.ReleaseDate, opt => opt.MapFrom(src => src.ReleaseDate))
            .ForMember(dest => dest.ImageUrl, opt => opt.MapFrom(src => src.ImageUrl));
    }
}
"@
	Set-Content -Path $fullPath -Value $newContent
}


function UpdateIApplicationDbContext()
{
    $fullPath = "src\Application\Common\Interfaces\IApplicationDbContext.cs"

	$newContent = @"
using $($projectName).Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace $($projectName).Application.Common.Interfaces;

public interface IApplicationDbContext
{
   
    DbSet<Product> Products { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken);
}
"@

	Set-Content -Path $fullPath -Value $newContent
}



function UpdateApplicationDbContext()
{
    $fullPath = "src\Infrastructure\Persistence\ApplicationDbContext.cs"

	$newContent = @"
using System.Reflection;
using $($projectName).Application.Common.Interfaces;
using $($projectName).Domain.Entities;
using $($projectName).Infrastructure.Identity;
using $($projectName).Infrastructure.Persistence.Interceptors;
using Duende.IdentityServer.EntityFramework.Options;
using MediatR;
using Microsoft.AspNetCore.ApiAuthorization.IdentityServer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace $($projectName).Infrastructure.Persistence;

public class ApplicationDbContext : ApiAuthorizationDbContext<ApplicationUser>, IApplicationDbContext
{
    private readonly IMediator _mediator;
    private readonly AuditableEntitySaveChangesInterceptor _auditableEntitySaveChangesInterceptor;

    public ApplicationDbContext(
        DbContextOptions<ApplicationDbContext> options,
        IOptions<OperationalStoreOptions> operationalStoreOptions,
        IMediator mediator,
        AuditableEntitySaveChangesInterceptor auditableEntitySaveChangesInterceptor) 
        : base(options, operationalStoreOptions)
    {
        _mediator = mediator;
        _auditableEntitySaveChangesInterceptor = auditableEntitySaveChangesInterceptor;
    }

    public DbSet<Product> Products => Set<Product>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        builder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly());

        base.OnModelCreating(builder);
    }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.AddInterceptors(_auditableEntitySaveChangesInterceptor);
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        await _mediator.DispatchDomainEvents(this);

        return await base.SaveChangesAsync(cancellationToken);
    }
}
"@

	Set-Content -Path $fullPath -Value $newContent
}


function GenerateApplicationDbContextInitializer()
{
    $fullPath = "src\Infrastructure\Persistence\ApplicationDbContextInitialiser.cs"

	$newContent = @"
using $($projectName).Domain.Entities;
using $($projectName).Domain.Enums;
using $($projectName).Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace $($projectName).Infrastructure.Persistence;

public class ApplicationDbContextInitialiser
{
    private readonly ILogger<ApplicationDbContextInitialiser> _logger;
    private readonly ApplicationDbContext _context;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly RoleManager<IdentityRole> _roleManager;

    public ApplicationDbContextInitialiser(ILogger<ApplicationDbContextInitialiser> logger, ApplicationDbContext context, UserManager<ApplicationUser> userManager, RoleManager<IdentityRole> roleManager)
    {
        _logger = logger;
        _context = context;
        _userManager = userManager;
        _roleManager = roleManager;
    }

    public async Task InitialiseAsync()
    {
        try
        {
            if (_context.Database.IsSqlServer())
            {
                await _context.Database.MigrateAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An error occurred while initialising the database.");
            throw;
        }
    }

    public async Task SeedAsync()
    {
        try
        {
            await TrySeedAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An error occurred while seeding the database.");
            throw;
        }
    }

    public async Task TrySeedAsync()
    {
        // Default roles
        var administratorRole = new IdentityRole("Administrator");

        if (_roleManager.Roles.All(r => r.Name != administratorRole.Name))
        {
            await _roleManager.CreateAsync(administratorRole);
        }

        // Default users
        var administrator = new ApplicationUser { UserName = "administrator@localhost", Email = "administrator@localhost" };

        if (_userManager.Users.All(u => u.UserName != administrator.UserName))
        {
            await _userManager.CreateAsync(administrator, "Administrator1!");
            if (!string.IsNullOrWhiteSpace(administratorRole.Name))
            {
                await _userManager.AddToRolesAsync(administrator, new [] { administratorRole.Name });
            }
        }

       // Default data
        // Seed, if necessary
        if (!_context.Products.Any())
        {
            _context.Products.AddRange(new List<Product>()
            {
                new Product()
                {
                    Name = "GTA 5",
                    Description = "Grand Theft Auto V is an action-adventure game developed by Rockstar North.",
                    Price = 89.99m,
                    StockQuantity = 100,
                    SKU = "GTA5-12345",
                    Category = Category.VideoGames,
                    Brand = "Rockstar Games",
                    ReleaseDate = new DateTime(2013, 9, 17),
                    ImageUrl = "https://cdn.discordapp.com/attachments/1155757087926796350/1166740990342733945/gta5.jpg?ex=654b9739&is=65392239&hm=9281cca5c6df486287ec794024826336031ac944a929521729bd6e2413360573&"
                },
                new Product()
                {
                    Name = "GTA 6",
                    Description = "Grand Theft Auto VI is the latest installment in the popular action-adventure series.",
                    Price = 149.99m,
                    StockQuantity = 50,
                    SKU = "GTA6-12345",
                    Category = Category.VideoGames,
                    Brand = "Rockstar Games",
                    ReleaseDate = new DateTime(2023, 9, 17), // Assuming a future release date
                    ImageUrl = "https://cdn.discordapp.com/attachments/1155757087926796350/1166741438013382666/gta6.jpg?ex=654b97a3&is=653922a3&hm=58e182e21f7bb2d5d87abf993eaf5112811b9bdf64d345cb96d8c36264cd7555&"
                },
                new Product()
                {
                    Name = "Black Ops 3",
                    Description = "Call of Duty: Black Ops III is a military science fiction first-person shooter.",
                    Price = 79.99m,
                    StockQuantity = 30,
                    SKU = "BO3-12345",
                    Category = Category.VideoGames,
                    Brand = "Activision",
                    ReleaseDate = new DateTime(2015, 11, 6),
                    ImageUrl = "https://cdn.discordapp.com/attachments/1155757087926796350/1166740821358411847/Black_Ops_3.jpg?ex=654b9710&is=65392210&hm=74cf98b2824b99e432a75556cbdb97cfcc17396bd3424085c482668401c0880a&"
                },
                new Product()
                {
                    Name = "Modern Warfare 3",
                    Description = "Call of Duty: Modern Warfare 3 is a first-person shooter game.",
                    Price = 99.99m,
                    StockQuantity = 40,
                    SKU = "MW3-12345",
                    Category = Category.VideoGames,
                    Brand = "Activision",
                    ReleaseDate = new DateTime(2011, 11, 8),
                    ImageUrl = "https://cdn.discordapp.com/attachments/1155757087926796350/1166544525838254141/MWIII-REVEAL-FULL-TOUT.jpg?ex=654ae040&is=65386b40&hm=63bdae27bc2bbf6c213849cc473679fa6281d1aada7a8aef7fb37eb971f589f2&"
                },
                new Product()
                {
                    Name = "Elden Ring",
                    Description = "Elden Ring is an action role-playing game developed by FromSoftware.",
                    Price = 9.99m,
                    StockQuantity = 200,
                    SKU = "ER-12345",
                    Category = Category.VideoGames,
                    Brand = "FromSoftware",
                    ReleaseDate = new DateTime(2022, 2, 25),
                    ImageUrl = "https://cdn.discordapp.com/attachments/1155757087926796350/1166741600978878534/eldenring.webp?ex=654b97ca&is=653922ca&hm=eaf2f85e2e986ffb13d720105613ca917deb5563fca3b122edf85a1a19a2d5c9&"
                },
            });

            await _context.SaveChangesAsync();
        }
    }
}
"@

	Set-Content -Path $fullPath -Value $newContent
}


function CreateProductPage() 
{
    $fullPath = "src\$($projectName)\Client\Pages\CreateProduct.razor"

    $createProductContent = @"
@page "/createproduct"
@using $($projectName).Client.Common.Interfaces;
@using $($projectName).Shared.Common.Models;
@using $($projectName).Shared.DTOs;
@using Blazored.FluentValidation;
@using Refit;

@inject IProductApi ProductApi
@inject IJSRuntime JSRuntime
@inject NavigationManager NavigationManager

@code {
    public ProductDto? Model = null;
    private EditContext? editContext;
    Result<List<string>> categories = new Result<List<string>> { Data = new List<string>(), Succeeded = false };
    private bool isLoading = false;

    protected override async void OnInitialized()
    {
        Model ??= new();
        editContext = new EditContext(Model);

        try
        {
            categories = await ProductApi.GetAllCategoriesAsync();

            if (categories.Data != null)
            {
                StateHasChanged();
            }

        }
        catch (ApiException ex)
        {
            Console.WriteLine("Categories: " + ex.ToString());

        }
    }

    private async Task SubmitAsync()
    {
        isLoading = true;

        Result<int>? response = null;

        if (Model != null)
        {
            try
            {
                response = await ProductApi.CreateProductAsync(Model);

                if (response.Succeeded)
                {
                    Console.WriteLine("Create: Success");
                    await JSRuntime.InvokeVoidAsync("alert", "Successfully added product!");
                    NavigationManager.NavigateTo("/");

                }
            }
            catch (ApiException ex)
            {
                await JSRuntime.InvokeVoidAsync("alert", ex.Content);
            }
            finally
            {
                isLoading = false;
            }
        }
    }
}

<PageTitle>Create Product</PageTitle>
<h1>Create Product</h1>

@if (Model != null)
{
    <EditForm OnValidSubmit="@SubmitAsync" EditContext="@editContext">
        <FluentValidationValidator />
        <div class="mx-12 row">
            <div class="mb-7 col-md-6">
                <label class="form-label required">Name</label>
                <InputText class="form-control" @bind-Value="Model.Name" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">Description</label>
                <InputTextArea class="form-control" @bind-Value="Model.Description" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label required">Price</label>
                <InputNumber class="form-control" @bind-Value="Model.Price" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">Stock Quantity</label>
                <InputNumber class="form-control" @bind-Value="Model.StockQuantity" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">SKU</label>
                <InputText class="form-control" @bind-Value="Model.SKU" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">Category</label>
                <InputSelect class="form-control" @bind-Value="Model.Category">
                @if (categories.Data != null)
                {
                    @foreach (var category in categories.Data)
                    {
                        <option value="@category">@category</option>
                    }
                }
                </InputSelect>
            </div>

            <div class="mb-7 col-md-6">
                <label class="form-label">Brand</label>
                <InputText class="form-control" @bind-Value="Model.Brand" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">Release Date</label>
                <InputDate class="form-control" @bind-Value="Model.ReleaseDate" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">Image URL</label>
                <InputText class="form-control" @bind-Value="Model.ImageUrl" />
            </div>

            <ValidationSummary />

            <div class="d-flex">
                <button type="submit" class="btn btn-primary btn-icon-light w-125px" disabled="@isLoading">
                    @if (isLoading)
                    {
                        <span>Loading...</span>
                    }
                    else
                    {
                        <span>Create</span>
                    }
                </button>
            </div>
        </div>
    </EditForm>
}
"@
    Set-Content -Path $fullPath -Value $createProductContent
}


function CreateUpdateProductPage() 
{
    $fullPath = "src\$($projectName)\Client\Pages\UpdateProduct.razor"
    $updateProductContent = @"
@page "/updateproduct/{id:int}"
@using $($projectName).Client.Common.Interfaces;
@using $($projectName).Shared.Common.Models;
@using $($projectName).Shared.DTOs;
@using Blazored.FluentValidation;
@using Refit;

@inject IProductApi ProductApi
@inject IJSRuntime JSRuntime
@inject NavigationManager NavigationManager

@code {
    private Result<ProductDto>? result = null;
    private ProductDto? product = null;
    private EditContext? editContext;
    Result<List<string>> categories = new Result<List<string>> { Data = new List<string>(), Succeeded = false };

    [Parameter]
    public int Id { get; set; }

    protected override async Task OnInitializedAsync()
    {
        try
        {
            categories = await ProductApi.GetAllCategoriesAsync();
            result = await ProductApi.GetProductByIdAsync(Id);

            if (result.Data != null)
            {
                product = result.Data;
                editContext = new EditContext(product);
            }
        }
        catch (ApiException)
        {
            // Handle API exception as needed
        }
    }

    private async Task Update()
    {
        Result? result = null;
        try
        {
            if (product != null)
            {
                if (product != null)
                {
                    result = await ProductApi.UpdateProductAsync(Id, product);
                }
            }
            if (result != null)
            {
                if (result.Succeeded)
                {
                    await JSRuntime.InvokeVoidAsync("alert", "Product updated successfully.");
                    NavigationManager.NavigateTo("/");
                }
                else
                {
                    await JSRuntime.InvokeVoidAsync("alert", "Error updating product.");
                }
            }
        }
        catch (ApiException ex)
        {
            await JSRuntime.InvokeVoidAsync("alert", ex.Content);
        }
    }
}

<PageTitle>Edit Product</PageTitle>
<h1>Edit Product</h1>

@if (product == null || categories.Data == null)
{
    <p><em>Loading...</em></p>
}
else
{
    <img src="@product.ImageUrl" alt="@product.Name" class="img-fluid">

    <EditForm OnValidSubmit="@Update" EditContext="@editContext">
        <FluentValidationValidator />
        <div class="mx-12 row">
            <div class="mb-7 col-md-6">
                <label class="form-label required">Name</label>
                <InputText class="form-control" @bind-Value="product.Name" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">Description</label>
                <InputTextArea class="form-control" @bind-Value="product.Description" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label required">Price</label>
                <InputNumber class="form-control" @bind-Value="product.Price" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label required">Stock Quantity</label>
                <InputNumber class="form-control" @bind-Value="product.StockQuantity" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">SKU</label>
                <InputText class="form-control" @bind-Value="product.SKU" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">Category</label>
                <InputSelect class="form-control" @bind-Value="product.Category">
                    @foreach (var category in categories.Data)
                    {
                        <option value="@category">@category</option>
                    }
                </InputSelect>
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">Brand</label>
                <InputText class="form-control" @bind-Value="product.Brand" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">Release Date</label>
                <InputDate class="form-control" @bind-Value="product.ReleaseDate" />
            </div>
            <div class="mb-7 col-md-6">
                <label class="form-label">Image URL</label>
                <InputText class="form-control" @bind-Value="product.ImageUrl" />
            </div>
            <ValidationSummary />

            <div class="d-flex">
                <button type="submit" class="btn btn-primary btn-icon-light w-125px">Update</button>
            </div>

        </div>
    </EditForm>
}
"@
    Set-Content -Path $fullPath -Value $updateProductContent
}



function CreateIndexPage() 
{
    $fullPath = "src\$($projectName)\Client\Pages\Index.razor"
    $indexPageContent = @"
@page "/"
@using $($projectName).Client.Common.Interfaces;
@using $($projectName).Client.Pages;
@using $($projectName).Shared.Common.Models;
@using $($projectName).Shared.DTOs;
@using Refit;

@inject IProductApi ProductApi
@inject NavigationManager NavigationManager

<PageTitle>Products</PageTitle>

<h1>Products List</h1>

@if (PaginatedProducts == null)
{
    <p><em>Loading...</em></p>
}
else
{
    <div class="scrollable-table">
        <table class="table">
            <thead>
                <tr>
                    <th>Id</th>
                    <th>Name</th>
                    <th>Description</th>
                    <th>Price</th>
                    <th>Stock</th>
                    <th>SKU</th>
                    <th>Available</th>
                    <th>Category</th>
                    <th>Brand</th>
                    <th>Release Date</th>
                    <th>Image</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                @foreach (var product in PaginatedProducts.Items)
                {
                    <tr>
                        <td>@product.Id</td>
                        <td>@product.Name</td>
                        <td>@product.Description</td>
                        <td>@product.Price</td>
                        <td>@product.StockQuantity</td>
                        <td>@product.SKU</td>
                        <td>@product.IsAvailable</td>
                        <td>@product.Category</td>
                        <td>@product.Brand</td>
                        <td>@product.ReleaseDate?.ToString("yyyy-MM-dd")</td>
                        <td><img src="@product.ImageUrl" alt="@product.Name" width="100"></td>
                        <td>
                            <button class="btn btn-primary" @onclick="() => UpdateProduct(product.Id)">Edit</button>
                            <button class="btn btn-danger" @onclick="() => DeleteProduct(product.Id)">Delete</button>
                        </td>
                    </tr>
                }
            </tbody>
        </table>
    </div>

    <GenericPaginator TItem="ProductDto"
                      PaginatedData="PaginatedProducts"
                      OnPageChanged="HandlePageChange" />
}

@code {
    private PaginatedList<ProductDto>? PaginatedProducts;
    private int currentPage = 1;
    private int pageSize = 3;

    protected override async Task OnInitializedAsync()
    {
        await FetchPaginatedData(currentPage, pageSize);
    }

    private async Task FetchPaginatedData(int pageNumber, int pageSize)
    {
        try
        {
            PaginatedProducts = await ProductApi.GetPaginatedAsync(pageNumber, pageSize);
        }
        catch (ApiException)
        {
            // Handle API exception as needed
        }
    }

    private void UpdateProduct(int productId)
    {
        // Navigate to the edit page or open a modal, depending on your design.
        NavigationManager.NavigateTo($"/updateproduct/{productId}");
    }

    private async Task DeleteProduct(int productId)
    {
        try
        {
            var result = await ProductApi.DeleteProductAsync(productId);

            if (result.Succeeded && PaginatedProducts != null)
            {
                var updatedItems = PaginatedProducts.Items.Where(p => p.Id != productId).ToList();
                PaginatedProducts = new PaginatedList<ProductDto>(updatedItems, PaginatedProducts.TotalCount, currentPage, pageSize);
                StateHasChanged();
            }
        }
        catch (ApiException)
        {
            // Handle API exception as needed
        }
    }


    private async Task HandlePageChange(int pageNumber)
    {
        if (pageNumber != currentPage)
        {
            currentPage = pageNumber;
            await FetchPaginatedData(pageNumber, pageSize);
        }
    }
}
"@
    Set-Content -Path $fullPath -Value $indexPageContent
}



Function UpdateNavMenuPage()
{
	$fullPath = "src\$($projectName)\Client\Shared\NavMenu.razor"

	$newContent = @"
	<div class="top-row ps-3 navbar navbar-dark">
    <div class="container-fluid">
        <a class="navbar-brand" href="">$($projectName)</a>
        <button title="Navigation menu" class="navbar-toggler" @onclick="ToggleNavMenu">
            <span class="navbar-toggler-icon"></span>
        </button>
    </div>
</div>

<div class="@NavMenuCssClass nav-scrollable" @onclick="ToggleNavMenu">
    <nav class="flex-column">
        <div class="nav-item px-3">
            <NavLink class="nav-link" href="" Match="NavLinkMatch.All">
                <span class="oi oi-home" aria-hidden="true"></span> Products
            </NavLink>
        </div>

        <div class="nav-item px-3">
            <NavLink class="nav-link" href="createproduct">
                <span class="oi oi-tag" aria-hidden="true"></span> Add Product
            </NavLink>
        </div>
    </nav>
</div>

@code {
    private bool collapseNavMenu = true;

    private string? NavMenuCssClass => collapseNavMenu ? "collapse" : null;

    private void ToggleNavMenu()
    {
        collapseNavMenu = !collapseNavMenu;
    }
}
"@

	Set-Content -Path $fullPath -Value $newContent
}


function UpdateAppCss()
{
    $cssContent = @"

.scrollable-table {
    overflow-x: auto; 
    max-width: 100%;
}
"@

$cssPath = "src\$($projectName)\Client\wwwroot\css\app.css"

Add-Content -Path $cssPath -Value $cssContent
}


UpdateAppSettingsJson
UpdateServerProgramCs
UpdateClientProgramCs

UpdateCurrentUserServiceNamespace

UpdateControllerNamespaces
UpdateApiControllerBaseUsingStatement
UpdateApiExceptionFilterAttributeNamespace

CreateIProductApi
CreateResultClass
CreateProductDtoClass
CreateConfigureClientServices
CreateInfrastructureConfigureServices
CreateProductsController
CreateProductCommandFile
CreateProductCommandValidatorFile
CreateProductEntity
DeleteProductCommandFile
UpdateProductCommandFile
CreateGetAllProductsQueryFile
CreateGetProductByIdQueryFile
DeleteProductCommandValidatorFile
CreateGetProductByIdQueryValidatorFile
CreateGetProductsWithPaginationQuery
CreateGetProductsWithPaginationQueryValidator
CreateUpdateProductCommandValidator
CreateProductDtoValidator
CreateProductConfigurationFile
CreateProductCreatedEvent
CreateProductProfile
CreateCategoryEnum
CreateIPaginate
CreateIPaginationService
CreatePaginationService
CreateGenericPaginatorRazor
CreatePaginatedList
CreateIIdentityService
CreateMappingExtensions
CreateIdentityResultExtensions
CreateIdentityService

GenerateICsvBuilder
GenerateCsvBuilder
GenerateApplicationDbContextInitializer

UpdateIApplicationDbContext
UpdateApplicationDbContext
CreateProductPage
CreateUpdateProductPage
CreateIndexPage
UpdateNavMenuPage
UpdateAppCss