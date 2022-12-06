<#
.SYNOPSIS
    Dumps User accounts for a domain with exchange on-premise
    
.DESCRIPTION

    Creates CSV file with selected Properties* of a domain's user accounts. Intended to be used with a sister
    script that upload dumped users in DB, that track the changes.
  
   *SID,GivenName,Surname,Name,Changed,Created,Enabled,SamAccountName,DisplayName,Email,EmailItems,EmailLastLogon,EmailSize,EmailMaxSize,Description,UserDn

.EXAMPLE
.OUTPUTS

    csv file
.NOTES

#>

$session = New-PSSession -ConfigurationName microsoft.exchange -ConnectionUri http://exchange-server/PowerShell
Import-PSSession $session

function getMailBoxSize( $totalItemSize)
{ #Get size of maibox
  $mailBoxSizeArray = $totalItemSize.ToString().ToCharArray()
  $mailBoxSizeArrayLength = $mailBoxSizeArray.Length

  $byte = 0
  $b = 0
  $mailBoxSize = 0
  # parse this string (4,089,512 bytes)
    for ( $i = 1; $i -lt $mailBoxSizeArrayLength -And $mailBoxSizeArray[$mailBoxSizeArrayLength-$i] -ne '(' ; $i++ )
    {
        # if digit multiply it by power of ten and add to mailBoxSize 
        if ( [int32]::TryParse($mailBoxSizeArray[$mailBoxSizeArrayLength-$i], [ref]$byte) ) { $mailBoxSize = (($byte*([math]::pow(10,($b++))))+$mailBoxSize)}
    }
  return $mailBoxSize
}



########
$outputFile = "\\VBOXSVR\ram\ud.csv"
$Domain = "internal.com"
$TotalUsers = @()

#Create user counter
$i = 0

$Parameters = @{

        Filter = "*"
        SearchScope = "SubTree"
        Server = $Domain
        ErrorAction = "SilentlyContinue"
    }   #End of $Parameters
   #end of else ($TargetOu)

#Get a list of AD users
$Users = Get-ADUser @Parameters -Properties mail,ParentGuid,Description,Name,DisplayName,whenChanged,whenCreated

if ($Users) {
    foreach ($User in $Users) {
        #Convert the parentGUID attribute (stored as a byte array) into a proper-job GUID

        $ParentGuid = ([GUID]$User.ParentGuid).Guid


        #Attempt to retrieve the object referenced by the parent GUID
        $ParentObject = Get-ADObject -Identity $ParentGuid -Server $Domain -ErrorAction SilentlyContinue

        #Check that we've retrieved the parent
        if ($ParentObject) {

            #Create a custom PS object
            $lastLogon = 0
            $size = 0
            $items = 0
            $maxsize = 0


            if( !($User.mail -eq $null))
            {
                try{
                      $mail=Get-MailboxStatistics $User.mail -EA SilentlyContinue
                      $maxsize = 
                      $lastLogon =  $mail.LastLogonTime
                      $items = $mail.ItemCount
                      $size = getMailBoxSize $mail.TotalItemSize
                      $maxsize = getMailBoxSize (Get-Mailbox $User.mail).IssueWarningQuota
                }
                catch
                {}
            }
            else { $User.mail = "-" ; $User.mail = "-" }

            if ( $User.GivenName -eq $null)  { $User.GivenName="-"}
            if ( $User.DisplayName -eq $null)  { $User.DisplayName="-"}

            if ( $User.Name -eq $null)  { $User.Name="-"}

            if ( $User.Surname -eq $null)  { $User.Surname="-"}
            if ( $User.Description -eq $null)  { $User.Description="-"}


            $UserInfo = [PSCustomObject]@{
                
                SID = $User.SID.ToString()
                GivenName = $User.GivenName.Replace("`n","").Replace("`r","")
                Surname = $User.Surname.Replace("`n","").Replace("`r","")
                Name = $User.Name.Replace("`n","").Replace("`r","")
                Changed = $User.whenChanged
                Created = $User.whenCreated
                Enabled = $User.Enabled
                SamAccountName = $User.SamAccountName.Replace("`n","").Replace("`r","")
                DisplayName = $User.DisplayName.Replace("`n","").Replace("`r","")
                Email = $User.mail
                EmailLastLogon = $lastLogon
                EmailSize = $size
                EmailItems = $items
                EmailMaxSize = $maxsize
                Description = $User.Description.Replace("`n","").Replace("`r","")
                UserDn = $User.DistinguishedName.Replace("`n","").Replace("`r","") 

            }#End of $UserInfo...

            #Add the object to our array
            $TotalUsers += $UserInfo

            #Spin up a progress bar for each filter processed
            Write-Progress -Activity "Finding users in $DomainDn" -Status "Processed: $i" -PercentComplete -1

            #Increment the filter counter
            $i++

        }   #end of if ($ParentObject)
    }   #end of foreach ($User in $Users)
}   #end if ($Users)

$TotalUsers | select SID,GivenName,Surname,Name,Changed,Created,Enabled,SamAccountName,DisplayName,Email,EmailItems,EmailLastLogon,EmailSize,EmailMaxSize,Description,UserDn  |Export-Csv -Path $outputFile -Delimiter ";" -NoTypeInformation
