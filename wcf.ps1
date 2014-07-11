<#  
.SYNOPSIS  
	Functions to call WCF Services With PowerShell.
.NOTES
	Version 1.3 11.07.2014
	Requires Powershell v2 and .NET 3.5
	
	Copyright (c) 2008 Christian Glessner
	Copyright (c) 2012 Justin Dearing
    Copyright (c) 2014 Christoph Petersen

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to
	deal in the Software without restriction, including without limitation the 
	rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
	sell copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
	IN THE SOFTWARE.

	Original version by Christian Glessner
	Blog: http://www.iLoveSharePoint.com
	Twitter: http://twitter.com/cglessner
	Codeplex: http://codeplex.com/iLoveSharePoint
	
	PowerShell v2.0 modification by Justin Dearing
	Blog: http://justaprogrammer.net
	Twitter: http://twitter.com/zippy1981 
.LINK  
	Blog describing original version: http://www.ilovesharepoint.com/2008/12/call-wcf-services-with-powershell.html
	Authoritative version of this fork: https://github.com/justaprogrammer/PowerShellWCF
	Posted to PoshCode.org http://poshcode.org/?lang=&q=PS2WCF
#>

# load WCF assemblies
Add-Type -AssemblyName "System.ServiceModel"
Add-Type -AssemblyName "System.Runtime.Serialization"

<#  
.SYNOPSIS  
	Get metadata of a service

.DESCRIPTION  
	Parses a wsdl or mex and generates a WsdlImporter object from it.
.EXAMPLE
	Get-WsdlImporter 'http://localhost.fiddler:14232/EchoService.svc/mex'
.EXAMPLE
	Get-WsdlImporter 'http://localhost.fiddler:14232/EchoService.svc' -HttpGet
.EXAMPLE
	Get-WsdlImporter 'http://localhost.fiddler:14232/EchoService.svc?wsdl' -HttpGet 

#>
function global:Get-WsdlImporter([CmdletBinding()][Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$WsdlUrl, [switch]$HttpGet, [int] $MaxMessageSize = 524288)
{
	$mexAddress = New-Object System.Uri($Uri);
    $mexMode = [System.ServiceModel.Description.MetadataExchangeClientMode]::MetadataExchange
        
    if($HttpGet)
	{
		$mexMode = [System.ServiceModel.Description.MetadataExchangeClientMode]::HttpGet
	}

    $binding = New-Object System.ServiceModel.WSHttpBinding -ArgumentList ([System.ServiceModel.SecurityMode]::None);
    $binding.MaxReceivedMessageSize = $MaxMessageSize;
	
    $mexClient = New-Object System.ServiceModel.Description.MetadataExchangeClient($binding);
    $mexClient.ResolveMetadataReferences = $true;
    $mexClient.MaximumResolvedReferences = [int]::MaxValue;

    $metaSet = $mexClient.GetMetadata($mexAddress, $mexMode);
	return New-Object System.ServiceModel.Description.WsdlImporter($metaSet);
}

<#  
.SYNOPSIS  
    Generate wcf proxy types

.DESCRIPTION  
    Examines a web services meta data (wsdl or mex) and generates the types for the client proxy, 
	as well as request and response contracts.
.EXAMPLE  
    $proxyType = Get-WcfProxyType $wsdlImporter
	$endpoints = $wsdlImporter.ImportAllEndpoints();
	$proxy = New-Object $proxyType($endpoints[0].Binding, $endpoints[0].Address);
#>
function global:Get-WcfProxyType(
	[CmdletBinding()]
	[Parameter(ParameterSetName='WsdlImporter', Position=0, Mandatory=$true, ValueFromPipeline=$true)][ServiceModel.Description.WsdlImporter] $WsdlImporter,
	[Parameter(ParameterSetName='WsdlUrl', Position=0, Mandatory=$true, ValueFromPipeline=$true)][string] $WsdlUrl, 
	[string] $proxyPath
) {
	switch ($PsCmdlet.ParameterSetName)
	{
		"WsdlUrl" {
			$WsdlImporter = Get-WsdlImporter $WsdlUrl
			trap [Exception]
			{
				$WsdlImporter = Get-WsdlImporter $WsdlUrl -HttpGet
				continue
			}
			break
		}
		"WsdlImporter" { break }
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
	
	return $result.CompiledAssembly.GetTypes() | Where-Object {$_.BaseType.IsGenericType -and $_.BaseType.GetGenericTypeDefinition().FullName -eq "System.ServiceModel.ClientBase``1" }
}

<#  
.SYNOPSIS  
    Generate wcf proxy

.DESCRIPTION  
    Generate wcf proxy in a manner similar to a Get-WebServiceProxy
.EXAMPLE
    $proxy = Get-WcfProxy 'http://localhost.fiddler:14232/EchoService.svc/mex'
	$proxy.Echo("Justin Dearing");
.EXAMPLE
	$proxy = Get-WcfProxy 'net.tcp://localhost:8732/EchoService/mex' 'net.tcp://localhost:8732/EchoService/' (New-Object System.ServiceModel.NetTcpBinding)
	$proxy.Echo("Justin Dearing");
#>
function global:Get-WcfProxy(
	[CmdletBinding()]
	[Parameter(ParameterSetName='WsdlImporter', Position=0, Mandatory=$true, ValueFromPipeline=$true)][ServiceModel.Description.WsdlImporter] $WsdlImporter,
	[Parameter(ParameterSetName='WsdlUrl', Position=0, Mandatory=$true, ValueFromPipeline=$true)][string] $WsdlUrl,
	[Parameter(Position=1, Mandatory=$false)][string] $EndpointAddress = $null,
	[Parameter(Position=2, Mandatory=$false)][System.ServiceModel.Channels.Binding] $Binding = $null,
	[Parameter(Position=3, Mandatory=$false)][Nullable[int]] $Timeout = $null
) {
	if ($Binding -ne $null -and [string]::IsNullOrEmpty($EndpointAddress)) {
		throw New-Object ArgumentNullException '$EndPointAddress', 'You cannot set $Binding without setting $EndpointAddress.'
	}
	
	switch ($PsCmdlet.ParameterSetName)
	{
		"WsdlUrl" {
			$WsdlImporter = Get-WsdlImporter $WsdlUrl
			trap [Exception]
			{
				$WsdlImporter = Get-WsdlImporter $WsdlUrl -HttpGet
				continue
			}
			break
		}
	}
	
	$proxyType = Get-WcfProxyType $wsdlImporter;
	
	if ([string]::IsNullOrEmpty($EndpointAddress)) {
		$endpoints = $WsdlImporter.ImportAllEndpoints();
		$Binding = $endpoints[0].Binding;
		$EndpointAddress = $endpoints[0].Address;
	}
	if ($Timeout -ne $null) {
		$Binding.SendTimeout = (New-TimeSpan -Seconds $Timeout);
	}
	
	return New-Object $proxyType($Binding, $EndpointAddress);
}
