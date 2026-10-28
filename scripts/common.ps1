$ErrorActionPreference = 'Continue'

function Get-ProjectRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Import-DotEnv {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontro el archivo de entorno: $Path"
    }

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $text = $line.Trim()
        if ($text -eq '' -or $text.StartsWith('#')) { continue }

        $idx = $text.IndexOf('=')
        if ($idx -lt 1) { continue }

        $key = $text.Substring(0, $idx).Trim()
        $value = $text.Substring($idx + 1).Trim()

        if ($value.Length -ge 2) {
            $first = $value.Substring(0, 1)
            $last = $value.Substring($value.Length - 1, 1)
            if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }

        $values[$key] = $value
        Set-Item -Path "Env:$key" -Value $value
    }

    return $values
}

function Invoke-Compose {
    param([string[]]$ComposeArgs)

    $root = Get-ProjectRoot
    & docker compose --project-directory $root @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose fallo: $($ComposeArgs -join ' ')"
    }
}

function Wait-ForHealthy {
    param(
        [string[]]$Containers,
        [int]$TimeoutSeconds = 420
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    foreach ($container in $Containers) {
        while ($true) {
            $status = (& docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $container 2>$null)
            if ($LASTEXITCODE -ne 0) { $status = 'missing' }

            if ($status -eq 'healthy' -or $status -eq 'running') {
                Write-Host "[ok] $container -> $status"
                break
            }

            if ((Get-Date) -gt $deadline) {
                throw "Tiempo de espera agotado para $container (estado: $status)"
            }

            Write-Host "[..] esperando $container ($status)"
            Start-Sleep -Seconds 5
        }
    }
}

function Invoke-PsqlFile {
    param(
        [string]$RelativePath,
        [hashtable]$Variables = @{}
    )

    $cmdArgs = @(
        'exec', '-i', '-e', 'PGOPTIONS=-c client_min_messages=error',
        'medical_pg',
        'psql', '-U', $env:PG_USER, '-d', $env:PG_DB,
        '-v', 'ON_ERROR_STOP=1'
    )

    foreach ($key in $Variables.Keys) {
        $cmdArgs += @('-v', "$key=$($Variables[$key])")
    }

    $cmdArgs += @('-f', "/sql/$RelativePath")

    & docker @cmdArgs
    if ($LASTEXITCODE -ne 0) {
        throw "psql fallo ejecutando $RelativePath"
    }
}

function Invoke-PsqlQuery {
    param(
        [string]$Sql,
        [string]$User = $env:PG_USER,
        [string]$Database = $env:PG_DB,
        [switch]$TupleOnly
    )

    $cmdArgs = @(
        'exec', '-i', '-e', 'PGOPTIONS=-c client_min_messages=error',
        'medical_pg',
        'psql', '-U', $User, '-d', $Database,
        '-v', 'ON_ERROR_STOP=1', '-P', 'pager=off'
    )

    if ($TupleOnly) { $cmdArgs += @('-t', '-A') }
    $cmdArgs += @('-c', $Sql)

    $output = & docker @cmdArgs
    if ($LASTEXITCODE -ne 0) {
        throw "psql fallo ejecutando consulta"
    }

    return ($output -join "`n")
}

function Invoke-SqlcmdFile {
    param(
        [string]$RelativePath,
        [hashtable]$Variables = @{}
    )

    $root = Get-ProjectRoot
    $path = Join-Path $root "sql/sqlserver/$RelativePath"

    $cmdArgs = @(
        '-S', "localhost,$($env:MSSQL_PORT)",
        '-U', 'sa',
        '-P', $env:MSSQL_SA_PASSWORD,
        '-C', '-b', '-f', '65001',
        '-i', $path
    )

    foreach ($key in $Variables.Keys) {
        $cmdArgs += @('-v', "$key=$($Variables[$key])")
    }

    & sqlcmd @cmdArgs
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd fallo ejecutando $RelativePath"
    }
}

function Invoke-MongoScript {
    param(
        [string]$ScriptName,
        [hashtable]$EnvVars = @{}
    )

    $cmdArgs = @('exec', '-i')
    foreach ($key in $EnvVars.Keys) {
        $cmdArgs += @('-e', "$key=$($EnvVars[$key])")
    }

    $cmdArgs += @(
        'medical_mongo',
        'mongosh', '--quiet',
        '-u', $env:MONGO_ROOT_USER,
        '-p', $env:MONGO_ROOT_PASSWORD,
        '--authenticationDatabase', 'admin',
        "/scripts/$ScriptName"
    )

    & docker @cmdArgs
    if ($LASTEXITCODE -ne 0) {
        throw "mongosh fallo ejecutando $ScriptName"
    }
}

function Invoke-MongoEval {
    param(
        [string]$Expression,
        [hashtable]$EnvVars = @{}
    )

    $cmdArgs = @('exec', '-i')
    foreach ($key in $EnvVars.Keys) {
        $cmdArgs += @('-e', "$key=$($EnvVars[$key])")
    }

    $cmdArgs += @(
        'medical_mongo',
        'mongosh', '--quiet',
        '-u', $env:MONGO_ROOT_USER,
        '-p', $env:MONGO_ROOT_PASSWORD,
        '--authenticationDatabase', 'admin',
        '--eval', $Expression
    )

    $output = & docker @cmdArgs
    if ($LASTEXITCODE -ne 0) {
        throw "mongosh fallo ejecutando eval"
    }

    return ($output -join "`n")
}


