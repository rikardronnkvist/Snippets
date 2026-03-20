# Dock hide/show automation

## Installation

### Shortcut

Download the [shortcut](https://www.icloud.com/shortcuts/5995307dc6f340a78d5f174bf5628c76) or create it

![Shortcut](shortcut.png)

### Automation

Create automation that runs when a display is connected or disconnected

![Dock monitor automation](automation.png)

### System

You might need to allow AEServer to control your computer under System Settings > Privacy & Security > Accessibility


## Alternative

Load with `launchctl load ~/Library/LaunchAgents/com.user.dockmonitor.plist`

It runs every 10 seconds.
