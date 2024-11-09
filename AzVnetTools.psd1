#
# Module manifest for module 'AzVnetTools'
#
# Generated by: FredrikRydin
#
# Generated on: 2024-11-09
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'AzVnetTools.psm1'

# Version number of this module.
ModuleVersion = '0.0.2'

# Supported PSEditions
CompatiblePSEditions = @('Desktop', 'Core')

# ID used to uniquely identify this module
GUID = 'cb5d1a34-e2d8-4457-8693-804c9bc26e35'

# Author of this module
Author = 'FredrikRydin'

# Company or vendor of this module
CompanyName = $null

# Copyright statement for this module
Copyright = '(c) FredrikRydin. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Module for to help finding next free Subnet in Azure Virtual Network'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
DotNetFrameworkVersion = '4.7.2'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @(@{ModuleName="Az.Network"; ModuleVersion="6.2.0"})

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Get-IncrementedIPAddress', 'Get-AzNextAvailableSubnet', 'Test-SubnetOverlap')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()
#CmdletsToExport = 'Get-IncrementedIPAddress', 'Get-AzNextAvailableSubnet',
#                  'Test-SubnetOverlap'

# Variables to export from this module
VariablesToExport = ''

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
FileList = @(
    'AzVnetTools.psm1',
    'AzVnetTools.psd1',
    'LICENSE.md',
    'README.md'
)

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('Core', 'desktop','Azure','VirtualNetwork', 'vnet', 'subnet', 'Network')

        # A URL to the license for this module.
        LicenseUri = 'https://www.gnu.org/licenses/agpl-3.0.en.html'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/Fredrik81/AzVnetTools'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

