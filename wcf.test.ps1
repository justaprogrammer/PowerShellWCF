. .\wcf.ps1

$wsdlImporter = Get-WsdlImporter 'http://localhost.fiddler:14232/EchoService.svc/mex'
#Get-WsdlImporter 'http://localhost.fiddler:14232/EchoService.svc' -HttpGet $true
#Get-WsdlImporter 'http://localhost.fiddler:14232/EchoService.svc?wsdl' -HttpGet $true

$proxyType = Get-WcfProxy $wsdlImporter

$endpoints = $wsdlImporter.ImportAllEndpoints();
$proxy = New-Object $proxyType($endpoints[0].Binding, $endpoints[0].Address);
$proxy.Echo("Justin Dearing");
