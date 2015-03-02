if (-not(get-module activedirectory)) {Import-Module ActiveDirectory}

$groups = get-adgroup -Filter * -ErrorAction SilentlyContinue | Where-Object {$_.name -notlike "Domain Computers" -and "Domain Controllers"}
# $groups | Select-Object -ExpandProperty Name | ogv
$report = @()
foreach ($group in $groups) {
    $members = get-adgroupmember $group.Name -ErrorAction SilentlyContinue
    Foreach ($member in $members) {
            $objGroupMember = New-Object PSCustomObject -Property @{
            Group = $Group.Name
            Member = $Member.SamAccountName
            }
            $report += $objGroupMember
        } #end foreach $member
} #end foreach $group

$report | Export-Csv GroupMembers.csv -NoTypeInformation