BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "QrCode"
}

Describe "Kod QR - elementy normy" {
    It "liczy informację o formacie i wersji (BCH) jak w normie" {
        $m = Get-Module QrCode
        (& $m { (Get-HTQrBchBits -Data ((1 -shl 3) -bor 0) -Width 15 -Poly 0x537) -bxor 0x5412 }) | Should -Be 0x77C4
        (& $m { (Get-HTQrBchBits -Data 0 -Width 15 -Poly 0x537) -bxor 0x5412 }) | Should -Be 0x5412
        (& $m { (Get-HTQrBchBits -Data 5 -Width 15 -Poly 0x537) -bxor 0x5412 }) | Should -Be 0x40CE
        (& $m { Get-HTQrBchBits -Data 7 -Width 18 -Poly 0x1F25 }) | Should -Be 0x7C94
    }
    It "liczy kody korekcji Reed-Solomona (przykład 1-M «HELLO WORLD»)" {
        $ecc = & (Get-Module QrCode) { Get-HTQrRsRemainder -Data @(32, 91, 11, 120, 209, 114, 220, 77, 67, 64, 236, 17, 236, 17, 236, 17) -Degree 10 }
        $ecc | Should -Be @(196, 35, 39, 119, 235, 215, 231, 226, 93, 23)
    }
    It "podaje pojemność wersji w trybie bajtowym" {
        Get-HTQrCapacity -Version 1 -Ecc M | Should -Be 14
        Get-HTQrCapacity -Version 8 -Ecc M | Should -Be 152
        Get-HTQrCapacity -Version 10 -Ecc M | Should -Be 213
        Get-HTQrCapacity -Version 15 -Ecc L | Should -Be 520
    }
}

Describe "New-HTQrCode" {
    It "tworzy kod «Hello» zgodny ze wzorcem (wersja 1, poziom M, maska 2)" {
        $q = New-HTQrCode -Text 'Hello'
        $q.Version | Should -Be 1
        $q.Ecc | Should -Be 'M'
        $q.Mask | Should -Be 2
        ConvertTo-HTQrText -QrCode $q | Should -Be @(
            '111111100111101111111'
            '100000100000101000001'
            '101110101010101011101'
            '101110101010001011101'
            '101110101100101011101'
            '100000101101001000001'
            '111111101010101111111'
            '000000001010000000000'
            '101111100101001111100'
            '000100001001111001101'
            '001111100110101101110'
            '001001011011111001100'
            '011100111110100100001'
            '000000001000100101000'
            '111111100101010010110'
            '100000101010000111110'
            '101110101001010010010'
            '101110101101111101000'
            '101110101100101100100'
            '100000100101111011100'
            '111111101100100010010'
        )
    }
    It "dobiera wersję do długości linku otpauth:// i ma znaczniki położenia w trzech rogach" {
        $uri = 'otpauth://totp/Helpdesk%20Tools%3AKonto%20podstawowe?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP&issuer=Helpdesk%20Tools&algorithm=SHA1&digits=6&period=30'
        $q = New-HTQrCode -Text $uri
        $q.Version | Should -Be 8
        $q.Size | Should -Be 49
        $rows = ConvertTo-HTQrText -QrCode $q
        foreach ($corner in @(@(0, 0), @(0, 42), @(42, 0))) {
            $rows[$corner[0]].Substring($corner[1], 7) | Should -Be '1111111'
            $rows[$corner[0] + 1].Substring($corner[1], 7) | Should -Be '1000001'
            $rows[$corner[0] + 2].Substring($corner[1], 7) | Should -Be '1011101'
        }
        # Pas synchronizacji (wiersz 6) i ciemny moduł obok dolnego znacznika
        $rows[6].Substring(8, 33) | Should -Be ('10' * 16 + '1')
        $rows[41][8] | Should -Be '1'
    }
    It "przechodzi na poziom L, gdy tekst nie mieści się przy M, i zgłasza zbyt długi tekst" {
        (New-HTQrCode -Text ('x' * 450) -Mask 0).Ecc | Should -Be 'L'
        { New-HTQrCode -Text ('x' * 600) } | Should -Throw
    }
}
