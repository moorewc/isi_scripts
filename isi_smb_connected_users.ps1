# Requirements:  Run as user with administrative access on isilon cluster


# Isilon smart connect name.  This needs to be a DNS address so we make
# sure to loop over all of the nodes.
$COMPUTERNAME=""
$SHARE_REGEX="^ifs"

# Name of file to output to
$OUTPUT="isi_smb_connected_users_report.csv"

function Get-Nodes {
  $NodeList = @()

  Write-Host "Discovering Nodes for $COMPUTERNAME"

  for($i=1;$i -le 100; $i++) {
    $ip = (Resolve-DnsName -Name $COMPUTERNAME -Type A)[0]
    if ($NodeList -notcontains $ip.IPAddress) {
      Write-Host "Adding "$ip.IPAddress" to NodeList"
        $NodeList += $ip.IPAddress
    }
  }

  $NodeList
}

$NodeList = Get-Nodes
$countHash = @{}

for($i=0;$i -le $NodeList.Length; $i++) {
  $nodeIp = $NodeList[$i]

  Write-Host "Checking Node "$nodeIp

  # Isilon does not support WMI calls so we have to piggy back on
  # ADSI connection.
  $lanman = [ADSI]"WinNT://${nodeIp}/lanmanserver"

  # Iterate through all child objects and look for any shares that
  # begin with ifs.
  $lanman.children | Where-Object {$_.Name -match $SHARE_REGEX} | ForEach-Object {
    $shareName = [string]$_.name
    $shareCount = [int][string]$_.CurrentuserCount


    $countHash[$shareName] += $shareCount
  }
}

Write-Host "Output"
$countHash.keys | ForEach-Object {
    $data = [PSCustomObject]@{
      date = (Get-Date)
      name = "\\${COMPUTERNAME}\"+ $_
      count = $countHash.Item($_)
  }

  $data
  $data | Export-CSV -Path ${OUTPUT} -Append
}
