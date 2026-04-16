param(
    [string]$ClangPath = (Join-Path $PSScriptRoot "..\\build-hotshot\\bin\\clang.exe"),
    [string]$VcVarsPath = "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat",
    [string]$OutDir = (Join-Path $PSScriptRoot "out")
)

$ErrorActionPreference = "Stop"

$Source = Join-Path $PSScriptRoot "hotshot_test.c"
$CommonFlags = @(
    "-O0",
    "-Xclang", "-disable-O0-optnone",
    "-fno-inline",
    "-fms-extensions",
    "-o"
)

$variants = @(
    @{ Name = "plain"; Passes = $null; EnableBackend = $false },
    @{ Name = "backend"; Passes = $null; EnableBackend = $true },
    @{ Name = "fla"; Passes = "fla"; EnableBackend = $false },
    @{ Name = "gvenc"; Passes = "gvenc"; EnableBackend = $false },
    @{ Name = "indcall"; Passes = "indcall"; EnableBackend = $false },
    @{ Name = "indbr"; Passes = "indbr"; EnableBackend = $false },
    @{ Name = "alias"; Passes = "alias"; EnableBackend = $false },
    @{ Name = "bcf"; Passes = "bcf"; EnableBackend = $false },
    @{ Name = "sub"; Passes = "sub"; EnableBackend = $false },
    @{ Name = "merge"; Passes = "merge"; EnableBackend = $false },
    @{ Name = "mba"; Passes = "mba"; EnableBackend = $false },
    @{ Name = "ccc"; Passes = "ccc"; EnableBackend = $false },
    @{ Name = "all"; Passes = "fla,gvenc,indcall,indbr,alias,bcf,sub,merge,mba,ccc"; EnableBackend = $true }
)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$results = @()

foreach ($variant in $variants) {
    $exe = Join-Path $OutDir ("hotshot_" + $variant.Name + ".exe")
    $args = New-Object System.Collections.Generic.List[string]
    $args.Add($Source)
    if ($variant.EnableBackend) {
        $args.Add("-DENABLE_HOTSHOT_MARKER")
    }
    if ($variant.Passes) {
        $args.Add("-mllvm")
        $args.Add("-passes=" + $variant.Passes)
    }
    foreach ($flag in $CommonFlags) {
        $args.Add([string]$flag)
    }
    $args.Add($exe)

    $clangArgs = ($args | ForEach-Object {
        if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
    }) -join " "

    $command = @(
        '"' + $VcVarsPath + '"',
        "&&",
        '"' + $ClangPath + '"',
        $clangArgs
    ) -join " "

    Write-Host ("[build] " + $variant.Name)
    cmd.exe /d /s /c $command | Out-Host

    $buildStatus = if ($LASTEXITCODE -eq 0) { "compiled" } else { "build_failed" }
    $runStatus = "not_run"
    $output = ""

    if ($buildStatus -eq "compiled") {
        if (Test-Path $exe) {
            try {
                $output = (& $exe 2>&1 | Out-String).Trim()
                if ($LASTEXITCODE -eq 0 -and $output -eq "hotshot-message:291") {
                    $runStatus = "ok"
                } elseif ($LASTEXITCODE -ne 0) {
                    $runStatus = "runtime_failed"
                } else {
                    $runStatus = "unexpected_output"
                }
            } catch {
                if (Test-Path $exe) {
                    $runStatus = "blocked"
                    $output = $_.Exception.Message
                } else {
                    $runStatus = "quarantined"
                    $output = $_.Exception.Message
                }
            }
        } else {
            $runStatus = "quarantined"
        }
    }

    $results += [pscustomobject]@{
        Name = $variant.Name
        BuildStatus = $buildStatus
        RunStatus = $runStatus
        Output = $output
        FileExists = (Test-Path $exe)
        Path = $exe
    }
}

$summaryPath = Join-Path $OutDir "summary.json"
$results | ConvertTo-Json -Depth 3 | Set-Content -Encoding ASCII $summaryPath
$results | Format-Table -AutoSize | Out-Host
Write-Host ("Wrote summary to " + $summaryPath)
