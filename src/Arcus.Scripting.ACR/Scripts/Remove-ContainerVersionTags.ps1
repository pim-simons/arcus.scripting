param(
	[Parameter(Mandatory = $true)][string] $RegistryName = $(throw "The name of the Azure Container Registry must be supplied"),
    [Parameter(Mandatory = $false)][string] $ReleaseName,
    [Parameter(Mandatory = $false)][string] $Namespace,
    [Parameter(Mandatory = $true)][int] $NumberOfRevisionsToKeep = $(throw "The number of revisions to keep must be supplied")
)

function GetTagsToKeep {
    param(
        [Parameter(Mandatory = $true)][string] $ReleaseName,
		[Parameter(Mandatory = $true)][string] $Namespace,
		[Parameter(Mandatory = $true)][int] $NumberOfRevisionsToKeep
    )

	Write-Host "Retrieving container release history for '$ReleaseName' in namespace '$Namespace'"
	$history = helm history $ReleaseName --max $NumberOfRevisionsToKeep -n $Namespace -o json | ConvertFrom-Json | foreach {$_} | where {$_ -ne $null}

	if ($history.Length -eq 0) {
		Write-Host "No container release history for '$ReleaseName' in namespace '$Namespace' found"
	} else {
		foreach ($item in $history) {
			$chart = $item.chart
			$revision = $item.revision
			$appversion = $item.app_version
			$updated = $item.updated
			$description = $item.description
	
			Write-Host "Found chart '$chart' with revision '$revision' for app version '$appversion' which was last updated at '$updated' with the description '$description'" 

			$pos = $chart.IndexOf("-")
			$chartName = $chart.Substring(0, $pos)
			$chartVersion = $chart.Substring($pos+1)
			$repo = helm search repo $chartName --version $chartVersion -o json | ConvertFrom-Json | foreach {$_} | where {$_ -ne $null}
			$repoName = $repo.name
			
			if (($global:tagsToKeep.Where({$_.RepoName -eq $repoName -And $_.Tag -eq $appversion}) | foreach {$_} | where {$_ -ne $null}).Length -eq 0) {
				$global:tagsToKeep += [pscustomobject]@{RepoName=$repoName; Tag=$appversion}
			}
		}
	}
	Write-Host "Retrieving container release history for '$ReleaseName' in namespace '$Namespace' done"
	Write-Host "----------"
}

function RemoveTags {
    param(
        [Parameter(Mandatory = $true)][string] $RegistryName
    )

	foreach ($tagToKeep in $global:tagsToKeep) {
		$repoName = $tagToKeep.RepoName
		$containerTags = (Get-AzContainerRegistryTag -RegistryName $RegistryName -RepositoryName $repoName).Tags
		if ($containerTags -ne $null) {
			foreach($containerTag in $containerTags.Name) {
				Write-Host "Tag '$containerTag' for '$repoName' in registry '$RegistryName' found"

				if ($containerTag -eq 'latest' -Or ($global:tagsToKeep.Where({$_.RepoName -eq $repoName -And $_.Tag -eq $containerTag}) | foreach {$_} | where {$_ -ne $null}).Length -eq 1) {
					Write-Host "Tag '$containerTag' for '$repoName' in registry '$RegistryName' falls within the revisions to keep and will not be removed"
				} else {
					$removeTag = Remove-AzContainerRegistryTag -RegistryName $RegistryName -RepositoryName $repoName -Name $containerTag
					Write-Host "Tag '$containerTag' for '$repoName' in registry '$RegistryName' removed"
				}
			}
		}
	}
}

$global:tagsToKeep = @()
if ($ReleaseName -eq '') {
	Write-Host "Retrieving container releases"
	$releases = helm list --all-namespaces -o json | ConvertFrom-Json | foreach {$_} | where {$_ -ne $null}

	if($releases.Length -eq 0) {
		Write-Host "No container releases found"
	} else {
		foreach ($release in $releases) {
			$releaseName = $release.name
			$releaseNamespace = $release.namespace
			
			GetTagsToKeep -ReleaseName $releaseName -Namespace $releaseNamespace -NumberOfRevisionsToKeep $NumberOfRevisionsToKeep
		}
	}
} else {
	if ($Namespace -eq '') {
		GetTagsToKeep -ReleaseName $ReleaseName -Namespace 'default' -NumberOfRevisionsToKeep $NumberOfRevisionsToKeep
	} else {
		GetTagsToKeep -ReleaseName $ReleaseName -Namespace $Namespace -NumberOfRevisionsToKeep $NumberOfRevisionsToKeep
	}
}

if ($global:tagsToKeep -ne $null -Or $global:tagsToKeep.Length -gt 0) {
	RemoveTags -RegistryName $RegistryName
}