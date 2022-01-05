Import-Module .\Posh-YNAB\Posh-YNAB.psd1 -Force

# Disable default parameter values during testing
$defaultParam = $PSDefaultParameterValues["Disabled"]
$PSDefaultParameterValues["Disabled"] = $true

$VerbosePreference = "Continue"

BeforeAll {
    $module = 'Posh-YNAB'

    $testPreset = 'Test Preset'
    $testBudget = 'Test Budget'
    $testAccount = 'Checking'
    $testPayee = 'Test Payee'
    $testCategory = 'Water'
    $testMemo = 'Test Memo'
    $testOutflow = 10.25
    $testFlagColor = 'Red'
    $testToken = 'Test Token'

    $transactionObject = [PSCustomObject]@{
        Budget = $testBudget
        Account = $testAccount
        Payee = $testPayee
        Category = $testCategory
        Memo = $testMemo
        Token = $testToken
        FlagColor = $testFlagColor
    }

    $transactionHashtable = @{
        Budget = $testBudget
        Account = $testAccount
        Payee = $testPayee
        Category = $testCategory
        Memo = $testMemo
        Token = $testToken
        FlagColor = $testFlagColor
    }
}

Describe -Tags ('Unit', 'Acceptance') "<module> Module Tests" {
    $functions = Get-ChildItem "$(Join-Path -Path $PSScriptRoot -ChildPath ..\Posh-YNAB\Public)" -Include "*.ps1" -Exclude "*.Tests.ps1" -Recurse #| Select-Object -First 1
    Context "<function.BaseName> - Function" -ForEach $functions {
        BeforeAll { 
            # $_ is the current item coming from the -ForEach, which is a new feature 
            # in the 5.1-beta1, we rename it here to give it a better name
            $function = $_

            $exportedFunctions = (Get-Module -Name Posh-YNAB).ExportedFunctions.Values.Name
        }

        # Files Exist
        It "should exist" {
            #Should "$($function.FullName)" -Exist
            "$($function.FullName)" | Should -Exist
        }

        # The files export a function that matches the file name
        It "$($_.Name) exports $($_.BaseName)" {
            $content = Get-Content $_.FullName 
            $function = $content[0].Split(' ')[1]
            $function | Should -Be $_.BaseName
        }

        # All files correspond to an exported function
        It "$($_.BaseName) is in exported functions" {
            $_.BaseName | Should -BeIn $exportedFunctions
        }

        # TODO: Make something that makes sure we have valid help for each thing
        #It "should have a SYNOPSIS section" {
        #   "$($function.FullName)" | Should -FileContentMatch '.SYNOPSIS'
        #}
      

#      It "is valid PowerShell code" {
#        $psFile = Get-Content -Path $function.FullName -ErrorAction Stop
#        $errors = $null
#        $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
#        $errors.Count | Should -Be 0
#      }
  }
}

Describe 'Add-YnabTransaction' {
    # Force 
    InModuleScope Posh-YNAB {
        $script:profilePath = $PSScriptRoot
    }

    BeforeAll {
        Mock -ModuleName Posh-YNAB -CommandName Invoke-RestMethod -Verifiable { 
            [PSCustomObject]@{
                data = @{
                    transaction_ids = @{
                        id = 1
                    }
                    transaction = @{
                        id = 1
                        date = "$(get-date -f 'yyyy-MM-dd')" # Used to be $Date.ToString('yyyy-MM-dd')
                        amount = ($Amount * 1000) # How do we get this to use the values from add-transaction?
                        memo = $Memo
                        cleared = 'uncleared'
                        approved = $Approved
                        flag_color = $FlagColor
                        account_id = $accountId
                        payee_id =  $payeeId
                        payee_name = $Payee
                        category_id = $categoryId
                        category_name = $categoryName
                        transfer_account_id = $null
                        transfer_transaction_id = $null
                        matched_transaction_id = $null
                        import_id = $null
                        deleted = $false
                        subtransactions = @{}
                    }
                }
            }
        }
        
        Mock -ModuleName Posh-YNAB -CommandName Get-YnabBudget {
            [PSCustomObject]@{
                Budget = $testBudget
                ID = '1'
            }
        }

        Mock -ModuleName Posh-YNAB -CommandName Get-YnabAccount {
            [PSCustomObject]@{
                Account = $testAccount
                ID = '1'
            }
        }

        Mock -ModuleName Posh-YNAB -CommandName Get-YnabCategory {
            [PSCustomObject]@{
                Category = $testCategory
                ID = '1'
            }
        }
        
    }

    Context 'Supports all expected parameter combinations' {
        It 'Supports transactions with Outflow' {
            $response = Add-YnabTransaction @transactionHashtable -Outflow 10.25
            
            $response.Count | Should -Be 1
            $response.Amount | Should -Be -10.25
        }
        
        It 'Supports transactions with Inflow' {
            $response = Add-YnabTransaction @transactionHashtable -Inflow 10.25
            
            $response.Count | Should -Be 1
            $response.Amount | Should -Be 10.25
        }

        It 'Supports transactions with Amount' {
            $response = Add-YnabTransaction @transactionHashtable -Amount -10.25

            $response.Count | Should -Be 1
            $response.Amount | Should -Be -10.25
        }
        
        It 'Supports transactions with Preset only' {
            $response = Add-YnabTransaction -Preset "Test Preset"
        
            $response.Count | Should -Be 1
            $response.Amount | Should -Be -10.25
        }
        
        It 'Supports transactions with an array of presets' {
            $response = Add-YnabTransaction -Preset @($testPreset,$testPreset)
        
            $response.Count | Should -Be 2
            $response[0].Amount | Should -Be -10.25
            $response[1].Amount | Should -Be -10.25
        }

        It 'Supports transactions with Preset and Outflow' {
            $response = Add-YnabTransaction -Preset $testPreset -Outflow 10.55
        
            $response.Count | Should -Be 1
            $response.Amount | Should -Be -10.55
        }
        
        It 'Supports transactions with Preset and Inflow' {
            $response = Add-YnabTransaction -Preset $testPreset -Inflow 10.55

            $response.Count | Should -Be 1
            $response.Amount | Should -Be 10.55
        }
        
        It 'Supports transactions with Preset and Amount' {
            $response = Add-YnabTransaction -Preset $testPreset -Amount -10.55

            $response.Count | Should -Be 1
            $response.Amount | Should -Be -10.55
        }

        It 'Supports transactions with Preset and other (non-amount) variables' {
            $response = Add-YnabTransaction -Preset $testPreset -Payee 'Test Payee2' -Memo 'Test Memo2' 

            $response.Count | Should -Be 1
            $response.Amount | Should -Be -10.25
            $response.Memo | Should -Be 'Test Memo2' 
            $response.Payee | Should -Be 'Test Payee2'
        }
    }
<#
    Context 'Supports pipeline' {
        It 'Supports pipeline input by property name for a single object' {
            $response = $transactionObject | Add-YnabTransaction
            
            ([Array]$response).Count | Should -Be 1
        }
    
        It 'Supports pipeline input by property name for an array of objects' {
            $response = @($transactionObject,$transactionObject) | Add-YnabTransaction
            
            $response.Count | Should -Be 2
        }
    
        It 'Supports pipeline input of a single preset by name' {
            $response = $testPreset | Add-YnabTransaction
            
            ([Array]$response).Count | Should -Be 1
            $response.Amount | Should -Be -10.25
        }
    
        It 'Supports pipeline input of an array of presets by name' {
            $response = @($testPreset,$testPreset) | Add-YnabTransaction
            
            $response.Count | Should -Be 2
            $response[0].Amount | Should -Be -10.25
            $response[1].Amount | Should -Be -10.25
        }
    }
#>
}

# Restore the original default parameter values state after testing
$PSDefaultParameterValues["Disabled"] = $defaultParam