
param(
    [Parameter()]
    [String]$dbglevel
)

#Set-ExecutionPolicy -ExecutionPolicy Unrestricted
[String[]]$CompName=$env:computername   

function Get-SysUpd ($CompName) {     


    #List all missing updates
    $session1 = New-Object -ComObject Microsoft.Update.Session -ErrorAction silentlycontinue
    #Creating Update searcher 
    $searcher = $session1.CreateUpdateSearcher()
    $result = $searcher.Search("IsInstalled=0")

    #Updates are waiting to be installed 
    $updates = $result.Updates;

    if ($updates.Count -ge 1 ) {
        Write-Host "Windows Updates: found $($updates.Count) to be installed. =>NOK" -Foregroundcolor Red
        if ($dbglevel -eq "--verbose"){
            $updates | Format-Table Title, AutoSelectOnWebSites, IsDownloaded, IsHiden, IsInstalled, IsMandatory, IsPresent, AutoSelection, AutoDownload -AutoSize
            }
    }
    else {
        Write-Host "Windows Updates: =>OK" -Foregroundcolor Green
         }
}


function Get-AvStatus ($CompName) {   

    #AV status
    [system.Version]$OSVersion = (Get-WmiObject win32_operatingsystem -computername $CompName).version

    If ($OSVersion -ge [system.version]'6.0.0.0'){
        $AntiVirusProduct = Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct -ComputerName $compName -ErrorAction Stop
                } 
    Else {
         $AntiVirusProduct = Get-WmiObject -Namespace root\SecurityCenter -Class AntiVirusProduct -ComputerName $compName -ErrorAction Stop
         } 

    #very unlikely to get here in modern Windows       
    if ($AntiVirusProduct.Count -eq 0) {
        Write-Host "Antivirus check: no such product found in the system. => NOK" -Foregroundcolor Red
        Return 1
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

        # convert to hex, add an additional '0' left if necessary

        $hex = [convert]::ToString($productState[0], 16).PadLeft(6,'0')
        $AvSecuritySignatureStatus = $hex.Substring(4,2)

        if ($AvSecuritySignatureStatus -eq "00"){
                $AvSecuritySignatureStatusOkCount++
        }
    }

    if ($AvSecuritySignatureStatusOkCount -eq 0 )  {
        Write-Host "Antivirus check: all your Antivirus definitions are Out of Date.=>NOK" -Foregroundcolor Yellow
    }   
    Else   {           
         Write-Host "Antivirus check: =>OK" -Foregroundcolor Green 
                
    }
}


function Get-FWStatus ($CompName) {
    
    $nofw = 1
    #Check external FW
    If ($OSVersion -ge [system.version]'6.0.0.0'){
        $firewalls =  @(Get-WmiObject -Namespace root\SecurityCenter2 -Class FirewallProduct -ComputerName $compName -ErrorAction Stop)
    }
    else {
        $firewalls = @(Get-WmiObject -Namespace root\SecurityCenter -Class FirewallProduct -ComputerName $compName -ErrorAction Stop)
         }

    if($firewalls.Count -ge 1){
        $nofw = 0
        if ($dbglevel -eq "--verbose"){
            Write-Host "Found external firewall(s)" -Foregroundcolor Green
            
            $firewalls | Foreach-Object {                       
                [int]$productState=$_.ProductState
                $hexString=[System.Convert]::toString($productState,16).padleft(6,'0')
                $provider=$hexString.substring(0,2)
                $realTimeProtec=$hexString.substring(2,2)
                $definition=$hexString.substring(4,2)

                "Product Name : {0}."     -f $_.displayName
                "Service Type : {0}."     -f $SecurityProvider[[String]$provider]
                "State        : {0}.`n`n" -f $RealTimeBehavior[[String]$realTimeProtec]
            }
    }
  }
    #Check Windows FW
    $FWService = (Get-Service | ?{$_.Name -eq "mpssvc"});
    $FWService | %{
     if($_.Status -eq "Running"){
        $nofw = 0  
        if ($dbglevel -eq "--verbose"){
            Write-Host "The $($_.DisplayName) service is running." -Foregroundcolor Green
            }
        }
     else {
            if ($dbglevel -eq "--verbose"){ 
                Write-Host "The $($_.DisplayName) service is stopped." -Foregroundcolor Red
                }
            Return $nofw
                
          }
        }
    
    if ($dbglevel -eq "--verbose"){
        $FWProfiles = (Get-NetFirewallProfile);
        Write-Host "Windows Firewall Profile Statuses" -Foregroundcolor Yellow;
        $FWProfiles | %{
            If($_.Enabled -eq 1){
                $nofw = 0
                Write-Host "The Windows Firewall $($_.Name) profile is enabled" -Foregroundcolor Green
            }
            else {
                Write-Host "The Windows Firewall $($_.Name) profile is disabled" -Foregroundcolor Red
                 }
            }
    }
    
    Return $nofw
}   


#Main
Write-Host "Checking basic Windows Security settings."

If (-not ($env:OS -Match "Win*")) {
    Write-Warning "Unsupported operating system."
    Exit
  }
    
Get-SysUpd $CompName
Get-AvStatus $CompName

$nofw = Get-FWStatus $CompName
if ($nofw -eq 0){
    Write-Host "Firewall status  =>OK"  -Foregroundcolor Green
                }
Else {
    Write-Host "Firewall status  =>NOK"  -Foregroundcolor Yellow
     } 

Exit