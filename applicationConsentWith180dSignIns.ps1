#region Get Application Sign In from Log Analytics

$tenantId = <tenantId>
$subscription = <subscription>
$resourceGroupName = <resourceGroupName>
$logAnalyticsWorkspace = <logAnalyticsWorkspace>

Connect-AzAccount -Tenant $tenantId
set-AzContext $subscription
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $logAnalyticsWorkspace


# Number of sign ins per app by service principals
$kqlQuery = '
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(180d)
| where ResultType == 0
| summarize count() by AppId
'
$AADServicePrincipalSignInLogs = Invoke-AzOperationalInsightsQuery -Workspace $Workspace -Query $kqlQuery

# Number of sign ins by service principals themselves.
# This will count sign ins by service principals twice, but its the only way I have figured out to get activity for service principals.
$kqlQuery = '
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(180d)
| where ResultType == 0
| summarize count() by ServicePrincipalId
'
$AADServicePrincipalSignInLogsActor = Invoke-AzOperationalInsightsQuery -Workspace $Workspace -Query $kqlQuery

# Non-interactive sign ins. Probably the least valuable data as it is almost always included in the sign in logs.
$kqlQuery = '
AADNonInteractiveUserSignInLogs
| where TimeGenerated > ago(180d)
| where ResultType == 0
| summarize count() by AppId
'
$AADNonInteractiveUserSignInLogs = Invoke-AzOperationalInsightsQuery -Workspace $Workspace -Query $kqlQuery

# Number of sign ins per app by a managed identity
$kqlQuery = '
AADManagedIdentitySignInLogs
| where TimeGenerated > ago(180d)
| where ResultType == 0
| summarize count() by AppId
'
$AADManagedIdentitySignInLogs = Invoke-AzOperationalInsightsQuery -Workspace $Workspace -Query $kqlQuery

# Number of sign ins per app by managed identity themselves.
# This will count sign ins by service principals twice, but its the only way I have figured out to get activity for managed identity.
$kqlQuery = '
AADManagedIdentitySignInLogs
| where TimeGenerated > ago(180d)
| where ResultType == 0
| summarize count() by ServicePrincipalId
'
$AADManagedIdentitySignInLogsActor = Invoke-AzOperationalInsightsQuery -Workspace $Workspace -Query $kqlQuery

# Normal interactive sign ins
$kqlQuery = '
SigninLogs
| where TimeGenerated > ago(180d)
| where ResultType == 0
| summarize count() by AppId
'
$SigninLogs = Invoke-AzOperationalInsightsQuery -Workspace $Workspace -Query $kqlQuery

$signinlogshash = @{}
$signinlogs.results | ForEach-Object {
    if($signinlogshash[$_."AppId"]) {
        $signinlogshash[$_."AppId"] += [int]$_."count_"
    }
    else {
        $signinlogshash.Add($_."AppId",[int]$_."count_")
    }
}

$AADServicePrincipalSignInLogs.results | ForEach-Object {
    if($signinlogshash[$_."AppId"]) {
        $signinlogshash[$_."AppId"] += [int]$_."count_"
    }
    else {
        $signinlogshash.Add($_."AppId",[int]$_."count_")
    }
}

$AADServicePrincipalSignInLogsActor.results | ForEach-Object {
    if($signinlogshash[$_."ServicePrincipalId"]) {
        $signinlogshash[$_."ServicePrincipalId"] += [int]$_."count_"
    }
    else {
        $signinlogshash.Add($_."ServicePrincipalId",[int]$_."count_")
    }
}

$AADNonInteractiveUserSignInLogs.results | ForEach-Object {
    if($signinlogshash[$_."AppId"]) {
        $signinlogshash[$_."AppId"] += [int]$_."count_"
    }
    else {
        $signinlogshash.Add($_."AppId",[int]$_."count_")
    }
}

$AADManagedIdentitySignInLogs.results | ForEach-Object {
    if($signinlogshash[$_."AppId"]) {
        $signinlogshash[$_."AppId"] += [int]$_."count_"
    }
    else {
        $signinlogshash.Add($_."AppId",[int]$_."count_")
    }
}

$AADManagedIdentitySignInLogsActor.results | ForEach-Object {
    if($signinlogshash[$_."ServicePrincipalId"]) {
        $signinlogshash[$_."ServicePrincipalId"] += [int]$_."count_"
    }
    else {
        $signinlogshash.Add($_."ServicePrincipalId",[int]$_."count_")
    }
}

#endregion Get Application Sign In from Log Analytics

#region Generate application consent report and add sign in count to it
$appConsent = Export-MsIdAppConsentGrantReport -ReportOutputType PowerShellObjects

$appConsent | ForEach-Object {
    if($signinlogshash[$_.AppId]) {
        $_ | Add-Member -MemberType NoteProperty -Name SignInCount -Value $signinlogshash[$_.AppId]
    }
    else {
        $_ | Add-Member -MemberType NoteProperty -Name SignInCount -Value 0
    }
}

$appConsent | Export-Excel '.\appConsentReportWithSignIns.xlsx'
#endregion Generate application consent report and add sign in count to it
