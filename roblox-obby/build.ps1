# Сборка RobloxObby.rbxlx из ObbyServer.luau + ObbyHud.luau
# Запуск: powershell -ExecutionPolicy Bypass -File build.ps1

$ErrorActionPreference = "Stop"

$dir = $PSScriptRoot
if (-not $dir) { $dir = (Get-Location).Path }

function Read-Source([string]$name) {
	$path = Join-Path $dir $name
	return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

function XmlEscape([string]$text) {
	return [System.Security.SecurityElement]::Escape($text)
}

$serverSrc = XmlEscape (Read-Source "ObbyServer.luau")
$hudSrc = XmlEscape (Read-Source "ObbyHud.luau")

$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<roblox xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
	<Item class="Workspace" referent="RBXWORKSPACE">
		<Properties>
			<string name="Name">Workspace</string>
			<bool name="StreamingEnabled">false</bool>
		</Properties>
	</Item>
	<Item class="Lighting" referent="RBXLIGHTING">
		<Properties>
			<string name="Name">Lighting</string>
		</Properties>
	</Item>
	<Item class="ServerScriptService" referent="RBXSERVICESCRIPTSERVICE">
		<Properties>
			<string name="Name">ServerScriptService</string>
		</Properties>
		<Item class="Script" referent="RBXOBBYSERVER">
			<Properties>
				<string name="Name">ObbyServer</string>
				<bool name="Disabled">false</bool>
				<ProtectedString name="Source">$serverSrc</ProtectedString>
			</Properties>
		</Item>
	</Item>
	<Item class="StarterPlayer" referent="RBXSTARTERPLAYER">
		<Properties>
			<string name="Name">StarterPlayer</string>
		</Properties>
		<Item class="StarterPlayerScripts" referent="RBXSTARTERPLAYERSCRIPTS">
			<Properties>
				<string name="Name">StarterPlayerScripts</string>
			</Properties>
			<Item class="LocalScript" referent="RBXOBBYHUD">
				<Properties>
					<string name="Name">ObbyHud</string>
					<bool name="Disabled">false</bool>
					<ProtectedString name="Source">$hudSrc</ProtectedString>
				</Properties>
			</Item>
		</Item>
	</Item>
</roblox>
"@

$out = Join-Path $dir "RobloxObby.rbxlx"
[System.IO.File]::WriteAllText($out, $xml, (New-Object System.Text.UTF8Encoding($false)))

# проверка, что XML корректный
[xml]$check = Get-Content -LiteralPath $out -Raw -Encoding UTF8
$items = ($check.roblox.Item | Measure-Object).Count
Write-Host ("OK: {0} ({1} bytes, services: {2})" -f $out, (Get-Item $out).Length, $items)
