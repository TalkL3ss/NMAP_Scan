#General Settings
$global:cFile = 'c:\temp\Current.csv'
$oFile = 'c:\temp\OldVer.csv'
$max = 20
cp $cFile $oFile -Force #copy the last scan report to old one for latest compare
'"IP","PORT"' | tee $cFile
$CompFile =  'C:\temp\RunNewOld.csv'

#Start Nmap With No Port and only ping to get all alive hosts, and strip the output to ip only
$nmapper = (nmap -sP 0.0.0.0/24 | Select-String -Pattern "\d{1,3}(\.\d{1,3}){3}" -AllMatches).Matches.Value


Function AsyncJobs($ip) {
#Scan for all open ports in the list
$sb = { param($ip)
        $results = (nmap -R -sS -T4 --open -p- $ip)
        $oPorts = (($results | Select-String -Pattern "\d{1,5}/tcp" -AllMatches).Matches.Value | select @{ Name = 'Port';  Expression = {$_}},@{ Name = 'IP';  Expression = {($results | Select -First 2 | select -Last 1).split(" ")[4]}})
        $oPorts | Export-Csv -Path 'c:\temp\Current.csv' -Append -NoClobber -NoTypeInformation
        }

         if (!((Get-Job -State Running).Count -lt $max)) { (Get-Job -State Running) | Wait-Job -Any }
            Start-Job -Name $ip -ScriptBlock $sb -ArgumentList $ip | out-null
} 

$nmapper | % { AsyncJobs -ip $_  }
Get-Job * | Wait-Job 
$CompObjs =  Compare-Object (gc $cFile) (gc $oFile) | select @{N='Address'; exp= {($_.InputObject).split(",")[1]}},@{N='Port'; exp= {($_.InputObject).split(",")[0]}},@{N='Removed/Add'; exp= {if ($_.SideIndicator -like "<=") { "Added" } elseif ($_.SideIndicator -like "=>") { "Removed" }}} 
if ($CompObjs.Count -ge 1) { $CompObjs | tee $CompFile }
else { "No Chnages Are Made" | tee $CompFile }
