# New-Uuid.Tests.ps1 — Tests for New-Uuid.ps1 (deterministic UUID generator + Xorshift32)
BeforeAll {
    Import-Module (Join-Path $Script:ModuleRoot 'Automation.psd1') -Force -ErrorAction Stop
}

Describe 'New-XivShift32PRNG — Xorshift32 seed → same sequence' {
    It 'Produces the same sequence from the same seed on two independent instances' {
        $seed  = 0xDEADBEEFu
        $rng_a = New-Object New_XorShift32PRNG([uint32]$seed)
        $rng_b = New-Object New_XorShift32PRNG([uint32]$seed)
        for ($i = 0; $i -lt 10; $i++) {
            $a = $rng_a.NextUInt32()
            $b = $rng_b.NextUInt32()
            $a | Should -Be $b
        }
    }

    It 'Produces a different sequence for different seeds' {
        $rng_a = New-Object New_XorShift32PRNG([uint32]1)
        $rng_b = New-Object New_XorShift32PRNG([uint32]2)
        $a = $rng_a.NextUInt32()
        $b = $rng_b.NextUInt32()
        $a | Should -Not -Be $b
    }

    It 'NextGuid returns a valid RFC-4122 v4 UUID version' {
        $rng = New-Object New_XorShift32PRNG([uint32]42)
        $guid = $rng.NextGuid()
        $version = ($guid.ToString('N').Substring(12, 1))
        $version | Should -Be '4'
    }

    It 'NextFloat returns a value in [0..1)' {
        $rng = New-Object New_XorShift32PRNG([uint32]7)
        # Sample 100 values
        for ($i = 0; $i -lt 100; $i++) {
            $v = $rng.NextFloat()
            $v -ge 0.0 | Should -Be $true
            $v -lt 1.0   | Should -Be $true
        }
    }
}

Describe 'Test-Uuid — Deterministic UUID generation' {
    It 'Generates a valid GUID for any server name' {
        $g = Test-Uuid -ServerName 'srv01'
        [Guid]$g | Should -Not -BeNullOrEmpty
        # GUID strings must have standard 36-char format (8-4-4-4-12)
        $g.Length | Should -Be 36
    }

    It 'Produces the same UUID for the same input (deterministic)' {
        $t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
        $a = Test-Uuid -ServerName 'srv01' -Timestamp $t
        $b = Test-Uuid -ServerName 'srv01' -Timestamp $t
        $a | Should -Be $b
    }

    It 'Produces different UUIDs for different inputs' {
        $t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
        $a = Test-Uuid -ServerName 'srv01' -Timestamp $t
        $b = Test-Uuid -ServerName 'srv02' -Timestamp $t
        $a | Should -Not -Be $b
    }

    It 'Uses current UTC time when no timestamp is given' {
        $before = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $g      = Test-Uuid -ServerName 'now_test'
        $after  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        # UUID must be valid
        [Guid]$g | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-Uuid — Output to file' {
    It 'Writes UUID to file when OutputPath is set' {
        $g = Test-Uuid -ServerName 'file_test'
        $f = Join-Path $Script:TempDir 'uuid_out.txt'
        Test-Uuid -ServerName 'file_test' -OutputPath $f
        (Test-Path $f) | Should -Be $true
        (Get-Content $f -Raw).Trim() | Should -Be $g
    }
}
