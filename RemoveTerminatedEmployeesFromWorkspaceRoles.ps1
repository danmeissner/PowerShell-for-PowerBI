# =================================================================================================================================================
## This script will loop through a list of Users no longer with the company and remove them from any from Power BI workspaces
##          IMPORTANT: Make sure the pipe is the only separator, no additional spaces, commas or other characters
## It will create a list of workspaces to which any of these users have access
## Then it will ask for the credentials of a Power BI Service Administrator (You)
## It will end by providing a list of Orphaned workspaces in case a terminated employee was the only Admin. Then those need to be addressed manually
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

Write-Host "`n"
$ListOfTerminatedUsers = Read-Host -Prompt 'Specify a pipe "|" delimited list of users (UPNs) that are no longer with the company'

if ($ListOfTerminatedUsers) {
    # Connecting to Power BI (this will prompt for credentials, use an account that has the Power BI admin role!)
    Write-Host "`Connecting to Power BI (this will prompt for credentials, use an account that has the Power BI admin role!)..."
    Connect-PowerBIServiceAccount

    # Keep track of all the workspaces that we 'touch'
    $listofworkspaces = [System.Collections.ArrayList]::new()

    #Split pipe delimited username filter list into array objects
    $ListOfTerminatedUsers = $ListOfTerminatedUsers.Split('|')
    $UserCount = $ListOfTerminatedUsers.Count
    Write-Host "UserCount: $UserCount"

    # Get all workspaces (and filter to only v2 workspaces of which one of the ex-employees was a user role)
    Write-Host "Retrieving workspaces..."
    $AllV2Workspaces = Get-PowerBIWorkspace -All -Scope Organization -Type Workspace | Where-Object { $_.State -eq 'Active' -and $_.Type -eq 'Workspace'}  
    
    # Find workspaces that have no assigned users - This will break the $item.Contains call below - Clean these workspaces up first
    # $AllV2Workspaces | ForEach-Object {
    #     $wsName2 = $_.Name 
    #     $item2 = $_.Users.Identifier
    #     if($item2.Count -eq 0) {Write-Warning "Empty Workspace $wsName2"}}
    # Return

    $FilteredV2Workspaces = $AllV2Workspaces | Where-Object {       
         $item = $_.Users.Identifier
         
         #Select only Workspaces that have at least one UPN from the list as Worspace User
        @($ListOfTerminatedUsers | Where-Object {$item.Contains($_)}).Count -gt 0
    }   
    Write-Host "=================================================================================================================================="
    
    # Check if there are workspaces to work with
    if ($FilteredV2Workspaces)
    {
        Write-Host "Found $($FilteredV2Workspaces.Count) workspaces..."
        
        # Warn if there are more than 200 workspaces, as this might trigger API thresholds
        if ($FilteredV2Workspaces.Count  -ge 100)
        {
            Write-Warning "Found 100 or more workspaces."
            Write-Warning "This might trigger the thresholds of the Power BI REST API assuming users had access to more than one workspace." 
            Return           
        }

        # Remove the Service Principal/User from workspaces
        $FilteredV2Workspaces | ForEach-Object {
            #Write-Host "=================================================================================================================================="
            $WorkspaceName = $_.Name
            $WorkspaceId = $_.Id
            $WorkspaceIdentifier = $_.Users.Identifier

           # Write-Host "Found workspace: $WorkspaceName."

            # Track this workspace
            $listofworkspaces += $WorkspaceName

            # Check if Service Principal/User is in the workspace
           $ListOfTerminatedUsers | ForEach-Object { 
                $UserInWorkspace = $_
                if ($WorkspaceIdentifier -match $UserInWorkspace)
                {  Write-Host "Looping on $UserInWorkspace, $WorkspaceName"
                    # Remove Service Principal/User
                    # Write-Host "Removing Service Principal/User from workspace..." -ForegroundColor DarkCyan
                    
                    # Call the REST API to remove users
                    try {
                        Remove-PowerBIWorkspaceUser -Scope Organization -Id $WorkspaceId -UserEmailAddress $UserInWorkspace
                    }
                    catch {
                        Resolve-PowerBIError -Last
                    }
                }
            } 

        # Report the tracked list of workspaces
        # Write-Host "List of workspaces we checked during the script:"
        # $listofworkspaces
        }   
    }
    else {
    Write-Error "No ObjectID or UPN provided!"
    }
}
Logout-PowerBIServiceAccount
Write-Host "`nScript finished."