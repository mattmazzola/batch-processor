# Batch Processor

1 Read values
2 Add Result

## Docker setup

```powershell
docker build -t processor-node .
```

```powershell
Import-Module "C:/repos/shared-resources/pipelines/scripts/common.psm1" -Force

$envFilePath = $(Resolve-Path ".env").Path
$databaseUrl = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'DATABASE_URL'
$shadowDatabaseUrl = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'SHADOW_DATABASE_URL'

docker run -it --rm `
    -e DATABASE_URL=$databaseUrl `
    -e SHADOW_DATABASE_URL=$shadowDatabaseUrl `
    processor-node
```

## Scaling

- <https://learn.microsoft.com/en-us/azure/container-apps/scale-app?pivots=azure-cli#example-2>

## Links

- <https://www.youtube.com/watch?v=z_QnOKVpbkA>
- <https://www.youtube.com/watch?v=RRJn63wzrfM>