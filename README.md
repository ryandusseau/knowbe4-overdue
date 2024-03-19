# KnowBe4-Overdue

Users who are overdue on their training may be subjected to account restrictions. Rather than manually or bulk disabling access in AD/AAD, an effective way to manage this is using conditional access policies in Entra / Azure Active Directory.

This is an automation job to handle adding and removing users from these restrictions based on their current KnowBe4 training status. The ps1 file is set as an Azure Automation runbook which will frequently connect to the KnowBe4 API and check whether the user is part of any in-scope smart groups (designed to detect 'overdue' training status). If they are a member of any, then the runbook will connect to Entra/AAD and add the user to a group which will be assigned to a conditional access policy that blocks most access until training can be completed. Once the user is no longer a member of any overdue KB4 groups, then they will be automatically removed from the group, lifting their access restriction.

## Requirements

1. KnowBe4
2. Entra / Azure Active Directory users & groups
3. Entra Conditional Access policies
4. Azure Automation account
5. Azure Logic App (optional)

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
    1. Paste the KB4 smart group(s) ID into the **$KB4groups** variable
    2. Paste the Entra group into the **$AADgroup** variable
5. To **schedule** your runbook, you can use the provided schedule in Automation Accounts. However, the most frequent option available is 1 hour, which may be too slow for releasing users once they complete their training. Therefore, you can optionally use an  **Azure Logic App** to execute your runbook on a more frequent schedule, such as every 15 minutes:
    1. Create an Azure Logic App.
    2. **Identity**: Enable the System assigned managed identity, and provide it permission 'Automation Job Operator' so that it will be able to execute your Automation Account runbook.
    3. **Logic app designer**:
        1. **Trigger**: Recurrence; frequency is up to you
        2. **Action**: Create job > Select your Automation Account runbook
    4. Recommended: Create an **Alert** on your logic app to detect run failures.
  
## Adding additional groups
To add more training campaigns over time, simply create another KnowBe4 smart group and add the ID into the **$KB4groups** variable of the ps1 file (comma separated).

## Disabling the automation
The automation should run on its own continuously for as long as your schedule is executing. If for some reason you'd like to stop it, you may either disable the runbook (or logic app) schedule, or you can set the conditional access policy to Report mode so that no block effect occurs.

NOTE: There are some safety conditions built into the ps1 file to identify and stop the runbook when unexpected behavior occurs, for example if too many users would be locked out at once.

