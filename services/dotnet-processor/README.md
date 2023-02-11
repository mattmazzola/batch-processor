# dotnet-processor

## Using Docker

### Build

```powershell
docker build -t dotnet-processor `
    -f Dockerfile .
```

### Run

```powershell
docker run `
    --rm `
    -it `
    --name dotnet-processor `
    dotnet-processor
```

### Exec Bash

```powershell
docker run `
    --rm `
    -it `
    --entrypoint /bin/bash `
    dotnet-processor
```
