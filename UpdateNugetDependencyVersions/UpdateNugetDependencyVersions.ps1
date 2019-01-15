[CmdletBinding()]
param(
    [string]$PackagesFolder,
    [string]$UseNupk
    [string]$UseVerbose = "false"
)
begin
{
    $CurrentVerbosePreference = $VerbosePreference;

    if($VerbosePreference -eq "SilentlyContinue" -And $UseVerbose -eq "true") {
        $VerbosePreference = "continue"
    }

    Write-Host "Initializing..."
    Write-Verbose "Packages are stored in: $PackagesFolder"

    if(-Not (Test-Path $PackagesFolder)) {
        Write-Warning "$PackagesFolder does not exist."
        exit 0;
    }

    # Import functions module that we use
    Import-Module -Name ./modules/UpdateNugetDependencyVersions_Functions -Force
}
process
{
    Write-Host "Commencing..."

    # Get list of nupkg files
    $nugetPackages = Get-ChildItem -Path $PackagesFolder -Filter *.nupkg -File

    Write-Verbose "Found $($nugetPackages.Length) NuGet packages in $PackagesFolder"

    $packageDictionary = @{}

    Write-Host "Extracting NuGet packages"

    foreach($nugetPackage in $nugetPackages)
    {
        $nugetFileName = $nugetPackage.BaseName;

        Write-Verbose "Processing $nugetFileName"
        
        $success = Get-NupkgContent -Nupkg $nugetFileName -Folder $PackagesFolder -Verbose

        if(-Not $success)
        {
            Write-Host "Failed to process $nugetFileName"
            continue
        }

        $info = Get-NupkgInformation -Nupkg $nugetFileName -Folder "$PackagesFolder\$NugetFileName"

        $packageDictionary[$info.id] = $info
    }

    Write-host "Checking dependencies"
   
    foreach($packageId in $packageDictionary.Keys)
    {
        Write-Verbose "Checking dependencies in '$packageId'"

        $package = $packageDictionary[$packageId]

        foreach($dependantPackageId in $package.Dependencies.Keys)
        {
            Write-Verbose "Checking dependency on '$dependantPackageId'"

            if($packageDictionary.ContainsKey($dependantPackageId))
            {
                $dependantPackage = $packageDictionary[$dependantPackageId];

                $dependencyOnVersion = $package.Dependencies[$dependantPackageId];

                if($dependantPackage.Version -ne $dependencyOnVersion)
                {
                    Write-Warning "Package '$packageId' is dependant on '$($dependantPackage.Id), $dependencyOnVersion' but the package is on version $($dependantPackage.Version)"
                    
                    $package.Changed = Update-NuspecDependencyVersion -Nuspec $package.Nuspec -DependencyId $dependantPackage.Id -Version $dependantPackage.Version
                }
            }
        }

        if($package.Changed -eq $True)
        {
            Write-Verbose "$packageId has been modified, re-creating nupkg file."

            $packageCreated = Set-NupkgContent -Nupkg $package.Nupkg -Folder $PackagesFolder

            if(-Not $packageCreated)
            {
                Write-Warning "Not able to create update nupkg file."
            }
        }

        Write-Verbose "Cleaning up files for $($package.Nupkg)"

        $cleanedUp = Clear-NupkgContent -Nupkg $package.Nupkg -Folder $PackagesFolder

        if(-Not $cleanedUp)
        {
            Write-Warning "Unable to clean up $($package.Nupkg)"
        }
    }

}
end
{
    $VerbosePreference = $CurrentVerbosePreference
}

