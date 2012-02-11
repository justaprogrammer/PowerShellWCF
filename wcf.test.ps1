param([switch] $UseFiddler)

. .\wcf.ps1

if ($UseFiddler) {
  $hostname = 'localhost.fiddler'
}
else {
  $hostname = 'localhost'
}

$wsdlImporter = Get-WsdlImporter "http://$($hostname):14232/EchoService.svc/mex"
# Get-WsdlImporter "http://$($hostname):14232/EchoService.svc" -HttpGet
# Get-WsdlImporter "http://$($hostname):14232/EchoService.svc?wsdl" -HttpGet 

# $proxyType = Get-WcfProxyType $wsdlImporter

# $endpoints = $wsdlImporter.ImportAllEndpoints();
# $proxy = New-Object $proxyType($endpoints[0].Binding, $endpoints[0].Address);
# $proxy = Get-WcfProxy "http://$($hostname):14232/EchoService.svc/mex"
# $proxy = Get-WcfProxy $wsdlImporter # "http://$($hostname):14232/EchoService.svc/WCF" (New-Object System.ServiceModel.WSHttpBinding)
$proxy = Get-WcfProxy 'net.tcp://localhost:8732/EchoService/mex' 'net.tcp://localhost:8732/EchoService/' (New-Object System.ServiceModel.NetTcpBinding)
$proxy.Echo("Justin Dearing");

#Get-Help Get-WsdlImporter
#Get-Help Get-WcfProxyType
#Get-Help Get-WcfProxy
