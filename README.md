# AzVnetTools
This module will help to find next available subnet (CIDR) with given ip mask and more.
Module include these commands:
- Get-AzNextAvailableSubnet
-- Find next available subnet address with given mask
- Get-IncrementedIPAddress
-- Increment an ipadress with given number of addresses
- Test-SubnetOverlap
-- Test if two subnet addresses overlap

```
# Example usage
$resourceGroupName = "rg-test"  # Replace with your resource group name
$vnetName = "vnet-test"  # Replace with your VNet name
$newSubnetMask = 28  # Replace with your desired subnet mask

$nextAvailableSubnet = Get-NextAvailableSubnet -ResourceGroupName $resourceGroupName -VNetName $vnetName -NewSubnetMask $newSubnetMask
if ($nextAvailableSubnet -eq $null) {
    Write-Error "No available subnet found"
    return
}
Write-Host "Next available subnet: $nextAvailableSubnet"
Write-Host "Network:"$nextAvailableSubnet.Split("/")[0]
Write-Host "Mask:"$nextAvailableSubnet.Split("/")[1]
```
-- Example output:
```
Next available subnet: 10.10.16.176/28
Network: 10.10.16.176
Mask: 28
```
