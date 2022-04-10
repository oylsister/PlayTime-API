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

	RegConsoleCmd("playtime", Command_PlayTime);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("PlayTime_GetClientLastLogin", Native_GetClientLastLogin);
	CreateNative("PlayTime_GetClientTotalPlayTime", Native_GetClientTotalPlayTime);
	CreateNative("PlayTime_GetClientTodayPlayTime", Native_GetClientTodayPlayTime);

	return APLRes_Success;
}

public Action Command_PlayTime(int client, int args)
{
	Menu menu = new Menu(PlayTimeMenu_Handler);
	menu.SetTitle("Play Time Stats");

	char thename[128];
	Format(thename, sizeof(thename), "Name: %N", client);
	menu.AddItem("name", thename);

	char lasttime[64];
	char lastlogin[128];
	FormatTime(lasttime, sizeof(lasttime), "%D %R", iLastLogin[client]);
	Format(lastlogin, sizeof(lastlogin), "Last Login: %s", lasttime);

	char todaylogin[128];
	char todaytime[64];
	GetTimeFromStamp(todaytime, sizeof(todaytime), iTodayPlayTime[client]);
	Format(todaylogin, sizeof(todaylogin), "Today Play Time: %s", todaytime);

	char totalplay[128];
	char totaltime[64];
	GetTimeFromStamp(totaltime, sizeof(totaltime), iTotalPlayTime[client]);
	Format(totalplay, sizeof(totalplay), "Total Play Time: %s", totaltime);

	menu.AddItem("lastlogin", lastlogin);
	menu.AddItem("todaylogin", todaylogin);
	menu.AddItem("totalplay", totalplay);

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int PlayTimeMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_DrawItem:
		{
			for(int i = 0; i < 3; i++)
			{
				if(i == param2)
					return ITEMDRAW_RAWLINE;
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

public void OnClientAuthorized(int client)
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

	// Query for creating table
	char sQuery[255];
	Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS playerplaytime (steamid VARCHAR(64) UNIQUE, last_connect INT(12), total_playtime INT(12), today_playtime INT(12));");
	g_hDatabase.Query(SQLErrorCheckCallback, sQuery);
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

		char steamid[128];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

		char sQuery[255];
		Format(sQuery, sizeof(sQuery), "INSERT INTO playerplaytime (steamid, last_connect, total_playtime, today_playtime) VALUES ('%s', %d, %d, %d);", steamid, iLastLogin[client], iTotalPlayTime[client], iTodayPlayTime[client]);
		g_hDatabase.Query(SQLErrorCheckCallback, sQuery);

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

stock void GetTimeFromStamp(char[] buffer, int maxlength, int timestamp)
{
	if (timestamp > 86400)
	{
		int days = timestamp / 86400 % 365;
		int hours = (timestamp / 3600) % 24;
		if (hours > 0)
		{
			FormatEx(buffer, maxlength, "%d Days %d Hours", days, hours);
		}
		else
		{
			FormatEx(buffer, maxlength, "%d Days", days);
		}
		return;
	}
	else
	{
		int Hours = (timestamp / 3600);
		int Mins = (timestamp / 60) % 60;

		if (Hours > 0)
		{
			FormatEx(buffer, maxlength, "%02d Hours %02d Minutes", Hours, Mins);
		}
		else
		{
			FormatEx(buffer, maxlength, "%02d Minutes", Mins);
		}
	}
}