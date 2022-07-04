
param(
    [Parameter()]
    [String]$dbglevel
)

#Set-ExecutionPolicy -ExecutionPolicy Unrestricted


If (-not ($env:OS -Match "Win*")) {
    Write-Warning "Unsupported operating system."
    Exit
        }

#List all missing updates
$session1 = New-Object -ComObject Microsoft.Update.Session -ErrorAction silentlycontinue
#Creating Update searcher 
$searcher = $session1.CreateUpdateSearcher()
$result = $searcher.Search("IsInstalled=0")

#Updates are waiting to be installed 
$updates = $result.Updates;
  [String[]]$CompName=$env:computername

if ($updates.Count -ge 1 ){
    Write-Warning "Windows Updates: found $($updates.Count) to be installed. =>NOK" 
    if ($dbglevel -eq "--verbose"){
        $updates | Format-Table Title, AutoSelectOnWebSites, IsDownloaded, IsHiden, IsInstalled, IsMandatory, IsPresent, AutoSelection, AutoDownload -AutoSize
        }
}
Else{
    Write-output "Windows Updates: =>OK"
}
#AV status
[system.Version]$OSVersion = (Get-WmiObject win32_operatingsystem -computername $CompName).version

If ($OSVersion -ge [system.version]'6.0.0.0') 
            {
                $AntiVirusProduct = Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct -ComputerName $compName -ErrorAction Stop
            } 
            Else 
            {
                $AntiVirusProduct = Get-WmiObject -Namespace root\SecurityCenter -Class AntiVirusProduct -ComputerName $compName -ErrorAction Stop
            } 

#very unlikely to get here in modern Windows       
if ($AntiVirusProduct.Count -eq 0) {
    Write-Warning "Antivirus check: no such product found in this system. => NOK"
    Exit
 }
 
 
$productStates = $AntiVirusProduct.productState
$wsc_security_signature_status_ok_status_count = 0
foreach($productState in $productStates){

    <#  
    This part is courtesy of :  
    https://mspscripts.com/get-installed-antivirus-information-2/   

    it appears that if you convert the productstate to HEX then you can read the 1st 2nd or 3rd block 
    to get whether product is enabled/disabled and whether definitons are up-to-date or outdated
    #>

    # convert to hex, add an additional '0' left if necesarry

    $hex = [convert]::ToString($productState[0], 16).PadLeft(6,'0')
    $AvSecuritySignatureStatus = $hex.Substring(4,2)

    if ($AvSecuritySignatureStatus -eq "00"){
            $AvSecuritySignatureStatusOkCount++
    }
}   

if ($AvSecuritySignatureStatusOkCount -eq 0 )  {
    Write-Warning "Antivirus check: all your Antivirus definitions are Out of Date.=>NOK" 
}   
Else   {           
    Write-output "Antivirus check: =>OK"       
            
} 

Exit