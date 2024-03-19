# KnowBe4-Overdue

Users who are overdue on their training may be subjected to account restrictions. Rather than manually or bulk disabling access in AD/AAD, conditional access policies are an effective way to limit access until they get their training done.

This is an automation job to handle adding and removing users from the restriction based on their current KnowBe4 training status. The ps1 file will be set as an Azure Automation runbook that frequently connects to the KnowBe4 API and checks whether the user is part of any 'overdue' smart groups. If they are a member of any, then the runbook will connect to Entra/AAD and add the user to an Entra/AAD group assigned to a conditional access policy that blocks most access except for KnowBe4. Once the user completes their training, the smart group will update quickly and the next runbook will handle removing them from the Entra group/conditional access policy.

## Requirements

1. KnowBe4
2. Entra / Azure Active Directory users & groups
3. Entra Conditional Access policies
4. Azure Automation account
5. Azure Logic App (optional)

A basic understanding of each of the Requirements is recommended, as well as basic understanding of Powershell.

## Disclaimer
The materials here are provided as-is and come with no warranty or guarantees for any environment. You should review all materials carefully before use to determine whether it is appropriate for your environment. Where necessary, use a test environment or set policies in Report mode to monitor their effect. Exercise caution with lockout policies by creating breakglass/exemption conditions.

## Set up

1. In **KnowBe4**, create a smart group that will identify users who are overdue on a particular training campaign. Take note of the group ID (in the URL). *NOTE: You will be able to add as many groups into the ps1 script as needed, for example if you create a unique overdue group per training campaign.*
2. In **Entra**, create a new group to add/remove the users using the script. Take note of the Object ID.
3. In **Entra**, create a conditional access policy that will block access until training is completed.
    1. **Users**: Assign the policy to your Entra group. RECOMMENDED: Exclude yourself and/or break glass accounts since this is a block policy that could cause a lockout.
    2. **Resources**: All cloud apps. Exclude: KnowBe4, optional: any other apps that don't need to be locked out such as VPN or communication tools for reaching Help Desk.
    3. **Conditions**: 0 conditions selected
    4. **Grant**: Block access
4. In **Azure Automation**, create a new Runbook and copy the provided ps1 file.
    1. Paste the KB4 smart group ID into the **$KB4groups** variable
    2. Paste the Entra group into the **$AADgroup** variable
5. To **schedule** your runbook, you can use the provided schedule in Automation Accounts. However, the most frequent option available is 1 hour, which may be too slow for releasing users once they complete their training. Therefore, you can optionally use an  **Azure Logic App** to execute your runbook on a more frequent schedule, such as every 15 minutes:
    1. Create an Azure Logic App.
    2. **Identity**: Enable the System Assigned Managed Identity. Provide it permission 'Automation Job Operator' where your Automation Account is located, so that it will be able to execute the runbook.
    3. **Logic app designer**:
        1. **Trigger**: Recurrence; frequency is up to you
        2. **Action**: Create job: Select your Automation Account runbook in Azure. For credential, select the Managed Identity of this logic app.
    4. **Alerts** (optional): Create an Alert Rule to detect logic app run failures, for example sending you an email or SMS.
  
## Adding additional groups
To add more training campaigns over time, simply create another KnowBe4 smart group and add the ID into the **$KB4groups** variable of the ps1 file (comma separated).

## Disabling the automation
The automation should run on its own continuously for as long as your schedule is executing. If for some reason you'd like to stop it, you may either disable the runbook (or logic app) schedule, or you can set the conditional access policy to Report mode so that no block effect occurs.

NOTE: There are some safety conditions built into the ps1 file to identify and stop the runbook when unexpected behavior occurs, for example if too many users would be locked out at once.

