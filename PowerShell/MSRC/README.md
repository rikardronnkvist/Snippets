# MSRC - Microsoft Security Response Center

Two scripts, the first [Get-MSRCUpdates.ps1](./Get-MSRCUpdates.ps1) creates an object that you can use in other scripts. The second script [MSRSC-Update-ToTeams.ps1](./MSRSC-Update-ToTeams.ps1) uses that objects with the help of [PSTeams](http://github.com/evotecit/psteams/) to post the information in MS Teams via a WebHook.

**Update** New script without the need for PSTeams and ready to run on a daily schedule [MSRC-ToTeams-OnSchedule.ps1](./MSRC-ToTeams-OnSchedule.ps1)

## Teams Example
![Teams Example](./teams-example.png?raw=true)

## Inspiration
https://github.com/Immersive-Labs-Sec/msrc-api
