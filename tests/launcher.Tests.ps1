# Tests for claude-code/shell/kanyerdr.ps1 with fake hc and claude executables.
# Usage: pwsh -NoProfile -File tests/launcher.Tests.ps1
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$script = Join-Path $here '../kanyerdr/claude-code/shell/kanyerdr.ps1'
$fakes = Join-Path $here 'fixtures/bin'
$sep = [IO.Path]::PathSeparator
$script:pass = 0; $script:fail = 0
$cfg = Join-Path ([IO.Path]::GetTempPath()) ("kyd-cfg-" + [guid]::NewGuid())
New-Item -ItemType Directory $cfg | Out-Null

# Run claude in a fresh pwsh with the launcher loaded; return its output lines.
function Invoke-Case([hashtable]$envs, [string]$prelude, [string[]]$argv) {
  $saved = @{}
  $all = @{ PATH = "$fakes$sep/usr/bin$sep/bin"; HC_TERMINAL_ID = $null; FAKE_HC_JSON = $null; FAKE_HC_EXIT = $null; CLAUDE_CONFIG_DIR = $cfg }
  foreach ($k in $envs.Keys) { $all[$k] = $envs[$k] }
  foreach ($k in $all.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $all[$k]) }
  try {
    $case = Join-Path ([IO.Path]::GetTempPath()) ("kyd-case-" + [guid]::NewGuid() + ".ps1")
    Set-Content -LiteralPath $case -Value "$prelude`n. '$script'`nclaude @args"
    $pwsh = (Get-Process -Id $PID).Path
    $out = & $pwsh -NoProfile -NonInteractive -File $case @argv
    Remove-Item -LiteralPath $case
    return ,@($out)
  } finally {
    foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
  }
}

function Check([string]$name, [string[]]$expected, [string[]]$actual) {
  if (($expected -join "`n") -ceq ($actual -join "`n")) { $script:pass++ }
  else { $script:fail++; Write-Host "FAIL $name`n--- expected`n$($expected -join "`n")`n--- actual`n$($actual -join "`n")" }
}

function Labels([string]$world) { '{"address":"t1","labels":{"herdr.space":"sp1","kanyerdr.world":' + $world + '}}' }

# A themed launch passes --settings <file>; the file must hold exactly the theme.
function Check-World([string]$name, [string]$world, [string[]]$actual, [string[]]$rest) {
  # The settings file must live in the user's own Claude config folder, never a shared temp folder.
  $ok = $actual.Count -ge 2 -and $actual[0] -ceq '--settings' -and (Test-Path -LiteralPath $actual[1]) -and $actual[1].StartsWith($cfg)
  if ($ok) { $ok = ((Get-Content -Raw -LiteralPath $actual[1]).Trim() -ceq ('{"theme":"custom:' + $world + '"}')) }
  if ($ok) { $ok = (($actual | Select-Object -Skip 2) -join "`n") -ceq ($rest -join "`n") }
  if ($ok) { $script:pass++ } else { $script:fail++; Write-Host "FAIL $name`n$($actual -join "`n")" }
}

$plain = @('-p', 'hello world')
Check-World 'world label adds the theme' 'cold-room' (Invoke-Case @{ HC_TERMINAL_ID = 't1'; FAKE_HC_JSON = (Labels '"cold-room"') } '' @('-p', 'hello world')) $plain
foreach ($w in 'study-hall', 'the-palace', 'launch-pad') {
  Check-World $w $w (Invoke-Case @{ HC_TERMINAL_ID = 't1'; FAKE_HC_JSON = (Labels "`"$w`"") } '' @()) @()
}
Check 'outside Herdr' $plain (Invoke-Case @{ FAKE_HC_JSON = (Labels '"cold-room"') } '' $plain)
Check 'hc fails' $plain (Invoke-Case @{ HC_TERMINAL_ID = 't1'; FAKE_HC_EXIT = '1' } '' $plain)
Check 'no label' $plain (Invoke-Case @{ HC_TERMINAL_ID = 't1'; FAKE_HC_JSON = '{"labels":{}}' } '' $plain)
Check 'hostile label' $plain (Invoke-Case @{ HC_TERMINAL_ID = 't1'; FAKE_HC_JSON = (Labels '"evil\";rm -rf"') } '' $plain)
Check 'unknown world' $plain (Invoke-Case @{ HC_TERMINAL_ID = 't1'; FAKE_HC_JSON = (Labels '"main"') } '' $plain)
Check 'not JSON' $plain (Invoke-Case @{ HC_TERMINAL_ID = 't1'; FAKE_HC_JSON = 'oops' } '' $plain)
$nohc = Join-Path ([IO.Path]::GetTempPath()) ("kyd-nohc-" + [guid]::NewGuid())
New-Item -ItemType Directory $nohc | Out-Null
New-Item -ItemType SymbolicLink -Path (Join-Path $nohc 'claude') -Target (Join-Path $fakes 'claude') | Out-Null
Check 'no hc on PATH' $plain (Invoke-Case @{ HC_TERMINAL_ID = 't1'; PATH = "$nohc$sep/usr/bin$sep/bin" } '' $plain)
Remove-Item -Recurse $nohc
$tricky = @('say "hi there" it''s $HOME `x`', '--flag=a b')
Check 'arguments pass through byte for byte' $tricky (Invoke-Case @{} '' $tricky)
Check 'a pre-existing alias is replaced' $plain (Invoke-Case @{} 'function Old { "ALIAS" }; Set-Alias claude Old' $plain)
Check 'a pre-existing function is replaced' $plain (Invoke-Case @{} 'function claude { "OLDFUNC" }' $plain)
$hidden = Join-Path ([IO.Path]::GetTempPath()) ("kyd-hidden-" + [guid]::NewGuid())
New-Item -ItemType Directory $hidden | Out-Null
Copy-Item (Join-Path $fakes 'claude') (Join-Path $hidden 'claude')
$onlyhc = Join-Path ([IO.Path]::GetTempPath()) ("kyd-onlyhc-" + [guid]::NewGuid())
New-Item -ItemType Directory $onlyhc | Out-Null
New-Item -ItemType SymbolicLink -Path (Join-Path $onlyhc 'hc') -Target (Join-Path $fakes 'hc') | Out-Null
$aliasPrelude = "Set-Alias claude '$(Join-Path $hidden 'claude')'"
Check 'claude only reachable through an alias' $plain (Invoke-Case @{ PATH = "$onlyhc$sep/usr/bin$sep/bin" } $aliasPrelude $plain)
Check-World 'alias-only claude still gets the world theme' 'launch-pad' (Invoke-Case @{ PATH = "$onlyhc$sep/usr/bin$sep/bin"; HC_TERMINAL_ID = 't1'; FAKE_HC_JSON = (Labels '"launch-pad"') } $aliasPrelude $plain) $plain
$roCfg = Join-Path ([IO.Path]::GetTempPath()) ("kyd-ro-" + [guid]::NewGuid())
New-Item -ItemType File $roCfg | Out-Null
Check 'settings folder not writable: plain claude' $plain (Invoke-Case @{ HC_TERMINAL_ID = 't1'; FAKE_HC_JSON = (Labels '"cold-room"'); CLAUDE_CONFIG_DIR = $roCfg } '' $plain)
Remove-Item -Recurse -Force $hidden, $onlyhc, $roCfg, $cfg

Write-Host "launcher tests (PowerShell): $($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
