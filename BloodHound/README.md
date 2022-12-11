# BloodHound Data from the domain
Exported with [SharpHound](https://github.com/BloodHoundAD/SharpHound)

Two versions exported, one with just the [createAdStructure.ps1](../Bicep/Active%20Directory/createAdStructure.ps1) script completed and one with some security flaws.


## Export log
```
PS C:\Tools\SharpHound-v1.1.0> .\SharpHound.exe -c All
2022-12-11T05:20:27.9723338+00:00|INFORMATION|This version of SharpHound is compatible with the 4.2 Release of BloodHound
2022-12-11T05:20:28.1440010+00:00|INFORMATION|Resolved Collection Methods: Group, LocalAdmin, GPOLocalGroup, Session, LoggedOn, Trusts, ACL, Container, RDP, ObjectProps, DCOM, SPNTargets, PSRemote
2022-12-11T05:20:28.1751667+00:00|INFORMATION|Initializing SharpHound at 5:20 AM on 12/11/2022
2022-12-11T05:20:28.3313330+00:00|INFORMATION|Flags: Group, LocalAdmin, GPOLocalGroup, Session, LoggedOn, Trusts, ACL, Container, RDP, ObjectProps, DCOM, SPNTargets, PSRemote
2022-12-11T05:20:28.4875060+00:00|INFORMATION|Beginning LDAP search for demo.local
2022-12-11T05:20:59.2240693+00:00|INFORMATION|Status: 0 objects finished (+0 0)/s -- Using 48 MB RAM
2022-12-11T05:21:14.0353672+00:00|INFORMATION|Producer has finished, closing LDAP channel
2022-12-11T05:21:14.0353672+00:00|INFORMATION|LDAP channel closed, waiting for consumers
2022-12-11T05:21:14.6912772+00:00|INFORMATION|Consumers finished, closing output channel
2022-12-11T05:21:14.7225286+00:00|INFORMATION|Output channel closed, waiting for output task to complete
Closing writers
2022-12-11T05:21:14.8787809+00:00|INFORMATION|Status: 2865 objects finished (+2865 62.28261)/s -- Using 71 MB RAM
2022-12-11T05:21:14.8787809+00:00|INFORMATION|Enumeration finished in 00:00:46.3950458
2022-12-11T05:21:15.1131593+00:00|INFORMATION|Saving cache with stats: 2823 ID to type mappings.
 2829 name to SID mappings.
 0 machine sid mappings.
 2 sid to domain mappings.
 0 global catalog mappings.
2022-12-11T05:21:15.1287850+00:00|INFORMATION|SharpHound Enumeration Completed at 5:21 AM on 12/11/2022! Happy Graphing!
PS C:\Tools\SharpHound-v1.1.0>
```

## Demo
Shortest path from **user.no110** to **Domain Admin**

![Demo](./demo.png?raw=true)
