#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#pragma newdecls required

#define MAX_RICOCHETS 10

public Plugin myinfo = 
{
	name = "",
	author = "NoTiCE",
	description = "",
	version = "",
	url = ""
};

enum
{
	Type_None,
	Type_Rocket,
	Type_Arrow
};

KeyValues g_Config = null;
StringMap g_Cookies = null;
Handle g_hIncrementDeflect = null;

public void OnPluginStart()
{
	LoadTranslations("ricochet.phrases");
	
	char szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/ricochet.txt");
	if(!FileExists(szBuffer))
		SetFailState("Config file '%s' is not exists", szBuffer);
	
	g_Config = new KeyValues("config");
	if(!g_Config.ImportFromFile(szBuffer))
		SetFailState("Error reading config file '%s'. Check syntax", szBuffer);
	
	g_Cookies = new StringMap();
	
	if(g_Config.GotoFirstSubKey())
	{
		char szProjectie[64];
		char szType[64];
		
		do
		{
			if(!g_Config.GetSectionName(szProjectie, sizeof(szProjectie)))
				continue;
			
			Handle cookie = RegClientCookie(szProjectie, "Ricochet plugin cookie", CookieAccess_Private);
			g_Cookies.SetValue(szProjectie, cookie);
			
			g_Config.GetString("type", szType, sizeof(szType));
			if(StrEqual(szType, "rocket", false))
				g_Config.SetNum("type_idx", Type_Rocket);
			else if(StrEqual(szType, "arrow", false))
				g_Config.SetNum("type_idx", Type_Arrow);
			else
				g_Config.SetNum("type_idx", Type_None);
		}
		while(g_Config.GotoNextKey());
	}
	
	Handle hGameConf = LoadGameConfigFile("tf2.ricochet");
	if(hGameConf == null)
		SetFailState("Could not locate tf2.ricochet.txt in gamedata folder");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFProjectile_Arrow::IncrementDeflect");
	g_hIncrementDeflect = EndPrepSDKCall();
	if(g_hIncrementDeflect == null)
		SetFailState("Could not initialize call for CTFProjectile_Arrow::IncrementDeflect");
	
	hGameConf.Close();
	
	RegAdminCmd("sm_ricochet", Cmd_Ricochet, ADMFLAG_RESERVATION);
}

int GetRicochetCount(int client, const char[] szProjectile)
{
	if(!AreClientCookiesCached(client))
		return 0;
	
	Handle cookie = null;
	if(g_Cookies.GetValue(szProjectile, cookie))
	{
		char szBuffer[16];
		GetClientCookie(client, cookie, szBuffer, sizeof(szBuffer));
		return (szBuffer[0] == '\0') ? 0 : StringToInt(szBuffer);
	}
	
	return 0;
}

bool SetRicochetCount(int client, const char[] szProjectile, int count)
{
	if(!AreClientCookiesCached(client))
		return false;
	
	Handle cookie = null;
	if(g_Cookies.GetValue(szProjectile, cookie))
	{
		char szBuffer[16];
		IntToString(count, szBuffer, sizeof(szBuffer));
		SetClientCookie(client, cookie, szBuffer);
		return true;
	}
	
	return false;
}

public Action Cmd_Ricochet(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] Ingame only");
		return Plugin_Handled;
	}
	
	DisplayMainMenu(client);
	return Plugin_Handled;
}

void DisplayMainMenu(int client)
{
	Menu menu = new Menu(MainMenuHandler, MENU_ACTIONS_DEFAULT | MenuAction_Display);
	
	g_Config.Rewind();
	if(g_Config.GotoFirstSubKey())
	{
		char szInfo[128], szDisplay[128];
		
		do
		{
			g_Config.GetSectionName(szInfo, sizeof(szInfo));
			g_Config.GetString("name", szDisplay, sizeof(szDisplay));
			Format(szDisplay, sizeof(szDisplay), "%s [%d]", szDisplay, GetRicochetCount(client, szInfo));
			menu.AddItem(szInfo, szDisplay);
		}
		while(g_Config.GotoNextKey());
	}
	
	if(menu.ItemCount)
	{
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		menu.Close();
		PrintToChat(client, "%t", "Menu Error");
	}
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	switch(action)
	{
		case MenuAction_End:
			menu.Close();
		
		case MenuAction_Display:
		{
			char[] szTitle = new char[256];
			Format(szTitle, 256, "%T", "Main Admin Menu Title", client);
			Panel panel = view_as<Panel>(param);
			panel.SetTitle(szTitle);
		}
		
		case MenuAction_Select:
		{
			char szInfo[128];
			menu.GetItem(param, szInfo, sizeof(szInfo));
			DisplayRicochetMenu(client, szInfo);
		}
	}
}

void DisplayRicochetMenu(int client, const char[] szProjectile)
{
	Menu menu = new Menu(RicochetMenuHandler, MENU_ACTIONS_DEFAULT | MenuAction_Display | MenuAction_DisplayItem);
	
	for (int i = 0; i <= MAX_RICOCHETS; i++)
		menu.AddItem(szProjectile, "");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int RicochetMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	switch(action)
	{
		case MenuAction_End:
			menu.Close();
		
		case MenuAction_Cancel:
		{
			if(param == MenuCancel_ExitBack)
				DisplayMainMenu(client);
		}
		
		case MenuAction_Display:
		{
			char szBuffer[256], szInfo[128];
			menu.GetItem(0, szInfo, sizeof(szInfo));
			if(GetProjectileName(szInfo, szBuffer, sizeof(szBuffer)))
			{
				Format(szBuffer, sizeof(szBuffer), "%T", "Ricochet Menu Title", client, szBuffer, GetRicochetCount(client, szInfo));
				Panel panel = view_as<Panel>(param);
				panel.SetTitle(szBuffer);
			}
		}
		
		case MenuAction_DisplayItem:
		{
			char szDisplay[128];
			Format(szDisplay, sizeof(szDisplay), "%T", "Ricochet Menu Item", client, param);
			return RedrawMenuItem(szDisplay);
		}
		
		case MenuAction_Select:
		{
			char szInfo[128];
			menu.GetItem(param, szInfo, sizeof(szInfo));
			SetRicochetCount(client, szInfo, param);
			DisplayMainMenu(client);
		}
	}
	
	return 0;
}

bool GetProjectileName(const char[] szProjectile, char[] szBuffer, int maxlen)
{
	g_Config.Rewind();
	if(g_Config.JumpToKey(szProjectile))
	{
		g_Config.GetString("name", szBuffer, maxlen);
		return true;
	}
	
	return false;
}

stock bool HasAccess(int client)
{
	return view_as<bool>(GetUserFlagBits(client) & (ADMFLAG_RESERVATION | ADMFLAG_ROOT));
}

stock bool IsClientIndex(int idx)
{
	return (1 <= idx <= MaxClients);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	g_Config.Rewind();
	if(g_Config.JumpToKey(classname))
		SDKHook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
}

public void Hook_SpawnPost(int entity)
{
	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	g_Config.Rewind();
	if(g_Config.JumpToKey(classname))
	{
		if(GetEntProp(entity, Prop_Data, "m_iHammerID") > 0)
			return;
		
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if(owner > MaxClients && HasEntProp(owner, Prop_Send, "m_hBuilder"))
			owner = GetEntPropEnt(owner, Prop_Send, "m_hBuilder");
		
		if(owner == -1 || !HasAccess(owner))
			return;
		
		int bounces = GetRicochetCount(owner, classname);
		if(bounces <= 0)
			return;
		
		SetEntProp(entity, Prop_Data, "m_iHammerID", bounces);
		
		switch(g_Config.GetNum("type_idx", Type_None))
		{
			case Type_Rocket:	SDKHook(entity, SDKHook_StartTouch, Hook_StartTouchRocket);
			case Type_Arrow:	SDKHook(entity, SDKHook_StartTouch, Hook_StartTouchArrow);
			case Type_None:		SDKHook(entity, SDKHook_StartTouch, Hook_StartTouch);
		}
	}
}

public Action Hook_StartTouchArrow(int entity, int other)
{
	if(IsClientIndex(other))
		return Plugin_Continue;
	
	int bounces = GetEntProp(entity, Prop_Data, "m_iHammerID");
	if(bounces <= 0)
		return Plugin_Continue;
	
	char szClassName[32];
	if(GetEntityClassname(other, szClassName, sizeof(szClassName)) && strncmp(szClassName, "obj_", 4, false) == 0)
		return Plugin_Continue;
	
	SDKCall(g_hIncrementDeflect, entity);
	int deflected = GetEntProp(entity, Prop_Send, "m_iDeflected");
	if (deflected > 0)
		SetEntProp(entity, Prop_Send, "m_iDeflected", deflected - 1);
	
	SDKHook(entity, SDKHook_Touch, Hook_Touch);
	return Plugin_Handled;
}

public Action Hook_StartTouch(int entity, int other)
{
	if(IsClientIndex(other))
		return Plugin_Continue;
	
	int bounces = GetEntProp(entity, Prop_Data, "m_iHammerID");
	if(bounces <= 0)
		return Plugin_Continue;
	
	char szClassName[32];
	if(GetEntityClassname(other, szClassName, sizeof(szClassName)) && strncmp(szClassName, "obj_", 4, false) == 0)
		return Plugin_Continue;
	
	SDKHook(entity, SDKHook_Touch, Hook_Touch);
	return Plugin_Handled;
}

public Action Hook_StartTouchRocket(int entity, int other)
{
	if(IsClientIndex(other))
		return Plugin_Continue;
	
	int bounces = GetEntProp(entity, Prop_Data, "m_iHammerID");
	if(bounces <= 0)
		return Plugin_Continue;
	
	char szClassName[32];
	if(GetEntityClassname(other, szClassName, sizeof(szClassName)) && strncmp(szClassName, "obj_", 4, false) == 0)
		return Plugin_Continue;
	
	if(IsRocketNearClient(entity))
		return Plugin_Continue;
	
	SDKHook(entity, SDKHook_Touch, Hook_Touch);
	return Plugin_Handled;
}

public Action Hook_Touch(int entity, int other)
{
	float vOrigin[3], vAngles[3], vVelocity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vVelocity);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelf, entity);
	if(!TR_DidHit(trace))
	{
		trace.Close();
		return Plugin_Continue;
	}
	
	float vNormal[3];
	TR_GetPlaneNormal(trace, vNormal);
	trace.Close();
	
	float dotProduct = GetVectorDotProduct(vNormal, vVelocity);
	
	ScaleVector(vNormal, dotProduct);
	ScaleVector(vNormal, 2.0);
	
	float vBounceVec[3];
	SubtractVectors(vVelocity, vNormal, vBounceVec);
	
	float vNewAngles[3];
	GetVectorAngles(vBounceVec, vNewAngles);
	
	TeleportEntity(entity, NULL_VECTOR, vNewAngles, vBounceVec);

	int bounces = GetEntProp(entity, Prop_Data, "m_iHammerID");
	SetEntProp(entity, Prop_Data, "m_iHammerID", bounces - 1);
	
	SDKUnhook(entity, SDKHook_Touch, Hook_Touch);
	return Plugin_Handled;
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return (entity != data);
}

stock bool IsRocketNearClient(int rocket)
{
	float vOrigin[3], vClientOrigin[3];
	GetEntPropVector(rocket, Prop_Data, "m_vecOrigin", vOrigin);
	for (int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client) || !IsPlayerAlive(client))
			continue;
		
		GetClientAbsOrigin(client, vClientOrigin);
		if(GetVectorDistance(vOrigin, vClientOrigin) < 83.00)
			return true;
	}
	
	char szEntitys[][] = {
		"obj_sentrygun",
		"obj_dispenser",
		"obj_teleporter"
	};
	
	for (int i = 0, iEnt; i < sizeof(szEntitys); i++)
	{
		iEnt = -1;
		while((iEnt = FindEntityByClassname(iEnt, szEntitys[i])) != -1)
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vClientOrigin);
			if (GetVectorDistance(vOrigin, vClientOrigin) < 83.00)
				return true;
		}
	}
	return false;
}