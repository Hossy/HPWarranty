Function Get-HPEServerWarrantyEntitlement {

    [CmdletBinding(DefaultParameterSetName = '__AllParameterSets')]
    [OutputType([PSCustomObject])]

	Param (
        [Parameter(
            ParameterSetName = 'Default',
            ValueFromPipeline = $true
        )]
        [ValidateScript({
            if ($_ -eq $env:COMPUTERNAME) {
                $true
            } else {
                try {
                    Test-Connection -ComputerName $_ -Count 1 -ErrorAction Stop
                    $true
                } catch {
                    throw "Unable to connect to $_."
                }
            }
        })]
        [String[]]
        $ComputerName = $env:ComputerName,

		[Parameter(
            Mandatory = $false,
            ParameterSetName = 'Static',
            ValueFromPipeLineByPropertyName = $true
        )]
		[String]
        $ProductNumber,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Static',
            ValueFromPipelineByPropertyName = $true
        )]
		[String]
        $SerialNumber,

        [Parameter(
            ParameterSetName = '__AllParameterSets'
        )]
		[Parameter(
            ParameterSetName = 'Default'
        )]
        [Parameter(
            ParameterSetName = 'Static'
        )]
		[String]
        $CountryCode = 'US',

        [Parameter(
            ParameterSetName = '__AllParameterSets'
        )]
		[Parameter(
            ParameterSetName = 'Default'
        )]
        [Parameter(
            ParameterSetName = 'Static'
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $XmlExportPath = $null
	)

    Begin {
        $request = [Management.Automation.PSObject]@{
          'countryCode' = "null"
          'productNo' = "null"
          'serialNo' = "null"
        }
    }

    Process {
        for ($i = 0; $i -lt $ComputerName.Length; $i++) {
            if (-not ($PSCmdlet.ParameterSetName -eq 'Static')) {
                if (($systemInformation = Get-HPProductNumberAndSerialNumber -ComputerName $ComputerName[$i]) -ne $null) {
                    $ProductNumber = $systemInformation.ProductNumber
                    $SerialNumber = $systemInformation.SerialNumber
                } else {
                    continue
                }
            } else {
                $ComputerName[$i] = $null
            }

            try {
                $request.serialNo = $SerialNumber
                $request.productNo = $ProductNumber
                $hpUrl = "https://hpscm-pro.glb.itcs.hp.com/mobileweb/hpsupport.asmx/GetEntitlementDetails"
                $entitlement = Invoke-RestMethod -Body ($request | ConvertTo-Json) -Method Post -ContentType "application/json" -Uri $hpUrl
            } catch {
                Write-Error -Message 'Failed to invoke REST request.'
                continue
            }

            if ($entitlement -ne $null) {
                $contracts = $entitlement.d | ConvertFrom-Json
				if ($contracts -ne $null) {
					foreach ($contract in $contracts) {
						[PSCustomObject]@{
							'ComputerName' = $ComputerName[$i]
							'SerialNumber' = $SerialNumber
							'ProductNumber' = $ProductNumber
							'ActiveWarrantyEntitlement' = $contract.status
							'OverallWarrantyStartDate' = $contract.startDate
							'OverallWarrantyEndDate' = $contract.endDate
							'WarrantyType' = $contract.title
							'WarrantyDeliverables' = $contract.deliverables
							'WarrantyOfferCode' = $contract.offerCode
						}
					}
				}
            } else {
                Write-Error -Message 'No entitlement found.'
                continue
            }
        }
    }
}