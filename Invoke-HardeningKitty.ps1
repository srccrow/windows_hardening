﻿<#
    Invoke-HardeningKitty - Checks and hardens your Windows configuration

    Author: Michael Schneider
    License: MIT    
    Required Dependencies: None
    Optional Dependencies: None
#>

[CmdletBinding()]

Param (

    [ValidateSet("Audit","Hardening","HailMary")]
    [String]
    $Mode = "Audit",

    [Bool]
    $EmojiSupport = $false
)


<#
    to do:
    * [ ] Build checks for other items then registy
    * [ ] Add all registry checks
    * [ ] Create machine readable output file
    * [ ] Create log file
    * [ ] Build modules based on categories
#>

Function Write-ProtocolEntry($Text, $LogLevel) {

    $Time = Get-Date -Format G

    Switch ($LogLevel) {
        "Info" { $Message = "[*] $Time - $Text"; Write-Host $Message; Break}
        "Debug" { $Message = "[-] $Time - $Text"; Write-Host -ForegroundColor Cyan $Message; Break}
        "Warning" { $Message = "[?] $Time - $Text"; Write-Host -ForegroundColor Yellow $Message; Break}
        "Error" { $Message = "[!] $Time - $Text"; Write-Host -ForegroundColor Red $Message; Break}
        "Success" { $Message = "[$] $Time - $Text"; Write-Host -ForegroundColor Green $Message; Break}
        Default { $Message = "[*] $Time - $Text"; Write-Host $Message; }
    }    
    # Add-Content -Path $ProtocolPath -Value $Message
}

Function Write-Result($Text, $SeverityLevel) {

    If($EmojiSupport) {
        Switch ($SeverityLevel) {
            "Passed" { $Emoji = [char]::ConvertFromUtf32(0x1F63A); $Message = "[$Emoji] $Text"; Write-Host -ForegroundColor Gray $Message; Break}
            "Low" { $Emoji = [char]::ConvertFromUtf32(0x1F63C); $Message = "[$Emoji]  $Text"; Write-Host -ForegroundColor Cyan $Message; Break}        
            "Medium" { $Emoji = [char]::ConvertFromUtf32(0x1F63F); $Message = "[$Emoji] $Text"; Write-Host -ForegroundColor Yellow $Message; Break}
            "High" { $Emoji = [char]::ConvertFromUtf32(0x1F640); $Message = "[$Emoji] $Text"; Write-Host -ForegroundColor Red $Message; Break}
            Default { $Message = "[*] $Text"; Write-Host $Message; }
        }
    } Else {
        Switch ($SeverityLevel) {
            "Passed" { $Message = "[$] $Text"; Write-Host -ForegroundColor Gray $Message; Break}
            "Low" { $Message = "[-]  $Text"; Write-Host -ForegroundColor Cyan $Message; Break}        
            "Medium" { $Message = "[?] $Text"; Write-Host -ForegroundColor Yellow $Message; Break}
            "High" { $Message = "[!] $Text"; Write-Host -ForegroundColor Red $Message; Break}
            Default { $Message = "[*] $Text"; Write-Host $Message; }
        }
    }
}

Function Create-FindingList {

    $FindingList = @(
        
        # Registry
        [pscustomobject]@{ID='1023';Category='LSA';Name='LSASS Protection Mode';Method='Registry';RegistryPath='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa';RegistryItem='RunAsPPL';DefaultValue='';RecommendedValue='1';Severity='Medium'}
        [pscustomobject]@{ID='1024';Category='LSA';Name='LSASS Audit Mode';Method='Registry';RegistryPath='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LSASS.exe';RegistryItem='AuditLevel';DefaultValue='';RecommendedValue='8';Severity='Low'}

        # Advanced Audit
        [pscustomobject]@{ID='2023';Category='Advanced Audit Policy Configuration';Name='Credential Validation';Method='auditpol';RegistryPath='';RegistryItem='';DefaultValue='';RecommendedValue='Success and Failure';Severity='Low'}
        [pscustomobject]@{ID='2024';Category='Advanced Audit Policy Configuration';Name='Kernel Object';Method='auditpol';RegistryPath='';RegistryItem='';DefaultValue='';RecommendedValue='Success and Failure';Severity='Low'}
    )

    Return $FindingList
}

Function Main {

    Write-Output "`n"
    Write-Output "      =^._.^="
    Write-Output "     _(      )/  HardeningKitty"
    Write-Output "`n"    
    Write-ProtocolEntry "Starting HardeningKitty" "Info"

    If ($Mode -eq "Audit") {

        $FindingList = Create-FindingList
        $LastCategory = ""

        ForEach ($Finding in $FindingList) {

            #
            # Category
            #
            If($LastCategory -ne $Finding.Category) {              
                $Message = "Starting Category " + $Finding.Category
                Write-Output "`n"                
                Write-ProtocolEntry $Message "Info"                
                $LastCategory = $Finding.Category
            }

            #
            # Get Registry Item
            #
            If ($Finding.Method -eq 'Registry') {

                If (Test-Path -Path $Finding.RegistryPath) {
                
                    try {
                        $Result = Get-ItemPropertyValue -Path $Finding.RegistryPath -Name $Finding.RegistryItem
                    } catch {
                        $Result = $Finding.DefaultValue
                    }
                }
            }
            
            #
            # Get Audit Policy
            #
            Elseif ($Finding.Method -eq 'auditpol') {

                $SubCategory = $Finding.Name                
                try {
                    $ResultOutput = auditpol.exe /get /subcategory:"$SubCategory"
                    
                    # "Parse" auditpol.exe output
                    $ResultOutput[4] -match '  ([a-z, /-]+)  ([a-z, ]+)' | Out-Null
                    $Result = $Matches[2]

                } catch {
                    $Result = $Finding.DefaultValue
                }
            }

            #
            # Compare result value and recommendation
            #
            If ($Result -eq $Finding.RecommendedValue) {
                # Passed
                $Message = $Finding.Name+": Passed"
                Write-Result $Message "Passed"
            } Else {
                # Failed
                $Message = $Finding.Name+": Result=$Result, Recommended="+$Finding.RecommendedValue+", Severity="+$Finding.Severity
                Write-Result $Message $Finding.Severity
            }

        }
    }
    
    Write-Output "`n"
    Write-ProtocolEntry "HardeningKitty is done" "Info"
    Write-Output "`n"
}

Main