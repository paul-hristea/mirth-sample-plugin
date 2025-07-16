Write-Host "########################################"
Write-Host ""
Write-Host "   Building jars..."
Write-Host ""
Write-Host "########################################"

mvn install package
if ($LASTEXITCODE -ne 0) {
    Write-Host "---------- Building failed"
    exit 1
}

$PLUGIN_PATH = mvn help:evaluate "-Dexpression=mirth.plugin.path" -q -DforceStdout | Out-String
$PLUGIN_PATH = $PLUGIN_PATH.Trim()

$ARTIFACT_ID = mvn help:evaluate "-Dexpression=project.artifactId" -q -DforceStdout | Out-String
$ARTIFACT_ID = $ARTIFACT_ID.Trim()

Write-Host "########################################"
Write-Host ""
Write-Host "   Copying libraries..."
Write-Host ""
Write-Host "########################################"

if (Test-Path $PLUGIN_PATH) {
    Remove-Item -Path $PLUGIN_PATH -Recurse -Force
}
New-Item -Path "$PLUGIN_PATH\libs" -ItemType Directory -Force | Out-Null

Copy-Item -Path "libs/runtime/client/*.jar" -Destination "$PLUGIN_PATH\libs\" -Force
Copy-Item -Path "libs/runtime/server/*.jar" -Destination "$PLUGIN_PATH\libs\" -Force
Copy-Item -Path "libs/runtime/shared/*.jar" -Destination "$PLUGIN_PATH\libs\" -Force

Write-Host "########################################"
Write-Host ""
Write-Host "   Generating plugin.xml..."
Write-Host ""
Write-Host "########################################"

mvn -N com.kaurpalang:mirth-plugin-maven-plugin:3.0.0:generate-plugin-xml
if ($LASTEXITCODE -ne 0) {
    Write-Host "---------- Plugin.xml generation failed"
    exit 1
}

Copy-Item -Path "plugin.xml" -Destination "$PLUGIN_PATH\" -Force

Write-Host "########################################"
Write-Host ""
Write-Host "   Signing jars..."
Write-Host ""
Write-Host "########################################"

$signingInput = "$PLUGIN_PATH\signing_input"
New-Item -Path $signingInput -ItemType Directory -Force | Out-Null

Copy-Item -Path "client/target/*.jar" -Destination $signingInput -Force
Copy-Item -Path "server/target/*.jar" -Destination $signingInput -Force
Copy-Item -Path "shared/target/*.jar" -Destination $signingInput -Force

$modules = @("server", "client", "shared")

foreach ($module in $modules) {
    $currentJar = Join-Path $signingInput "$ARTIFACT_ID-$module.jar"
    Write-Host "signing $currentJar"
    & jarsigner `
        -keystore "certificate/keystore.jks" `
        -storepass "storepass" `
        -keypass "keypass" `
        -signedjar (Join-Path $PLUGIN_PATH "$ARTIFACT_ID-$module.jar") `
        $currentJar `
        "selfsigned"
}

Remove-Item -Path $signingInput -Recurse -Force

Write-Host "########################################"
Write-Host ""
Write-Host "   Packaging plugin..."
Write-Host ""
Write-Host "########################################"

if (Test-Path "$PLUGIN_PATH.zip") {
    Remove-Item -Path "$PLUGIN_PATH.zip" -Force
}

Push-Location $PLUGIN_PATH

& jar cMf "..\$PLUGIN_PATH.zip" *

Pop-Location

Write-Host "Done!"
