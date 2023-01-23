# Batch Processor

1 Read values
2 Add Result

## Docker setup

```powershell
docker build -t processor-node .
```

```powershell
docker run -it --rm `
    processor-node `
    -e DATABASE_URL=a `
    -e SHADOW_DATABASE_URL=a `
    batch-processor-client
```

## Scaling

- <https://learn.microsoft.com/en-us/azure/container-apps/scale-app?pivots=azure-cli#example-2>