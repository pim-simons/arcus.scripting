<#
 .Synopsis
  Removes the version tag from old containers in Azure Container Registry.

 .Description
  The Remove-ContainerVersionTags cmdlet removes the version tag of old containers in the Azure Container Registry by retrieving the history of helm releases and removing old tags of containers that are not used anymore.

 .Parameter RegistryName
  The name of the of Azure Container Registry.

 .Parameter ReleaseName
  The name of the helm release.

 .Parameter Namespace
  The helm namespace used to retrieve the releases.

 .Parameter NumberOfRevisionsToKeep
  The number of release revisions for which the tags are not deleted.
#>
function Remove-ContainerVersionTags {
    param(
	    [Parameter(Mandatory = $true)][string] $RegistryName = $(throw "The name of the Azure Container Registry must be supplied"),
        [Parameter(Mandatory = $false)][string] $ReleaseName,
        [Parameter(Mandatory = $false)][string] $Namespace,
        [Parameter(Mandatory = $true)][int] $NumberOfRevisionsToKeep = $(throw "The number of revisions to keep must be supplied")
    )

    . $PSScriptRoot\Scripts\Remove-ContainerVersionTags.ps1 -RegistryName $RegistryName -ReleaseName $ReleaseName -Namespace $Namespace -NumberOfRevisionsToKeep $NumberOfRevisionsToKeep

}

Export-ModuleMember -Function Remove-ContainerVersionTags