function ReadXmlContent($filePath)
{
    try {
        [xml]$xmlContent = Get-Content $filePath;
        return $xmlContent;
    }
    catch {
        Write-Error "Failed to read file : $filePath";
        Write-Error $Error[0].Exception;
        exit 1;
    }
}

<# 
 .Synopsis
  Extract the contents of a NuGet package using nuget.exe

 .Description
  Extract the contents of a NuGet package using nuget.exe

 .Parameter Nupkg
  The NuGet package to extract

 .Parameter Folder
  The folder in which the NuGet package resides

 .Parameter ExtractTo
  The folder to which the NuGet package should be extracted

 .Example
   # Extract a nuget package
   Get-NupkgContent('MyPackage-1.0.0.nupkg', 'C:\packages\', 'C:\ExtractedPackages')
#>
function Get-NupkgContent2
{
    param([string]$Nupkg, [string]$Folder, [string]$ExtractTo)

    try
    {
        if(-Not (Test-path $ExtractTo))
        {
            New-Item -ItemType Directory $ExtractTo
        }

        # Use nuget to extract the package
        .\nuget.exe install $Nupkg -Source $Folder -OutputDirectory $ExtractTo

        return $true;
    }
    catch
    {
        throw;
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-NupkgContent
{
    [cmdletbinding()]
     param([string]$Nupkg, [string]$Folder)

     try
     {
        if(Test-Path("$Folder\$Nupkg"))
        {
            Write-Verbose "$Nupkg is already extracted. Skipping."
            return $true
        }

        # Rename file to zip
        #Get-ChildItem "$Folder\$Nupkg.nupkg" | Rename-Item -NewName {  $_.name  -replace ".nupkg",".zip"  }

        #[System.IO.Compression.ZipFile]::ExtractToDirectory("$Folder\$Nupkg.zip", "$Folder\$Nupkg")
        [System.IO.Compression.ZipFile]::ExtractToDirectory("$Folder\$Nupkg.nupkg", "$Folder\$Nupkg")

        # Rename file to nupkg again
        #Get-ChildItem "$Folder\$Nupkg.zip" | Rename-Item -NewName { $_.Name -replace ".zip", ".nupkg" }

        return $true
     }
     catch
     {
        return $false
     }
}

function Set-NupkgContent
{
    [cmdletbinding()]
     param([string]$Nupkg, [string]$Folder)

     try
     {
        # Remove the old nupkg file
        Remove-Item "$Folder\$Nupkg.nupkg"
        
        # Create new nupkg file
        [System.IO.Compression.ZipFile]::CreateFromDirectory("$Folder\$Nupkg", "$Folder\$Nupkg.nupkg")
        
        
        return $true
     }
     catch
     {
        return $false
     }
}

function Clear-NupkgContent 
{
[cmdletbinding()]
     param([string]$Nupkg, [string]$Folder)

     try
     {
        Remove-Item "$Folder\$Nupkg" -Recurse
      
        return $true
     }
     catch
     {
        return $false
     }
}

function Get-NupkgInformation
{
    [CmdletBinding()]
    param([string]$Nupkg, [string]$Folder)

    try
    {
        $nuspec = Get-ChildItem -Path "$Folder\$Nupk" -Filter "*.nuspec"

        $nuspecXml = ReadXmlContent($nuspec.FullName)

        $id = $nuspecXml.package.metadata.id
        $version = $nuspecXml.package.metadata.version

        $dependencies = @{}

        foreach($dependency in $nuspecXml.package.metadata.dependencies.dependency)
        {
            #Write-Verbose $dependency.dependency.id

            $depId = $($dependency.id)
            $depVersion = $($dependency.version)

            $dependencies[$depId] = $depVersion
        }

        return  @{ 'Id' = $id; 'Version' = $version; 'Nuspec' = $nuspec.FullName; 'Nupkg' = $Nupkg; 'Dependencies' = $dependencies; 'Changed' = $False }
    }
    catch
    {
        throw
    }
}

function Update-NuspecDependencyVersion
{
    param([string]$Nuspec, [string]$DependencyId, [string]$Version)

    try
    {
        $nuspecXml = ReadXmlContent($Nuspec)

        $dependency = $nuspecXml.package.metadata.dependencies.dependency | where { $_.id -eq $DependencyId }
        
        $dependency.version = $Version

        $nuspecXml.Save($Nuspec)

        return $true;

    }
    catch
    {
        return $false;
    }
}