# =================================================================================================================================================
## This script will delete a list of workspaces in bulk by adding the admin account of your choosing then deleting the workspace
## Then it will ask for both a pipe delimited list of workspaces to be deleted and an admin account email
##          IMPORTANT: Make sure the pipe is the only separator, no additional spaces, commas or other characters
## Then it will ask for the credentials of a Power BI Service Administrator (You)
# =================================================================================================================================================

## Parameters


# =================================================================================================================================================
Clear-Host
$ErrorActionPreference = 'Stop'
Write-Host "
========================================================================
Script by Dan Meissner - August, 2022

https://github.com/danmeissner/PowerShell-for-PowerBI
========================================================================
"

#IMPORTANT: you need the correct ObjectId of the Service Principal or UPN of user
$PowerBIAdminUPN = Read-Host -Prompt 'Enter the UPN (User Principal Name) of a Power BI Admin'
Write-Host "`n"
$WorkspacesNameFilter = Read-Host -Prompt 'Specify a pipe "|" delimited list of workspaces to delete'

if ($WorkspacesNameFilter)
    {
        #Split pipe delimited workspace filter list into array objects
        $WorkspacesNameFilter = $WorkspacesNameFilter.Split('|')
    }       
    else {
        Write-Host "No workspaces listed for deletion."
        Return
    }

if ($PowerBIAdminUPN) {
    # Connecting to Power BI (this will prompt for credentials, use an account that has the Power BI admin role!)
    Write-Host "`nConnecting to Power BI (this will prompt for credentials, use an account that has the Power BI admin role!)..."
    Connect-PowerBIServiceAccount

    # Get all workspaces (and filter to only v2 workspaces)
    Write-Host "Retrieving workspace IDs...`n"
    $DeletingWorkspaces = Get-PowerBIWorkspace -All -Scope Organization | Where-Object { $item = $_.Name
        @($WorkspacesNameFilter | Where-Object {$item.Equals($_)}).Count -gt 0 -and $_.Type -eq "Workspace"}
        
    Write-Host "=================================================================================================================================="
    $DeletingWorkspaces | ForEach-Object {
        $WorkspaceName = $_.Name
        Write-Host "Found workspace: $WorkspaceName."
    }
    Write-Host "=================================================================================================================================="

        ForEach ($w in $DeletingWorkspaces)
        {
            ### In order to delete the orphaned workspace, we need to have admin rights to it. Right now
            ### there are no owners of the workspace, so a delete will fail with a 401 (Unauthorized)
            ### if we do nothing. This is because there is no Admin API for deleting a workspace.
        
            Write-Host "Deleting: $($w.Name)"
        
            ### Add an Admin of the workspace
            Invoke-PowerBIRestMethod -Url "https://api.powerbi.com/v1.0/myorg/admin/groups/$($w.id)/users" -Method Post -Body "{ 'emailAddress': '$PowerBIAdminUPN', 'groupUserAccessRight': 'Admin' }"
        
            ### Delete the workspace
            Invoke-PowerBIRestMethod -Url "https://api.powerbi.com/v1.0/myorg/groups/$($w.id)" -Method Delete
        }

        Write-Host "=================================================================================================================================="
    
}
else {
  Write-Error "No Admin UPN provided!"
}

Logout-PowerBIServiceAccount
Write-Host "`nScript finished."