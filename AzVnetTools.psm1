#AzVnetTools.psm1

<#
.SYNOPSIS
Increments an IP address by a specified amount.

.DESCRIPTION
This function takes an IP address as a string and increments it by the specified amount.
If no increment is specified, it defaults to 1.

.PARAMETER IPAddress
The IP address to increment.

.PARAMETER IncrementBy
The number to increment the IP address by. Defaults to 1.

.EXAMPLE
Increment-IPAddress -IPAddress "192.168.0.1" -IncrementBy 5
Returns: 192.168.0.6

.NOTES
This function wraps around to 0.0.0.0 if the increment goes beyond 255.255.255.255.
#>
function Get-IncrementedIPAddress {
    param (
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        [Parameter(Mandatory = $false)]
        [int]$IncrementBy = 1
    )

    try {
        # Convert the IP address string to an IPAddress object
        $ip = [System.Net.IPAddress]::Parse($IPAddress)

        # Convert the IP address to a 32-bit unsigned integer
        $arrAddress = $ip.GetAddressBytes()
        [array]::Reverse($arrAddress)
        $ipInt = [System.BitConverter]::ToUInt32($arrAddress, 0)

        # Increment the integer
        $ipInt += $IncrementBy

        # Convert back to an IP address and reverse array
        $newIP = [System.Net.IPAddress]::new($ipInt)
        $arrAddress = $newIP.GetAddressBytes()
        [array]::Reverse($arrAddress)
        $newIP = [System.Net.IPAddress]::new($arrAddress)

        return $newIP.ToString()
    }
    catch {
        Write-Error "Failed to increment IP address: $_"
        return $null
    }
}

function Get-FlippedAddressBits
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $IPAddress
    )

    try {
        # Convert the IP address string to an IPAddress object
        $ip = [System.Net.IPAddress]::Parse($IPAddress)

        # Convert the IP address to a 32-bit unsigned integer
        $arrAddress = $ip.GetAddressBytes()
        $ipInt = [System.BitConverter]::ToUInt32($arrAddress, 0)

        return $ipInt
    }
    catch {
        Write-Error "Failed to increment IP address: $_"
        return $null
    }
}

<#
.SYNOPSIS
Finds the next available subnet in an Azure Virtual Network.

.DESCRIPTION
This function searches for the next available subnet within a specified Azure Virtual Network
that doesn't overlap with existing subnets.

.PARAMETER ResourceGroupName
The name of the resource group containing the Virtual Network.

.PARAMETER VNetName
The name of the Virtual Network.

.PARAMETER NewSubnetMask
The subnet mask for the new subnet (in CIDR notation, e.g., 24 for a /24 subnet).

.EXAMPLE
Get-AzNextAvailableSubnet -ResourceGroupName "MyRG" -VNetName "MyVNet" -NewSubnetMask 24
Returns: "10.0.1.0/24" (if this is the next available /24 subnet)

.NOTES
Requires the Az PowerShell module to be installed and connected to an Azure account.
#>
function Get-AzNextAvailableSubnet {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [string]$VNetName,
        [Parameter(Mandatory=$true)]
        [int]$NewSubnetMask
    )

    # Get the VNet
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName

    if (-not $vnet) {
        Write-Error "VNet not found"
        return $null
    }

    # Get existing subnets
    $existingSubnets = $vnet.Subnets.AddressPrefix

    # Get the VNet address space
    $vnetAddressSpace = $vnet.AddressSpace.AddressPrefixes[0]
    $vnetNetwork = [System.Net.IPAddress]::Parse(($vnetAddressSpace -split "/")[0])
    $vnetMask = [System.Convert]::ToInt32(($vnetAddressSpace -split "/")[1])

    # Calculate the number of IP addresses in the new subnet
    $newSubnetSize = [Math]::Pow(2, (32 - $NewSubnetMask))

    # Start from the beginning of the VNet range
    $currentIP = $vnetNetwork.IPAddressToString

    $maxAddress = Get-IncrementedIPAddress -IPAddress $vnetNetwork.IPAddressToString -IncrementBy ([Math]::Pow(2, (32 - $vnetMask)))
    $maxBit = [System.Net.IPAddress]::Parse($maxAddress).Address
    $maxBit = Get-FlippedAddressBits -IPAddress $maxBit
    while ((Get-FlippedAddressBits -IPAddress ([System.Net.IPAddress]::Parse($currentIP).Address)) -lt $maxBit) {
        $candidateCIDR = "$currentIP/$NewSubnetMask"

        # Check if this range overlaps with existing subnets
        $overlap = $false
        foreach ($subnet in $existingSubnets) {
            if (Test-SubnetOverlap -Subnet1 $candidateCIDR -Subnet2 $subnet) {
                $overlap = $true
                break
            }
        }

        if (-not $overlap) {
            return $candidateCIDR
        }

        # Move to the next potential subnet
        $currentIP = Get-IncrementedIPAddress -IPAddress $currentIP -IncrementBy $newSubnetSize
    }

    return
}

<#
.SYNOPSIS
Tests if two subnets overlap.

.DESCRIPTION
This function checks if two given subnets (in CIDR notation) overlap with each other.

.PARAMETER Subnet1
The first subnet in CIDR notation (e.g., "192.168.1.0/24").

.PARAMETER Subnet2
The second subnet in CIDR notation (e.g., "192.168.2.0/24").

.EXAMPLE
Test-SubnetOverlap -Subnet1 "192.168.1.0/24" -Subnet2 "192.168.1.128/25"
Returns: $true (because these subnets overlap)

.NOTES
This function does not validate the correctness of the CIDR notation.
#>
function Test-SubnetOverlap {
    param (
        [string]$Subnet1,
        [string]$Subnet2
    )

    $network1 = [System.Net.IPAddress]::Parse(($Subnet1 -split "/")[0])
    $mask1 = [System.Convert]::ToInt32(($Subnet1 -split "/")[1])
    $net1start = Get-FlippedAddressBits -IPAddress $network1.Address
    $net1end = $net1start + ([Math]::Pow(2, (32 - $mask1))) - 1
    $network2 = [System.Net.IPAddress]::Parse(($Subnet2 -split "/")[0])
    $mask2 = [System.Convert]::ToInt32(($Subnet2 -split "/")[1])
    $net2start = Get-FlippedAddressBits -IPAddress $network2.Address
    $net2end = $net2start + ([Math]::Pow(2, (32 - $mask2))) -1

    return (($net1start -le $net2end) -and ($net1end -ge $net2start))
}

# Export the public functions
Export-ModuleMember -Function Get-IncrementedIPAddress, Get-AzNextAvailableSubnet, Test-SubnetOverlap
