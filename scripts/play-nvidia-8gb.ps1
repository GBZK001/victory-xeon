param(
    [Parameter(Mandatory = $true)]
    [string]$Exe,
    [int]$DropMips = 2,
    [string]$Resolution = "1920x1080",
    [switch]$Borderless,
    [switch]$Water,
    [switch]$NoOverlay
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$victory = Join-Path $repoRoot "target\release\victory.exe"

if (-not (Test-Path $victory)) {
    Write-Error "Release binary not found at $victory. Build it first with: cargo build --release --bin victory"
    exit 1
}

Remove-Item Env:VICTORY_* -ErrorAction SilentlyContinue

if ($Resolution) {
    $env:VICTORY_RESOLUTION = $Resolution
}
if ($Borderless) {
    $env:VICTORY_BORDERLESS = "1"
}
if ($Water) {
    $env:VICTORY_TEXTURE_BACK = "1"
}
if ($NoOverlay) {
    $env:VICTORY_OVERLAY = "0"
}

$env:VICTORY_TEXTURE_DROP_MIPS = "$DropMips"
$env:VICTORY_COPY_PLAIN = "1"
$env:VICTORY_INDIRECT_GATHER = "1"
$env:VICTORY_HEAP_WORKER = "1"
$env:VICTORY_ALIAS_ONCE = "1"
$env:VICTORY_JOIN_PARTS = "1"
$env:VICTORY_BACK_OWN_VIEW = "1"
$env:VICTORY_INDIRECT_WINDOW_DRAWS = "1"
$env:VICTORY_GUARD_HOLES_FRAME = "1"
$env:VICTORY_COPY_CHANGED = "1"
$env:VICTORY_CARD_WINDOWS_MB = "2048"
$env:VICTORY_CARD_BUFFERS_MB = "1024"
$env:VICTORY_CLAMP_WAITS = "0"
$env:VICTORY_WIDE_MERGE = "1"
$env:VICTORY_RELAY_OWN_QUEUE = "1"

& $victory run --execute $Exe
