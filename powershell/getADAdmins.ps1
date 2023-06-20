$users = Get-ADGroupMember -Identity administrators -Recursive | Select SamAccountName,objectclass
foreach( $user in $users)
{
  if( $user.objectclass -eq 'user')
  {
      $status = Get-ADUser -Identity $user.SamAccountName
      $name = $status.name
      $enabled = $status.Enabled
      echo "$name $enabled"
  }
}
