# =================================================================================================================================================
## This script will remove the given Service Principal OR User from Power BI workspaces
## It will first ask for the (correct) ObjectId if a Service Principal OR the UPN (User Principal Name) if a normal user
## Then it will ask for a pipe delimited list of workspaces if the user is to be removed from only a subset of the workspaces to which they have access
##          IMPORTANT: Make sure the pipe is the only separator, no additional spaces, commas or other characters
## Then it will ask for the credentials of a Power BI Service Administrator (You)
# =================================================================================================================================================

## Parameters

# Remove the Service Principal/User from workspaces that are in Premium capacity?
$RemoveFromPremiumCapacityWorkspaces = $true

# Remove the Service Principal/User from workspaces that are in shared capacity?
$RemoveFromSharedCapacityWorkspaces = $true

# =================================================================================================================================================
Clear-Host
$ErrorActionPreference = 'Stop'
Write-Host "
========================================================================
Script by Dan Meissner - August, 2022
Adapted from original script by Dave Ruijter       
========================================================================
"

#IMPORTANT: you need the correct ObjectId of the Service Principal or UPN of user
$PowerBIServicePrincipalObjectId = Read-Host -Prompt 'Enter the ObjectId of Service Principal or the UPN (User Principal Name) of any User:'
Write-Host "`n"
$WorkspacesNameFilter = Read-Host -Prompt 'Specify a pipe "|" separated list of workspaces from which to remove user (enter return/blank line for "all" workspaces):'

if ($PowerBIServicePrincipalObjectId) {
    # Connecting to Power BI (this will prompt for credentials, use an account that has the Power BI admin role!)
    Write-Host "`Connecting to Power BI (this will prompt for credentials, use an account that has the Power BI admin role!)..."
    Connect-PowerBIServiceAccount

    # Keep track of all the workspaces that we 'touch'
    $listofworkspaces = [System.Collections.ArrayList]::new()

    # Get all workspaces (and filter to only v2 workspaces)
    Write-Host "Retrieving workspaces..."
    $AllV2Workspaces = Get-PowerBIWorkspace -All -Scope Organization -Include All | Where-Object { $_.Type -eq "Workspace" -and `
        ( `
            ($_.IsOnDedicatedCapacity -eq $True -and $RemoveFromPremiumCapacityWorkspaces -eq $true) `
            -or ($_.IsOnDedicatedCapacity -eq $False -and $RemoveFromSharedCapacityWorkspaces -eq $true) `
        ) `
        -and $_.Users.Identifier -eq $PowerBIServicePrincipalObjectId
    }

    # Apply filter if one was added, otherwise use the entire list of workspaces to which the user has access (for terminated employees for example)
    if ($WorkspacesNameFilter)
    {
        #Split pipe delimited workspace filter list into array objects
        $WorkspacesNameFilter = $WorkspacesNameFilter.Split('|')

        # Filter "all workspaces" by the filter array
        $FilteredV2Workspaces = $AllV2Workspaces | Where-Object {
            $item = $_.Name
            @($WorkspacesNameFilter | Where-Object {$item.Equals($_)}).Count -gt 0
        }
    }       
    else {
        $FilteredV2Workspaces = $AllV2Workspaces
    }

    Write-Host "=================================================================================================================================="

    # Check if there are workspaces to work with
    if ($FilteredV2Workspaces)
    {
        Write-Host "Found $($FilteredV2Workspaces.Count) workspaces..."
        
        # Warn if there are more than 200 workspaces, as this might trigger API thresholds
        if ($FilteredV2Workspaces.Count -ge 200)
        {
            Write-Warning "Found 200 workspaces or more. This might trigger the thresholds of the Power BI REST API."            
        }

        # Remove the Service Principal/User from workspaces
        $FilteredV2Workspaces | ForEach-Object {
            Write-Host "=================================================================================================================================="
            $WorkspaceName = $_.Name
            $WorkspaceId = $_.Id

            Write-Host "Found workspace: $WorkspaceName."

            # Track this workspace
            $listofworkspaces += $WorkspaceName

            # Check if Service Principal/User is in the workspace
            $ServicePrincipalInWorkspace = $_.Users | Where-Object {$_.Identifier -eq $PowerBIServicePrincipalObjectId}
            if ($ServicePrincipalInWorkspace)
            {
                Write-Host "Service Principal/User is a $($ServicePrincipalInWorkspace.AccessRight) of: $WorkspaceName."
                
                # Remove Service Principal/User
                Write-Host "Removing Service Principal/User from workspace..." -ForegroundColor DarkCyan
                
                # Call the REST API (updating a role type is not a native cmdlet in the module)
                try {
                    Invoke-PowerBIRestMethod -Method Delete -Url "admin/groups/$WorkspaceId/users/$PowerBIServicePrincipalObjectId"
                    Write-Host "Done."
                }
                catch {
                    Resolve-PowerBIError -Last
                }
            }
            else {
            Write-Host "Service Principal/User is not a member of: $WorkspaceName."
            }
        }

        Write-Host "=================================================================================================================================="

        # Report the tracked list of workspaces
        Write-Host "List of workspaces we checked during the script:"
        $listofworkspaces
    }
    else {
        Write-Warning "No workspaces that contain the Service Principal/User!"
    }
}
else {
  Write-Error "No ObjectID or UPN provided!"
}

Logout-PowerBIServiceAccount
Write-Host "`nScript finished."