# kanyerdr: start Claude Code in the theme of the Herdr world this terminal is in.
# Dot-source this file from your $PROFILE. Outside a kanyerdr world, `claude` runs as usual.
# Works in Windows PowerShell 5.1 and PowerShell 7.
#
# The worlds mod labels every terminal kanyerdr.world=<world>; this reads the
# label with `hc get` and passes the theme for this session only (--settings),
# so your global Claude Code settings never change. The theme goes in a small
# JSON file in your Claude Code folder (~/.claude/kanyerdr/), because Windows can
# strip the quotes from a JSON string passed on the command line.

# An existing `claude` alias is replaced by the function below. If that alias was
# the only way to reach Claude Code, keep using it.
$script:KanyerdrClaudeAlias = (Get-Alias claude -ErrorAction SilentlyContinue).Definition
Remove-Item Alias:claude -Force -ErrorAction SilentlyContinue

function global:claude {
  $real = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($real) { $run = $real.Source }
  elseif ($script:KanyerdrClaudeAlias) { $run = $script:KanyerdrClaudeAlias }
  else { Write-Error 'claude: Claude Code is not installed or not on PATH'; return }

  $world = $null
  if ($env:HC_TERMINAL_ID) {
    $hc = Get-Command hc -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hc) {
      try {
        $out = & $hc.Source get $env:HC_TERMINAL_ID --json 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) {
          $world = (($out -join "`n") | ConvertFrom-Json).labels.'kanyerdr.world'
        }
      } catch { $world = $null }
    }
  }

  $settings = $null
  if (@('study-hall', 'the-palace', 'launch-pad', 'cold-room') -ccontains $world) {
    try {
      $config = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
      $dir = Join-Path $config 'kanyerdr'
      New-Item -ItemType Directory -Force -Path $dir -ErrorAction Stop | Out-Null
      $settings = Join-Path $dir "$world.json"
      [IO.File]::WriteAllText($settings, '{"theme":"custom:' + $world + '"}')
    } catch { $settings = $null }
  }

  if ($settings) { & $run --settings $settings @args } else { & $run @args }
}
