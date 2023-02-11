FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /app

# Restore as distinct layers
COPY *.csproj .
RUN dotnet restore

# Build and publish a release
COPY . ./
RUN dotnet publish -c Release -o out

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:7.0
WORKDIR /app
COPY --from=build /app/out .

ENTRYPOINT ["dotnet", "dotnet-processor.dll"]
