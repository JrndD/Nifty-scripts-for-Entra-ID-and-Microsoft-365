#region Get Application Sign In from Log Analytics

$tenantId = <tenantId>
$subscription = <subscription>
$resourceGroupName = <resourceGroupName>
$logAnalyticsWorkspace = <logAnalyticsWorkspace>

Connect-AzAccount -Tenant $tenantId
set-AzContext $subscription
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $logAnalyticsWorkspace

$kqlQuery = '
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(180d)
| where ResultType == 0
| summarize count() by AppId
'
$AADServicePrincipalSignInLogs = Invoke-AzOperationalInsightsQuery -Workspace $Workspace -Query $kqlQuery

$kqlQuery = '
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(180d)
| where ResultType == 0
| summarize count() by ServicePrincipalId
'
$AADServicePrincipalSignInLogsActor = Invoke-AzOperationalInsightsQuery -Workspace $Workspace -Query $kqlQuery

$kqlQuery = '
AADNonInteractiveUserSignInLogs
| where TimeGenerated > ago(180d)
| where ResultType == 0
| summarize count() by AppId
'
$AADNonInteractiveUserSignInLogs = Invoke-AzOperationalInsightsQuery -Workspace $Workspace -Query $kqlQuery

$kqlQuery = '
AADManagedIdentitySignInLogs
| where TimeGenerated > ago(180d)
| where ResultType == 0
| summarize count() by AppId
'
$AADManagedIdentitySignInLogs = Invoke-AzOperationalInsightsQuery -Workspace $Workspace -Query $kqlQuery

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
