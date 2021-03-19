#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =  {
	name = "[TF2] Baseball", 
	author = "Scag", 
	description = "Gone forever", 
	version = "1.0.0", 
	url = "https://github.com/Scags/TF2-Baseball"
};

Handle hSmack;
Handle hWorldSpaceCenter;
Handle hGetVelocity;

ConVar cvScalar;
ConVar cvFOV;
ConVar cvRange;
ConVar cvTauntRange;
ConVar bEnabled;

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile("tf2.baseball");
	if (!conf)
		SetFailState("Could not find gamedata for tf2.baseball");

	hSmack = DHookCreate(0, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);
	if (!DHookSetFromConf(hSmack, conf, SDKConf_Virtual, "CTFBat::Smack"))
		SetFailState("Could not initialize call to CTFBat::Smack");

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "CBaseEntity::GetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Plain, 0, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Plain, 0, VENCODE_FLAG_COPYBACK);
	if (!(hGetVelocity = EndPrepSDKCall()))
		SetFailState("Could not initialize call to CBaseEntity::GetVelocity");

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "CBaseEntity::WorldSpaceCenter");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if (!(hWorldSpaceCenter = EndPrepSDKCall()))
		LogError("Could not initialize call to CBaseEntity::WorldSpaceCenter. Falling back to m_vecOrigin.");

	Handle hook = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	DHookSetFromConf(hook, conf, SDKConf_Signature, "CTFPlayer::DoTauntAttack");
	if (!DHookEnableDetour(hook, false, CTFPlayer_DoTauntAttack))
		LogError("Could not load detour for CTFPlayer::DoTauntAttack!");	// Don't need to fail if its just the taunt effect

	bEnabled = CreateConVar("sm_tfbaseball_enabled", "1.0", "Enable TF2Baseball.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvScalar = CreateConVar("sm_tfbaseball_velmult", "1.15", "Speed multiplier for a bat'd projectile.", FCVAR_NOTIFY, true, 0.00001);
	cvFOV = CreateConVar("sm_tfbaseball_fov", "70.0", "FOV range for bat swing to register as a valid hit.", FCVAR_NOTIFY, true, 0.0, true, 180.0);
	cvRange = CreateConVar("sm_tfbaseball_range", "150.0", "Max range a projectile can be before it is bat'd.", FCVAR_NOTIFY, true, 0.0);
	cvTauntRange = CreateConVar("sm_tfbaseball_taunt_scale", "1.5", "When a scout does his swing taunt, how much should its range scale for projectiles?", FCVAR_NOTIFY, true, 0.0);

	AutoExecConfig(true, "TF2Baseball");

	delete conf;
}

public void OnMapStart()
{
	PrecacheSound("mvm/melee_impacts/bat_baseball_hit_robo01.wav", true);
	PrecacheSound("passtime/crowd_cheer.wav", true);
	PrecacheSound("weapons/bat_baseball_hit1.wav", true);
	PrecacheSound("weapons/bat_baseball_hit2.wav", true);
}

public void OnEntityCreated(int ent, const char[] classname)
{
	if (bEnabled.BoolValue && !StrContains(classname, "tf_weapon_bat", false))
		DHookEntity(hSmack, false, ent, _, Smack);
}

public MRESReturn Smack(int pThis)
{
	int owner = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if (!(0 < owner <= MaxClients))
		return;

	float vecEye[3]; GetClientEyeAngles(owner, vecEye);
	float vecFwd[3]; GetAngleVectors(vecEye, vecFwd, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vecFwd, vecFwd);

	int ent = FindBall(owner, vecFwd);

	if (ent == -1)
		return;

//	if (!HasEntProp(ent, Prop_Send, "m_iDeflected"))
//		return;

	Deflect(ent, owner, vecEye, vecFwd);

	return;
}

#define TAUNTATK_SCOUT_GRAND_SLAM 6

public MRESReturn CTFPlayer_DoTauntAttack(int pThis)
{
	if (!bEnabled.BoolValue || !TF2_IsPlayerInCondition(pThis, TFCond_Taunting) || !IsPlayerAlive(pThis))
		return;

	int tauntatk = GetEntData(pThis, FindSendPropInfo("CTFPlayer", "m_iSpawnCounter") - 24);

	if (tauntatk == TAUNTATK_SCOUT_GRAND_SLAM)
	{
		float vecForward[3];
		float ang[3]; GetClientEyeAngles(pThis, ang);
//		ang[2] = GetEntPropFloat(pThis, Prop_Send, "m_angEyeAngles[1]");
		ang[0] = ang[2] = 0.0;
		GetAngleVectors(ang, vecForward, NULL_VECTOR, NULL_VECTOR);

		float vecCenter[3], vecFwdScaled[3];
		vecFwdScaled = vecForward;
		ScaleVector(vecFwdScaled, 64.0);
		AddVectors(WorldSpaceCenter(pThis), vecFwdScaled, vecCenter);

		float vecSize[3] = {24.0, 24.0, 24.0};
		ScaleVector(vecSize, cvTauntRange.FloatValue);

		// Respect the scale
		float vecSizeN[3];
		vecSizeN[0] = -vecSize[0];
		vecSizeN[1] = -vecSize[1];
		vecSizeN[2] = -vecSize[2];

//		float vecStart[3], vecEnd[3];
//		SubtractVectors(vecCenter, vecSize, vecStart);
//		AddVectors(vecCenter, vecSize, vecEnd);

		ArrayList objects = new ArrayList();	// Half-assed UTIL_EntitiesInBox
//		TR_EnumerateEntitiesHull(vecCenter, vecCenter, vecStart, vecEnd, PARTITION_SOLID_EDICTS, ReflectHullTrace, objects);

		TR_TraceHullFilter(vecCenter, vecCenter, vecSizeN, vecSize, MASK_SOLID, ReflectHullTrace, objects);

		float vecToTarget[3];
		int pTarget;
		for (int i = 0; i < objects.Length; ++i)
		{
			pTarget = objects.Get(i);
			SubtractVectors(WorldSpaceCenter(pTarget), WorldSpaceCenter(pThis), vecToTarget);
			NormalizeVector(vecToTarget, vecToTarget);

			float flDot = GetVectorDotProduct(vecForward, vecToTarget);
			if (flDot < 0.80)
				continue;

			if (GetTeamNumber(pTarget) == GetTeamNumber(pThis))
				continue;

			// Do a quick trace and make sure we have LOS.
			TR_TraceRayFilter(WorldSpaceCenter(pThis), WorldSpaceCenter(pTarget), MASK_SOLID, RayType_EndPoint, TheTrace, pThis);

			// This was literally hit or miss, opting for direct line instead
//			if (TR_GetFraction() < 1.0)
//				continue;

			if (!TR_DidHit() || TR_GetEntityIndex() == pTarget)
			{
				Deflect(pTarget, pThis, ang, vecForward, true);
			}
		}

		delete objects;
	}
}

void Deflect(int ent, int owner, float vecEye[3], float vecFwd[3], bool grandslam = false)
{
	float vecVel[3]; vecVel = GetVelocity(ent);
	float speed = GetVectorLength(vecVel);

	ScaleVector(vecFwd, speed);
	ScaleVector(vecFwd, cvScalar.FloatValue);	// To be fair you are SWINGING a bat, so velocity should go up, right?
												// Or down if you want that

	if (IsBaseball(ent))
	{
		if (GetEntProp(ent, Prop_Send, "m_bTouched"))
		{
			SetEntProp(ent, Prop_Send, "m_bTouched", false);	// Full-on baseball
/*
			// 1420 linux
			int m_bDefensiveBomb = FindSendPropInfo("CTFStunBall", "m_bDefensiveBomb");
			int currparticle = GetEntDataEnt2(ent, m_bDefensiveBomb + 72);

			// Refresh or remake the sprite
			if (currparticle != -1)
				RemoveEntity(ent);

			char particle[32];
			particle = GetClientTeam(owner) == 2 ? "effects/baseballtrail_red.vmt" : "effects/baseballtrail_blu.vmt";
			SetEntDataEnt2(ent, m_bDefensiveBomb + 72, AttachBBallSprite(ent, particle));
			// Refresh the alpha timer
			SetEntDataFloat(ent, m_bDefensiveBomb + 68, 1.0);
*/
		}

		if (grandslam)
		{	// If we Ortiz'd this fother mucker
			GetClientEyeAngles(owner, vecEye);
			vecEye[0] = -45.0;
			vecEye[2] = 0.0;

//			vecEye[0] = -45.0;
//			vecEye[1] = GetEntPropFloat(owner, Prop_Send, "m_angEyeAngles[1]");
//			vecEye[2] = 0.0;

			GetAngleVectors(vecEye, vecFwd, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(vecFwd, 1300.0);	// This gets clamped for some reason... oh whale
											// Making it any higher forces its env_spritetrail to kill it
		}

		char s[256];
		FormatEx(s, sizeof(s), "weapons/bat_baseball_hit%d.wav", GetRandomInt(1, 2));
		EmitSoundToAll(s, owner);
	}
	else EmitSoundToAll("mvm/melee_impacts/bat_baseball_hit_robo01.wav", owner);

	TeleportEntity(ent, NULL_VECTOR, vecEye, vecFwd);

	if (grandslam)
	{
		// And the crowd goes WILD
		CreateTimer(0.5, Timer_Cheer, GetClientUserId(owner), TIMER_FLAG_NO_MAPCHANGE);
	}

	SetEntProp(ent, Prop_Send, "m_iDeflected", GetEntProp(ent, Prop_Send, "m_iDeflected")+1);
	char classname[32]; GetEntityClassname(ent, classname, sizeof(classname));

	if (!StrEqual(classname, "tf_projectile_pipe_remote", false))	// Shouldn't own sticky bombs
	{
		int team = GetClientTeam(owner);
		if (HasEntProp(ent, Prop_Send, "m_hDeflectOwner"))
			SetEntPropEnt(ent, Prop_Send, "m_hDeflectOwner", owner);
		if (HasEntProp(ent, Prop_Send, "m_hLauncher"))
			SetEntPropEnt(ent, Prop_Send, "m_hLauncher", owner);
		if (HasEntProp(ent, Prop_Send, "m_hThrower"))
			SetEntPropEnt(ent, Prop_Send, "m_hThrower", owner);		// ONE of these HAS to work

		SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", owner);
		SetEntProp(ent, Prop_Send, "m_iTeamNum", team);
		SetEntProp(ent, Prop_Send, "m_nSkin", team-2);
	}
}

public int FindBall(int client, const float vecFwd[3])
{
	float max = 1.0 - cvFOV.FloatValue/180.0;
	int ent = -1;
	float vecPos[3]; GetClientEyePosition(client, vecPos);
	float vecOtherPos[3];
	float vecSub[3];

	while ((ent = FindEntityByClassname(ent, "tf_projectile*")) != -1)
	{
		vecOtherPos = WorldSpaceCenter(ent);
		if (GetVectorDistance(vecPos, vecOtherPos) > cvRange.FloatValue)
			continue;

		if (GetEntProp(ent, Prop_Send, "m_iTeamNum") == GetClientTeam(client))
			continue;

		if (!HasEntProp(ent, Prop_Send, "m_iDeflected"))
			continue;

//		PrintToChatAll("found %d", ent);
		SubtractVectors(vecOtherPos, vecPos, vecSub);
		NormalizeVector(vecSub, vecSub);
		if (GetVectorDotProduct(vecFwd, vecSub) < max)	// It's within fov and within a reasonable melee range 
			continue;									// Now, can you actually see it?

		TR_TraceRayFilter(vecPos, vecOtherPos, MASK_SOLID, RayType_EndPoint, TheTrace, client);
		if (!TR_DidHit() || TR_GetEntityIndex() == ent)
			return ent;		// Yes, now reflect it!
	}
	return -1;
}

public Action Timer_Cheer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client)
		EmitSoundToAll("passtime/crowd_cheer.wav", client);
}

float[] WorldSpaceCenter(int entity)
{
	float pos[3];
	if (hWorldSpaceCenter)
		SDKCall(hWorldSpaceCenter, entity, pos);
	else GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);	// If it doesn't exist then fall back to vecOrigin

	return pos;
}

float[] GetVelocity(int entity)
{
	float vel[3], dummy[3];
	SDKCall(hGetVelocity, entity, vel, dummy);
	return vel;
}

stock int GetTeamNumber(int ent)
{
	return GetEntProp(ent, Prop_Send, "m_iTeamNum");
}

stock bool IsBaseball(int ent)
{
	char cls[32]; GetEntityClassname(ent, cls, sizeof(cls));
	return !strcmp(cls, "tf_projectile_stun_ball", false);
}

#define EF_BONEMERGE (1 << 0)
stock int AttachBBallSprite(int entity, const char[] name)
{
	int sprite = CreateEntityByName("env_spritetrail");
	if (sprite != -1)
	{
		DispatchKeyValue(sprite, "spritename", name);
		DispatchKeyValueVector(sprite, "origin", WorldSpaceCenter(entity));

		DispatchKeyValueFloat(sprite, "startwidth", 9.0);
		DispatchKeyValueFloat(sprite, "lifetime", 0.4);

		DispatchSpawn(sprite);

		SetVariantString("!activator");
		AcceptEntityInput(sprite, "SetParent", entity);

		SetEntProp(sprite, Prop_Send, "m_flTextureRes", 1.0 / (96.0 * 1.0));
		SetEntPropEnt(sprite, Prop_Send, "m_hAttachedToEntity", entity);
		SetEntProp(sprite, Prop_Send, "m_nAttachment", 0);
		SetEntProp(sprite, Prop_Send, "m_fEffects", GetEntProp(sprite, Prop_Send, "m_fEffects") | EF_BONEMERGE);

		SetEntityRenderMode(sprite, RENDER_TRANSALPHA);
		SetEntityRenderColor(sprite, 255, 255, 255, 128);

		AcceptEntityInput(sprite, "TurnOn");
	}
	return sprite;
}

public bool TheTrace(int ent, int mask, any data)
{
	if (ent <= MaxClients)
		return false;

	char cls[32]; GetEntityClassname(ent, cls, sizeof(cls));
	if (StrContains(cls, "tf_projectile", false))
		return false;

	return true;
}

public bool ReflectHullTrace(int ent, int mask, ArrayList objs)
{
	if (ent <= MaxClients)
		return false;

	if (!HasEntProp(ent, Prop_Send, "m_iDeflected"))
		return false;

	char cls[32]; GetEntityClassname(ent, cls, sizeof(cls));
	if (strncmp(cls, "tf_proj", 7, false))
		return false;

	if (objs.FindValue(ent) != -1)	// o_0
		return false;

//	TR_ClipCurrentRayToEntity(MASK_SOLID, ent);
//	if (!TR_DidHit())
//		return false;

	objs.Push(ent);
	return false;
}
