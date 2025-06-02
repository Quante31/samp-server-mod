# SAMP Gamemode by Quante31

[![sampctl](https://img.shields.io/badge/sampctl-server--package-2f2f2f.svg?style=for-the-badge)](https://github.com/Quante31/samp-server-mod)

A basic SA-MP gamemode written in Pawn and managed via [sampctl](https://github.com/Southclaws/sampctl).
Designed for modularity, performance, and ease of extension.

## Current features
- Database (MySQL/Marinadb) integrated house, territory and player information.    
- Gang wars by capturing territories.
- Teleportation pickups (not fully developed).
- Secure authorization using hash encryption.

 ## 🛠 Available Commands

| Command             | Description                          |
|---------------------|--------------------------------------|
| `/givecar`          | Spawns a vehicle for a player        |
| `/givemoney`        | Gives money to a player              |
| `/givegun`          | Gives a weapon                       |
| `/pay`              | Transfer money to another player     |
| `/tp`               | Teleport to coordinates              |
| `/jetpack`          | Gives a jetpack                      |
| `/pos`              | Shows current position and angle     |
| `/fixcar`           | Repairs the current vehicle          |
| `/stats`            | Shows player statistics              |
| `/help`             | Lists available commands             |
| `/changeinterior`   | Change player's interior             |
| `/addpickup`        | Creates a teleport pickup            |
| `/removepickup`     | Removes a pickup                     |
| `/listpickups`      | Lists all pickups                    |
| `/reloadpickups`    | Reloads pickup data from DB          |
| `/reloadterritories`| Reloads territory zones              |
| `/reloadhouses`     | Reloads house data from DB           |
| `/capture`          | Initiates gang territory capture     |
| `/changevirtualworld` | Sets player's virtual world       |
 
## Installation

Clone the repository:

```bash
git clone https://github.com/Quante31/samp-server-mod
cd samp-server-mod
```

Install sampctl into the same folder and initiate:

```bash
sampctl init
```

Compile and run:

```bash
sampctl package build
sampctl package run
```
