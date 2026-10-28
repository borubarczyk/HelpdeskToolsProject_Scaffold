@{
    # Kontrola w CI (.github/workflows/tests.yml): tylko błędy. Wyłączone reguły - świadome użycie w programie:
    # hasła generowane i ustawiane przez administratora (reset hasła, nowe konta) przechodzą przez SecureString z tekstu.
    Severity     = @('Error')
    ExcludeRules = @(
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSAvoidUsingPlainTextForPassword'
    )
}
