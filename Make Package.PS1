$packageslocation = "c:\packages\"
$savelocation = ""
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
add-type -assemblyname system.windows.forms

function get-MSIVersion{
    param (
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()] 
            [System.IO.FileInfo] $MSIPATH
    ) 
    if (!(Test-Path $MSIPATH.FullName)) { 
        throw "File '{0}' does not exist" -f $MSIPATH.FullName 
    } 
    try { 
        $WindowsInstaller = New-Object -com WindowsInstaller.Installer 
        $Database = $WindowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $Null, $WindowsInstaller, @($MSIPATH.FullName, 0)) 
        $Query = "SELECT Value FROM Property WHERE Property = 'ProductVersion'"
        $View = $database.GetType().InvokeMember("OpenView", "InvokeMethod", $Null, $Database, ($Query)) 
        $View.GetType().InvokeMember("Execute", "InvokeMethod", $Null, $View, $Null) | Out-Null
        $Record = $View.GetType().InvokeMember( "Fetch", "InvokeMethod", $Null, $View, $Null ) 
        $Version = $Record.GetType().InvokeMember( "StringData", "GetProperty", $Null, $Record, 1 ) 
        return $Version
    } catch { 
        throw "Failed to get MSI file version: {0}." -f $_
    }    
}

$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = $packageslocation }
$FileBrowser.ShowDialog()
$splitfilename = $FileBrowser.SafeFileName.split(".")
$extension = $splitfilename[$splitfilename.count - 1]

#$foldername = [Microsoft.VisualBasic.Interaction]::InputBox('Folder name', 'Folder Name')
[string]$foldername = read-host "Product"
[string]$authors = read-host "Authors"
[string]$summary = read-host "summary"
[string]$description = read-host "Description"
if($extension -eq "EXE"){[string]$SilentArgs = read-host "Silent Args"}


$newpackagelocation = join-path $packageslocation $foldername
$nuspeclocation = join-path $newpackagelocation ($foldername + '.nuspec')
$toolslocation = Join-path $newpackagelocation 'tools'
$toolsinstalllocation = join-path $toolslocation $filebrowser.SafeFileName
$chocolateyinstalllocation = join-path $toolslocation 'chocolateyinstall.ps1'
$chocolateyuninstalllocation = join-path $toolslocation 'chocolateyuninstall.ps1'
$Readmelocation = join-path $newpackagelocation 'ReadMe.md'

& "$env:ProgramData\chocolatey\choco.exe" new $foldername --outputdirectory $packageslocation
Copy-Item $filebrowser.filename "$newpackagelocation\tools"

[xml]$nuspec = Get-Content $nuspeclocation
if ($extension = 'MSI'){
    $MSIVersion = get-MSIVersion -MSIPATH $filebrowser.FileName
    $nuspec.package.metadata.version = $MSIVersion
}


$nuspec.package.metadata.authors = $authors
$nuspec.package.metadata.summary = $summary
$nuspec.package.metadata.description = $description

$nuspec.save($nuspeclocation)

$chocolateyinstall = Get-Content $chocolateyinstalllocation

Write-Output "  fileType      = '$extension' #only one of these: exe, msi, msu"
Write-Output "  #file         = $toolsinstalllocation"
Write-Output '  silentArgs    = "/S"'
Write-Output '#Install-ChocolateyPackage @packageArgs # https://docs.chocolatey.org/en-us/create/functions/install-chocolateypackage'
Write-Output 'Install-ChocolateyInstallPackage @packageArgs # https://docs.chocolatey.org/en-us/create/functions/install-chocolateyinstallpackage'

$chocolateyinstall[
    $chocolateyinstall.indexof(
        '  fileType      = ''EXE_MSI_OR_MSU'' #only one of these: exe, msi, msu'
    )
] = "  fileType      = '$extension' #only one of these: exe, msi, msu"

$chocolateyinstall[
    $chocolateyinstall.indexof(
        '  #file         = $fileLocation'
    )
] = '  file         = Join-Path $toolsDir ' + "'" + $filebrowser.SafeFileName + "'"
if ($extension -eq 'MSI'){
    $chocolateyinstall[
        $chocolateyinstall.indexof(
            '  silentArgs    = "/qn /norestart /l*v `"$($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`"" # ALLUSERS=1 DISABLEDESKTOPSHORTCUT=1 ADDDESKTOPICON=0 ADDSTARTMENU=0'
        )
    ] = '  silentArgs    = "/qn"'
}
if ($extension -eq 'exe'){
    $chocolateyinstall[
        $chocolateyinstall.indexof(
            '  silentArgs    = "/qn /norestart /l*v `"$($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`"" # ALLUSERS=1 DISABLEDESKTOPSHORTCUT=1 ADDDESKTOPICON=0 ADDSTARTMENU=0'
        )
    ] = "  silentArgs    = `"$SilentArgs`""
}
$chocolateyinstall[
    $chocolateyinstall.indexof(
        'Install-ChocolateyPackage @packageArgs # https://docs.chocolatey.org/en-us/create/functions/install-chocolateypackage'
    )
] = '#Install-ChocolateyPackage @packageArgs # https://docs.chocolatey.org/en-us/create/functions/install-chocolateypackage'
$chocolateyinstall[
    $chocolateyinstall.indexof(
        '#Install-ChocolateyInstallPackage @packageArgs # https://docs.chocolatey.org/en-us/create/functions/install-chocolateyinstallpackage'
    )
] = 'Install-ChocolateyInstallPackage @packageArgs # https://docs.chocolatey.org/en-us/create/functions/install-chocolateyinstallpackage'
set-content  $chocolateyinstalllocation $chocolateyinstall

Remove-Item $Readmelocation
Remove-item $chocolateyuninstalllocation

& "$env:ProgramData\chocolatey\choco.exe" pack $nuspeclocation --outputdirectory $savelocation

