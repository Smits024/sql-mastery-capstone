<#
Sets this project up on a new machine from GitHub alone. No browser needed.

Run it from anywhere - it clones the repo, then verifies every dataset actually
arrived intact. Datasets are committed, so nothing else needs downloading.

    # download this one file, or paste the whole thing into a PowerShell window
    pwsh -File bootstrap.ps1
    pwsh -File bootstrap.ps1 -Target "D:\projects" -Shallow

  -Target   where to put the clone. Default: current directory.
  -Shallow  clone only the latest commit. Much faster and about half the
            download, but you lose history. Fine if you only want the files.
#>

[CmdletBinding()]
param(
    [string] $Target = (Get-Location).Path,
    [switch] $Shallow
)

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/Smits024/sql-mastery-capstone.git"
$Name    = "sql-mastery-capstone"
$Dest    = Join-Path $Target $Name

function Say($msg)  { Write-Host $msg }
function Ok($msg)   { Write-Host "  OK   $msg" }
function Bad($msg)  { Write-Host "  FAIL $msg" }

# --- preflight ---------------------------------------------------------------
Say "checking git"
try {
    $v = (git --version) 2>&1
    Ok $v
} catch {
    Bad "git is not installed or not on PATH."
    Say ""
    Say "Install Git first: https://git-scm.com/download/win"
    Say "Or use IntelliJ's bundled client: File > New > Project from Version Control"
    exit 1
}

if (Test-Path $Dest) {
    Bad "$Dest already exists. Move or rename it, or pass a different -Target."
    exit 1
}
New-Item -ItemType Directory -Force -Path $Target | Out-Null

# --- clone -------------------------------------------------------------------
# The repo is public, so no token, no login, no browser.
Say ""
Say "cloning $RepoUrl"
Say "about 270 MB of data is committed, so this takes a few minutes"
$gitArgs = @("clone", "--progress")
if ($Shallow) { $gitArgs += @("--depth", "1") }
$gitArgs += @($RepoUrl, $Dest)
git @gitArgs
if ($LASTEXITCODE -ne 0) {
    Bad "clone failed."
    Say ""
    Say "If this machine sits behind a proxy, set it and retry:"
    Say '  git config --global http.proxy http://user:pass@proxyhost:port'
    Say "If HTTPS to github.com is blocked entirely, no script can work around that -"
    Say "copy the folder across on a USB drive instead."
    exit 1
}

Set-Location $Dest

# --- verify ------------------------------------------------------------------
# A clone can succeed and still hand you truncated or line-ending-mangled data,
# so check the real contents rather than trusting exit code 0.
Say ""
Say "verifying datasets"
$fail = 0

$expect = @(
    @{ p = "data\chinook\Chinook_Sqlite.sqlite";               mb = 0.96 },
    @{ p = "data\nyc-taxi\yellow_tripdata_2024-01.parquet";    mb = 47.6 },
    @{ p = "data\gharchive\2024-01-01-15.json.gz";             mb = 79.3 },
    @{ p = "data\online-retail\online-retail.csv";             mb = 45.8 },
    @{ p = "data\superstore\superstore-orders.csv";            mb = 2.3  },
    @{ p = "data\hr\HRDataset_v14.csv";                        mb = 0.07 },
    @{ p = "data\pagila\pagila-master\pagila-schema.sql";      mb = 0.09 },
    @{ p = "data\pagila\pagila-master\pagila-data.sql";        mb = 12.4 },
    @{ p = "data\csv-samples\files\customers-100000.csv";      mb = 16.5 }
)

foreach ($e in $expect) {
    if (-not (Test-Path $e.p)) { Bad "missing  $($e.p)"; $fail++; continue }
    $mb = (Get-Item $e.p).Length / 1MB
    # 15% tolerance absorbs any line-ending difference without hiding a truncated file
    if ($mb -lt ($e.mb * 0.85)) {
        Bad ("{0}  {1:N1} MB, expected about {2:N1} MB" -f $e.p, $mb, $e.mb)
        $fail++
    } else {
        Ok ("{0,-52} {1,7:N1} MB" -f $e.p, $mb)
    }
}

# format spot checks - a wrong magic number means the file was mangled in transit
$sig = @(
    @{ p = "data\chinook\Chinook_Sqlite.sqlite";            want = "SQLite format 3"; n = 15 },
    @{ p = "data\nyc-taxi\yellow_tripdata_2024-01.parquet"; want = "PAR1";            n = 4  }
)
foreach ($s in $sig) {
    if (-not (Test-Path $s.p)) { continue }
    $fs = [System.IO.File]::OpenRead((Resolve-Path $s.p))
    $b = New-Object byte[] $s.n
    $fs.Read($b, 0, $s.n) | Out-Null
    $fs.Close()
    $got = [System.Text.Encoding]::ASCII.GetString($b)
    if ($got -eq $s.want) { Ok "$($s.want) signature intact" }
    else { Bad "$($s.p) signature is '$got', expected '$($s.want)'"; $fail++ }
}

Say ""
if ($fail -gt 0) {
    Bad "$fail check(s) failed. Try: git fsck, or re-clone."
    exit 1
}
Ok "all datasets present and intact"

# --- next steps --------------------------------------------------------------
Say ""
Say "cloned to: $Dest"
Say ""
Say "To open in IntelliJ:"
Say "  File > Open  ->  pick the folder above  ->  Trust Project"
Say ""
Say "Or let IntelliJ do the clone itself, no browser required:"
Say "  File > New > Project from Version Control"
Say "  URL: $RepoUrl"
Say ""
Say "Git identity for this repo is not set. If you will commit, run:"
Say '  git config --local user.name  "Your Name"'
Say '  git config --local user.email "you@example.com"'
Say ""
Say "See README.md for layout and data/README.md for load instructions."
