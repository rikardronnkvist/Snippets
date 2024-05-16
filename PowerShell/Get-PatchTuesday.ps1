Function Get-PatchTuesday {
    $firstDayOfMonth = Get-Date -Day 1

    (0..7) | ForEach-Object {
        if ($firstDayOfMonth.AddDays($_).DayOfWeek -eq "Tuesday") {
            Return Get-Date -Day ($_ + 8)
        }        
    }
}

# Example on how to use the function
If ( (Get-PatchTuesday).Date -eq (Get-Date).Date ) {
    Write-Host "Today is patch Tuesday :)"
}

If ( (Get-PatchTuesday).AddDays(2).Date -eq (Get-Date).Date ) {
    Write-Host "Now we are two days after patch Tuesday"
}
