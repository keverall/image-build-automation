
$file = "docs\BitBucket_Code_Map_Maitenance_Mode.md"

(Get-Content $file) | ForEach-Object {
    if ($_ -match '^(#{2,3})\s+(.+)$') {
        $level = $matches[1]
        $title = $matches[2]

        $anchor = $title.ToLower()
        $anchor = $anchor -replace '[^a-z0-9\s\-]', ''
        $anchor = $anchor -replace '\s+', '-'
        $anchor = $anchor -replace '\.', ''
        
        "<a name=\"$anchor\"></a>`n$level $title"
    }
    else {
        $_
    }
} | Set-Content "$file.patched.md"
