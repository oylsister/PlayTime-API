#include <sourcemod>
#include <playtime>

int iLastLogin[MAXPLAYERS+1];
int iTotalPlayTime[MAXPLAYERS+1];
int iTodayPlayTime[MAXPLAYERS+1];

Handle hTimerUpdate[MAXPLAYERS+1];

Database g_hDatabase;

public Plugin myinfo =
{
	name = "Play-Time API",
	author = "Oylsister",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	// Connect To Database
	Database.Connect(Database_Connect, "playtime");

	// Query for creating table
	char sQuery[255];
	Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS playerplaytime (steamid VARCHAR(20) UNIQUE, last_connect INT(12), total_playtime INT(12), today_playtime INT(12));");
	g_hDatabase.Query(SQLErrorCheckCallback, sQuery);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("PlayTime_GetClientLastLogin", Native_GetClientLastLogin);
	CreateNative("PlayTime_GetClientTotalPlayTime", Native_GetClientTotalPlayTime);
	CreateNative("PlayTime_GetClientTodayPlayTime", Native_GetClientTodayPlayTime);
}

public void OnClientConnected(int client)
{
	char sQuery[256];

	char steamid[128];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	QueryLastTimePlayerData(client, steamid);

	hTimerUpdate[client] = CreateTimer(10.0, UpdatePlayTimer, client, TIMER_REPEAT);

	int iNewLogin = GetTime();

	char newtime[32], lasttime[32];
	FormatTime(newtime, sizeof(newtime), "%d", iNewLogin);
	FormatTime(lasttime, sizeof(lasttime), "%d", iLastLogin[client]);

	int newtimelogin = StringToInt(newtime);
	int lasttimelogin = StringToInt(lasttime);

	if(newtimelogin - lasttimelogin > 0)
	{
		iLastLogin[client] = GetTime();
		iTodayPlayTime[client] = 0;
	}

	Format(sQuery, sizeof(sQuery), "UPDATE `playerplaytime` SET `last_connect` = %i, `today_playtime` = %i WHERE `steamid` = '%s'", iLastLogin[client], iTodayPlayTime[client], steamid);
	g_hDatabase.Query(SQLErrorCheckCallback, sQuery);
}

void QueryLastTimePlayerData(int client, const char[] steamid)
{
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "SELECT `last_connect`,`total_playtime`,`today_playtime` FROM `playerplaytime` WHERE `steamid` = '%s';", steamid);
	g_hDatabase.Query(SQLGetClientData, sQuery, client);
}

public void OnClientDisconnect(int client)
{
	if(hTimerUpdate[client] != INVALID_HANDLE)
	{
		KillTimer(hTimerUpdate[client]);
	}

	hTimerUpdate[client] = INVALID_HANDLE;

	char steamid[128];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	iLastLogin[client] = GetTime();

	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "UPDATE `playerplaytime` SET `last_connect` = %i, `total_playtime` = %i, `today_playtime` = %i WHERE `steamid` = '%s'", iLastLogin[client], iTotalPlayTime, iTodayPlayTime, steamid);
	g_hDatabase.Query(SQLErrorCheckCallback, sQuery);
}

public Action UpdatePlayTimer(Handle timer, any client)
{
	if(!IsClientInGame(client))
		return Plugin_Handled;

	iTodayPlayTime[client] += 10;
	iTotalPlayTime[client] += 10;

	return Plugin_Continue;
}

// Query Stuff
public void Database_Connect(Database db, const char[] error, any data)
{
	if(db == null)
	{
		LogError("Database_Connect returned invalid Database Handle");
		return;
	}
	g_hDatabase = db;
}

public void SQLErrorCheckCallback(Database db, DBResultSet results, const char[] error, any client)
{
	if(db == null)
	{
		LogError("Query returned invalid Database Handle");
		return;
	}
}

public void SQLGetClientData(Database db, DBResultSet results, const char[] error, any client)
{
	if(db == null)
	{
		LogError("Query returned invalid Database Handle");
		return;
	}

	if(results == null)
	{
		LogError("No result!");
		return;
	}

	results.FetchRow();

	if(results.RowCount == 0)
	{
		iLastLogin[client] = GetTime();
		iTotalPlayTime[client] = 0;
		iTodayPlayTime[client] = 0;
		return;
	}

	iLastLogin[client] = results.FetchInt(0);
	iTotalPlayTime[client] = results.FetchInt(1);
	iTodayPlayTime[client] = results.FetchInt(2);
	return;
}

// Native Stuff
public int Native_GetClientLastLogin(Handle hPlugin, int numParams)
{
	return LastPlayerLogin(GetNativeCell(1));
}

public int Native_GetClientTotalPlayTime(Handle hPlugin, int numParams)
{
	return TotalPlayerPlayTime(GetNativeCell(1));
}

public int Native_GetClientTodayPlayTime(Handle hPlugin, int numParams)
{
	return TodayPlayerPlayTime(GetNativeCell(1));
}

stock int LastPlayerLogin(int client)
{
	if(!IsClientInGame(client))
		return -1;

	return iLastLogin[client];
}

stock int TotalPlayerPlayTime(int client)
{
	if(!IsClientInGame(client))
		return -1;

	return iTotalPlayTime[client];
}

stock int TodayPlayerPlayTime(int client)
{
	if(!IsClientInGame(client))
		return -1;

	return iTodayPlayTime[client];
}