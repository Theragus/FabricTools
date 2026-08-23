Function Remove-FabricItem {
<#
.SYNOPSIS
   Removes selected items from a Fabric workspace.

.DESCRIPTION
   The Remove-FabricItem function removes items from a specified Fabric workspace.

   The scope of the deletion must be stated explicitly by supplying exactly one of `ItemID`,
   `Filter`, or `All`. Supplying none of them is rejected, because the workspace listing that
   drives the deletion would otherwise match every item it contains.

   Each item is confirmed individually, so `-WhatIf` lists precisely what would be removed and
   `-Confirm` prompts per item rather than once for the whole batch.

.PARAMETER WorkspaceID
   The ID of the Fabric workspace. This is a mandatory parameter.

.PARAMETER Filter
   A wildcard pattern matched against each item's DisplayName. Only matching items are removed.

.PARAMETER ItemID
   The ID of a single item to remove.

.PARAMETER All
   Removes every item in the workspace. Required to opt in to a workspace-wide deletion, which
   is otherwise refused.

.EXAMPLE
    Removes every item in the workspace whose DisplayName contains "test".

    ```powershell
    Remove-FabricItem -WorkspaceID "12345678-90ab-cdef-1234-567890abcdef" -Filter "*test*"
    ```

.EXAMPLE
    Removes a single item by ID.

    ```powershell
    Remove-FabricItem -WorkspaceID "12345678-90ab-cdef-1234-567890abcdef" -ItemID "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    ```

.EXAMPLE
    Lists what a workspace-wide deletion would remove, without removing anything.

    ```powershell
    Remove-FabricItem -WorkspaceID "12345678-90ab-cdef-1234-567890abcdef" -All -WhatIf
    ```

.INPUTS
   String. You can pipe a string that contains the workspace ID to Remove-FabricItem.

.OUTPUTS
   None. This function does not return any output.

.NOTES

   Revision History:

   - 2026-08-23 - PBO: Require ItemID, Filter, or All so an unscoped call can no longer delete
     every item in the workspace. Moved ShouldProcess to per-item so the prompt names the item.

   Author: Rui Romano
   https://github.com/microsoft/Analysis-Services/tree/master/pbidevmode/fabricps-pbip

#>
   [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
   param
   (
      [Parameter(Mandatory = $true)]
      [guid]$WorkspaceId,
      [Parameter(Mandatory = $false)]
      [string]$filter,
      [Parameter(Mandatory = $false)]
      [guid]$itemID,
      [Parameter(Mandatory = $false)]
      [switch]$All
   )

   Confirm-TokenState

   if ($itemID) {
      if ($PSCmdlet.ShouldProcess("item $itemID in workspace $WorkspaceId", 'Remove')) {
         Invoke-FabricRestMethod -Uri "workspaces/$($WorkspaceId)/items/$($itemID)" -Method Delete
      }
      return
   }

   if (-not $filter -and -not $All) {
      Write-Message -Message "No scope specified for Remove-FabricItem on workspace $WorkspaceId." -Level Error
      throw "Specify -ItemID, -Filter, or -All. Without one of these every item in workspace $WorkspaceId would be removed; pass -All if that is intended."
   }

   $items = @(Invoke-FabricRestMethod -Uri "workspaces/$WorkspaceId/items" -Method Get)
   Write-Message -Message "Workspace $WorkspaceId contains $($items.Count) item(s)." -Level Verbose

   if ($filter) {
      $items = @($items | Where-Object { $_.DisplayName -like $filter })
      Write-Message -Message "$($items.Count) item(s) match filter '$filter'." -Level Info
   } else {
      Write-Message -Message "Removing all $($items.Count) item(s) from workspace $WorkspaceId." -Level Info
   }

   foreach ($item in $items) {
      $target = "'{0}' (id {1}) in workspace {2}" -f $item.displayName, $item.id, $WorkspaceId
      if ($PSCmdlet.ShouldProcess($target, 'Remove')) {
         Invoke-FabricRestMethod -Uri "workspaces/$WorkspaceId/items/$($item.id)" -Method Delete
      }
   }
}
