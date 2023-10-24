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


function RemoveMicrosoftIdentityWebApiForB2C 
{
    $filePath = "src\$projectName\Server\Program.cs"
    $content = Get-Content -Path $filePath -Raw
    $modifiedContent = $content -replace '\s*\.AddMicrosoftIdentityWebApi\(builder\.Configuration\.GetSection\("AzureAdB2C"\)\);', ''
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



function UpdateServerProgramCs 
{
    $programPath = "src\$projectName\Server\Program.cs"
    $programContent = Get-Content -Path $programPath

    # Lines to add under the 'using' section
    $newUsings = @("using $projectName.Application.Common.Interfaces;", "using $projectName.Server.Services;")
    
    $linesToRemove = @(
        "// Add services to the container.",
        "builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)",
        "app.UseAuthorization();",
        "    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection(`"AzureAd`"));"
    )

    # Remove unwanted lines
    $filteredContent = $programContent | Where-Object { $_ -notin $linesToRemove }

    # Add the new 'using' statements if they don't already exist
    foreach ($newUsing in $newUsings) 
	{
        if ($filteredContent -notcontains $newUsing) 
		{
            $filteredContent = @($newUsing) + $filteredContent
        } 
    }

    # Modify builder lines
    $insertLines = "builder.Services.AddScoped<ICurrentUserService, CurrentUserService>();`r`nbuilder.Services.AddApplicationServices();`r`nbuilder.Services.AddInfrastructureServices(builder.Configuration);"
    $filteredContent = $filteredContent -replace '(var builder = WebApplication\.CreateBuilder\(args\);)', ('$1' + "`r`n" + $insertLines)

    # Save the new content
    $filteredContent -join [System.Environment]::NewLine | Set-Content -Path $programPath
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

public interface IProductApi
{
    [Get("/api/Products")]
    Task<IEnumerable<ProductDto>> GetProductsAsync();

    [Get("/api/Products/{id}")]
    Task<ProductDto> GetProductByIdAsync(int id);

    [Post("/api/Products")]
    Task<Result<int>> CreateProductAsync(ProductDto product);

    [Put("/api/Products/{id}")]
    Task<Result> UpdateProductAsync(int id, ProductDto product);

    [Delete("/api/Products/{id}")]
    Task<Result> DeleteProductAsync(int id);
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

    public Result(T data, bool succeeded)
    {
        Data = data;
        Succeeded = succeeded;
    }

    public static Result<T> Success(T data)
    {
        return new Result<T>(data, true);
    }

    public static Result<T> Failure(T data, IDictionary<string, IEnumerable<string>>? fieldErrors = null, IEnumerable<string>? generalErrors = null)
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
    public bool IsAvailable { get; set; }
    public Category Category { get; set; }
    public string? Brand { get; set; }
    public DateTime? ReleaseDate { get; set; }
    public string? ImageUrl { get; set; }
}
"@
    New-Item -Path $filePath -ItemType File
    Set-Content -Path $filePath -Value $content
}


function CreateProductListingDto() 
{
    $directory = "src\Application\Common\Models"
	
    if (-Not (Test-Path $directory)) 
	{
        New-Item -Path $directory -ItemType Directory
    }

    $filePath = Join-Path -Path $directory -ChildPath "ProductListingDto.cs"
	
    $content = @"
using $($projectName).Application.Common.Mappings;
using $($projectName).Domain.Entities;
using $($projectName).Domain.Enums;

namespace $($projectName).Application.Common.Models
{
    public class ProductListingDto : IMapFrom<Product>
    {
        public int Id { get; init; }
        public string? Name { get; init; }
        public decimal Price { get; init; }
        public Category Category { get; init; }
        public string? Brand { get; init; }
        public bool IsAvailable { get; init; }
        public string? ImageUrl { get; init; }
        
        // Automapper mapping configuration
        public void Mapping(Profile profile)
        {
            profile.CreateMap<Product, ProductListingDto>()
                .ForMember(dto => dto.Name, opt => opt.MapFrom(src => src.Name))
                .ForMember(dto => dto.Price, opt => opt.MapFrom(src => src.Price))
                .ForMember(dto => dto.Category, opt => opt.MapFrom(src => src.Category))
                .ForMember(dto => dto.Brand, opt => opt.MapFrom(src => src.Brand))
                .ForMember(dto => dto.IsAvailable, opt => opt.MapFrom(src => src.IsAvailable))
                .ForMember(dto => dto.ImageUrl, opt => opt.MapFrom(src => src.ImageUrl));
        }
    }
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
using Microsoft.AspNetCore.Mvc;
using $($projectName).Shared.DTOs;
using $($projectName).Shared.Common.Models;
using $($projectName).Application.Common.Exceptions;
using System.Linq;

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

            if (product != null)
            {
                return Ok(product);
            }
            else
            {
                return NotFound(); // Product with the given ID was not found.
            }
        }
        catch (NotFoundException)
        {
            return NotFound(); // Handle the case where the requested product was not found.
        }
    }


    [HttpPost]
    public async Task<ActionResult<Result<int>>> Create([FromBody] CreateProductCommand command)
    {
        var result = await Mediator.Send(command);

        if (result.Succeeded)
        {
            return CreatedAtAction(nameof(GetAll), new { id = result.Data }, result);
        }
        else
        {
            if (result.FieldErrors.Any())
            {
                return BadRequest(result);
            }
            return StatusCode(500, result.GeneralErrors);
        }
    }


    [HttpPut("{id}")]
    public async Task<ActionResult<Result>> Update(int id, [FromBody] UpdateProductCommand command)
    {
        if (id != command.Id)
        {
            return BadRequest(new { Error = "Mismatched product ID" });
        }

        var result = await Mediator.Send(command);

        if (result.Succeeded)
        {
            return Ok(result);
        }
        else
        {
            if (result.FieldErrors.Any())
            {
                return BadRequest(result);
            }
            return StatusCode(500, result.GeneralErrors);
        }
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult<Result>> Delete(int id)
    {
        var result = await Mediator.Send(new DeleteProductCommand(id));

        if (result.Succeeded)
        {
            return Ok(result);
        }
        else
        {
            if (result.FieldErrors.Any())
            {
                return BadRequest(result);
            }
            return StatusCode(500, result.GeneralErrors);
        }
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
using $($projectName).Shared.Common.Models;
using MediatR;

namespace $($projectName).Application.Features.Products.Commands;

public record CreateProductCommand(string Name, decimal Price) : IRequest<Result<int>>;

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
            var product = new Product { Name = request.Name, Price = request.Price };
            _dbContext.Products.Add(product);
            await _dbContext.SaveChangesAsync(cancellationToken);
            return Result<int>.Success(product.Id);
        }
        catch (Exception ex)
        {
            return Result<int>.Failure(-1, generalErrors: new string[] {ex.Message});
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
            var product = await _dbContext.Products.FindAsync(request.Id);
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
using $($projectName).Shared.Common.Models;
using MediatR;

namespace $($projectName).Application.Features.Products.Commands;

public record UpdateProductCommand(int Id, string Name, decimal Price) : IRequest<Result<int>>;

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
            var product = await _dbContext.Products.FindAsync(request.Id);
            if (product == null) return Result<int>.Failure(-1, generalErrors: new string[] { "Product not found." });

            product.Name = request.Name;
            product.Price = request.Price;

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
            Price = product.Price
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
using MediatR;

namespace $($projectName).Application.Features.Products.Queries;

public class GetProductByIdQuery : IRequest<ProductDto>
{
    public int Id { get; set; }
}


public class GetProductByIdQueryHandler : IRequestHandler<GetProductByIdQuery, ProductDto>
{
    private readonly IApplicationDbContext _context;

    public GetProductByIdQueryHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<ProductDto> Handle(GetProductByIdQuery request, CancellationToken cancellationToken)
    {
        // Retrieve the product by its Id from the data source.
        var product = await _context.Products.FindAsync(request.Id);

        if (product != null)
        {
            // Map the entity to a DTO or ViewModel as needed.
            var productDto = new ProductDto
            {
                Id = product.Id,
                Name = product.Name,
                Price = product.Price,
                // Map other properties here...
            };

            return productDto;
        }

        return null; // Return null if the product is not found.
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
            Price = command.Price
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
            Price = command.Price
        }).SetValidator(new ProductDtoValidator());

        RuleFor(command => command.Name).Must(IsNameUnique).WithMessage("Product name must be unique.");
    }

    private bool Exist(int id)
    {
        return _context.Products.Any(product => product.Id == id);
    }

    private bool IsNameUnique(UpdateProductCommand command, string name)
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
using AutoMapper.QueryableExtensions;
using $($projectName).Application.Common.Interfaces;
using $($projectName).Application.Common.Mappings;
using $($projectName).Application.Common.Models;
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
    private readonly IApplicationDbContext _context;
    private readonly IMapper _mapper;

    public GetProductsWithPaginationQueryHandler(IApplicationDbContext context, IMapper mapper)
    {
        _context = context;
        _mapper = mapper;
    }

    public async Task<PaginatedList<ProductDto>> Handle(GetProductsWithPaginationQuery request, CancellationToken cancellationToken)
    {
        return await _context.Products
            .OrderBy(x => x.Name)
            .ProjectTo<ProductDto>(_mapper.ConfigurationProvider)
            .PaginatedListAsync(request.PageNumber, request.PageSize);
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
        RuleFor(product => product.Name).NotEmpty().WithMessage("Name is required.").
               Length(2, 50).WithMessage("Name must be between 2 and 50 characters.");

        RuleFor(product => product.Price).NotEmpty().WithMessage("Price is required.")
                .GreaterThan(0).WithMessage("Price must be greater than 0.");

    }
}
"@
    # Write the content to the file
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
    public string Name { get; set; }
    public string Description { get; set; }
    public decimal Price { get; set; }
    public int StockQuantity { get; set; }
    public string SKU { get; set; }  // Stock Keeping Unit
    public bool IsAvailable => StockQuantity > 0;
    public Category Category { get; set; }
    public string Brand { get; set; }
    public DateTime? ReleaseDate { get; set; }
    public string ImageUrl { get; set; }
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
        // Configure the Price property to have a precision of 18 with 2 decimal places.
        builder.Property(p => p.Price)
            .HasColumnType("decimal(18,2)")
            .IsRequired();

        // You can add more property configurations as required.
        // Example: Configuring a string property to have a max length.
        // builder.Property(p => p.ProductName)
        //    .HasMaxLength(200)
        //    .IsRequired();
    }
}
"@
    Set-Content -Path $filePath -Value $content
}



function CreateProductRecordMap()
{
    $fullPath = "src\Infrastructure\Files\Map\ProductRecordMap.cs"

	$newContent = @"
using CsvHelper.Configuration;
using System.Globalization;
using $($projectName).Shared.DTOs;

namespace $($projectName).Infrastructure.Files.Maps
{
    public class ProductRecordMap : ClassMap<ProductDto>
    {
        public ProductRecordMap()
        {
            AutoMap(CultureInfo.InvariantCulture);

            Map(m => m.Name).Name("Product Name");
            Map(m => m.Description).Name("Description");
            Map(m => m.Price).Name("Price");
            Map(m => m.SKU).Name("SKU");
            Map(m => m.Category).Name("Category");
            Map(m => m.Brand).Name("Brand");
            Map(m => m.ReleaseDate).Name("Release Date").TypeConverterOption.Format("yyyy-MM-dd");
            Map(m => m.ImageUrl).Name("Image URL");
            // ... add other mappings as needed
        }
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
                new Product() { Name = "GTA 5", Price = 89.99m },
                new Product() { Name = "GTA 6",  Price = 149.99m },
                new Product() { Name = "Black Ops 3", Price = 79.99m },
                new Product() { Name = "Modern Warfare 3", Price = 99.99m },
                new Product() { Name = "Elden Ring", Price = 9.99m },
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

<h1>Create Product</h1>

@code {
    public ProductDto? Model { get; set; }
    private EditContext? editContext;
    private bool isLoading = false;

    protected override void OnInitialized()
    {
        Model ??= new();
        editContext = new EditContext(Model);
    }

    private async Task SubmitAsync()
    {
        isLoading = true;

        Result<int>? response = null;

        if (Model != null)
        {
            Console.WriteLine("Product isn't null: " + Model.Name + " | " + Model.Price);

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
            catch (ApiException)
            {
                await JSRuntime.InvokeVoidAsync("alert", "Name must be unique");
            }
            finally
            {
                isLoading = false;
            }
        }
    }
}

<EditForm OnValidSubmit="@SubmitAsync" EditContext="@editContext">
    <FluentValidationValidator />
    <div class="mx-12 row">
        <div class="mb-7 col-md-6">
            <label class="form-label required">Name</label>
            <InputText class="form-control" @bind-Value="Model.Name" />
        </div>
        <div class="mb-7 col-md-6">
            <label class="form-label required">Price</label>
            <InputNumber class="form-control" @bind-Value="Model.Price" />
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
<PageTitle>Edit Product</PageTitle>

<h1>Edit Product</h1>

@if (product == null)
{
    <p><em>Loading...</em></p>
}
else
{
    <EditForm OnValidSubmit="@Update" EditContext="@editContext">
    <FluentValidationValidator />
    <div class="mx-12 row">
        <div class="mb-7 col-md-6">
            <label class="form-label required">Name</label>
            <InputText class="form-control" @bind-Value="product.Name" />
        </div>
        <div class="mb-7 col-md-6">
            <label class="form-label required">Price</label>
            <InputNumber class="form-control" @bind-Value="product.Price" />
        </div>
        <ValidationSummary />

        <div class="d-flex">
            <button type="submit" class="btn btn-primary btn-icon-light w-125px">Update</button>
        </div>
       
    </div>
    </EditForm>
   
}

@code {
    private ProductDto? product;

    [Parameter]
    public int Id { get; set; }

    private EditContext? editContext;

    protected override async Task OnInitializedAsync()
    {
        try
        {
            product = await ProductApi.GetProductByIdAsync(Id);
            editContext = new EditContext(product);
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
                result = await ProductApi.UpdateProductAsync(Id, product);
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
        catch (ApiException)
        {
            await JSRuntime.InvokeVoidAsync("alert", "Name must be unique");
        }
    }
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
@using $($projectName).Shared.DTOs;
@using Refit;

@inject IProductApi ProductApi
@inject NavigationManager NavigationManager

<PageTitle>Products</PageTitle>

<h1>Products List</h1>

@if (products == null)
{
    <p><em>Loading...</em></p>
}
else
{
    <table class="table">
        <thead>
            <tr>
                <th>Id</th>
                <th>Name</th>
                <th>Price</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            @foreach (var product in products)
            {
                <tr>
                    <td>@product.Id</td>
                    <td>@product.Name</td>
                    <td>@product.Price</td>
                    <td>
                        <button class="btn btn-primary" @onclick="() => UpdateProduct(product.Id)">Edit</button>
                        <button class="btn btn-danger" @onclick="() => DeleteProduct(product.Id)">Delete</button>
                    </td>
                </tr>
            }
        </tbody>
    </table>
}

@code {
    private List<ProductDto>? products;

    protected override async Task OnInitializedAsync()
    {
        try
        {
            products = (await ProductApi.GetProductsAsync()).ToList();
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
            if (result.Succeeded)
            {
                products = products.Where(p => p.Id != productId).ToList();
                StateHasChanged();
            }
            else
            {
                // Handle the error appropriately
            }
        }
        catch (ApiException)
        {
            // Handle API exception as needed
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
        <a class="navbar-brand" href="">DashboardV2</a>
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



UpdateAppSettingsJson
UpdateServerProgramCs
UpdateClientProgramCs
UpdateCurrentUserServiceNamespace

UpdateControllerNamespaces
UpdateApiControllerBaseUsingStatement
UpdateApiExceptionFilterAttributeNamespace

RemoveMicrosoftIdentityWebApiForB2C
CreateIProductApi
CreateResultClass
CreateProductDtoClass
CreateConfigureClientServices
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
CreateProductRecordMap
CreateProductListingDto

GenerateICsvBuilder
GenerateCsvBuilder
GenerateApplicationDbContextInitializer

UpdateIApplicationDbContext
UpdateApplicationDbContext
CreateProductPage
CreateUpdateProductPage
CreateIndexPage
UpdateNavMenuPage