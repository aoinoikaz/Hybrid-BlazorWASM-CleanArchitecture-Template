:: Hybrid Blazor Web Assembly Clean Architecture Template
:: 26-09-2023

@echo off
setlocal


dotnet ef --version >NUL 2>&1

if %ERRORLEVEL% neq 0 (
    echo "NET CLI is not installed - attempting to install..."
    dotnet tool install --global dotnet-ef
)


set /p PROJECT_NAME="Enter the project name: "
set /p USE_AUTH="Do you want to include Authentication? (none/b2c/ad): "
set /p DATABASE_TYPE="Do you want to use an in-memory database or SQL? (in-memory/sql): "


if "%DATABASE_TYPE%"=="sql" (
    set /p INSTANCE_NAME="Please enter the SQL instance name: "
) else (
    set INSTANCE_NAME="N/A"
)


set "templateExists="

:: Check if the template exists in the global list of templates
for /f %%i in ('dotnet new --list ^| findstr "ca-sln"') do (
    set templateExists=%%i
)

:: Install the template if it doesn't exist
if not defined templateExists (
    dotnet new install "Clean.Architecture.Solution.Template"
)

:: Create base clean arch template
dotnet new ca-sln --name %PROJECT_NAME%

:: Delete the initial solution as we build our own
cd %PROJECT_NAME%
del %PROJECT_NAME%.sln

:: Clear the old webui tests folder
cd tests
rmdir /s /q WebUI.AcceptanceTests
cd ../


:: Create the hosted blazor web assembly project accordingly
cd src
if "%USE_AUTH%"=="b2c" (
    echo "Including Azure B2C Authentication."
    dotnet new blazorwasm -n %PROJECT_NAME% --hosted --output %PROJECT_NAME% --auth IndividualB2C
) else if "%USE_AUTH%"=="ad" (
    echo "Including Azure AD Authentication."
    dotnet new blazorwasm -n %PROJECT_NAME% --hosted --output %PROJECT_NAME% --auth SingleOrg
) else (
    echo "Creating without Authentication."
    dotnet new blazorwasm -n %PROJECT_NAME% --hosted --output %PROJECT_NAME%
)

cd %PROJECT_NAME%/Client
mkdir Features\Feature
cd Features/Feature
mkdir Components
mkdir Pages

cd ../../../../

:: Move over some dependencies we need from base ca-sln template
mkdir "%PROJECT_NAME%\Server\Filters"
mkdir "%PROJECT_NAME%\Server\Services"
move /y "WebUI\Services\CurrentUserService.cs" "%PROJECT_NAME%\Server\Services\"
move /y "WebUI\appsettings*.json" "%PROJECT_NAME%\Server\"
move /y "WebUI\Controllers\*" "%PROJECT_NAME%\Server\Controllers\"
move /y "WebUI\Filters\*" "%PROJECT_NAME%\Server\Filters\"

:: Clean up autogenerated webUI folder
rmdir /s /q WebUI

:: Also delete the auto generated sln, we'll make a new one
cd %PROJECT_NAME%
del %PROJECT_NAME%.sln

:: Remove the auto generated shared folder inside the hosted blazor as well
rmdir /s /q Shared

::Remove default migration as we will re migrate and update manually
cd ../Infrastructure/Persistence/Migrations
del *.* /Q
cd ../../../


cd Application
rmdir /s /q TodoItems
rmdir /s /q TodoLists
rmdir /s /q WeatherForecasts

cd ../

:: Delete more crap we dont need
del "Domain\Events\*.*" /Q
del "Domain\Entities\TodoItem.cs" /Q
del "Domain\Entities\TodoList.cs" /Q
del "Domain\Enums\PriorityLevel.cs" /Q
del "Application\Common\Models\LookupDto.cs" /Q

del "Infrastructure\Persistence\Configurations\TodoListConfiguration.cs" /Q
del "Infrastructure\Persistence\Configurations\TodoItemConfiguration.cs" /Q
del "Application\Common\Models\Result.cs" /Q
del "Application\Common\Models\PaginatedList.cs" /Q
del "Infrastructure\Files\Maps\TodoItemRecordMap.cs" /Q
del "%PROJECT_NAME%\Server\Controllers\TodoItemsController.cs" /Q
del "%PROJECT_NAME%\Server\Controllers\TodoListsController.cs" /Q
del "%PROJECT_NAME%\Server\Controllers\WeatherForecastController.cs" /Q
del "%PROJECT_NAME%\Client\Pages\FetchData.razor" /Q
del "%PROJECT_NAME%\Client\Pages\Counter.razor" /Q

:: Remove the initial references as we will configure them for our hybrid clean architecture
cd %PROJECT_NAME%/Client
dotnet remove reference ../Shared/%PROJECT_NAME%.Shared.csproj
cd ../Server
dotnet remove reference ../Shared/%PROJECT_NAME%.Shared.csproj
cd ../../


cd Application
mkdir Features\Feature
cd Features\Feature
mkdir Caching
mkdir Commands
mkdir EventHandlers
mkdir Queries
mkdir Validators
cd ../../../

:: Create the shared library 
mkdir Shared
cd Shared
dotnet new classlib -n Shared --output .
mkdir Common
mkdir Common\Exceptions
mkdir Common\Extensions
mkdir Common\Helpers
mkdir Common\Models
mkdir Common\Theme
mkdir DTOs
mkdir Enums
mkdir References
mkdir Validators

del "Class1.cs" /Q

cd ../../

:: Was easier to clean up the commands and put them
:: in their own powershell file
powershell -ExecutionPolicy Bypass -File "..\hbwc-commands.ps1" -projectName %PROJECT_NAME% -databaseType %DATABASE_TYPE% -instanceName %INSTANCE_NAME%

:: Setup clean arch reference structure
cd src/%PROJECT_NAME%/Client/
dotnet add reference ../../Shared/Shared.csproj

cd ../Server/
dotnet add reference ../../Application/Application.csproj
dotnet add reference ../../Infrastructure/Infrastructure.csproj
dotnet add reference ../../Shared/Shared.csproj

cd ../../Application
dotnet add reference ../Shared/Shared.csproj

cd ../../

dotnet new sln --name %PROJECT_NAME%

:: Add projects to solution
dotnet sln add src/%PROJECT_NAME%/Server/%PROJECT_NAME%.Server.csproj
dotnet sln add src/%PROJECT_NAME%/Client/%PROJECT_NAME%.Client.csproj
dotnet sln add src/Application/Application.csproj
dotnet sln add src/Domain/Domain.csproj
dotnet sln add src/Infrastructure/Infrastructure.csproj
dotnet sln add src/Shared/Shared.csproj

cd src/Infrastructure

dotnet add package Microsoft.EntityFrameworkCore.Tools --version 7.0.7 --source https://api.nuget.org/v3/index.json
dotnet add package Microsoft.EntityFrameworkCore.Design --version 7.0.7 --source https://api.nuget.org/v3/index.json

cd ../%PROJECT_NAME%/Client
dotnet add package Blazored.FluentValidation --version 2.1.0 --source https://api.nuget.org/v3/index.json
dotnet add package Refit --version 7.0.0 --source https://api.nuget.org/v3/index.json
dotnet add package Refit.HttpClientFactory --version 7.0.0 --source https://api.nuget.org/v3/index.json

cd ../Server
dotnet add package Microsoft.EntityFrameworkCore.Design --version 7.0.12 --source https://api.nuget.org/v3/index.json

cd ../../Shared
dotnet add package FluentValidation.DependencyInjectionExtensions --version 11.5.2 --source https://api.nuget.org/v3/index.json

cd ../../

dotnet restore %PROJECT_NAME%.sln

if "%DATABASE_TYPE%"=="sql" (
    powershell -ExecutionPolicy Bypass -File "..\hbwc-handle-migrations.ps1" -projectName %PROJECT_NAME%

    :: We need to clean and rebuild entire solution after we create custom migrations
    dotnet clean %PROJECT_NAME%.sln
    dotnet build %PROJECT_NAME%.sln
) else (
    echo "Using in-memory database. Skipping migrations."
)

echo "Project setup complete."
pause