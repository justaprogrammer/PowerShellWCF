. .\wcf.ps1

$wsdlImporter = Get-WsdlImporter 'http://localhost.fiddler:14232/EchoService.svc/mex'
# Get-WsdlImporter 'http://localhost.fiddler:14232/EchoService.svc' -HttpGet
# Get-WsdlImporter 'http://localhost.fiddler:14232/EchoService.svc?wsdl' -HttpGet 

# $proxyType = Get-WcfProxyType $wsdlImporter

# $endpoints = $wsdlImporter.ImportAllEndpoints();
# $proxy = New-Object $proxyType($endpoints[0].Binding, $endpoints[0].Address);
$proxy = Get-WcfProxy 'http://localhost.fiddler:14232/EchoService.svc/mex'
$proxy.Echo("Justin Dearing");

Get-Help Get-WsdlImporter
Get-Help Get-WcfProxyType
Get-Help Get-WcfProxy
