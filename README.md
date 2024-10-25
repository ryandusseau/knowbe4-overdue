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
The materials here are provided as-is and come with no warranty or guarantees for any environment. Before use, you should carefully review all materials to determine whether it is appropriate for your environment. Where necessary, use a test environment and set policies in Report mode to monitor their effect first. Exercise caution when using lockout policies by creating breakglass/exemption conditions and validating the What If conditional access feature.

## Set up

1. In **KnowBe4**, create a smart group that will identify users who are overdue on a particular training campaign. Take note of the group ID (in the URL). *NOTE: You will be able to add as many groups into the ps1 script as needed, for example if you create a unique overdue group per training campaign.*
   1. **Example Smart Group (annual training with a fixed deadline)**:
       1. Training - User must have been enrolled in all of these 4 assignments from 01/01/2024 through 02/01/2024 *(where the dates indicate the assigned and deadline dates of the training)*
       2. Training - User must not have completed all of these 4 assignments from 02/01/2024 through 12/31/2099 *(where the start date indicates the deadline)*
    2. **Example Smart Group (new hire training with a relative deadline)**:
       1. Training - User must have been enrolled in all of these 5 assignments prior to the last 30 days *(where days represents the maximum alloted time to complete the assignment)*
       2. Training - User must not have completed all of these 5 assignments
3. In **Entra**, create a new group where you will be adding overdue users. Take note of the Object ID.
4. In **Entra**, create a conditional access policy that will block most access until training is completed.
    1. **Users**: Assign the policy to your Entra group. Recommended: Exclude yourself and/or break glass account since this is a block policy that could cause a lockout.
    2. **Resources**: All cloud apps. Exclude: KnowBe4, optional: any other apps that don't need to be locked out such as VPN or communication tools for reaching Help Desk.
    3. **Conditions**: 0 conditions selected
    4. **Grant**: Block access
5. In **Azure Automation Accounts**:
    1. Create a new Runbook and copy the provided ps1 file.
        1. Paste the KB4 smart group ID into the *$KB4groups* variable
        2. Paste the Entra group object ID into the *$AADgroup* variable
    2. **Variables**: Create a Variable called *KB4AuthToken*. Type: String. This will be your KB4 API token value. You can locate it in KnowBe4 > Account Settings > API > Reporting Token. You can encrypt the Variable if prompted (recommended).
    3. **Identity**:
        1. Enable the System Assigned Managed Identity. The identity's name will be the Automation Account name.
        2. In **Entra Privileged Identity Management (PIM)**, grant the identity the role **Groups Administrator** so that your runbook can modify Entra groups.
    4. **Schedule** your runbook: You can use a Schedule in Automation Accounts, however, the most frequent option available is 1 hour. You may find this to be too slow for releasing user access once they complete their training. Therefore, you can optionally use an **Azure Logic App** to execute your runbook at a higher frequency, such as every 15 minutes:
6. ALTERNATIVE SCHEDULE:
    1. Create an **Azure Logic App**.
    2. **Identity**: Enable the System Assigned Managed Identity. Provide it permission 'Automation Job Operator' where your Automation Account is located, so that it will be able to execute the runbook.
    3. **Logic app designer**:
        1. **Trigger**: Recurrence; frequency is up to you
        2. **Action**: Create job: Select your Automation Account runbook in Azure. For credential, select the Managed Identity of this logic app.
    4. **Alerts** (optional): Create an Alert Rule to detect logic app run failures, for example sending you an email or SMS.
  
## Adding additional KB4 groups
To add more training campaigns over time, simply create another KnowBe4 smart group and paste the ID into the ps1 file *$KB4groups* variable (comma separated).

## Disabling the automation
If you'd like to suspend or terminate this automation, then you may either disable the runbook (or logic app) schedule, or set the conditional access policy to Report mode so that no block effect occurs.

NOTE: There are some safety conditions built into the ps1 file to identify and stop the runbook when unexpected behavior occurs, for example if too many users would be added at once to the Entra group.

