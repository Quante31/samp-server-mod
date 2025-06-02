//----------------------------------------------------------
//
//  GRAND LARCENY  1.0
//  A freeroam gamemode for SA-MP 0.3
//
//----------------------------------------------------------

#include <a_samp>
#include <core>
#include <float>
#include <sscanf2>
#include <samp_bcrypt>
#include <Pawn.CMD>
#include <a_mysql>
#include <streamer>

#include "include/gl_common.inc"
#include "include/gl_spawns.inc"

#pragma tabsize 0

//----------------------------------------------------------

#define COLOR_NORMAL_PLAYER 0xFFBB7777

// === ?? Основные цвета (фракции, зоны) ===
#define COLOR_RED             0xFF3C3CFF
#define COLOR_BLUE            0x3C8CFFF7
#define COLOR_GREEN           0x32C850FF
#define COLOR_YELLOW          0xFFDC00FF
#define COLOR_PURPLE          0xA05AFFFF
#define COLOR_ORANGE          0xFF8200FF
#define COLOR_WHITE 		  0xFFFFFFFF
#define COLOR_GRAY            0x969696FF
#define COLOR_BLACK           0x000000FF

// === ?? Чат, уведомления, интерфейс ===
#define COLOR_SYSTEM          0x66CCFFFF  // Информация от системы
#define COLOR_ERROR           0xFF6666FF  // Ошибки, предупреждения
#define COLOR_SUCCESS         0x99FF99FF  // Успешное действие
#define COLOR_COMMAND         0xFFFFFFFF  // Команды игроков
#define COLOR_ADMIN           0xFF66CCFF  // Сообщения от админов
#define COLOR_RADIO_RP        0xE8D47FFF  // РП-радио, фракционные чаты

// === ?? Дополнительные ===
#define COLOR_TRANSPARENT     0x00000000  // Полностью прозрачный
#define COLOR_GOLD            0xFFD700FF  // Золотой для VIP / наград
#define COLOR_CYAN            0x00FFFFFF  // Яркий голубой
#define COLOR_PINK            0xFF69B4FF  // Для женских персонажей, может быть кастомным цветом


#define CITY_LOS_SANTOS 	0
#define CITY_SAN_FIERRO 	1
#define CITY_LAS_VENTURAS 	2

new total_vehicles_from_files=0;

// Class selection globals
//new gPlayerCitySelection[MAX_PLAYERS];
//new gPlayerHasCitySelected[MAX_PLAYERS];
//new gPlayerLastCitySelectionTick[MAX_PLAYERS];

//new Text:txtClassSelHelper;
//new Text:txtLosSantos;
//new Text:txtSanFierro;
//new Text:txtLasVenturas;


#define DIALOG_REGISTER     1000
#define DIALOG_LOGIN        1001

#define MAX_NAME_LENGTH 24
#define MAX_PASSWORD_LENGTH 64
#define INVALID_PICKUP_ID 0
#define FREEZE_TIME 30
new MySQL:dbHandle;


new gPlayerID[MAX_PLAYERS];

enum PlayerData
{
    Name[MAX_NAME_LENGTH],
    Level,
    Money,
    Experience,
	Fraction,
	Capturing,
	lastPickupUseTick
};

enum TerritoryInfo {
	zone,
	color,
	name[MAX_NAME_LENGTH],
	owner,
	Float:minX,
    Float:minY,
    Float:maxX,
    Float:maxY,
};
enum BusinessInfo {
	id,
	name[32],
	ownerId,
	price,
	lock,
	product,
	subleaderId1,
	subleaderId2,
	bX,
	bY,
	bZ,
	buyX,
	buyY,
	buyZ,
	bInterior
};
enum PickupInfo {
	pickupId,
    Float:posX,
    Float:posY,
    Float:posZ,
    virtualWorld,
	pInterior,
    Float:interiorX,
    Float:interiorY,
    Float:interiorZ,
    fractionId,
	model
};
enum HouseData
{
    houseId,
    pickupID,
    price,
    ownerID,
    bool:locked,
    ownerName[MAX_NAME_LENGTH],
	exitPickupID
};

#define MAX_TERRITORIES 5
#define MAX_TERRITORY_ATTACKERS 32
#define INCOME_PER_TERRITORY 500

#define MAX_BUSINESSES 100
#define MAX_PICKUPS 100
#define MAX_HOUSES 100

new Territories[MAX_TERRITORIES][TerritoryInfo];
new TerritoryCaptureTimers[MAX_TERRITORIES];

new CaptureTimer[MAX_PLAYERS];
new CAPTURE_TIME = 180; // 3 минуты


new bool:gLoggedIn[MAX_PLAYERS];
new Players[MAX_PLAYERS][PlayerData];

new Business[MAX_BUSINESSES][BusinessInfo];
new Pickups[MAX_PICKUPS][PickupInfo]; // допустим, 10 пикапов максимум
new g_PickupCount = 0;

new Houses[MAX_HOUSES][HouseData];
new g_HouseCount = 0;

new PAYDAY = 0;
//new thisanimid=0;
//new lastanimid=0;

//----------------------------------------------------------

main()
{
	print("\n---------------------------------------");
	print("Running Grand World - by Quante31\n");
	print("---------------------------------------\n");
}

//----------------------------------------------------------

public OnPlayerConnect(playerid)
{
	GameTextForPlayer(playerid,"~w~Grand World",3000,4);
  	SendClientMessage(playerid,COLOR_BLUE,"Welcome to {88AA88}G{FFFFFF}rand {88AA88}W{FFFFFF}orld");
  	TogglePlayerSpectating(playerid, true);
	
	SetTimer("GiveTerritoryIncome", 300000, true); // 300000 мс = 5 минут

  	//gPlayerCitySelection[playerid] = -1;
	//gPlayerHasCitySelected[playerid] = 0;
	//gPlayerLastCitySelectionTick[playerid] = GetTickCount();

	SetPlayerColor(playerid, COLOR_NORMAL_PLAYER);

	gPlayerID[playerid] = playerid;
	GetPlayerName(playerid, Players[playerid][Name], MAX_NAME_LENGTH);
	CheckRegister(playerid);
	ShowTerritoriesForPlayer(playerid);
	
	
	/*
	Removes vending machines
	RemoveBuildingForPlayer(playerid, 1302, 0.0, 0.0, 0.0, 6000.0);
	RemoveBuildingForPlayer(playerid, 1209, 0.0, 0.0, 0.0, 6000.0);
	RemoveBuildingForPlayer(playerid, 955, 0.0, 0.0, 0.0, 6000.0);
	RemoveBuildingForPlayer(playerid, 1775, 0.0, 0.0, 0.0, 6000.0);
	RemoveBuildingForPlayer(playerid, 1776, 0.0, 0.0, 0.0, 6000.0);
	*/
	
	/*
	new ClientVersion[32];
	GetPlayerVersion(playerid, ClientVersion, 32);
	printf("Player %d reports client version: %s", playerid, ClientVersion);*/
 	return 1;
}

public OnPlayerPickUpDynamicPickup(playerid, pickupid){

	// Сначала проверим: это пикап дома?
    for (new i = 0; i < MAX_HOUSES; i++)
    {
        if (Houses[i][pickupID] == pickupid)
        {
			printf("Player %d picked up house pickup with id %d (index %d)", playerid, pickupid, i);
            if (Houses[i][locked])
                return SendClientMessage(playerid, -1, "Этот дом закрыт.");
			
			if ((GetTickCount() - Players[playerid][lastPickupUseTick]) < 3000){
				printf("Player %d tried to use pickup with id %d too fast!", playerid, pickupid);
				return 0;
			}
            SetPlayerVirtualWorld(playerid, Pickups[i][virtualWorld]);
            SetPlayerInterior(playerid, Pickups[i][pInterior]);
			J_SetPlayerPosFreeze(playerid, Pickups[i][interiorX], Pickups[i][interiorY], Pickups[i][interiorZ]);
			J_SetPlayerFacingAngle(playerid, 0.0);
			Players[playerid][lastPickupUseTick] = GetTickCount();
			//g_PickupCount--;
            SendClientMessage(playerid, -1, "Вы вошли в дом.");
            return 1;
        }
    }

    // Если это не дом — обычная логика для интерьеров
    for (new i = 0; i < MAX_PICKUPS; i++)
    {
        if (Pickups[i][pickupId] == pickupid)
        {
            printf("Player %d picked up pickup with id %d (index %d)", playerid, pickupid, i);
			if ((GetTickCount() - Players[playerid][lastPickupUseTick]) < 3000){
				printf("Player %d tried to use pickup with id %d too fast!", playerid, pickupid);
				return 0; // слишком быстро, не даём использовать
			}

            SetPlayerVirtualWorld(playerid, Pickups[i][virtualWorld]);
            SetPlayerInterior(playerid, Pickups[i][pInterior]);
            SetPlayerPos(playerid, Pickups[i][interiorX], Pickups[i][interiorY], Pickups[i][interiorZ]);
			Players[playerid][lastPickupUseTick] = GetTickCount();
            //g_PickupCount--;
            return SendClientMessage(playerid, -1, "Вы вошли/вышли из интерьера.");
        }
    }

    printf("Unknown pickup ID: %d", pickupid);
    return 0;
    
}
forward LoadHousesFromDB();
public LoadHousesFromDB()
{
	new query[128];
	mysql_format(dbHandle, query, sizeof(query), "SELECT id, pickupid, price, owner_id, locked, owner_name, exitPickupid FROM houses");
    mysql_tquery(dbHandle, query, "OnHousesLoaded");
    return 1;
}
forward OnHousesLoaded();
public OnHousesLoaded()
{
	new rows = cache_num_rows();
	g_HouseCount = 0;
	for (new i = 0; i < rows; i++, g_HouseCount++)
	{
		if (g_HouseCount > MAX_HOUSES) return 1;

		new hID, pID, p, oID, l, exitP;
		new oName[MAX_NAME_LENGTH];

		cache_get_value_index_int(i, 0, hID);
		cache_get_value_index_int(i, 1, pID);
		cache_get_value_index_int(i, 2, p);
		cache_get_value_index_int(i, 3, oID);
		cache_get_value_index_int(i, 4, l);
		cache_get_value_index(i, 5, oName, sizeof(oName));
		cache_get_value_index_int(i, 6, exitP);

		Houses[g_HouseCount][houseId] = hID;
		Houses[g_HouseCount][pickupID] = pID;
		Houses[g_HouseCount][price] = p;
		Houses[g_HouseCount][ownerID] = oID;
		Houses[g_HouseCount][locked] = l;
		Houses[g_HouseCount][ownerName] = oName;
		Houses[g_HouseCount][exitPickupID] = exitP;

		printf("Loaded house %d: Pickup ID %d, Price %d, Owner ID %d. Exit Pickup ID", hID, pID, p, oID, exitP);
	}
	return 1;
}


// Загрузка пикапов из базы при старте

stock LoadTerritoriesFromDB()
{
	new query[128];
	mysql_format(dbHandle, query, sizeof(query), "SELECT id, name, owner, minX, minY, maxX, maxY FROM territories");
	mysql_tquery(dbHandle, query, "OnTerritoriesLoaded");
	return 1;
}
forward OnTerritoriesLoaded();
public OnTerritoriesLoaded()
{
	new rows = cache_num_rows();
	for (new i = 0; i < rows; i++)
	{
		new tid, towner, tname[MAX_NAME_LENGTH];
		new Float:tminX, tminY, tmaxX, tmaxY;

		cache_get_value_index_int(i, 0, tid);
		cache_get_value_index(i, 1, tname);
		cache_get_value_index_int(i, 2, towner);
		cache_get_value_index_float(i, 3, tminX);
		cache_get_value_index_float(i, 4, tminY);
		cache_get_value_index_float(i, 5, tmaxX);
		cache_get_value_index_float(i, 6, tmaxY);

		Territories[tid][zone] = GangZoneCreate(tminX, tminY, tmaxX, tmaxY);
		Territories[tid][color] = GetFractionColor(towner);
		Territories[tid][name] = tname;
		Territories[tid][owner] = towner;
		Territories[tid][minX] = tminX;
		Territories[tid][minY] = tminY;
		Territories[tid][maxX] = tmaxX;
		Territories[tid][maxY] = tmaxY;
		
		printf("Loaded territory %d: %s, owner: %d.", tid, tname, towner);
	}
	return 1;
}
stock SavePickupToDB(pickupid, Float:posx, Float:posy, Float:posz, interior, vw, Float:intX, Float:intY, Float:intZ, model)
{
    new query[512];
	mysql_format(dbHandle, query, sizeof(query),"INSERT INTO pickups (pickupid, posX, posY, posZ, interior, virtualWorld, interiorX, interiorY, interiorZ, model) VALUES (%d, %f, %f, %f, %d, %d, %f, %f, %f)", pickupid, posx, posy, posz, interior, vw, intX, intY, intZ, model);
    mysql_tquery(dbHandle, query);

    return 1;
}
stock LoadPickupsFromDB()
{
    new query[256];
    mysql_format(dbHandle, query, sizeof(query), "SELECT pickupid, posX, posY, posZ, interior, virtualWorld, interiorX, interiorY, interiorZ, model FROM pickups");    
    mysql_tquery(dbHandle, query, "OnPickupsLoaded");
    return 1;
}
forward OnPickupsLoaded();
public OnPickupsLoaded()
{
    new rows = cache_num_rows();
    g_PickupCount = 0;

    for (new i = 0; i < rows; i++, g_PickupCount++)
    {
        if (g_PickupCount > MAX_PICKUPS) break;

        new pickupid, interior, vw, m;
        new Float:posx, Float:posy, Float:posz;
        new Float:intX, Float:intY, Float:intZ;

        cache_get_value_index_int(i, 0, pickupid);
        cache_get_value_index_float(i, 1, posx);
        cache_get_value_index_float(i, 2, posy);
        cache_get_value_index_float(i, 3, posz);
        cache_get_value_index_int(i, 4, interior);
        cache_get_value_index_int(i, 5, vw);
        cache_get_value_index_float(i, 6, intX);
        cache_get_value_index_float(i, 7, intY);
        cache_get_value_index_float(i, 8, intZ);
        cache_get_value_index_int(i, 9, m);

        Pickups[g_PickupCount][pickupId] = CreateDynamicPickup(m, 1, posx, posy, posz);
        Pickups[g_PickupCount][posX] = posx;
        Pickups[g_PickupCount][posY] = posy;
        Pickups[g_PickupCount][posZ] = posz;
        Pickups[g_PickupCount][pInterior] = interior;
        Pickups[g_PickupCount][virtualWorld] = vw;
        Pickups[g_PickupCount][interiorX] = intX;
        Pickups[g_PickupCount][interiorY] = intY;
        Pickups[g_PickupCount][interiorZ] = intZ;
		Pickups[g_PickupCount][model] = m;

        printf("Pickup %d loaded at %.2f, %.2f, %.2f | VW: %d | Int: %d | Model: %d", g_PickupCount, posx, posy, posz, vw, interior, m);
    }

    printf("Loaded %d pickups (async).", g_PickupCount);
    return 1;
}
stock ShowTerritoriesForPlayer(playerid)
{
	for (new i = 0; i < MAX_TERRITORIES; i++)
	{
		GangZoneShowForPlayer(playerid, Territories[i][zone], Territories[i][color]);
	}
}
stock IsPlayerInZone(playerid, tid)
{
	new Float:px, Float:py, Float:pz;
	GetPlayerPos(playerid, px, py, pz);

	return (px >= Territories[tid][minX] && px <= Territories[tid][maxX] && py >= Territories[tid][minY] && py <= Territories[tid][maxY]);
}
stock GetFractionColor(fractionid)
{
	switch (fractionid)
	{
		case 0: { return 0xFFFF0088;} // Aztecas (жёлтый)
		case 1:{ return 0xAA00AA88;} // Ballas (фиолетовый)
		case 2:{ return 0x00FF0088; }// Grove (зелёный)
		case 3:{ return 0x0000FF88;}// Vagos (синий)
		case 4: {return 0xFF990088;} // хз (оранжевый)
		default:{ return 0x88888888; }// Серый = без фракции
	}
	return 0x88888888; // Серый = без фракции
}
forward GiveTerritoryIncome();
public GiveTerritoryIncome()
{

	for (new i = 0; i < MAX_TERRITORIES; i++)
	{
		new o = Territories[i][owner];

		if (o == 0) continue; // никто не владеет

		for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
		{
			if ((Players[playerid][Fraction] == o) && IsPlayerConnected(playerid))
			{
				Players[playerid][Money] += INCOME_PER_TERRITORY;
				GivePlayerMoney(playerid, INCOME_PER_TERRITORY);

				new msg[128];
				format(msg, sizeof(msg), "[Доход] Ваша фракция получила $%d за территорию \"%s\".", INCOME_PER_TERRITORY, Territories[i][name]);
				SendClientMessage(playerid, 0x33AA33FF, msg);

				// Если синхронизируем с БД:
				new query[128];
				format(query, sizeof(query), "UPDATE users SET money = money + %d WHERE name = '%e'", INCOME_PER_TERRITORY, Players[playerid][Name]);
				mysql_tquery(dbHandle, query);
			}
		}
	}
	return 1;
}


stock bool:HasAliveAttackers(tid, pid)
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (pid == i) continue; // Пропускаем игрока, который инициировал захват
		if (Players[i][Capturing] == tid && IsPlayerConnected(i)) return true;
	}
	return false;
}

forward FinishTerritoryCapture(tid, pid);
public FinishTerritoryCapture(tid, pid)
{
	TerritoryCaptureTimers[tid] = 0;

	new newOwner = Players[pid][Fraction];
	Territories[tid][owner] = newOwner;
	Territories[tid][color] = GetFractionColor(newOwner);
	GangZoneStopFlashForAll(Territories[tid][zone]);
	GangZoneHideForAll(Territories[tid][zone]);
	GangZoneShowForAll(Territories[tid][zone], Territories[tid][color]);
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if (IsPlayerConnected(i))
		{
			if (Players[i][Fraction] == newOwner) {
				Players[i][Capturing] = -1; // Сброс флага захвата
			}
		}
	}

	// Сохраняем в БД
	new query[128];
	format(query, sizeof(query), "UPDATE territories SET owner = %d WHERE id = %d", newOwner, tid);
	mysql_tquery(dbHandle, query);

	new msg[128];
	format(msg, sizeof(msg), "[Захват] Территория \"%s\" перешла под контроль фракции %d!", Territories[tid][name], newOwner);
	SendClientMessageToAll(0x33CC33FF, msg);


	return 1;
}
stock GetTerritoryAtPlayer(playerid)
{

	for (new tid = 0; tid < MAX_TERRITORIES; tid++)
	{
		if (IsPlayerInZone(playerid, tid))
			return tid;
	}
	return -1;
}
stock SendMessageToFraction(fractionid, const message[])
{
	for (new i = 0; i < MAX_PLAYERS; i++)
	{
		if ((Players[i][Fraction] == fractionid) && IsPlayerConnected(i))
		{
			SendClientMessage(i, 0x00FF00FF, message);
		}
	}
}




// Обновление статистики в меню

stock DisableCapturing(pid) {
	if (Players[pid][Capturing] != -1) {
		new tid = Players[pid][Capturing];
		if (!HasAliveAttackers(tid, pid)){
			KillTimer(TerritoryCaptureTimers[tid]);
			TerritoryCaptureTimers[tid] = 0;
			new msg[128];
			format(msg, sizeof(msg), "Захват территории %s (%d) отменён — все атакующие выбыли.", Territories[tid][name], tid);
			GangZoneStopFlashForAll(Territories[tid][zone]);
			SendClientMessageToAll(0xFF0000FF, msg);
		}	
		Players[pid][Capturing] = -1;
	}
	return 1;
}
public OnPlayerDisconnect(playerid, reason)
{
	DisableCapturing(playerid);
	
    new query[256];
    mysql_format(dbHandle, query, sizeof(query), "UPDATE users SET money = %d, level = %d, experience = %d WHERE name = '%e'", Players[playerid][Money], Players[playerid][Level], Players[playerid][Experience], Players[playerid][Name]);
    mysql_tquery(dbHandle, query);
	Players[playerid][Name][0] = '\0';
    Players[playerid][Level] = 0;
    Players[playerid][Money] = 0;
    Players[playerid][Experience] = 0;
    gPlayerID[playerid] = 0;
	gLoggedIn[playerid] = false;
    return 1;
}
//----------------------------------------------------------

public OnPlayerUpdate(playerid)
{
	if(!IsPlayerConnected(playerid)) return 0;
	if(IsPlayerNPC(playerid)) return 1;

	// changing cities by inputs
	
	// No weapons in interiors
	//if(GetPlayerInterior(playerid) != 0 && GetPlayerWeapon(playerid) != 0) {
	    //SetPlayerArmedWeapon(playerid,0); // fists
	    //return 0; // no syncing until they change their weapon
	//}
	
	// Don't allow minigun
	if(GetPlayerWeapon(playerid) == WEAPON_MINIGUN) {
	    Kick(playerid);
	    return 0;
	}
	
	/*new currentMoney = GetPlayerMoney(playerid);
    if ((currentMoney != Players[playerid][Money]) && (gLoggedIn[playerid]))
    {
		printf("OnPlayerUpdate: Player %d has money: %d", playerid, currentMoney);
		printf("OnPlayerUpdate: System money: %d", Players[playerid][Money]);
		//CallLocalFunction("OnPlayerMoneyChange", "ii", playerid, currentMoney);
		Players[playerid][Money] = currentMoney;
    }
	else if ((currentMoney != Players[playerid][Money]) && (!gLoggedIn[playerid])){
		currentMoney = Players[playerid][Money];
	}*/

	/* No jetpacks allowed
	if(GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_USEJETPACK) {
	    Kick(playerid);
	    return 0;
	}*/

	/* For testing animations
    new msg[128+1];
	new animlib[32+1];
	new animname[32+1];

	thisanimid = GetPlayerAnimationIndex(playerid);
	if(lastanimid != thisanimid)
	{
		GetAnimationName(thisanimid,animlib,32,animname,32);
		format(msg, 128, "anim(%d,%d): %s %s", lastanimid, thisanimid, animlib, animname);
		lastanimid = thisanimid;
		SendClientMessage(playerid, 0xFFFFFFFF, msg);
	}*/

	return 1;
}
forward OnPlayerMoneyChange(playerid, nmoney);
public OnPlayerMoneyChange(playerid, nmoney)
{
    printf("Player %d money changed to %d", playerid, nmoney);
	new query[128];
	mysql_format(dbHandle, query, sizeof(query), "UPDATE users SET money = %d WHERE name = '%e'", nmoney, Players[playerid][Name]);
    mysql_tquery(dbHandle, query);
}
public OnPlayerSpawn(playerid)
{
	if(IsPlayerNPC(playerid)) return 1;
	StopAudioStreamForPlayer(playerid);
	TogglePlayerControllable(playerid, false);
	SetTimerEx("UnFreeze",GetPlayerPing(playerid)*2*(FREEZE_TIME), 0, "d", playerid);
	//SetSpawnInfo(playerid, 255, 0, 167.6, -109.2, 1.6, 272.7, 0, 0, 0, 0, 0, 0);
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
	//SetPlayerPos(playerid, 167.6, -109.2, 1.6);
   // SetPlayerFacingAngle(playerid, 0.0);
   // SetPlayerPos(playerid, -1034.0, -644.6, 32.0);
	//TogglePlayerClock(playerid,0);
 	//ResetPlayerMoney(playerid);
	//GivePlayerMoney(playerid, 30000);

	/*if(CITY_LOS_SANTOS == gPlayerCitySelection[playerid]) {
 	    randSpawn = random(sizeof(gRandomSpawns_LosSantos));
 	    SetPlayerPos(playerid,
		 gRandomSpawns_LosSantos[randSpawn][0],
		 gRandomSpawns_LosSantos[randSpawn][1],
		 gRandomSpawns_LosSantos[randSpawn][2]);
		SetPlayerFacingAngle(playerid,gRandomSpawns_LosSantos[randSpawn][3]);
	}
	else if(CITY_SAN_FIERRO == gPlayerCitySelection[playerid]) {
 	    randSpawn = random(sizeof(gRandomSpawns_SanFierro));
 	    SetPlayerPos(playerid,
		 gRandomSpawns_SanFierro[randSpawn][0],
		 gRandomSpawns_SanFierro[randSpawn][1],
		 gRandomSpawns_SanFierro[randSpawn][2]);
		SetPlayerFacingAngle(playerid,gRandomSpawns_SanFierro[randSpawn][3]);
	}
	else if(CITY_LAS_VENTURAS == gPlayerCitySelection[playerid]) {
 	    randSpawn = random(sizeof(gRandomSpawns_LasVenturas));
 	    SetPlayerPos(playerid,
		 gRandomSpawns_LasVenturas[randSpawn][0],
		 gRandomSpawns_LasVenturas[randSpawn][1],
		 gRandomSpawns_LasVenturas[randSpawn][2]);
		SetPlayerFacingAngle(playerid,gRandomSpawns_LasVenturas[randSpawn][3]);
	}*/

	//SetPlayerColor(playerid,COLOR_NORMAL_PLAYER);
	
	/*
	SetPlayerSkillLevel(playerid,WEAPONSKILL_PISTOL,200);
    SetPlayerSkillLevel(playerid,WEAPONSKILL_PISTOL_SILENCED,200);
    SetPlayerSkillLevel(playerid,WEAPONSKILL_DESERT_EAGLE,200);
    SetPlayerSkillLevel(playerid,WEAPONSKILL_SHOTGUN,200);
    SetPlayerSkillLevel(playerid,WEAPONSKILL_SAWNOFF_SHOTGUN,200);
    SetPlayerSkillLevel(playerid,WEAPONSKILL_SPAS12_SHOTGUN,200);
    SetPlayerSkillLevel(playerid,WEAPONSKILL_MICRO_UZI,200);
    SetPlayerSkillLevel(playerid,WEAPONSKILL_MP5,200);
    SetPlayerSkillLevel(playerid,WEAPONSKILL_AK47,200);
    SetPlayerSkillLevel(playerid,WEAPONSKILL_M4,200);
    SetPlayerSkillLevel(playerid,WEAPONSKILL_SNIPERRIFLE,200);*/
    
    //GivePlayerWeapon(playerid,WEAPON_COLT45,100);
	//GivePlayerWeapon(playerid,WEAPON_MP5,100);
	TogglePlayerClock(playerid, 0);

	return 1;
}

//----------------------------------------------------------

public OnPlayerDeath(playerid, killerid, reason)
{
	DisableCapturing(playerid);
	
	 // Сброс флага захвата
    //new playercash;
    
    // if they ever return to class selection make them city
	// select again first
	//gPlayerHasCitySelected[playerid] = 0;
    
	/*if(killerid == INVALID_PLAYER_ID) {
        ResetPlayerMoney(playerid);
	} else {
		playercash = GetPlayerMoney(playerid);
		if(playercash > 0)  {
			GivePlayerMoney(killerid, playercash);
			ResetPlayerMoney(playerid);
		}
	}*/
   	return 1;
}

//----------------------------------------------------------

/*ClassSel_SetupCharSelection(playerid)
{
   	if(gPlayerCitySelection[playerid] == CITY_LOS_SANTOS) {
		SetPlayerInterior(playerid,11);
		SetPlayerPos(playerid,508.7362,-87.4335,998.9609);
		SetPlayerFacingAngle(playerid,0.0);
    	SetPlayerCameraPos(playerid,508.7362,-83.4335,998.9609);
		SetPlayerCameraLookAt(playerid,508.7362,-87.4335,998.9609);
	}
	else if(gPlayerCitySelection[playerid] == CITY_SAN_FIERRO) {
		SetPlayerInterior(playerid,3);
		SetPlayerPos(playerid,-2673.8381,1399.7424,918.3516);
		SetPlayerFacingAngle(playerid,181.0);
    	SetPlayerCameraPos(playerid,-2673.2776,1394.3859,918.3516);
		SetPlayerCameraLookAt(playerid,-2673.8381,1399.7424,918.3516);
	}
	else if(gPlayerCitySelection[playerid] == CITY_LAS_VENTURAS) {
		SetPlayerInterior(playerid,3);
		SetPlayerPos(playerid,349.0453,193.2271,1014.1797);
		SetPlayerFacingAngle(playerid,286.25);
    	SetPlayerCameraPos(playerid,352.9164,194.5702,1014.1875);
		SetPlayerCameraLookAt(playerid,349.0453,193.2271,1014.1797);
	}
	
}*/

//----------------------------------------------------------
// Used to init textdraws of city names

/*ClassSel_InitCityNameText(Text:txtInit)
{
  	TextDrawUseBox(txtInit, 0);
	TextDrawLetterSize(txtInit,1.25,3.0);
	TextDrawFont(txtInit, 0);
	TextDrawSetShadow(txtInit,0);
    TextDrawSetOutline(txtInit,1);
    TextDrawColor(txtInit,0xEEEEEEFF);
    TextDrawBackgroundColor(txtClassSelHelper,0x000000FF);
}*/

//----------------------------------------------------------

/*ClassSel_InitTextDraws()
{
    // Init our observer helper text display
	txtLosSantos = TextDrawCreate(10.0, 380.0, "Los Santos");
	ClassSel_InitCityNameText(txtLosSantos);
	txtSanFierro = TextDrawCreate(10.0, 380.0, "San Fierro");
	ClassSel_InitCityNameText(txtSanFierro);
	txtLasVenturas = TextDrawCreate(10.0, 380.0, "Las Venturas");
	ClassSel_InitCityNameText(txtLasVenturas);

    // Init our observer helper text display
	txtClassSelHelper = TextDrawCreate(10.0, 415.0,
	   " Press ~b~~k~~GO_LEFT~ ~w~or ~b~~k~~GO_RIGHT~ ~w~to switch cities.~n~ Press ~r~~k~~PED_FIREWEAPON~ ~w~to select.");
	TextDrawUseBox(txtClassSelHelper, 1);
	TextDrawBoxColor(txtClassSelHelper,0x222222BB);
	TextDrawLetterSize(txtClassSelHelper,0.3,1.0);
	TextDrawTextSize(txtClassSelHelper,400.0,40.0);
	TextDrawFont(txtClassSelHelper, 2);
	TextDrawSetShadow(txtClassSelHelper,0);
    TextDrawSetOutline(txtClassSelHelper,1);
    TextDrawBackgroundColor(txtClassSelHelper,0x000000FF);
    TextDrawColor(txtClassSelHelper,0xFFFFFFFF);
}*/

//----------------------------------------------------------

/*ClassSel_SetupSelectedCity(playerid)
{
	if(gPlayerCitySelection[playerid] == -1) {
		gPlayerCitySelection[playerid] = CITY_LOS_SANTOS;
	}
	
	if(gPlayerCitySelection[playerid] == CITY_LOS_SANTOS) {
		SetPlayerInterior(playerid,0);
   		SetPlayerCameraPos(playerid,1630.6136,-2286.0298,110.0);
		SetPlayerCameraLookAt(playerid,1887.6034,-1682.1442,47.6167);
		
		TextDrawShowForPlayer(playerid,txtLosSantos);
		TextDrawHideForPlayer(playerid,txtSanFierro);
		TextDrawHideForPlayer(playerid,txtLasVenturas);
	}
	else if(gPlayerCitySelection[playerid] == CITY_SAN_FIERRO) {
		SetPlayerInterior(playerid,0);
   		SetPlayerCameraPos(playerid,-1300.8754,68.0546,129.4823);
		SetPlayerCameraLookAt(playerid,-1817.9412,769.3878,132.6589);
		
		TextDrawHideForPlayer(playerid,txtLosSantos);
		TextDrawShowForPlayer(playerid,txtSanFierro);
		TextDrawHideForPlayer(playerid,txtLasVenturas);
	}
	else if(gPlayerCitySelection[playerid] == CITY_LAS_VENTURAS) {
		SetPlayerInterior(playerid,0);
   		SetPlayerCameraPos(playerid,1310.6155,1675.9182,110.7390);
		SetPlayerCameraLookAt(playerid,2285.2944,1919.3756,68.2275);
		
		TextDrawHideForPlayer(playerid,txtLosSantos);
		TextDrawHideForPlayer(playerid,txtSanFierro);
		TextDrawShowForPlayer(playerid,txtLasVenturas);
	}
}*/

//----------------------------------------------------------

/*ClassSel_SwitchToNextCity(playerid)
{
    gPlayerCitySelection[playerid]++;
	if(gPlayerCitySelection[playerid] > CITY_LAS_VENTURAS) {
	    gPlayerCitySelection[playerid] = CITY_LOS_SANTOS;
	}
	PlayerPlaySound(playerid,1052,0.0,0.0,0.0);
	gPlayerLastCitySelectionTick[playerid] = GetTickCount();
	ClassSel_SetupSelectedCity(playerid);
}*/

//----------------------------------------------------------

/*ClassSel_SwitchToPreviousCity(playerid)
{
    gPlayerCitySelection[playerid]--;
	if(gPlayerCitySelection[playerid] < CITY_LOS_SANTOS) {
	    gPlayerCitySelection[playerid] = CITY_LAS_VENTURAS;
	}
	PlayerPlaySound(playerid,1053,0.0,0.0,0.0);
	gPlayerLastCitySelectionTick[playerid] = GetTickCount();
	ClassSel_SetupSelectedCity(playerid);
}*/

//----------------------------------------------------------

/*ClassSel_HandleCitySelection(playerid)
{
	new Keys,ud,lr;
    GetPlayerKeys(playerid,Keys,ud,lr);
    
    if(gPlayerCitySelection[playerid] == -1) {
		ClassSel_SwitchToNextCity(playerid);
		return;
	}

	// only allow new selection every ~500 ms
	if( (GetTickCount() - gPlayerLastCitySelectionTick[playerid]) < 500 ) return;
	
	if(Keys & KEY_FIRE) {
	    gPlayerHasCitySelected[playerid] = 1;
	    TextDrawHideForPlayer(playerid,txtClassSelHelper);
		TextDrawHideForPlayer(playerid,txtLosSantos);
		TextDrawHideForPlayer(playerid,txtSanFierro);
		TextDrawHideForPlayer(playerid,txtLasVenturas);
	    TogglePlayerSpectating(playerid,0);
	    return;
	}
	
	if(lr > 0) {
	   ClassSel_SwitchToNextCity(playerid);
	}
	else if(lr < 0) {
	   ClassSel_SwitchToPreviousCity(playerid);
	}
}*/

//----------------------------------------------------------

/*public OnPlayerRequestClass(playerid, classid)
{
	if(IsPlayerNPC(playerid)) return 1;

	if(gPlayerHasCitySelected[playerid]) {
		ClassSel_SetupCharSelection(playerid);
		return 1;
	} else {
		if(GetPlayerState(playerid) != PLAYER_STATE_SPECTATING) {
			TogglePlayerSpectating(playerid,1);
    		TextDrawShowForPlayer(playerid, txtClassSelHelper);
    		gPlayerCitySelection[playerid] = -1;
		}
  	}
    
	return 0;
}*/
stock CheckRegister(playerid){
	new query[128];
	mysql_format(dbHandle, query, sizeof(query), "SELECT * FROM users WHERE name = '%e'", Players[playerid][Name]);
    mysql_tquery(dbHandle, query, "OnCheckRegister", "i", playerid);
}
forward OnCheckRegister(playerid);
public OnCheckRegister(playerid)
{
	new resultCount;
    if (!cache_get_result_count(resultCount)) {
		print("OnCheckRegister: No results found.");
		return 1;
    }
	new rows;
	cache_set_result(0);
	rows = cache_num_rows();
	if (rows > 0){
        ShowPlayerDialog(
            playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD,
            "{bfbbba}Авторизация", 
            "Добро пожаловать на {3c8cff}Grand World\n\nВведите свой пароль:\n", 
            "Ввод", "Выход"
        );
		printf("Player %d is already registered with name '%s'.", playerid, Players[playerid][Name]);
		
	} 
    else{
		ShowPlayerDialog(
            playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD,
            "Добро пожаловать на {3c8cff}Grand World{FF0000}\n\nЭтот аккаунт не {ff6347}зарегистрирован {FFFFFF}на нашем сервере. \nДля регистрации введите ваш новый пароль: \n",              
            "Придумайте пароль (6+ символов):", 
            "Ок", "Выход"
        );
	} 
    return 1;
}

forward OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]);
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == DIALOG_REGISTER) {
        if (response && inputtext[0] != '\0') {
            if (strlen(inputtext) < 6) {
                SendClientMessage(playerid, 0xFF0000AA, "Пароль должен быть не менее 6 символов");
               	ShowPlayerDialog(
					playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD,
					"Добро пожаловать на {3c8cff}Grand World{FF0000}\n\nЭтот аккаунт не {ff6347}зарегистрирован {FFFFFF}на нашем сервере. \nДля регистрации введите ваш новый пароль: \n",              
					"Придумайте пароль (6+ символов):", 
					"Ок", "Выход"
				);
            }
            else
            {
				new query[128];
				bcrypt_hash(playerid, "OnPasswordHash", inputtext, BCRYPT_COST);

				Players[playerid][Money] = 500;
				Players[playerid][Level] = 1; 
				Players[playerid][Experience] = 0;
				Players[playerid][Fraction] = -1;
				Players[playerid][Capturing] = -1;

				mysql_format(dbHandle, query, sizeof(query), "UPDATE users SET money = %d, level = %d, experience = %d WHERE name = '%e'", Players[playerid][Money], Players[playerid][Level], Players[playerid][Experience], Players[playerid][Name]);
                mysql_tquery(dbHandle, query);
				
				

                SendClientMessage(playerid, 0x00FF00AA, "Вы успешно создали свой аккаунт, приятной игры");
				printf("Player %d registered with name '%s' and password '%s'.", playerid, Players[playerid][Name], inputtext);	
				TogglePlayerSpectating(playerid, false);
				SetSpawnInfo(playerid, 255, 0, 167.6, -109.2, 1.6, 272.7, 0, 0, 0, 0, 0, 0);
				SpawnPlayer(playerid);
            }
        }
		else if (!response) {
			SendClientMessage(playerid, 0xFF0000AA, "Регистрация отменена.");
			printf("Player %d cancelled registration dialog.", playerid);
			SendRconCommand("exit");
		}
        return 1;
    }
    else if (dialogid == DIALOG_LOGIN) {
        if (response && inputtext[0] != '\0') {
			new query[64];
			mysql_format(dbHandle, query, sizeof(query), "SELECT password FROM users WHERE name = '%e'", Players[playerid][Name]);
			mysql_tquery(dbHandle, query, "OnLoginCheck", "ds", playerid, inputtext);
			//bcrypt_verify(playerid, "OnLoginCheck", pass, hpass);
			//mysql_format(dbHandle, query, sizeof(query), "SELECT password, money, level, experience, fraction FROM users WHERE name = '%e'", Players[playerid][Name]);
            //mysql_tquery(dbHandle, query, "OnLoginCheck", "ds", playerid, inputtext);
        }
        return 1;
    }

    return 0;
}


forward OnLoginCheck(pid, input[]);
public OnLoginCheck(pid, input[]){
	new resultCount;
    if (!cache_get_result_count(resultCount)) {
		print("OnLoginCheck: MySQL result error.");
		return 1;
    }
	new hpass[MAX_PASSWORD_LENGTH];

	cache_get_value_index(0, 0, hpass);
	bcrypt_verify(pid, "OnPasswordCheck", input, hpass);	
	return 1;
}
forward OnRetrievePlayerData(playerid);
public OnRetrievePlayerData(playerid)
{
	// This function is called after the password verification is successful
	// and retrieves the player's data from the database.
	
	new resultCount;
	if (!cache_get_result_count(resultCount)) {
		print("OnRetrievePlayerData: MySQL result error.");
		return 1;
	}

	cache_get_value_index_int(0, 0, Players[playerid][Money]);
	cache_get_value_index_int(0, 1, Players[playerid][Level]);
	cache_get_value_index_int(0, 2, Players[playerid][Experience]);
	cache_get_value_index_int(0, 3, Players[playerid][Fraction]);

	printf("OnRetrievePlayerData: Player %d has money %d", playerid, Players[playerid][Money]);
	printf("OnRetrievePlayerData: Player %d has level %d", playerid, Players[playerid][Level]);
	printf("OnRetrievePlayerData: Player %d has experience %d", playerid, Players[playerid][Experience]);
	printf("OnRetrievePlayerData: Player %d has fraction %d", playerid, Players[playerid][Fraction]);

	Players[playerid][Capturing] = -1; // Reset capturing status
	if (!GivePlayerMoney(playerid, Players[playerid][Money])){
		printf("OnRetrievePlayerData: Failed to give money to player %d.", playerid);
	}
 	SendClientMessage(playerid, 0x00FF00AA, "Успешный вход!");
	gLoggedIn[playerid] = true;
	printf("Player %d logged in with name '%s'.", playerid, Players[playerid][Name]);
	TogglePlayerSpectating(playerid, false);
	SetSpawnInfo(playerid, 255, 0, 167.6, -109.2, 1.6, 272.7, 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	return 1;
}	
/*{
	new resultCount;
    if (!cache_get_result_count(resultCount)) {
		print("OnLoginCheck: MySQL result error.");
		return 1;
    }
	new hpass[MAX_PASSWORD_LENGTH];

	cache_get_value_index(0,0,hpass);	
	cache_get_value_index_int(0, 1, Players[playerid][Money]);
	cache_get_value_index_int(0, 2, Players[playerid][Level]);
	cache_get_value_index_int(0, 3, Players[playerid][Experience]);
	cache_get_value_index_int(0, 4, Players[playerid][Fraction]);
	printf("OnLoginCheck: Player %d has money %d", playerid, Players[playerid][Money]);
	printf("OnLoginCheck: Player %d has level %d", playerid, Players[playerid][Level]);
	printf("OnLoginCheck: Player %d has experience %d", playerid, Players[playerid][Experience]);
	printf("OnLoginCheck: Player %d has fraction %d", playerid, Players[playerid][Fraction]);
	Players[playerid][Capturing] = -1;
	bcrypt_verify(playerid, "OnPasswordVerify", pass, hpass);
	

    return 1;
}*/
forward OnPasswordCheck(playerid, bool:success);
public OnPasswordCheck(playerid, bool:success)
{
	
 	if (success){
		new query[128];
		mysql_format(dbHandle, query, sizeof(query), "SELECT money, level, experience, fraction FROM users WHERE name = '%e'", Players[playerid][Name]);
        mysql_tquery(dbHandle, query, "OnRetrievePlayerData", "d", playerid);			
 	} 
 	else{
 		SendClientMessage(playerid, 0xFF0000AA, "Неверный пароль.");
		ShowPlayerDialog(
            playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD,
            "{bfbbba}Авторизация", 
            "Добро пожаловать на {3c8cff}Grand World{FF0000}\n\nВведите свой пароль:\n", 
            "Ввод", "Выход"
        );
		printf("Player %d failed to log in with name '%s'.", playerid, Players[playerid][Name]);
 	}
}
forward OnPasswordHash(playerid);
public OnPasswordHash(playerid){
 	new dest[MAX_PASSWORD_LENGTH];
 	bcrypt_get_hash(dest, MAX_PASSWORD_LENGTH);
	new query[128];
	mysql_format(dbHandle, query, sizeof(query), "INSERT INTO users (name, password) VALUES ('%e','%e')", Players[playerid][Name], dest);
    mysql_tquery(dbHandle, query);
}


public OnGameModeInit(){

	SetGameModeText("Grand World v.0.1");
	ShowPlayerMarkers(PLAYER_MARKERS_MODE_STREAMED);
	ShowNameTags(1);
	EnableStuntBonusForAll(0);
	DisableInteriorEnterExits();
	SetNameTagDrawDistance(30.0);
	LimitPlayerMarkerRadius(70.0);
	SetWeather(14);
	SetWorldTime(11);
	SetGravity(0.01);
	//mysql_log(ALL); 
	dbHandle = mysql_connect("127.0.0.1", "root", "12345678", "samp");
	if (dbHandle == MYSQL_INVALID_HANDLE) {
		print("MySQL connection failed.");
		SendRconCommand("exit");
	}

	LoadPickupsFromDB();
	LoadTerritoriesFromDB();
	LoadHousesFromDB();
	


	//SetObjectsDefaultCameraCol(true);
	//UsePlayerPedAnims();
	ManualVehicleEngineAndLights();
	LimitGlobalChatRadius(200.0);
	
  	CreateDynamic3DTextLabel(!"Центральный рынок Los Santos\n/trade - Продать/Обменять",COLOR_WHITE,1129.0028,-1467.4628,15.7373,5.0);
    CreateDynamic3DTextLabel(!"Центральный рынок\n{9CCF00}Парковать {FFFFFF}авто на улице, запрещено!\nВо избежания нежелательных штрафов, используйте\nПодземный паркинг!",COLOR_WHITE,1113.5651,-1412.7012,13.5743,10.0);
	// SPECIAL
	total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/trains.txt");
	total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/pilots.txt");

   	// LAS VENTURAS
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/lv_law.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/lv_airport.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/lv_gen.txt");
    
    // SAN FIERRO
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/sf_law.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/sf_airport.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/sf_gen.txt");
    
    // LOS SANTOS
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/ls_law.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/ls_airport.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/ls_gen_inner.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/ls_gen_outer.txt");
    
    // OTHER AREAS
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/whetstone.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/bone.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/flint.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/tierra.txt");
    total_vehicles_from_files += LoadStaticVehiclesFromFile("vehicles/red_county.txt");

	J_AddStaticVehicleEx(462, -65.5372,180.3578,2.7914,151.5640,0, 0, 100);
	J_AddStaticVehicleEx(462, -62.7703,178.6715,2.7919,150.7218,0, 0, 100);
	J_AddStaticVehicleEx(462, -59.9803,177.0867,2.7924,149.4475,0, 0, 100);
	J_AddStaticVehicleEx(462, -57.3355,175.5419,2.7928,151.5186,0, 0, 100);
	J_AddStaticVehicleEx(462, -54.5681,173.8783,2.7931,150.4021,0, 0, 100);
	J_AddStaticVehicleEx(462, -51.9701,172.1236,2.7936,152.6581,0, 0, 100);
	J_AddStaticVehicleEx(462, -49.2016,170.6800,2.7939,152.4701,0, 0, 100);
	J_AddStaticVehicleEx(462, -46.4403,169.1648,2.7942,151.9280,0, 0, 100);
	J_AddStaticVehicleEx(462, -43.6433,167.5364,2.7944,153.2448,0, 0, 100);
	J_AddStaticVehicleEx(462, -40.9221,165.9719,2.7946,151.3950,0, 0, 100);
	J_AddStaticVehicleEx(462, -38.0611,164.4731,2.7947,152.4842,0, 0, 100);
	J_AddStaticVehicleEx(462, -43.5738,154.7764,2.7957,329.5657,0, 0, 100);
	J_AddStaticVehicleEx(462, -46.0988,156.2726,2.7958,331.8217,0, 0, 100);
	J_AddStaticVehicleEx(462, -48.7693,157.8368,2.7959,331.5321,0, 0, 100);
	J_AddStaticVehicleEx(462, -51.4755,159.3690,2.7960,330.2161,0, 0, 100);
	J_AddStaticVehicleEx(462, -54.2625,160.9640,2.7961,330.7792,0, 0, 100);
	J_AddStaticVehicleEx(462, -57.1369,162.7042,2.7963,330.2003,0, 0, 100);
	//Вокзал ЛС мопеды  17 мопедов
    J_AddStaticVehicleEx(462, 1560.4829,-2260.7219,13.3769,90.9198,0, 0, 100);
    J_AddStaticVehicleEx(462, 1560.5972,-2257.4260,13.3769,89.4121,0, 0, 100);
    J_AddStaticVehicleEx(462, 1560.6049,-2254.2712,13.3769,90.3647,0, 0, 100);
    J_AddStaticVehicleEx(462, 1560.7993,-2251.1021,13.3769,91.2798,0, 0, 100);
    J_AddStaticVehicleEx(462, 1560.8169,-2308.8674,13.3769,89.5037,0, 0, 100);
    J_AddStaticVehicleEx(462, 1560.7726,-2312.1182,13.3769,89.2460,0, 0, 100);
    J_AddStaticVehicleEx(462, 1560.8342,-2315.4333,13.3769,89.2932,0, 0, 100);
    J_AddStaticVehicleEx(462, 1560.7264,-2318.7490,13.3769,89.4496,0, 0, 100);

	J_AddStaticVehicleEx(462, 185.7913, -86.8502, 1.0242, 179.3730, 0, 0, 100);
	J_AddStaticVehicleEx(462, 187.2928, -86.8041, 1.0242, 179.3730, 0, 0, 100);
	J_AddStaticVehicleEx(462, 188.9126, -86.7857, 1.0242, 179.3730, 0, 0, 100);

	J_AddStaticVehicleEx(462, -85.2464, -313.4781, 0.9261, 89.0466, 0, 0, 200);
	J_AddStaticVehicleEx(462, -85.2508, -314.6550, 0.9261, 89.0466, 0, 0, 200);
	J_AddStaticVehicleEx(462, -85.2205, -315.8159, 0.9261, 89.0466, 0, 0, 200);

	J_AddStaticVehicleEx(462, 1348.5857,287.1873,19.1417,155.5508, 0, 0, 100);
	J_AddStaticVehicleEx(462, 1346.9385,287.8734,19.1410,148.9387, 0, 0, 100);
	J_AddStaticVehicleEx(462, 1345.3339,288.7947,19.1238,155.1355, 0, 0, 100);
	J_AddStaticVehicleEx(462, 1343.8882,289.4364,19.1251,149.5628, 0, 0, 100);
	J_AddStaticVehicleEx(462, 1342.1022,290.2208,19.1264,149.7179, 0, 0, 100);

    printf("Total vehicles from files: %d",total_vehicles_from_files);
	new hour, minute, second;
	gettime(hour, minute, second);
	SetWorldTime(hour);
	SetTimer("GrandTimer", 1000, true);
	return 1;
}
cmd:givecar(playerid, params[])
{
    new modelid;

    if (sscanf(params, "d", modelid))
        return SendClientMessage(playerid, 0xFF0000FF, "Использование: /givecar [modelid]");

    if (modelid < 400 || modelid > 611)
        return SendClientMessage(playerid, 0xFF0000FF, "Модель машины должна быть от 400 до 611.");

    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);

    new vehicleid = CreateVehicle(modelid, x + 2.0, y, z, a, -1, -1, 600);

    if (vehicleid != INVALID_VEHICLE_ID)
    {
        PutPlayerInVehicle(playerid, vehicleid, 0);
        SendClientMessage(playerid, 0x00FF00FF, "Машина выдана.");
    }
    else
    {
        SendClientMessage(playerid, 0xFF0000FF, "Не удалось создать транспорт.");
    }

    return 1;
}
cmd:givemoney(playerid, params[])
{
    new amount;
    if (sscanf(params, "d", amount))
        return SendClientMessage(playerid, 0xFF0000FF, "Использование: /givemoney [сумма]");

    if (amount <= 0)
        return SendClientMessage(playerid, 0xFF0000FF, "Сумма не может быть отрицательной.");

    Players[playerid][Money] += amount;
    GivePlayerMoney(playerid, amount);

    new query[128];
    mysql_format(dbHandle, query, sizeof(query),"UPDATE users SET money = %d WHERE name = '%e'", Players[playerid][Money], Players[playerid][Name]);
    mysql_tquery(dbHandle, query);

    new msg[64];
    format(msg, sizeof(msg), "Выдано $%d", amount);
    SendClientMessage(playerid, 0x00FF00FF, msg);

    return 1;
}

cmd:givegun(playerid, params[])
{
    new weaponid, ammo;

    if (sscanf(params, "dd", weaponid, ammo))
        return SendClientMessage(playerid, 0xFF0000FF, "Использование: /givegun [weaponid] [ammo]");

    if (weaponid < 1 || weaponid > 46)
        return SendClientMessage(playerid, 0xFF0000FF, "Неверный ID оружия (1–46).");

    if (ammo <= 0 || ammo > 1000)
        return SendClientMessage(playerid, 0xFF0000FF, "Укажите адекватное количество патронов (1–1000).");

    GivePlayerWeapon(playerid, weaponid, ammo);

    new msg[64];
    format(msg, sizeof(msg), "Выдано оружие %d с %d патронами.", weaponid, ammo);
    SendClientMessage(playerid, 0x00FF00FF, msg);

    return 1;
}
cmd:help(playerid, params[])
{
    SendClientMessage(playerid, 0xFFFFFF00, "Доступные команды:");
    SendClientMessage(playerid, 0xFFFFFF00, "/menu - открыть это меню");
    SendClientMessage(playerid, 0xFFFFFF00, "/givecar [modelid] - получить машину");
    SendClientMessage(playerid, 0xFFFFFF00, "/givegun [weaponid] [ammo] - получить оружие");
    SendClientMessage(playerid, 0xFFFFFF00, "/givemoney [сумма] - получить деньги");
	SendClientMessage(playerid, 0xFFFFFF00, "/pay [id] [сумма] - отправить деньги");
	SendClientMessage(playerid, 0xFFFFFF00, "/tp [x] [y] [z] - телепортироваться на координаты x y z");
	SendClientMessage(playerid, 0xFFFFFF00, "/jetpack - получить джетпак"); 
	SendClientMessage(playerid, 0xFFFFFF00, "/pos - показать текущие координаты");
	SendClientMessage(playerid, 0xFFFFFF00, "/fixcar - починить транспорт");
	SendClientMessage(playerid, 0xFFFFFF00, "/stats - показать свою статистику");
	SendClientMessage(playerid, 0xFFFFFF00, "/addpickup [posX] [posY] [posZ] [interior] [vw] [interiorX] [interiorY] [interiorZ] [model] - добавить пикап");	
	SendClientMessage(playerid, 0xFFFFFF00, "/removepickup [id] - удалить пикап по ID");


    return 1;
}
Float:GetDistanceBetweenCoords(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2)
{
    return floatsqroot(floatpower(x1 - x2, 2) + floatpower(y1 - y2, 2) + floatpower(z1 - z2, 2));
}
cmd:pay(playerid, params[])
{
    new targetid, amount;
    if(sscanf(params, "ui", targetid, amount)) return SendClientMessage(playerid, 0xFF0000FF, "Используй: /pay [id] [сумма]");
    if(!IsPlayerConnected(targetid)) return SendClientMessage(playerid, 0xFF0000FF, "Игрок не в сети.");
    if(targetid == playerid) return SendClientMessage(playerid, 0xFF0000FF, "Нельзя передать деньги себе.");
    if(amount <= 0) return SendClientMessage(playerid, 0xFF0000FF, "Сумма должна быть больше 0.");

    new Float:px, Float:py, Float:pz, Float:tx, Float:ty, Float:tz;
    GetPlayerPos(playerid, px, py, pz);
    GetPlayerPos(targetid, tx, ty, tz);
    
    if(GetDistanceBetweenCoords(px, py, pz, tx, ty, tz) > 5.0)
        return SendClientMessage(playerid, 0xFF0000FF, "Игрок слишком далеко.");

    if(GetPlayerMoney(playerid) < amount)
        return SendClientMessage(playerid, 0xFF0000FF, "У тебя недостаточно денег.");

    // Выдаём деньги
	Players[playerid][Money] -= amount;
    GivePlayerMoney(playerid, -amount);

	Players[targetid][Money] += amount;
    GivePlayerMoney(targetid, amount);

    // Получаем ники
    new senderName[MAX_NAME_LENGTH], receiverName[MAX_NAME_LENGTH];
	
    senderName = Players[playerid][Name];
	receiverName = Players[targetid][Name];

    // Обновляем БД
    new query[256];
    mysql_format(dbHandle, query, sizeof(query), 
	"START TRANSACTION; \
     UPDATE users SET money = money - %d WHERE name = '%e'; \
     UPDATE users SET money = money + %d WHERE name = '%e'; \
     COMMIT;",
         amount, senderName, amount, receiverName);
    mysql_tquery(dbHandle, query);

    // Уведомления
    new msg[128];
    format(msg, sizeof(msg), "Вы передали %d$ игроку %s.", amount, receiverName);
    SendClientMessage(playerid, 0x00FF00FF, msg);

    format(msg, sizeof(msg), "%s передал вам %d$.", senderName, amount);
    SendClientMessage(targetid, 0x00FF00FF, msg);

    return 1;
}
cmd:tp(playerid, params[])
{
    new Float:x, Float:y, Float:z;
    if(sscanf(params, "fff", x, y, z)) return SendClientMessage(playerid, 0xFF0000FF, "Используй: /tp [x] [y] [z]");

    SetPlayerPos(playerid, x, y, z);
	SetCameraBehindPlayer(playerid);
    SendClientMessage(playerid, 0x00FF00FF, "Телепорт выполнен.");
    return 1;
}
cmd:jetpack(playerid, params[])
{
	if (GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_USEJETPACK){
		ApplyAnimation(playerid, "PED", "WALK_DRUNK", 4.1, true, true, true, true, 1, 1);
		ClearAnimations(playerid);
		SendClientMessage(playerid, 0xFF0000FF, "Вы убрали джетпак.");
		return 1;
	}
    SetPlayerSpecialAction(playerid, SPECIAL_ACTION_USEJETPACK);
    SendClientMessage(playerid, 0x00FF00FF, "Вы получили джетпак.");
    return 1;
}
cmd:pos(playerid, params[])
{
    new Float:x, Float:y, Float:z, msg[128];
    GetPlayerPos(playerid, x, y, z);
    format(msg, sizeof(msg), "Твоя позиция: X: %.2f, Y: %.2f, Z: %.2f", x, y, z);
    SendClientMessage(playerid, 0xFFFF00FF, msg);
    return 1;
}
cmd:fixcar(playerid, params[])
{
    new vehicleid = GetPlayerVehicleID(playerid);

    if(vehicleid == 0)
        return SendClientMessage(playerid, 0xFF0000FF, "Вы не находитесь в транспорте.");

    RepairVehicle(vehicleid); // чинит машину
    SendClientMessage(playerid, 0x00FF00FF, "Транспорт починен.");
    return 1;
}
cmd:stats(playerid, params[])
{
	new msg[256];
	format(msg, sizeof(msg), "Статистика игрока %s:\nДеньги: $%d\nУровень: %d\nОпыт: %d\nФракция: %d\nНомер захвачиваемой территории: %d",
							  Players[playerid][Name],
							  Players[playerid][Money],
							  Players[playerid][Level],
							  Players[playerid][Experience],
							  Players[playerid][Fraction],
							  Players[playerid][Capturing]);
	SendClientMessage(playerid, 0x00FF00FF, msg);
	return 1;
}
cmd:changeinterior(playerid, params[])
{
	new interiorid;
	if (sscanf(params, "d", interiorid))
		return SendClientMessage(playerid, 0xFF0000FF, "Использование: /interior [id]");

	if (interiorid < 0 || interiorid > 19)
		return SendClientMessage(playerid, 0xFF0000FF, "Неверный ID интерьера (0-19).");

	SetPlayerInterior(playerid, interiorid);
	SendClientMessage(playerid, 0x00FF00FF, "Интерьер изменён.");
	return 1;
}
cmd:addpickup(playerid, params[]){
	if (g_PickupCount >= MAX_PICKUPS)
    {
        SendClientMessage(playerid, 0xFF0000FF, "Максимум пикапов достигнут.");
        return 0;
    }
	new Float:posx, posy, posz;
    new interior, vw, m;
    new Float:intX, intY, intZ;

    if (sscanf(params, "fffiifffi", posx, posy, posz, interior, vw, intX, intY, intZ, m))
    {
        SendClientMessage(playerid, 0xFF0000FF, "Использование: /addpickup [posX] [posY] [posZ] [interior] [vw] [interiorX] [interiorY] [interiorZ] [model]");
        return 0;
    }

    new idx = g_PickupCount;

    new pickupid = CreateDynamicPickup(m, 2, posx, posy, posz);
    if (pickupid == INVALID_PICKUP_ID)
    {
        SendClientMessage(playerid, 0xFF0000FF, "Ошибка создания пикапа!");
        return 0;
    }

    Pickups[idx][pickupId] = pickupid;
    Pickups[idx][posX] = posx;
    Pickups[idx][posY] = posy;
    Pickups[idx][posZ] = posz;
    Pickups[idx][pInterior] = interior;
    Pickups[idx][virtualWorld] = vw;
    Pickups[idx][interiorX] = intX;
    Pickups[idx][interiorY] = intY;
    Pickups[idx][interiorZ] = intZ;
	Pickups[idx][model] = m;
	
    g_PickupCount++;

    // Сохраняем пикап в БД
    SavePickupToDB(pickupid, posx, posx, posz, interior, vw, intX, intY, intZ, m);

    SendClientMessage(playerid, 0x00FF00FF, "Пикап (%d) успешно создан и сохранён!", idx);
    printf("Created pickup with ID %d at %.2f, %.2f, %.2f", pickupid, posx, posy, posz);

    return 1;
}
cmd:removepickup(playerid, params[])
{
	new pickupid;
	if (sscanf(params, "d", pickupid))
	{
		SendClientMessage(playerid, 0xFF0000FF, "Использование: /removepickup [pickupid]");
		return 0;
	}

	if (pickupid < 0 || pickupid >= g_PickupCount)
	{
		SendClientMessage(playerid, 0xFF0000FF, "Неверный ID пикапа.");
		return 0;
	}

	// Удаляем пикап из мира
	DestroyDynamicPickup(Pickups[pickupid][pickupId]);

	// Удаляем из массива
	Pickups[pickupid][pickupId] = INVALID_PICKUP_ID;
	g_PickupCount--;
	// Удаляем из БД
	new query[128];
	mysql_format(dbHandle, query, sizeof(query), "DELETE FROM pickups WHERE pickupid = %d", pickupid);
	mysql_tquery(dbHandle, query);

	SendClientMessage(playerid, 0x00FF00FF, "Пикап (%d) успешно удалён!", pickupid);
	printf("Removed pickup with ID %d", pickupid);

	return 1;
}
cmd:listpickups(playerid, params[])
{
	if (g_PickupCount == 0)
	{
		SendClientMessage(playerid, 0xFF0000FF, "Нет доступных пикапов.");
		return 1;
	}

	new msg[256];
	format(msg, sizeof(msg), "Список пикапов (%d):", g_PickupCount);
	SendClientMessage(playerid, 0x00FF00FF, msg);

	for (new i = 0; i < g_PickupCount; i++)
	{
		if (Pickups[i][pickupId] == INVALID_PICKUP_ID) continue;

		format(msg, sizeof(msg), "ID: %d | Pos: (%.2f, %.2f, %.2f) | Int: %d | VW: %d | Model: %d",
			   i, Pickups[i][posX], Pickups[i][posY], Pickups[i][posZ],
			   Pickups[i][pInterior], Pickups[i][virtualWorld], Pickups[i][model]);
		SendClientMessage(playerid, 0x00FF00FF, msg);
	}

	return 1;
}
cmd:reloadpickups(playerid, params[])
{
	for (new i = 0; i < g_PickupCount; i++)
	{
		if (Pickups[i][pickupId] != INVALID_PICKUP_ID)
		{
			DestroyDynamicPickup(Pickups[i][pickupId]);
			Pickups[i][pickupId] = INVALID_PICKUP_ID;
		}
	}
	LoadPickupsFromDB();

	return 1;
}
cmd:reloadterritories(playerid, params[])
{
	LoadTerritoriesFromDB();
	return 1;
}
cmd:reloadhouses(playerid, params[])
{

	LoadHousesFromDB();
	return 1;
}
cmd:capture(playerid, params[])
{

	new tid = GetTerritoryAtPlayer(playerid);
	if (tid == -1) return SendClientMessage(playerid, -1, "Вы не на территории.");

	if (Territories[tid][owner] == Players[playerid][Fraction])
		return SendClientMessage(playerid, -1, "Вы уже владеете этой территорией.");
	
	if (Players[playerid][Capturing] != -1)
		return SendClientMessage(playerid, -1, "Вы уже участвуете в захвате.");

	Players[playerid][Capturing] = tid;	
	//AddPlayerToCapture(tid, playerid);

	if (!TerritoryCaptureTimers[tid])
	{

		TerritoryCaptureTimers[tid] = SetTimerEx("FinishTerritoryCapture", CAPTURE_TIME * 1000, false, "ii", tid, playerid);
		GangZoneFlashForAll(Territories[tid][zone], GetFractionColor(Players[playerid][Fraction]));
		SendMessageToFraction(Players[playerid][Fraction], "[Захват] Ваша фракция начала захват территории!");
	}
	return 1;
}
cmd:changevirtualworld(playerid, params[])
{
	new worldid;
	if (sscanf(params, "d", worldid))
		return SendClientMessage(playerid, 0xFF0000FF, "Использование: /virtualworld [id]");

	if (worldid < 0 || worldid > 65535)
		return SendClientMessage(playerid, 0xFF0000FF, "Неверный ID виртуального мира (0-65535).");

	SetPlayerVirtualWorld(playerid, worldid);
	SendClientMessage(playerid, 0x00FF00FF, "Виртуальный мир изменён.");
	return 1;
}
public J_SetPlayerPosFreeze(playerid, Float:X, Float:Y, Float:Z)
{
	SetPlayerPos(playerid, Float:X,Float:Y,Float:Z);
	TogglePlayerControllable(playerid, false);
	SetTimerEx("UnFreeze",GetPlayerPing(playerid)*2*(FREEZE_TIME), 0, "d", playerid);
	return 1;
} 
public J_SetPlayerFacingAngle(playerid, Float:angle)
{
    SetPlayerFacingAngle(playerid, angle);
    SetCameraBehindPlayer(playerid);
    return true;
}
J_AddStaticVehicleEx(model, Float:x, Float:y, Float:z, Float:a, color_1, color_2, spawntime = 300, interior = 0, world = 0)
{
	new carid = AddStaticVehicleEx(model, x, y, z, a, color_1, color_2, spawntime);
	LinkVehicleToInterior(carid, interior);
	SetVehicleVirtualWorld(carid, world);
	return carid;
}
public UnFreeze(playerid)
{
	TogglePlayerControllable(playerid, true);
	return 1;
}
forward GrandTimer();
public GrandTimer()
{
	new tickcount = GetTickCount();
	new year, month, day, hour, minute, second;
	getdate(year, month, day);
	gettime(hour, minute, second);
	
	if (minute == 0 && second >= 11 && second <= 16) PAYDAY = 0;
	if (minute == 0 && second >= 0 && second <= 10){
		PAYDAY = 1;
		SetWorldTime(hour);	
	} 

	return 1;
}