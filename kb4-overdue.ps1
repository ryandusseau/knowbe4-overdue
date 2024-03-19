# DESCRIPTION:
# Pull lists of KnowBe4 users who are overdue on KnowBe4 trainings by referencing KB4 Smart Groups over the KB4 API.
# 1) For each overdue user, add them to an AAD group which can restrict their online account access via conditional access policy.
# 2) If a user is no longer overdue, then remove them from the AAD group.

# TO ADD MORE KB4 GROUPS TO THIS SCRIPT:
# 1) In KnowBe4, create a copy of an existing 'Overdue' group. Modify the name and smart criteria to fit your latest training campaign.
# 2) Locate the group ID in the URL.
# 3) In the SCRIPT section below, add the group ID to the $KB4groups variable. Also, add a comment of the group name for easy reference.


$KB4groups = <SMART GROUPS HERE, separate multiple groups by commma>
# 10001 = Example group
# 10002 = Example group 2


# --- KNOWBE4 CONNECTION ---
$AuthToken = Get-AutomationVariable -Name KB4AuthToken

#### Base Settings ####
#Base URL
$Base = "https://us.api.knowbe4.com"
#Force PowerShell to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
#Set Required Headers
$auth =@{
  "ContentType" = 'application/json'
  "Method" = 'GET'
  "Headers" = @{
    "Authorization" = "Bearer $AuthToken"
    "Accept" = "application/json"
  }
}

#### Verify Connectivity to API ####
#Clear-Host
Try {
    Write-Output `n`n
    $KB4account = Invoke-RestMethod @auth -Uri "$Base/v1/account"
    $KB4account | Format-List name, type, domains, subscription*,current_risk_score,number_of_seats
  } Catch {
    $ReqError = $_
  }
  If ($ReqError -ne $null) {
    #$ReqError.Exception,$ReqError.InvocationInfo,$ReqError.TargetObject | Out-File $LocalPath\APIConnectivityFail_$date -append
    Write-Output "Connection to KB4 API failed"
    Exit
}


# --- CONNECT TO AZUREAD ---
Disable-AzContextAutosave -Scope Process
Connect-azaccount -identity
$context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
$graphToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.microsoft.com").AccessToken
$aadToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.windows.net").AccessToken
#Write-Output "Hi I'm $($context.Account.Id)"
Connect-AzureAD -AadAccessToken $aadToken -AccountId $context.Account.Id -TenantId $context.tenant.id


# ---- SCRIPT ----
# Gather KnowBe4 group members
$pages = [math]::ceiling($KB4account.number_of_seats/500) #Number of seats divided by 500 per page, round up
foreach ($group in $KB4groups){
    $stopcheck = 500 #To ensure that the upcoming pagination If loop will run at least page 1

    for ($i=1;$i -le $pages; $i++) { #Pagination loop but don't exceed pages that exceed license seat count
        $endpoint = "/v1/groups/$group/members?per_page=500&page=$i"
        $fullurl = $base + $endpoint
        if ($stopcheck -eq 500){
            $return = Invoke-RestMethod @auth -Uri "$fullurl"
            $kb4members += $return
            Start-Sleep -Seconds 1
            
            $stopcheck = $return.count #Did this page return 500 members? If yes, then loop again for the next page. Repeat until you pull less than 500 on a page, meaning you can exit the pagination loop.
        }
    }
}

$members_unique = $kb4members | sort -unique -property email #Remove duplicates
Write-Output "Unique KB4 group members found: "$members_unique.count


# BEGIN AAD STEPS
$AADgroup = "<ENTRA ID / AZURE ACTIVE DIRECTORY OBJECT ID HERE>" #<GROUP NAME>
$AADgroupmembers = Get-AzureADGroupMember -ObjectId $AADgroup -All $true

#Compare the KB4 overdue members with the current AAD group members; The Catch condition is in case the AAD group is empty which creates a Compare error, preventing the $diff variables from being created.
try { $diff_add = Compare-Object -ReferenceObject $members_unique.email -DifferenceObject $AADgroupmembers.userprincipalname | where-object {$_.sideindicator -eq "<="} } #Add to AAD group
catch { $diff_add = $members_unique | Select-Object @{Name='InputObject';Expression={$_.email}} } #Rename the KB4 "email" column header to "InputObject", which would have been the header name if the Compare had worked.
try { $diff_remove = Compare-Object -ReferenceObject $members_unique.email -DifferenceObject $AADgroupmembers.userprincipalname | where-object {$_.sideindicator -eq "=>"} } #Remove from AAD group
catch { $diff_remove = $null }

#If new overdue members are detected, then add them to the AAD group
Write-Output "Users to be added to the AAD group:" $diff_add.inputobject.count
$safeguard = ($KB4account.number_of_seats)/10 #Do not add anyone if an overdue count is greater than 10% of license seats (possible group misconfig)
if ($diff_add.inputobject.count -le $safeguard) {
    foreach ($user in $diff_add){
        #Get their AAD object ID using their email
        $email = $user.inputobject
        $AADuser = Get-AzureADUser -Filter "mail eq '$email'"

        Write-Output "Adding user:" $email
        Add-AzureADGroupMember -ObjectId $AADgroup -RefObjectId $AADuser.objectid
    }
}

#If they have completed training, then take them out of the AAD group
Write-Output "Users to be removed from the AAD group:" $diff_remove.inputobject.count
foreach ($user in $diff_remove){
    #Get their AAD object ID using their email
    $email = $user.inputobject
    $AADuser = Get-AzureADUser -Filter "mail eq '$email'"

    Write-Output "Removing user:" $email
    Remove-AzureADGroupMember -ObjectId $AADgroup -MemberId $AADuser.objectid
}
