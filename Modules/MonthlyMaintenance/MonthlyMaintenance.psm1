Function Get-DiskDrive{
  <#
   .Synopsis
    This function returns capacity and freespace in gigs, and percent free
   .Description
    This function returns capacity and freespace in gigs, and percent free. By
    default it returns the system drive (normally drive c:)
   .Example
    Get-DiskDrive
    Returns capacity and free space in gigabytes. It also returns percent free,
    and the drive letter and drive label of the system drive on the local machine.
   .Example
    Get-DiskDrive -drive e: -computer berlin
    Returns capacity and free space in gigabytes of the e: drive. It also returns
    percent free, and the drive letter and drive label of the system drive on the
    remote machine named berlin.
   .Example
    Get-DiskDrive -drive e: -computer berlin, munich
    Returns capacity and free space in gigabytes of the e: drive. It also returns
    percent free, and the drive letter and drive label of the system drive on two
    remote machines named berlin and munich.
   .Example
    Get-DiskDrive -drive c:, e: -computer berlin, munich
    Returns capacity and free space in gigabytes of the C: and e: drive. It also
    returns percent free, and the drive letter and drive label of the system drive
    on two remote machines named berlin and munich.
   .Example
    "c:","d:","f:" | % { Get-DiskDrive $_ }
    Returns information about c, d, and f drives on local computer.
   .Example
    Get-DiskDrive -d "c:","d:","f:"
    Returns information about c, d, and f drives on local computer. Same command
    as the previous example - but easier to read. But on my computer this is a
    bit slower than the previous command (40 milliseconds).
   .Parameter drive
    The drive letter to query.  Defaults to system drive (normally c:)
   .Parameter computername
    The name of the computer to query. Defaults to local machine.
   .Notes
    NAME:  Example-
    AUTHOR: ed wilson, msft
    LASTEDIT: 06/02/2011 16:12:08
    KEYWORDS:
    HSG: HSG-06-26-2011
   .Link
    Http://www.ScriptingGuys.com/blog
 #Requires -Version 2.0
 #>
 Param(
  [string[]]$drive = $env:SystemDrive,
  [string[]]$computername = $env:COMPUTERNAME
 ) #end param
 Foreach($d in $drive)
 {
  Get-WmiObject -Class win32_Volume -ComputerName $computername -Filter "DriveLetter = '$d'" |
  Select-object DriveLetter, Label, FileSystem, PageFilePresent,
  @{Name = "ComputerName"; Expression = {$_.__Server} },
  @{Name = "Capacity(GB)"; Expression = {$_.capacity / 1GB} },
  @{Name = "FreeSpace(GB)"; Expression = {$_.Freespace / 1GB} },
  @{Name = "PercentFree"; Expression = { ($_.FreeSpace / $_.Capacity)*100 } }
 } # end foreach
 
} #end function get-diskdrive
function Get-DiskFree {
    [CmdletBinding()]
    param 
    (
        [Parameter(Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias('hostname')]
        [Alias('cn')]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        
        [Parameter(Position=1,
                   Mandatory=$false)]
        [Alias('runas')]
        [System.Management.Automation.Credential()]$Credential =
        [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Position=2)]
        [switch]$Format
    )
    
    BEGIN
    {
        function Format-HumanReadable 
        {
            param ($size)
            switch ($size) 
            {
                {$_ -ge 1PB}{"{0:#.#'P'}" -f ($size / 1PB); break}
                {$_ -ge 1TB}{"{0:#.#'T'}" -f ($size / 1TB); break}
                {$_ -ge 1GB}{"{0:#.#'G'}" -f ($size / 1GB); break}
                {$_ -ge 1MB}{"{0:#.#'M'}" -f ($size / 1MB); break}
                {$_ -ge 1KB}{"{0:#'K'}" -f ($size / 1KB); break}
                default {"{0}" -f ($size) + "B"}
            }
        }
        
        $wmiq = 'SELECT * FROM Win32_LogicalDisk WHERE Size != Null AND DriveType >= 2'
    }
    
    PROCESS
    {
        foreach ($computer in $ComputerName)
        {
            try
            {
                if ($computer -eq $env:COMPUTERNAME)
                {
                    $disks = Get-WmiObject -Query $wmiq `
                             -ComputerName $computer -ErrorAction Stop
                }
                else
                {
                    $disks = Get-WmiObject -Query $wmiq `
                             -ComputerName $computer -Credential $Credential `
                             -ErrorAction Stop
                }
                
                if ($Format)
                {
                    # Create array for $disk objects and then populate
                    $diskarray = @()
                    $disks | ForEach-Object { $diskarray += $_ }
                    
                    $diskarray | Select-Object @{n='Name';e={$_.SystemName}}, 
                        @{n='Vol';e={$_.DeviceID}},
                        @{n='Size';e={Format-HumanReadable $_.Size}},
                        @{n='Used';e={Format-HumanReadable `
                        (($_.Size)-($_.FreeSpace))}},
                        @{n='Avail';e={Format-HumanReadable $_.FreeSpace}},
                        @{n='Use%';e={[int](((($_.Size)-($_.FreeSpace))`
                        /($_.Size) * 100))}},
                        @{n='FS';e={$_.FileSystem}},
                        @{n='Type';e={$_.Description}}
                }
                else 
                {
                    foreach ($disk in $disks)
                    {
                        $diskprops = @{'Volume'=$disk.DeviceID;
                                   'Size'=$disk.Size;
                                   'Used'=($disk.Size - $disk.FreeSpace);
                                   'Available'=$disk.FreeSpace;
                                   'FileSystem'=$disk.FileSystem;
                                   'Type'=$disk.Description
                                   'Computer'=$disk.SystemName;}
                    
                        # Create custom PS object and apply type
                        $diskobj = New-Object -TypeName PSObject `
                                   -Property $diskprops
                        $diskobj.PSObject.TypeNames.Insert(0,'BinaryNature.DiskFree')
                    
                        Write-Output $diskobj
                    }
                }
            }
            catch 
            {
                # Check for common DCOM errors and display "friendly" output
                switch ($_)
                {
                    { $_.Exception.ErrorCode -eq 0x800706ba } `
                        { $err = 'Unavailable (Host Offline or Firewall)'; 
                            break; }
                    { $_.CategoryInfo.Reason -eq 'UnauthorizedAccessException' } `
                        { $err = 'Access denied (Check User Permissions)'; 
                            break; }
                    default { $err = $_.Exception.Message }
                }
                Write-Warning "$computer - $err"
            } 
        }
    }
    
    END {}
}
function Get-LogErrorByMessage {
<#
.Synopsis
   LogErrorByMessage is a function to sort log files into a useful summary
.DESCRIPTION
   LogErrorByMessage shows all errors in a log file and sorts them uniquely by the data in the messages. Errors with duplicate messages are filtered out.
.EXAMPLE
   LogErrorByMessage -log System -days 30
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   -ComputerName Specify the computer(s) to query
   -log Specify the log to query (System, Application, Security, or Setup)
   -days The number of days to search back in log history. Default is 30 days.
.NOTES
   Written by JOlson
#>
    [CmdletBinding()]
    Param (

        #Specify the computer to query
        [Parameter(Mandatory=$true,
                   Position=1, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [Alias("hostname")]
        [string[]]
        $Computername,

        # Specify the log to query
        [Parameter(Mandatory=$true, 
                   Position=2)]
        [ValidateSet("Application", "System", "Security","Setup")]
        [Alias("logfile")]
        [string]
        $Log,

        # Specify the amount of days to report on.
        [Parameter(Position=3)]
        [int]
        $Days = 30

    )

    Begin {
    }
    Process {
        foreach ($Computer in $Computername) {
            $errorlog = Get-EventLog -ComputerName $Computer -LogName $Log -After ((get-date).adddays(-$Days))
            $errormessage = $errorlog | 
                Where-Object {$_.EntryType -eq "Error"} | 
                Sort-Object -Property Time |
                Sort-Object -Property Message -Unique
            $output = @()
                Foreach ($error in $errormessage) {
                New-Object PSCustomObject -Property @{
                Computer = $Computer
                Source = $error.source
                Message = $error.message
                Time = $error.TimeGenerated
                }   
            $output | Select-Object Computer,Time,Source,Message
            } 
        }
    }
    End {
    }
}
function Get-LogReportBySource {
<#
.Synopsis
   Get-LogReport is a function to sort log files into a useful summary
.DESCRIPTION
   Get-LogReport shows total count of log entries, errors, and warnings. It also shows unique entries in a sorted list for review. You can specify the log to report on and the number of days to review.
.EXAMPLE
   Get-LogReport -log System -days 30
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   -log Specify the log to query
   -days The number of days to search back in log history. Default is 30 days.
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
    [CmdletBinding()]
    Param (

        #Specify the computer to query
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [Alias("hostname")]
        [string[]]
        $Computername,

        # Specify the log to query
        [Parameter(Mandatory=$true, 
                   Position=2)]
        [ValidateSet("Application", "System", "Security","Setup")]
        [Alias("logfile")]
        [string]
        $Log,

        # Specify the amount of days to report on.
        [Parameter(Position=3)]
        [int]
        $Days = 30

    )

    Begin {
    }
    Process {
        foreach ($Computer in $Computername) {
            $logsource = Get-EventLog -ComputerName $Computername -LogName $Log -After ((get-date).adddays(-$Days))
            $errorsource = $logsource |
            Where-Object {$_.EntryType -eq "Error"} |
            Sort-Object -Property Time |
            Sort-Object -Property Source -Unique
            $output = @()
                Foreach ($error in $errorsource) {
                    New-Object PSCustomObject -Property @{
                        Computer = $Computer
                        Source = $error.source
                        Message = $error.message
                        Time = $error.TimeGenerated
                    }
                }   
            $output | Select-Object Computer,Time,Source,Message  
        }
    }
    End {
    }
}
function Get-LogReportErrorCount {
<#
.Synopsis
   Get-LogReport is a function to sort log files into a useful summary
.DESCRIPTION
   Get-LogReport shows total count of log entries, errors, and warnings. It also shows unique entries in a sorted list for review. You can specify the log to report on and the number of days to review.
.EXAMPLE
   Get-LogReport -log System -days 30
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   -log Specify the log to query
   -days The number of days to search back in log history. Default is 30 days.
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
    [CmdletBinding()]
    Param (

        #Specify the computer to query
        [Parameter(Mandatory=$true,
                   Position=1, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [Alias("hostname")]
        [string[]]
        $Computername,

        # Specify the log to query
        [Parameter(Mandatory=$true, 
                   Position=2)]
        [ValidateSet("Application", "System", "Security","Setup")]
        [Alias("logfile")]
        [string]
        $Log,

        # Specify the amount of days to report on.
        [Parameter(Position=3)]
        [int]
        $Days = 30

    )

    Begin {
    }
    Process {
        foreach ($Computer in $Computername) {
            $logcount = Get-EventLog -ComputerName $Computername -LogName $Log -After ((get-date).adddays(-$Days))
            $eventcount = $logcount |
            Measure-Object |
            Select-Object -ExpandProperty Count
            Write-Output "There are $eventcount errors in the $computer $log log" 
        }
    }
    End {
    }
}
function Get-DomainExpiration {
    [CmdletBinding()]
    Param (
        #Get input for domain name to query for domain expiration
        [string[]]$sites)
	        # Update console
	        Write-host "Checking WhoIs for domain expiration ($site)" -ForegroundColor "green"

	        # Define where we're grabbing WhoIs data
	        $web = New-WebServiceProxy "http://www.webservicex.net/whois.asmx?WSDL"

	        # Actual WhoIs query
	        foreach ($site in $sites) {
                $whois = $web.GetWhoIs("$site")
	            $exp = $whois | Select-String -Pattern "Expiration" -CaseSensitive
	            $expdt = "$exp".split()
	            $expires +="$Site expires on "+ $expdt[5]
            }
            $expires
}
function Get-SSLExpiraton {
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Input the urls to check
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [string[]]$urls,
        # Set the number of days to notify if the cert is expiring
        [int]$minimumCertAgeDays = 60,
        # Set the timeout value for the certificate check
        [int]$timeouteMilliseconds = 10000
    )

    Begin{
        #disabling the cert validation check.
        [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    }
    Process{
        $sslurls = @()
            foreach ($url in $urls) {
                $req = [Net.HttpWebRequest]::Create("https://$url/")
                try{$req.GetResponse() | Out-Null}
                catch{}
                New-Object PSCustomObject -Property @{
                    SSLdomain = $($req.Address.Host)
                    SSLexpiration = $($req.ServicePoint.Certificate.GetExpirationDateString())
                }
            }
            $sslurls
    }
    End{
    }
}
function Get-OSServicepack {
    [CmdletBinding()]
    Param (
        [Parameter(Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias('hostname')]
        [Alias('cn')]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        
        [Parameter(Position=1,
                   Mandatory=$false)]
        [Alias('runas')]
        [System.Management.Automation.Credential()]$Credential =
        [System.Management.Automation.PSCredential]::Empty  
    )
    foreach ($computer in $ComputerName) {
        $servicepackinfo = Get-WmiObject win32_operatingsystem -ComputerName $computer -Credential $Credential |
        select *
            $output = @()
            $output +=
                New-Object PSCustomObject -Property @{
                Computer = $Computer
                WMIName = $servicepackinfo.PSComputername
                Architecture = $servicepackinfo.OSArchitecture
                ServicePack = $servicepackinfo.CSDVersion
                }
        $output
    }
}