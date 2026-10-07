BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "ModulesConnection"
    Initialize-HTTestEnvironment -Root $TestDrive

    # Kompilacja testowej biblioteki o podanej nazwie i wersji (kompilator Roslyn dostarczany z PowerShell)
    Add-Type -AssemblyName Microsoft.CodeAnalysis, Microsoft.CodeAnalysis.CSharp
    function New-TestAssembly {
        param([string]$Directory, [string]$Name, [string]$Version, [string]$Code, [string[]]$References = @())
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        $path = Join-Path $Directory "$Name.dll"
        $source = "[assembly: System.Reflection.AssemblyVersion(""$Version"")]`n$Code"
        $tree = [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText($source)
        $refs = New-Object 'System.Collections.Generic.List[Microsoft.CodeAnalysis.MetadataReference]'
        foreach ($r in @([object].Assembly.Location, (Join-Path $PSHOME "System.Runtime.dll")) + $References) { $refs.Add([Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile($r)) }
        $options = [Microsoft.CodeAnalysis.CSharp.CSharpCompilationOptions]::new([Microsoft.CodeAnalysis.OutputKind]::DynamicallyLinkedLibrary)
        $compilation = [Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create($Name, [Microsoft.CodeAnalysis.SyntaxTree[]]@($tree), $refs, $options)
        $stream = [System.IO.File]::Create($path)
        try { $result = $compilation.Emit($stream) } finally { $stream.Dispose() }
        if (-not $result.Success) { throw (($result.Diagnostics | ForEach-Object { $_.ToString() }) -join "`n") }
        return $path
    }
    $libCode = 'namespace HTShared { public static class Lib { public static int Value() { return 1; } } }'
    $script:Root = Join-Path $TestDrive "packages"
    $newLib = New-TestAssembly -Directory (Join-Path $script:Root "lib2") -Name "HT.Shared" -Version "2.0.0.0" -Code $libCode
    New-TestAssembly -Directory (Join-Path $script:Root "runtimeOld") -Name "HT.Shared" -Version "1.0.0.0" -Code $libCode | Out-Null
    New-TestAssembly -Directory (Join-Path $script:Root "runtimeNew") -Name "HT.Shared" -Version "2.0.0.0" -Code $libCode | Out-Null
    # «Moduł», który wymaga nowszej biblioteki (jak moduł zbudowany pod nowszy .NET)
    $script:ModuleDir = Join-Path $script:Root "Module\1.0.0"
    New-TestAssembly -Directory $script:ModuleDir -Name "HT.Consumer" -Version "1.0.0.0" -References $newLib `
        -Code 'namespace HTConsumer { public static class C { public static int Use() { return HTShared.Lib.Value(); } } }' | Out-Null
    # Biblioteka dla Windows PowerShell (.NET Framework) - powinna być pominięta
    New-Item -ItemType Directory -Path (Join-Path $script:ModuleDir "netFramework") -Force | Out-Null
    Copy-Item (Join-Path $script:ModuleDir "HT.Consumer.dll") (Join-Path $script:ModuleDir "netFramework\HT.Framework.dll")
    $script:MsalLib = New-TestAssembly -Directory (Join-Path $script:Root "msal") -Name "Microsoft.Identity.Client" -Version "4.70.0.0" `
        -Code 'namespace HTMsal { public static class M { public static int Value() { return 2; } } }'
}

Describe "Get-HTAssemblyInfo" {
    It "odczytuje nazwę, wersję i odwołania bez ładowania biblioteki" {
        $info = Get-HTAssemblyInfo -Path (Join-Path $script:ModuleDir "HT.Consumer.dll")
        $info.Name | Should -Be "HT.Consumer"
        ($info.References | Where-Object Name -eq "HT.Shared").Version | Should -Be ([version]"2.0.0.0")
    }
    It "zwraca null dla pliku, który nie jest biblioteką .NET" {
        $path = Join-Path $TestDrive "native.dll"
        [System.IO.File]::WriteAllBytes($path, [byte[]](1..64))
        Get-HTAssemblyInfo -Path $path | Should -BeNullOrEmpty
    }
}

Describe "Test-HTModuleCompatibility" {
    It "wykrywa moduł wymagający nowszej biblioteki niż dostarczona z PowerShell" {
        $r = Test-HTModuleCompatibility -ModuleBase $script:ModuleDir -RuntimeDirectory (Join-Path $script:Root "runtimeOld") -SkipLoadedCheck
        $r.Compatible | Should -BeFalse
        $r.RuntimeIssues[0].Assembly | Should -Be "HT.Shared"
        $r.RuntimeIssues[0].Required | Should -Be ([version]"2.0.0.0")
        $r.RuntimeIssues[0].Available | Should -Be ([version]"1.0.0.0")
    }
    It "uznaje moduł za zgodny, gdy PowerShell ma wymaganą wersję" {
        (Test-HTModuleCompatibility -ModuleBase $script:ModuleDir -RuntimeDirectory (Join-Path $script:Root "runtimeNew") -SkipLoadedCheck).Compatible | Should -BeTrue
    }
    It "zgłasza konflikt z biblioteką współdzieloną załadowaną przez inny moduł" {
        $dir = Join-Path $script:Root "ConflictModule"
        New-TestAssembly -Directory $dir -Name "HT.Auth" -Version "1.0.0.0" -References $script:MsalLib `
            -Code 'namespace HTAuth { public static class A { public static int Use() { return HTMsal.M.Value(); } } }' | Out-Null
        $loaded = @([PSCustomObject]@{ Name = "Microsoft.Identity.Client"; Version = [version]"4.60.0.0"; Location = "C:\Modules\Other\Microsoft.Identity.Client.dll" })
        $r = Test-HTModuleCompatibility -ModuleBase $dir -RuntimeDirectory (Join-Path $script:Root "runtimeNew") -LoadedAssemblies $loaded
        $r.Compatible | Should -BeTrue
        $r.LoadedIssues[0].Assembly | Should -Be "Microsoft.Identity.Client"
        $r.LoadedIssues[0].Available | Should -Be ([version]"4.60.0.0")
    }
}

Describe "ConvertFrom-HTAssemblyLoadError" {
    It "rozpoznaje moduł wymagający nowszego .NET (System.Text.Json 10)" {
        $err = [System.IO.FileNotFoundException]::new("Could not load file or assembly 'System.Text.Json, Version=99.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51'. The system cannot find the file specified.")
        $problem = ConvertFrom-HTAssemblyLoadError -ErrorRecord $err -Module "Microsoft.Graph.Authentication"
        $problem.Data["HTKind"] | Should -Be "Runtime"
        $problem.Data["HTModule"] | Should -Be "Microsoft.Graph.Authentication"
        $problem.Message | Should -Match "System.Text.Json"
    }
    It "zwraca null dla innych błędów" {
        ConvertFrom-HTAssemblyLoadError -ErrorRecord ([System.Exception]::new("AADSTS50076: MFA required")) -Module "X" | Should -BeNullOrEmpty
    }
}

Describe "Resolve-HTModuleVersion" {
    It "zgłasza brak modułu" {
        (Resolve-HTModuleVersion -Name "HT.Nieistniejacy.Modul").Status | Should -Be "Missing"
    }
}
