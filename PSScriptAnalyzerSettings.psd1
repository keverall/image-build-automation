@{
    # Combined linting target directives
    IncludeRules = @(
        'PSAvoidUsingCmdletAliases'
        'PSAvoidUsingWriteHost'
        'PSAvoidUsingPlainTextForPassword'
        'PSAvoidUsingConvertToSecureStringWithPlainText'
        'PSUseApprovedVerbs'
        'PSUseDeclaredVarsMoreThanAssignments'
        'PSUseShouldProcessForStateChangingFunctions'
        'PSUseSingularNouns'
        'PSAvoidGlobalVars'
        'PSAvoidUsingInvokeExpression'
        'PSUseCompatibleCmdlets'
        'PSReviewUnusedParameter'
        'PSUseConsistentIndentation'
        'PSUseConsistentWhitespace'
        'PSUseCorrectCasing'
        'PSAvoidUsingEmptyCatchBlocks'
        'PSAvoidUsingWMICmdlet'
        'PSPlaceOpenBrace'
    )

    Rules = @{
        # Whitespace and Structural Positioning
        PSUseConsistentIndentation = @{
            Enable          = $true
            IndentationSize = 4
            Kind            = 'space'
        }
        PSUseConsistentWhitespace = @{
            Enable                         = $true
            CheckInnerBrace                = $true
            CheckOpenBrace                 = $true
            CheckOpenParen                 = $true
            CheckOperator                  = $true
            CheckPipe                      = $true
            CheckPipeForRedundantWhitespace = $true
            CheckSeparator                 = $true
        }
        PSPlaceOpenBrace = @{
            Enable     = $true
            OnSameLine = $true  # Microsoft layout: Opening braces stay on the same line
            NewLineAfter = $true
        }
        PSPlaceCloseBrace = @{
            Enable       = $true
            NewLineAfter = $true
        }
        
        # Casing, Naming conventions, and Aliases
        PSUseCorrectCasing = @{
            Enable = $true
        }
        PSUseSingularNouns = @{
            Enable = $true
        }
        PSAvoidUsingCmdletAliases = @{
            Enable    = $true
            Whitelist = @(
                'cat'    # Get-Content (interactive)
                'rm'     # Remove-Item (interactive)
                'mv'     # Move-Item (interactive)
                'ps'     # Get-Process (interactive)
                'ls'     # Get-ChildItem (interactive)
                'll'     # eza alias (interactive)
            )
        }
        PSAvoidUsingWriteHost = @{
            Enable = $true
        }
    }
}
