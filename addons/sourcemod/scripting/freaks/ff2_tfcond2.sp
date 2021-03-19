#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <ff2_ams>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define MAJOR_REVISION "1"
#define MINOR_REVISION "1"
#define PATCH_REVISION "1"

#if !defined PATCH_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...PATCH_REVISION
#endif

new bool:bEnableSuperDuperJump[MAXPLAYERS+1];
new bool:HasTFCondTweak[MAXPLAYERS+1];
new bool:TFCond_TriggerAMS[MAXPLAYERS+1];
new String:TFCondTweakConditions[MAXPLAYERS+1][768];
new String:SpecialTFCondTweakConditions[MAXPLAYERS+1][768];
new Handle:chargeHUD;

new buttonmode[MAXPLAYERS+1];
new Float:dotCost[MAXPLAYERS+1], Float:minCost[MAXPLAYERS+1], Float:curRage[MAXPLAYERS+1];

public Plugin:myinfo = {
    name = "Freak Fortress 2: TFConditions",
    author = "SHADoW NiNE TR3S",
    version = PLUGIN_VERSION,
};

public OnPluginStart2()
{
	HookEvent("arena_round_start", Event_ArenaRoundStart);
	HookEvent("arena_win_panel", Event_ArenaWinPanel);
	chargeHUD=CreateHudSynchronizer();
	if(FF2_GetRoundState()==1)
	{
		PrepareAbilities();
	}
}

public Action:FF2_OnAbility2(boss, const String:plugin_name[], const String:ability_name[], status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....

	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name, "rage_tfcondition"))
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			TFCond_TriggerAMS[client]=false;
		}
		
		if(!TFCond_TriggerAMS[client])
			TFC_Invoke(client);
	}
	if(!strcmp(ability_name, "charge_tfcondition"))
	{
		new slot=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 0);
		Charge_TFCondition(ability_name, boss, slot, status, client);
	}
	return Plugin_Continue;
}

public Action:Event_ArenaRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
		
	PrepareAbilities();
}

public PrepareAbilities()
{
	for(new client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client))
			continue;
		TFCond_TriggerAMS[client]=false;
		HasTFCondTweak[client]=false;
		bEnableSuperDuperJump[client]=false;
	}
	
	decl bossClient;
	for(new bossIdx=0;(bossClient=GetClientOfUserId(FF2_GetBossUserId(bossIdx)))>0;bossIdx++)
	{
		if(!IsValidClient(bossClient))
			continue;
			
			
		// AMS-exclusive version
		decl String:condName[96], String:condShort[96];
		for(new abilityNum=0; abilityNum<=9;abilityNum++)
		{
			Format(condName, sizeof(condName), "ams_tfcond_%i", abilityNum);
			if(FF2_HasAbility(bossIdx, this_plugin_name, condName))
			{
				Format(condShort, sizeof(condShort), "TC%i", abilityNum);
				AMS_InitSubability(bossIdx, bossClient, this_plugin_name, condName, condShort);
			}
		}
	
		// Legacy			
		if(FF2_HasAbility(bossIdx, this_plugin_name, "rage_tfcondition"))
		{
			if(AMS_IsSubabilityReady(bossIdx, this_plugin_name, "rage_tfcondition"))
			{
				TFCond_TriggerAMS[bossClient] = true;
				AMS_InitSubability(bossIdx, bossClient, this_plugin_name, "rage_tfcondition", "TFC");
			}
		}
			
		if(FF2_HasAbility(bossIdx, this_plugin_name, "tfconditions"))
		{
			HasTFCondTweak[bossClient]=true;
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, "tfconditions", 1, TFCondTweakConditions[bossClient], sizeof(TFCondTweakConditions[])); // boss TFConds		
			if(TFCondTweakConditions[bossClient][0]!='\0')
			{
				SetCondition(bossClient, TFCondTweakConditions[bossClient]);
			}
			for(new targetIdx;targetIdx<=MaxClients;targetIdx++)
			{
				if(!IsValidClient(targetIdx))
					continue;
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, "tfconditions", 2, TFCondTweakConditions[targetIdx], sizeof(TFCondTweakConditions[])); // client TFConds		
				if(TFCondTweakConditions[targetIdx][0]!='\0')
				{
					HasTFCondTweak[targetIdx]=true;
					SetCondition(targetIdx, TFCondTweakConditions[targetIdx]);
				}
			
			}
		}	
		if(FF2_HasAbility(bossIdx, this_plugin_name, "special_tfcondition"))
		{	
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, "special_tfcondition", 1, SpecialTFCondTweakConditions[bossClient], sizeof(SpecialTFCondTweakConditions[])); // boss TFConds		
			minCost[bossClient]=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, "special_tfcondition", 2);
			dotCost[bossClient]=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, "special_tfcondition", 3);
			buttonmode[bossClient]=FF2_GetAbilityArgument(bossIdx, this_plugin_name, "special_tfcondition", 4);
			SDKHook(bossClient, SDKHook_PreThink, PersistentTFCondition_PreThink);
		}
	}
}

public Action:Event_ArenaWinPanel(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if(IsValidClient(client))
		{
			TFCond_TriggerAMS[client]=false;
			bEnableSuperDuperJump[client]=false;
			if(IsPlayerAlive(client) && HasTFCondTweak[client])
			{
				HasTFCondTweak[client]=false;
				if(TFCondTweakConditions[client][0]!='\0')
				{
					RemoveCondition(client, TFCondTweakConditions[client]);
				}
			}
		}
	}
}

public PersistentTFCondition_PreThink(client)
{
	if(FF2_GetRoundState()!=1 || !IsPlayerAlive(client) || !IsValidClient(client, false)) // Round ended or boss was defeated?
	{
		SDKUnhook(client, SDKHook_PreThink, PersistentTFCondition_PreThink);
		return;
	}
	
	new bossIdx=FF2_GetBossIndex(client);
	if(FF2_HasAbility(bossIdx, this_plugin_name, "special_tfcondition"))
	{
		curRage[client]=FF2_GetBossCharge(bossIdx, 0);
		if(!buttonmode[client] && (GetClientButtons(client) & IN_ATTACK2) || buttonmode[client]==1 && (GetClientButtons(client) & IN_RELOAD) || buttonmode[client]==2 && (GetClientButtons(client) & IN_ATTACK3))
		{
			if(curRage[client]<=minCost[client]-1.0 && !IsPlayerInSpecificConditions(client, SpecialTFCondTweakConditions[client]) || curRage[client]<=0.44)
			{
				SetHudTextParams(-1.0, 0.5, 3.0, 255, 0, 0, 255);
				ShowHudText(client, -1, "Insufficient RAGE! You need a minimum of %i percent RAGE to use!", RoundFloat(minCost[client]));
				return;
			}
			
			FF2_SetBossCharge(bossIdx, 0, curRage[client]-dotCost[client]);
			SetPersistentCondition(client, SpecialTFCondTweakConditions[client]);
		}
	}
}


Charge_TFCondition(const String:ability_name[], boss, slot, action, bClient)
{
	new String:VictimCond[768], String:BossCond[768], String:cHUDText[512], String:cHUDText2[512], String:cSDJHUDText[512], String:cRCOSTHUDTXT[512];
	new Float:charge = FF2_GetBossCharge(boss,slot), Float:bCharge = FF2_GetBossCharge(boss,0);
	new Float:rCost = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 3);

	// HUD Strings
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 7, cHUDText, sizeof(cHUDText));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 8, cHUDText2, sizeof(cHUDText2));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 9, cSDJHUDText, sizeof(cSDJHUDText));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 10, cRCOSTHUDTXT, sizeof(cRCOSTHUDTXT));
	new override=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 11);

	if(rCost && !bEnableSuperDuperJump[boss])
	{
		if(bCharge<rCost)
		{
			return;
		}
	}
	switch (action)
	{
		case 1:
		{
			switch(slot)
			{
				case 1:
					SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
				case 2:
					SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
			}
			if(override)
				ShowSyncHudText(bClient, chargeHUD, cHUDText2, -RoundFloat(charge));
			else
				FF2_ShowSyncHudText(bClient, chargeHUD, cHUDText2, -RoundFloat(charge));
		}	
		case 2:
		{
			switch(slot)
			{
				case 1:
					SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
				case 2:
					SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
			}
			if (bEnableSuperDuperJump[boss] && slot == 1)
			{
				SetHudTextParams(-1.0, 0.88, 0.15, 255, 64, 64, 255);
				if(override)
					ShowSyncHudText(bClient, chargeHUD, cSDJHUDText);
				else
					FF2_ShowSyncHudText(bClient, chargeHUD, cSDJHUDText);
			}	
			else
			{	
				if(override)
					ShowSyncHudText(bClient, chargeHUD, cHUDText ,RoundFloat(charge));
				else
					FF2_ShowSyncHudText(bClient, chargeHUD, cHUDText ,RoundFloat(charge));

			}
		}
		case 3:
		{
			if (bEnableSuperDuperJump[boss] && slot == 1)
			{
				new Float:vel[3], Float: rot[3];
				GetEntPropVector(bClient, Prop_Data, "m_vecVelocity", vel);
				GetClientEyeAngles(bClient, rot);
				vel[2]=750.0+500.0*charge/70+2000;
				vel[0]+=Cosine(DegToRad(rot[0]))*Cosine(DegToRad(rot[1]))*500;
				vel[1]+=Cosine(DegToRad(rot[0]))*Sine(DegToRad(rot[1]))*500;
				bEnableSuperDuperJump[boss] = false;
				TeleportEntity(bClient, NULL_VECTOR, NULL_VECTOR, vel);
			}
			else
			{
				if(charge<100)
				{
					CreateTimer(0.1, ResetCharge, boss*10000+slot);
					return;					
				}
				if(rCost)
				{
					FF2_SetBossCharge(boss,0,bCharge-rCost);
				}
				
				// Conditions
				FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 4, BossCond, sizeof(BossCond)); // client TFConds
				FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 5, VictimCond, sizeof(VictimCond)); // victim TFConds
				
				if(BossCond[0]!='\0')
				{
					SetCondition(bClient, BossCond);
				}
				
				if(VictimCond[0]!='\0')
				{
					new Float:pos[3], Float:pos2[3], Float:dist;
					new Float:dist2=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 6, FF2_GetRageDist(boss, this_plugin_name, ability_name));
					if(!dist2)
					{
						dist2=FF2_GetRageDist(boss, this_plugin_name, ability_name); // Use Ragedist if range is not set
					}
					GetEntPropVector(bClient, Prop_Send, "m_vecOrigin", pos);
					for(new target=1; target<=MaxClients; target++)
					{
						if(IsValidClient(target) && IsPlayerAlive(target) && GetClientTeam(target)!= FF2_GetBossTeam())
						{
							GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
							dist=GetVectorDistance(pos,pos2);
							if (dist<dist2 && GetClientTeam(target)!=FF2_GetBossTeam())
							{
								SetCondition(target, VictimCond);
							}
						}
					}
				}
				

				new Float:position[3];
				new String:sound[PLATFORM_MAX_PATH];
				if(FF2_RandomSound("sound_ability", sound, PLATFORM_MAX_PATH, boss, slot))
				{
					EmitSoundToAll(sound, bClient, _, _, _, _, _, boss, position);
					EmitSoundToAll(sound, bClient, _, _, _, _, _, boss, position);
	
					for(new target=1; target<=MaxClients; target++)
					{
						if(IsClientInGame(target) && target!=boss)
						{
							EmitSoundToClient(target, sound, bClient, _, _, _, _, _, boss, position);
							EmitSoundToClient(target, sound, bClient, _, _, _, _, _, boss, position);
						}
					}
				}
			}			
		}
		default:
		{
			if(rCost && charge<=0.2 && !bEnableSuperDuperJump[boss])
			{
				switch(slot)
				{
					case 1:
						SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
					case 2:
						SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
				}
				if(override)
					ShowSyncHudText(bClient, chargeHUD, cRCOSTHUDTXT);
				else
					FF2_ShowSyncHudText(bClient, chargeHUD, cRCOSTHUDTXT);
			}
		}
	}
}

public Action:FF2_OnTriggerHurt(boss, triggerhurt, &Float:damage)
{
	if(!bEnableSuperDuperJump[boss])
	{
		bEnableSuperDuperJump[boss]=true;
		if (FF2_GetBossCharge(boss,1)<0)
			FF2_SetBossCharge(boss,1,0.0);
	}
	return Plugin_Continue;
}

public Action:ResetCharge(Handle:timer, any:boss)
{
	new slot=boss%10000;
	boss/=1000;
	FF2_SetBossCharge(boss, slot, 0.0);
}

stock bool:IsBoss(client)
{
	if(FF2_GetBossIndex(client)==-1) return false;
	if(GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	return true;
}

stock bool:IsValidClient(client, bool:isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}

stock SetCondition(client, String:cond[])
{
	new String:conds[32][32];
	new count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (new i = 0; i < count; i+=2)
		{
			if(!TF2_IsPlayerInCondition(client, TFCond:StringToInt(conds[i])))
			{
				TF2_AddCondition(client, TFCond:StringToInt(conds[i]), StringToFloat(conds[i+1]));
			}
		}
	}
}

stock SetPersistentCondition(client, String:cond[])
{
	new String:conds[32][32];
	new count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (new i = 0; i < count; i++)
		{
			if(TFCond:StringToInt(conds[i])==TFCond_Charging)
			{
				SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", 100.0);
			}
			TF2_AddCondition(client, TFCond:StringToInt(conds[i]), 0.2);
		}
	}
}

stock bool:IsPlayerInSpecificConditions(client, String:cond[])
{
	new String:conds[32][32];
	new count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (new i = 0; i < count; i++)
		{
			return TF2_IsPlayerInCondition(client, TFCond:StringToInt(conds[i]));
		}
	}
	return false;
}

stock RemoveCondition(client, String:cond[])
{
	new String:conds[32][32];
	new count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (new i = 0; i < count; i+=2)
		{
			if(TF2_IsPlayerInCondition(client, TFCond:StringToInt(conds[i])))
			{
				TF2_RemoveCondition(client, TFCond:StringToInt(conds[i]));
			}
		}
	}
}

///////////////////////////////////////////
// Combo RAGE & AMS TFConditions Version //
///////////////////////////////////////////

public bool:TFC_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TFC_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, -1);
}

////////////////////////////////////////
// AMS-exclusive TFConditions Version //
////////////////////////////////////////

public bool:TC0_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC0_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 0);
}

public bool:TC1_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC1_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 1);
}

public bool:TC2_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC2_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 2);
}

public bool:TC3_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC3_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 3);
}

public bool:TC4_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC4_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 4);
}

public bool:TC5_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC5_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 5);
}

public bool:TC6_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC6_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 6);
}

public bool:TC7_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC7_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 7);
}

public bool:TC8_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC8_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 8);
}

public bool:TC9_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC9_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 9);
}

public InvokeCondition(boss, client, tfcnum)
{
	decl String:amsCond[96], String:abilitySound[PLATFORM_MAX_PATH];
	
	if(tfcnum<0)
	{
		Format(amsCond, sizeof(amsCond), "rage_tfcondition");
		Format(abilitySound,sizeof(abilitySound), "sound_tfcondition");
	}
	else
	{
		Format(amsCond, sizeof(amsCond), "ams_tfcond_%i", tfcnum);
		Format(abilitySound,sizeof(abilitySound), "sound_tfcondition_%i", tfcnum);
	}
	
	new String:PlayerCond[768], String:BossCond[768], String:snd[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, amsCond, 1, BossCond, sizeof(BossCond)); // client TFConds
	FF2_GetAbilityArgumentString(boss, this_plugin_name, amsCond, 2, PlayerCond, sizeof(PlayerCond)); // Player TFConds

	if(FF2_RandomSound(abilitySound, snd, sizeof(snd), boss))
	{
		EmitSoundToAll(snd);
	}	
	
	if(BossCond[0]!='\0')
	{
		SetCondition(client, BossCond);
	}
	if(PlayerCond[0]!='\0')
	{
		new Float:pos[3], Float:pos2[3], Float:dist;
		new Float:dist2=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, amsCond, 3, FF2_GetRageDist(boss, this_plugin_name, amsCond));
		if(!dist2)
		{
			dist2=FF2_GetRageDist(boss, this_plugin_name, amsCond); // Use Ragedist if range is not set
		}
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
		for(new target=1; target<=MaxClients; target++)
		{
			if(IsValidClient(target) && IsPlayerAlive(target) && GetClientTeam(target)!= FF2_GetBossTeam())
			{
				GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
				dist=GetVectorDistance(pos,pos2);
				if (dist<dist2 && GetClientTeam(target)!=FF2_GetBossTeam())
				{
					SetCondition(target, PlayerCond);
				}
			}
		}
	}	
}