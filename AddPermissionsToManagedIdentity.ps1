Connect-MgGraph -Scope Directory.Read.All, AppRoleAssignment.ReadWrite.All, Application.Read.All

# Object ID of the managed identity, NOT application ID!
$servicePrincipalId = "00000000-0000-0000-0000-000000000000"

# Lazy first version. This can be filtered down into the actual useful applications.
$allServicePrincipal = Get-MgServicePrincipal -All

# Create a searchable GUI for the user to select the approle they want. When user clicks the approle, the approle is stored in $chosenRole
$roles = $allServicePrincipal | ForEach-Object {
    foreach($r in $_.AppRoles) {
        [PSCustomObject]@{
            AppId       = $_.Id
            DisplayName = $_.DisplayName
            Id          = $r.Id
            RoleName    = $r.DisplayName
            Value       = $r.Value
        }
    }
}

$roles | Out-GridView -PassThru -Title "Select the approle you want to assign to the managed identity" | ForEach-Object {
    $chosenRole = $_
}

@"
To grant $($chosenRole.RoleName) ($($chosenRole.Value)) from $($chosenRole.DisplayName) to the managed identity with object ID $servicePrincipalId, run the following:

`$params = @{
	principalId = $servicePrincipalId
	resourceId = $($chosenRole.AppId)
	appRoleId =  $($chosenRole.Id)
}
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $servicePrincipalId -BodyParameter `$params
"@
