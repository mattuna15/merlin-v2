Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$GhdlExe = $env:GHDL_EXE
if (-not $GhdlExe -or $GhdlExe.Trim().Length -eq 0) {
  $defaultPath = 'C:\code\ghdl-mcode-5.1.1-mingw64\bin\ghdl.exe'
  if (Test-Path $defaultPath) {
    $GhdlExe = $defaultPath
  } else {
    $GhdlExe = 'ghdl'
  }
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Push-Location $RepoRoot

Write-Host "Using GHDL: $GhdlExe"

function Invoke-Ghdl {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Args
  )

  Write-Host "$GhdlExe $($Args -join ' ')"
  & $GhdlExe @Args
  if ($LASTEXITCODE -ne 0) {
    throw "GHDL command failed (exit $LASTEXITCODE): $GhdlExe $($Args -join ' ')"
  }
}

$AnalyzeArgs = @(
  '-a', '--std=08', '--ieee=synopsys',
  '68K30L/wf68k30L_pkg.vhd',
  '68K30L/wf68k30L_address_registers.vhd',
  '68K30L/wf68k30L_alu.vhd',
  '68K30L/wf68k30L_bus_interface.vhd',
  '68K30L/wf68k30L_control.vhd',
  '68K30L/wf68k30L_data_registers.vhd',
  '68K30L/wf68k30L_exception_handler.vhd',
  '68K30L/wf68k30L_opcode_decoder.vhd',
  '68K30L/wf68k30L_top.vhd',
  '68K30L/tb/tb_wf68k30L_alu.vhd',
  '68K30L/tb/tb_wf68k30L_opcode_decoder.vhd',
  '68K30L/tb/tb_wf68k30L_coproc_decode.vhd',
  '68K30L/tb/tb_wf68k30L_bus_interface.vhd',
  '68K30L/tb/tb_wf68k30L_top_smoke.vhd',
  '68K30L/tb/tb_wf68k30L_top_coproc_bus.vhd'
)
Invoke-Ghdl -Args $AnalyzeArgs

$benches = @(
  'tb_wf68k30L_alu',
  'tb_wf68k30L_opcode_decoder',
  'tb_wf68k30L_coproc_decode',
  'tb_wf68k30L_bus_interface',
  'tb_wf68k30L_top_smoke',
  'tb_wf68k30L_top_coproc_bus'
)

foreach ($bench in $benches) {
  Invoke-Ghdl -Args @('-e', '--std=08', '--ieee=synopsys', $bench)
  Invoke-Ghdl -Args @('-r', '--std=08', '--ieee=synopsys', $bench, '--assert-level=error')
}

Pop-Location
Write-Host 'CPU GHDL tests passed.'

