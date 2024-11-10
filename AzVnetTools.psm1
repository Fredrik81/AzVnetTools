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

function Get-FlippedAddressBits {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
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
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$VNetName,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 32)]
        [int]$NewSubnetMask
    )

    begin {
        # Check if Azure PowerShell module is installed
        if (-not (Get-Module -ListAvailable -Name Az.Network)) {
            throw "Azure PowerShell module 'Az.Network' is not installed. Please install it using: Install-Module -Name Az.Network"
        }

        # Check Azure connection
        try {
            $context = Get-AzContext
            if (-not $context) {
                throw "Not connected to Azure. Please run Connect-AzAccount first."
            }
        }
        catch {
            throw "Failed to check Azure connection: $($_.Exception.Message)"
        }
    }

    process {
        # Get the VNet
        try {
            # Verify resource group exists
            $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName.Trim() -ErrorAction Stop
            Write-Verbose "Found resource group: $ResourceGroupName in subscription $((Get-AzContext).Subscription.Name)"
        }
        catch {
            Throw "Could not find resource group: $ResourceGroupName in subscription $((Get-AzContext).Subscription.Name)"
        }

        # Get Virtual Network with detailed error handling
        try {
            $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName.Trim() -Name $VNetName.Trim() -ErrorAction Stop
            if (-not $vnet) {
                throw "Virtual Network not found"
            }
            Write-Verbose "Successfully retrieved VNet: $VNetName"
        }
        catch {
            $errMsg = $_.Exception.Message
            switch -Regex ($errMsg) {
                'StatusCode: 404' {
                    throw "Virtual Network '$VNetName' not found in resource group '$ResourceGroupName'"
                }
                'StatusCode: 403' {
                    throw "Access denied. Please check your permissions for Virtual Network '$VNetName'"
                }
                'StatusCode: 429' {
                    throw "Too many requests. Please try again later"
                }
                default {
                    throw "Failed to get Virtual Network: $($errMsg)"
                }
            }
        }

        # Validate VNet has address space
        if (-not $vnet.AddressSpace.AddressPrefixes -or $vnet.AddressSpace.AddressPrefixes.Count -eq 0) {
            throw "Virtual Network has no address space configured"
        }

        # Get existing subnets
        $existingSubnets = $vnet.Subnets.AddressPrefix
        Write-Verbose "Found $($existingSubnets.Count) existing subnets"

        # Get the VNet address space
        $vnetAddressSpace = $vnet.AddressSpace.AddressPrefixes[0]
        $vnetNetwork = [System.Net.IPAddress]::Parse(($vnetAddressSpace -split "/")[0])
        $vnetMask = [System.Convert]::ToInt32(($vnetAddressSpace -split "/")[1])

        # Validate subnet mask is valid for VNet
        if ($NewSubnetMask -lt $vnetMask) {
            throw "New subnet mask /$NewSubnetMask is larger than VNet mask /$vnetMask"
        }

        try {
            # Calculate the number of IP addresses in the new subnet
            $newSubnetSize = [Math]::Pow(2, (32 - $NewSubnetMask))

            # Start from the beginning of the VNet range
            $currentIP = $vnetNetwork.IPAddressToString

            #Get vNet maximum parameters
            $maxAddress = Get-IncrementedIPAddress -IPAddress $vnetNetwork.IPAddressToString -IncrementBy ([Math]::Pow(2, (32 - $vnetMask)))
            $maxBit = [System.Net.IPAddress]::Parse($maxAddress).Address
            $maxBit = Get-FlippedAddressBits -IPAddress $maxBit

            Write-Verbose "Searching for available subnet space..."
            while ((Get-FlippedAddressBits -IPAddress ([System.Net.IPAddress]::Parse($currentIP).Address)) -lt $maxBit) {
                $candidateCIDR = "$currentIP/$NewSubnetMask"

                # Check if this range overlaps with existing subnets
                $overlap = $false
                foreach ($subnet in $existingSubnets) {
                    if (Test-SubnetOverlap -Subnet1 $candidateCIDR -Subnet2 $subnet) {
                        $overlap = $true
                        Write-Verbose "Subnet $candidateCIDR overlaps with existing subnet $subnet"
                        break
                    }
                }

                if (-not $overlap) {
                    Write-Verbose "Found available subnet: $candidateCIDR"
                    return $candidateCIDR
                }

                # Move to the next potential subnet
                $currentIP = Get-IncrementedIPAddress -IPAddress $currentIP -IncrementBy $newSubnetSize
            }
            throw "No available subnet space found within VNet address range"
        }
        catch {
            # Log the error and rethrow
            Write-Error "Error in Get-NextAvailableSubnet: $($_.Exception.Message)"
            throw
        }
    }
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
    $net2end = $net2start + ([Math]::Pow(2, (32 - $mask2))) - 1

    return (($net1start -le $net2end) -and ($net1end -ge $net2start))
}

# Export the public functions
Export-ModuleMember -Function Get-IncrementedIPAddress, Get-AzNextAvailableSubnet, Test-SubnetOverlap
