# Schultz Tables

```
npm run dev
```

## Docker

```
docker build -t batch-processor-client .
```

```powershell
$sharedResourceGroupName = "shared"
$sharedRgString = 'klgoyi'

Import-Module "C:/repos/shared-resources/pipelines/scripts/common.psm1" -Force

$sharedResourceNames = Get-ResourceNames $sharedResourceGroupName $sharedRgString

$envFilePath = $(Resolve-Path ".env").Path
$databaseUrl = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'DATABASE_URL'
$shadowDatabaseUrl = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'SHADOW_DATABASE_URL'

docker run -it --rm `
    -p 3000:8080 `
    -e DATABASE_URL=$databaseUrl `
    -e SHADOW_DATABASE_URL=$shadowDatabaseUrl `
    batch-processor-client
```

## 1 Run SQL Database Locally

[Prisma Docker Docs](https://www.prisma.io/docs/concepts/database-connectors/sql-server/sql-server-docker)

```
docker run -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD=<YourStrong@Passw0rd>' -p 1433:1433 --name sql1 -d mcr.microsoft.com/mssql/server:2019-latest
```

```
docker exec -it sql1 "bash"
```

```
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "<YourStrong@Passw0rd>"
```

```
CREATE DATABASE batchprocessor
GO
CREATE DATABASE batchprocessorshadow
GO
```

## 2 Initialize Prisma for Database

<https://remix.run/docs/en/v1/tutorials/jokes#set-up-prisma>
```
npx prisma init --datasource-provider sqlserver
```

## 2 Use Prisma to execute command against DB

<https://www.prisma.io/docs/reference/api-reference/command-reference#db-execute>

```
npx prisma db push
```
