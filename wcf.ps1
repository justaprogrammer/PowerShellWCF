# Call WCF Services With PowerShell V1.1 10.02.2012
# described on http://www.ilovesharepoint.com/2008/12/call-wcf-services-with-powershell.html
# requires Powershell v2 
#
# original version by Christian Glessner
# Blog: http://www.iLoveSharePoint.com
# Twitter: http://twitter.com/cglessner
# Codeplex: http://codeplex.com/iLoveSharePoint
#
# PowerShell v2.0 modification by Justin Dearing
# Blog: http://justaprogrammer.net
# Twitter: http://twitter.com/zippy1981 
#
# requires .NET 3.5

# load WCF assemblies
Add-Type -AssemblyName "System.ServiceModel"
Add-Type -AssemblyName "System.Runtime.Serialization"

# get metadata of a service
function global:Get-WsdlImporter([Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$wsdlUrl, [switch]$httpGet)
{
	if($httpGet -eq $true)
	{
		$local:mode = [System.ServiceModel.Description.MetadataExchangeClientMode]::HttpGet
	}
	else
	{
		$local:mode = [System.ServiceModel.Description.MetadataExchangeClientMode]::MetadataExchange
	}
	
	$mexClient = New-Object System.ServiceModel.Description.MetadataExchangeClient((New-Object System.Uri($wsdlUrl)),$mode)
	$mexClient.MaximumResolvedReferences = [System.Int32]::MaxValue
	$metadataSet = $mexClient.GetMetadata()
	$wsdlImporter = New-Object System.ServiceModel.Description.WsdlImporter($metadataSet)
	
	return $wsdlImporter	
}

# Generate wcf proxy types
function global:Get-WcfProxy(
	[Parameter(ParameterSetName='WsdlImporter', Position=0, Mandatory=$true, ValueFromPipeline=$true)][ServiceModel.Description.WsdlImporter] $wsdlImporter,
	[Parameter(ParameterSetName='WsdlUrl', Position=0, Mandatory=$true, ValueFromPipeline=$true)][string] $wsdlUrl, 
	[string] $proxyPath
) {
	switch ($PsCmdlet.ParameterSetName)
	{
		"WsdlUrl"  {
			$wsdlImporter = Get-WsdlImporter -wsdlUrl $wsdlUrl
			trap [Exception]
			{
				$script:wsdlImporter = Get-WsdlImporter -wsdlUrl $wsdlUrl -httpGet $true
				continue
			}
			break
		}
		"WsdlUrl"  { break }
	}
	
	$generator = new-object System.ServiceModel.Description.ServiceContractGenerator
	
	foreach($contractDescription in $wsdlImporter.ImportAllContracts())
	{
		[void]$generator.GenerateServiceContractType($contractDescription)
	}
	
	$parameters = New-Object System.CodeDom.Compiler.CompilerParameters
	if($proxyPath -eq $null)
	{
		$parameters.GenerateInMemory = $true
	}
	else
	{
		$parameters.OutputAssembly = $proxyPath
	}
	
	$providerOptions = New-Object "Collections.Generic.Dictionary[String,String]"
	[void]$providerOptions.Add("CompilerVersion","v3.5")
	
	$compiler = New-Object Microsoft.CSharp.CSharpCodeProvider($providerOptions)
	$result = $compiler.CompileAssemblyFromDom($parameters, $generator.TargetCompileUnit);
	
	if($result.Errors.Count -gt 0)
	{
		throw "Proxy generation failed"       
	}
	
	foreach($type in $result.CompiledAssembly.GetTypes())
	{
		if($type.BaseType.IsGenericType)
		{
			if($type.BaseType.GetGenericTypeDefinition().FullName -eq "System.ServiceModel.ClientBase``1" )
			{
				$type
			}
		}
	}
}

