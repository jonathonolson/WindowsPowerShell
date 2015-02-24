$csv = 'C:\Users\test\Documents\serveurs.csv'

$servers = Import-Csv $csv

# clear job queue
Remove-Job *
# load job queue with test jobs
$servers | % {
  Start-Job -ScriptBlock {
    $args[0]
    [bool](Test-Connection -Count 1 $args[0] 2>$null)
  } -ArgumentList $_.Ip
}
# wait for jobs to finish
Do {
  Start-Sleep -Milliseconds 100
} while (Get-Job -State 'Running')

# gather job results into hashtable
$availability = @{}
Get-Job | % {
  $result = Receive-Job -Id $_.Id
  $availability[$result[0]] = $result[1]
  Remove-Job -Id $_.Id
}

# add availability column to server data and export back to CSV
$servers | select ServerName, Ip, @{n='Available';e={$availability[$_.Ip]}} |
  Export-Csv $csv -NoType