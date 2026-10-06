param(
	[string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
	# Sólo para paquetes de validación aislados. No modifica project.godot del
	# workspace: reemplaza la escena de inicio únicamente dentro del ZIP.
	[string]$MainScene = ''
)

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$archivePath = Join-Path $ProjectRoot "RogueSpace_TEST_MOBILE_$timestamp.zip"
$excludedDirectories = @('.godot', '.git', '.agents', '.codex', 'artifacts')
$allowedTopLevel = @(
	'autoloads', 'resources', 'scenes', 'scripts', 'tools',
	'export_templates', 'feature_profiles', 'script_templates', 'text_editor_themes',
	'project.godot', 'RogueSpace_CORE_Design_UPDATED.md', 'RogueSpace_CURRENT_State_UPDATED.md'
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$files = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Force | Where-Object {
	$relativePath = $_.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/')
	$segments = $relativePath -split '[\\/]'
	$hasExcludedDirectory = $segments | Where-Object { $_ -in $excludedDirectories }
	$hasAllowedTopLevel = $segments.Count -gt 0 -and $segments[0] -in $allowedTopLevel
	$relativePath -notlike 'RogueSpace_TEST_MOBILE_*.zip' -and
	# Review/build archives are not project source and must never be nested in
	# a mobile validation package.
	$_.Extension -ne '.zip' -and
	$_.Name -notin @('Thumbs.db', 'desktop.ini') -and
	-not $hasExcludedDirectory -and
	# No incorporar archivos residuales de extracciones o rutas absolutas
	# mal normalizadas: un paquete sólo contiene raíces explícitas del proyecto.
	$hasAllowedTopLevel
}

$archive = [System.IO.Compression.ZipFile]::Open($archivePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
	foreach ($file in $files) {
		$entryName = $file.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/') -replace '\\', '/'
		if ($entryName -eq 'project.godot' -and -not [string]::IsNullOrWhiteSpace($MainScene)) {
			$projectText = Get-Content -LiteralPath $file.FullName -Raw
			$projectText = [regex]::Replace($projectText, '(?m)^run/main_scene\s*=\s*"[^"]*"', ('run/main_scene="' + $MainScene + '"'))
			$entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
			$writer = New-Object System.IO.StreamWriter($entry.Open())
			try { $writer.Write($projectText) } finally { $writer.Dispose() }
		}
		else {
			[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
				$archive,
				$file.FullName,
				$entryName,
				[System.IO.Compression.CompressionLevel]::Optimal
			) | Out-Null
		}
	}
}
finally {
	$archive.Dispose()
}

Write-Output $archivePath
