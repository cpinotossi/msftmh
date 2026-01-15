# Docker Desktop PowerShell Cheatsheet

## Start Docker Desktop (Headless/Background)

```powershell
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Hidden
```

## Verify Docker is Running

```powershell
docker info
```
