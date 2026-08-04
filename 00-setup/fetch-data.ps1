# Downloads every no-login dataset into data/.
# Kaggle datasets need an account and are not handled here - see data/README.md.
# Usage:  pwsh -File 00-setup/fetch-data.ps1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path $root "data"

function Get-File($url, $dest) {
    if (Test-Path $dest) {
        Write-Host ("skip  {0} (already present)" -f (Split-Path $dest -Leaf))
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
    Write-Host ("get   {0}" -f (Split-Path $dest -Leaf))
    Invoke-WebRequest -Uri $url -OutFile $dest -TimeoutSec 600
    Write-Host ("      {0} MB" -f [math]::Round((Get-Item $dest).Length / 1MB, 2))
}

# Dataset A - Chinook, SQLite, ready to open
Get-File "https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite" `
         (Join-Path $data "chinook\Chinook_Sqlite.sqlite")

# Dataset B - Pagila, PostgreSQL dump
$pagilaZip = Join-Path $data "pagila\pagila-master.zip"
Get-File "https://github.com/devrimgunduz/pagila/archive/refs/heads/master.zip" $pagilaZip
if (-not (Test-Path (Join-Path $data "pagila\pagila-master"))) {
    Expand-Archive -Path $pagilaZip -DestinationPath (Join-Path $data "pagila") -Force
}

# Dataset C - sample CSVs.
# The datablist repo zip holds only generator scripts, so pull the real CSVs
# from the Google Drive ids listed in that repo's README.
$csv = [ordered]@{
    "customers-10000.csv"     = "1x2IdSNcHGLmot9i1h90gwMJr5lULC2QV"
    "customers-100000.csv"    = "1N1xoxgcw2K3d-49tlchXAWw4wuxLj7EV"
    "people-10000.csv"        = "1VEi-dnEh4RbBKa97fyl_Eenkvu2NC6ki"
    "people-100000.csv"       = "1NW7EnwxuY6RpMIxOazRVibOYrZfMjsb2"
    "organizations-10000.csv" = "13p-box0F9kou4wE9AyeBNKMSfE767xT-"
    "organizations-100000.csv"= "1g4wqEIsKyiBWeCAwd0wEkiC4Psc4zwFu"
    "leads-10000.csv"         = "1IHpMYaUbCwOjzVANMm818FlFG0u3-9iC"
}
foreach ($name in $csv.Keys) {
    Get-File ("https://drive.usercontent.google.com/download?id={0}&export=download&confirm=t" -f $csv[$name]) `
             (Join-Path $data "csv-samples\files\$name")
}

# Dataset C - NYC yellow cab trips. Change the month as needed.
Get-File "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet" `
         (Join-Path $data "nyc-taxi\yellow_tripdata_2024-01.parquet")

# Dataset D - GH Archive, one hour of GitHub events as JSON lines
Get-File "https://data.gharchive.org/2024-01-01-15.json.gz" `
         (Join-Path $data "gharchive\2024-01-01-15.json.gz")

# Online Retail - the primary UCI source for what Kaggle lists as carrie1/ecommerce-data.
# No account needed. Ships as .xlsx; convert to CSV with 00-setup/excel-to-csv.py.
$retailZip = Join-Path $data "online-retail\online-retail.zip"
Get-File "https://archive.ics.uci.edu/static/public/352/online+retail.zip" $retailZip
if (-not (Test-Path (Join-Path $data "online-retail\Online Retail.xlsx"))) {
    Expand-Archive -Path $retailZip -DestinationPath (Join-Path $data "online-retail") -Force
}

# Superstore - Tableau's public sample data, the origin of the Kaggle superstore dataset.
# Three sheets: Orders, People, Returns.
Get-File "https://public.tableau.com/app/sample-data/sample_-_superstore.xls" `
         (Join-Path $data "superstore\sample-superstore.xls")

Write-Host ""
Write-Host "done. see data/README.md for load instructions."
Write-Host "to regenerate the CSVs from the Excel sources: python 00-setup/excel-to-csv.py"
