function Main {
    Clear-Host
    # Check for administrator permissions
    $userIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $userPrincipal = [Security.Principal.WindowsPrincipal] $userIdentity
    $isAdmin = $userPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Display-Logo
        Display-Options
    } else {
        Write-Host "Insufficient permissions! Make sure you are running as administrator!" -f Red
        $userInput = Read-Host
        Exit
    }
}

function Display-Logo {
    Write-Host "------------------------------------------------" -f Blue
    Write-Host "`|               NTFS Relocations               `|" -f Blue
    Write-Host "`| https://github.com/KingSlme/ntfs-relocations `|" -f Blue
    Write-Host "------------------------------------------------" -f Blue
}

function Display-Options {
    $ntfsDriveLetters = Get-NTFS-Drive-Letters
    $optionDictionary = @{}
    $index = 1
    foreach ($ntfsDriveLetter in $ntfsDriveLetters) {
        $optionDictionary[$index] = $ntfsDriveLetter
        $index++
    }
    Write-Host "`nWhich drive(s) would you like to scan?" -f Blue
    foreach ($key in $optionDictionary.Keys | Sort-Object) {
        Write-Host "[" -f White -NoNewline; Write-Host "$key" -f Green -NoNewline; Write-Host "] " -f White -NoNewline;
        Write-Host "$($optionDictionary[$key])"
    }
    Write-Host "[" -f White -NoNewline; Write-Host "$index" -f Green -NoNewline; Write-Host "] " -f White -NoNewline;
    Write-Host "All"
    Write-Host "[" -f White -NoNewline; Write-Host "$($index + 1)" -f Green -NoNewline; Write-Host "] " -f White -NoNewline;
    Write-Host "Exit"
    Write-Host "-> " -f Yellow -NoNewline
    $userInput = Read-Host
    try {
        $userInput = [int]$userInput
        if ($optionDictionary.ContainsKey($userInput)) {
            Get-NTFS-Relocations -ntfsDriveLetters @($optionDictionary[$userInput].ToLower())
        } elseif ($userInput -eq $index) {
            Get-NTFS-Relocations -ntfsDriveLetters $ntfsDriveLetters | ForEach-Object { $_.ToLower() }
        } elseif ($userInput -eq $index + 1) {
            Exit
        } else {
            Write-Host "$userInput " -f Red -NoNewline; Write-Host "is not a valid choice!" -f White;
            Display-Options
        }
    } catch {
        Write-Host "$userInput " -f Red -NoNewline; Write-Host "is not a valid choice!" -f White;
        Display-Options
    }
}

function Get-NTFS-Drive-Letters {
    $ntfsDrives = Get-WmiObject Win32_LogicalDisk | Where-Object {$_.FileSystem -eq "NTFS"} | Select-Object DeviceID
    $ntfsDriveLetters = @()
    foreach ($drive in $ntfsDrives) {
        $ntfsDriveLetters += $drive.DeviceID
    }
    return $ntfsDriveLetters
}

function Get-NTFS-Relocations {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$ntfsDriveLetters
    )
    Write-Host("`nWhich file type would you like to check?") -f Blue
    Write-Host "-> " -f Yellow -NoNewline
    $stringToMatch = Read-Host
    foreach ($ntfsDriveLetter in $ntfsDriveLetters) {
        Write-Host "Analyzing $($ntfsDriveLetter.ToUpper()) Journal..." -ForegroundColor Blue
        $ntfsDriveLetterNoColon = $ntfsDriveLetter.Replace(":", "")
        fsutil usn readjournal $ntfsDriveLetter csv | findstr /i /c:$stringToMatch | findstr /i /c:0x00001000 > "$env:AppData\oldNames_$ntfsDriveLetterNoColon.txt"
        fsutil usn readjournal $ntfsDriveLetter csv | findstr /i /c:$stringToMatch | findstr /i /c:0x00002000 > "$env:AppData\newNames_$ntfsDriveLetterNoColon.txt"
        $oldContent = Get-Content "$env:AppData\oldNames_$ntfsDriveLetterNoColon.txt"
        $newContent = Get-Content "$env:AppData\newNames_$ntfsDriveLetterNoColon.txt"
        if ($oldContent -ne $null -and $newContent -ne $null) {
            $oldSubstrings = Get-Substrings -content $oldContent
            $newSubstrings = Get-Substrings -content $newContent
            $commonSubstrings = Compare-Object $oldSubstrings $newSubstrings -IncludeEqual | Where-Object {$_.SideIndicator -eq '=='}
            $matchedLines = $commonSubstrings.InputObject
            if ($matchedLines.Count -lt 1) {
                Write-Host "NONE" -f Green
            } else {
                foreach($line in $matchedLines) {
                    Write-Host $line -f Green
                }
            }
        } else {
            Write-Host "NONE" -f Green
        }
        Remove-Item "$env:AppData\oldNames_$ntfsDriveLetterNoColon.txt" -Force
        Remove-Item "$env:AppData\newNames_$ntfsDriveLetterNoColon.txt" -Force
    }
    Display-Options
}

function Get-Substrings {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$content
    )
    $substrings = @()
    foreach ($line in $content) {
        $values = $line -split ','
        $path = $values[1]
        $time = $values[5]
        $substrings += "$path $time"
    }
    return $substrings
}

Main