# Need to add a loop for each Pipeline to retrieve the workspaces associated with that pipeline.
Connect-PowerBIServiceAccount

Write-Host "Getting Expanded Pipeline Info."

try {
    $json = Invoke-PowerBIRestMethod -Method Get -Url "admin/pipelines?`$expand=users&`$top=100"
    Write-Host "Done."
}
catch {
    Resolve-PowerBIError -Last
}
$json = $json | ConvertFrom-Json
$json = $json.psobject.Properties.Value

Write-Host -ForegroundColor Blue -BackgroundColor White "$($json.count) Pipelines found."

$json | ForEach-Object {
    Write-Host "=================================================================================================================================="
    $PipelineName = $_.displayName
    $PipelineId = $_.id
    $PipelineUsers = $_.Users

    Write-Host "Pipeline Name is `"$PipelineName`" with ID:  $PipelineId"
    $PipelineUsers | ForEach-Object {"`t $($_.accessRight): $($_.Identifier)"}
}

Write-Host "=================================================================================================================================="
