#TODO: split the config from the function + do not send report if no changes are made
$cFile = 'c:\temp\Current.csv'
$oFile = 'c:\temp\OldVer.csv'
cp $cFile $oFile -Force
$max = 20
$nmapper = (nmap -sP 0.0.0.0/24 | Select-String -Pattern "\d{1,3}(\.\d{1,3}){3}" -AllMatches).Matches.Value
rm $cFile -Force -Confirm:$false
'"IP","PORT"' | tee $cFile -Force 

Function AsyncJobs($ip) {
$sb = { param($ip)
        $results = (nmap -R -sS -n -T4 --open -p- $ip)
        $oPorts = (($results | Select-String -Pattern "\d{1,5}/tcp" -AllMatches).Matches.Value | select @{ Name = 'Port';  Expression = {$_}},@{ Name = 'IP';  Expression = {($results | Select -First 2 | select -Last 1).split(" ")[4]}})
        $oPorts | Export-Csv -Path $cFile -Append -NoClobber -NoTypeInformation
        }

         if (!((Get-Job -State Running).Count -lt $max)) { (Get-Job -State Running) | Wait-Job -Any }
            Start-Job -Name $ip -ScriptBlock $sb -ArgumentList $ip | out-null


} 

$nmapper | select -First 4 |  % -parallel { AsyncJobs -ip $_  }
Get-Job * | Wait-Job 
Compare-Object (gc 'C:\temp\Current.csv') (gc 'C:\temp\OldVer.csv') | select @{N='Address'; exp= {($_.InputObject).split(",")[1]}},@{N='Port'; exp= {($_.InputObject).split(",")[0]}},@{N='Removed/Add'; exp= {if ($_.SideIndicator -like "<=") { "Added" } elseif ($_.SideIndicator -like "=>") { "Removed" }}} | tee C:\temp\RunNewOld.csv
ii C:\temp\RunNewOld.csv
