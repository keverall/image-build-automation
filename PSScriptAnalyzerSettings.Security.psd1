@{
    # =========================================================================
    # PSScriptAnalyzer - SECURITY rule set (CI security gate)
    # =========================================================================
    # This file is deliberately SEPARATE from PSScriptAnalyzerSettings.psd1.
    #
    #   PSScriptAnalyzerSettings.psd1           -> style/quality, used by lint.ps1
    #   PSScriptAnalyzerSettings.Security.psd1  -> security, used by ci-security-check.ps1
    #
    # Rationale (EMIR / DORA evidencing): the security gate must not be able to
    # be weakened as a side effect of someone relaxing a formatting rule. The
    # two concerns are versioned and reviewed independently.
    #
    # RULES HERE MUST NOT BE SUPPRESSED IN CI.
    # The previous ci-security-check.ps1 excluded PSAvoidUsingInvokeExpression,
    # PSAvoidUsingConvertToSecureStringWithPlainText and
    # PSAvoidUsingUsernameAndPasswordParams, which meant the gate could not
    # detect the highest-severity defects present in this repository.
    #
    # Accepted, risk-assessed exceptions belong in .security-baseline.json,
    # where each one carries an owner, a justification and an expiry date.
    # They do NOT belong in this file.
    # =========================================================================

    IncludeRules = @(
        # --- Code injection -------------------------------------------------
        'PSAvoidUsingInvokeExpression'          # arbitrary code execution
        'PSAvoidUsingComputerNameHardcoded'

        # --- Credential handling --------------------------------------------
        'PSAvoidUsingPlainTextForPassword'      # credentials typed [string]
        'PSAvoidUsingUsernameAndPasswordParams' # use [pscredential] instead
        'PSAvoidUsingConvertToSecureStringWithPlainText'
        'PSUsePSCredentialType'
        'PSAvoidUsingBrokenHashAlgorithms'      # MD5 / SHA1

        # --- Error suppression that destroys the audit trail -----------------
        'PSAvoidUsingEmptyCatchBlock'

        # --- Correctness defects with security impact ------------------------
        # $null on the right-hand side silently misbehaves against arrays,
        # which is how authorisation/validation checks quietly pass.
        'PSPossibleIncorrectComparisonWithNull'
        'PSPossibleIncorrectUsageOfAssignmentOperator'
        'PSPossibleIncorrectUsageOfRedirectionOperator'
        'PSAvoidAssignmentToAutomaticVariable'
        'PSAvoidOverwritingBuiltInCmdlets'

        # --- Shared mutable state --------------------------------------------
        'PSAvoidGlobalVars'
        'PSAvoidGlobalAliases'
        'PSAvoidGlobalFunctions'

        # --- Change control / operator safety --------------------------------
        # Destructive operations (firmware flash, ISO deploy, maintenance-mode
        # suppression) must support -WhatIf/-Confirm to be demonstrably
        # controllable under a change process.
        'PSUseShouldProcessForStateChangingFunctions'
        'PSShouldProcess'

        # --- Deprecated / unsafe APIs ----------------------------------------
        'PSAvoidUsingWMICmdlet'                 # WMI has no transport encryption
    )

    # Deliberately NOT included, and why:
    #
    #   PSUseApprovedVerbs, PSUseSingularNouns, PSAvoidUsingWriteHost,
    #   PSAvoidUsingPositionalParameters, PSUseConsistent*, PSPlace*
    #       Style and naming concerns. They belong to lint.ps1 via
    #       PSScriptAnalyzerSettings.psd1. Including them here would bury 100+
    #       cosmetic findings in the security report and train reviewers to
    #       ignore the gate - the failure mode that made the previous gate
    #       useless.
    #
    #   PSUseBOMForUnicodeEncodedFile
    #       Encoding preference, no security impact.
}
