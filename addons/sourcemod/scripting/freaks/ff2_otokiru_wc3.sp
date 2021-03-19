//#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <sdkhooks>

#define MAXPLAYERSCUSTOM 66
#define entangleSound "war3source/entanglingrootsdecay1.wav"
#define teleportSound "war3source/blinkarrival.wav"
#define lightningSound "war3source/lightningbolt.wav"
#define DMG_ENERGYBEAM			(1 << 10)

new BeamSprite,HaloSprite,BloodSpray,BloodDrop;
new Boss;
new var1;	//Activation Key
new var2; 	//Additional variable
new I_SkillTimes;	//No of times skill can be used per rage
new Float:float_time; //Float Time
new ignoreClient;
new Float:emptypos[3];
new Float:oldpos[MAXPLAYERSCUSTOM][3];
new Float:teleportpos[MAXPLAYERSCUSTOM][3];
new bool:inteleportcheck[MAXPLAYERSCUSTOM];
new bool:bBeenHit[MAXPLAYERSCUSTOM][MAXPLAYERSCUSTOM];

public Plugin:myinfo = {
	name = "Freak Fortress 2: WC3 Ability Pack (1.1)",
	author = "Otokiru",
};

public OnPluginStart2()
{
	HookEvent("teamplay_round_start", event_round_start);
}

public OnMapStart()
{
	AddFileToDownloadsTable("sound/war3source/entanglingrootsdecay1.wav");
	AddFileToDownloadsTable("sound/war3source/blinkarrival.wav");
	AddFileToDownloadsTable("sound/war3source/lightningbolt.wav");
	BeamSprite=PrecacheModel("materials/sprites/lgtning.vmt");
	HaloSprite=PrecacheModel("materials/sprites/halo01.vmt");
	BloodDrop=PrecacheModel("sprites/blood.vmt");
	BloodSpray=PrecacheModel("sprites/bloodspray.vmt");
	PrecacheSound(entangleSound,true);
	PrecacheSound(teleportSound,true);
	PrecacheSound(lightningSound,true);
}

public Action:FF2_OnAbility2(index,const String:plugin_name[],const String:ability_name[],action)
{
	if (!strcmp(ability_name,"charge_weightdown_fix"))
		Charge_OnWeightDown_Fix(index);
	else if (!strcmp(ability_name,"entangle_config"))
		Entangle_Config(ability_name,index);
	else if (!strcmp(ability_name,"entangle_activator"))
		Entangle_Activator(index);
	else if (!strcmp(ability_name,"teleport_config"))
		Teleport_Config(ability_name,index);
	else if (!strcmp(ability_name,"teleport_activator"))
		Teleport_Activator(index);
	else if (!strcmp(ability_name,"chainlightning_config"))
		ChainLightning_Config(ability_name,index);
	else if (!strcmp(ability_name,"chainlightning_activator"))
		ChainLightning_Activator(index);

	return Plugin_Continue;
}

public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	I_SkillTimes=0;
	return Plugin_Continue;
}

Charge_OnWeightDown_Fix(index)
{
	Boss=GetClientOfUserId(FF2_GetBossUserId(index));
	if (GetClientButtons(Boss) & IN_DUCK)
	{
		if (!(GetEntityFlags(Boss) & FL_ONGROUND))
		{
			decl Float:ang[3];
			GetClientEyeAngles(Boss, ang);
			if (ang[0]>60.0)
			{
				new Float:fVelocity[3];
				GetEntPropVector(Boss, Prop_Data, "m_vecVelocity", fVelocity);
				fVelocity[2] = -5000.0;
				TeleportEntity(Boss, NULL_VECTOR, NULL_VECTOR, fVelocity);
				SetEntityGravity(Boss, 6.0);
			}
		}
		SetEntityGravity(Boss, 1.0);
	}
}

Entangle_Config(const String:ability_name[],index)
{
	Boss=GetClientOfUserId(FF2_GetBossUserId(index));
	var1=FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 1);	//Activation Key
	I_SkillTimes=FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 2);	//No of times skill can be used per rage
	float_time=FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name,3,5.0); //Entangle Time
	SetKeysBits(var1);
}

Entangle_Activator(index)
{	
	Boss=GetClientOfUserId(FF2_GetBossUserId(index));
	if(I_SkillTimes > 0)
	{
		PrintCenterText(Boss,"Skill Remaining: %i",I_SkillTimes);
		if (GetClientButtons(Boss) & var1)
		{
			new Float:distance=0.0;
			new target;	
			new Float:our_pos[3];
			GetClientAbsOrigin(Boss,our_pos);
			target=War3_GetTargetInViewCone(Boss,distance);
			
			if(IsValidClient(target))
			{
				I_SkillTimes = I_SkillTimes-1;
				new Float:fVelocity[3] = {0.0,0.0,0.0};
				TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, fVelocity);
				SetEntityMoveType(target, MOVETYPE_NONE);
				CreateTimer(float_time,StopEntangle,target);
				new Float:effect_vec[3];
				GetClientAbsOrigin(target,effect_vec);
				effect_vec[2]+=15.0;
				TE_SetupBeamRingPoint(effect_vec,45.0,44.0,BeamSprite,HaloSprite,0,15,float_time,5.0,0.0,{0,255,0,255},10,0);
				TE_SendToAll();
				effect_vec[2]+=15.0;
				TE_SetupBeamRingPoint(effect_vec,45.0,44.0,BeamSprite,HaloSprite,0,15,float_time,5.0,0.0,{0,255,0,255},10,0);
				TE_SendToAll();
				effect_vec[2]+=15.0;
				TE_SetupBeamRingPoint(effect_vec,45.0,44.0,BeamSprite,HaloSprite,0,15,float_time,5.0,0.0,{0,255,0,255},10,0);
				TE_SendToAll();
				our_pos[2]+=25.0;
				TE_SetupBeamPoints(our_pos,effect_vec,BeamSprite,HaloSprite,0,50,4.0,6.0,25.0,0,12.0,{80,255,90,255},40);
				TE_SendToAll();
				PrintCenterText(target,"You got Entangled!");
				PrintCenterText(Boss,"Skill Remaining: %i",I_SkillTimes);
				
				EmitSoundToAll(entangleSound);
				EmitSoundToAll(entangleSound);
			}
			else
			{
				PrintCenterText(Boss,"No target found!");
			}
		}
	}
}

public Action:StopEntangle(Handle:timer,any:client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
		SetEntityMoveType(client, MOVETYPE_WALK);	
}

Teleport_Config(const String:ability_name[],index)
{
	Boss=GetClientOfUserId(FF2_GetBossUserId(index));
	new keyss=FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 1);	//Activation Key
	I_SkillTimes=FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 2);	//No of times skill can be used per rage
	float_time=FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name,3,9999.0); //Teleport Distance
	SetKeysBits(keyss);
}

Teleport_Activator(index)
{	
	Boss=GetClientOfUserId(FF2_GetBossUserId(index));
	if(I_SkillTimes > 0)
	{
		PrintCenterText(Boss,"Skill Remaining: %i",I_SkillTimes);
		if (GetClientButtons(Boss) & var1)
		{
			War3_Teleport(Boss,float_time);
		}
	}
}

ChainLightning_Config(const String:ability_name[],index)
{
	Boss=GetClientOfUserId(FF2_GetBossUserId(index));
	new keyss=FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 1);	//Activation Key
	I_SkillTimes=FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 2);	//No of times skill can be used per rage
	float_time=FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name,3,9999.0); //Chain Lightning Distance
	var2=FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 4);	//Damage
	SetKeysBits(keyss);
}

ChainLightning_Activator(index)
{	
	Boss=GetClientOfUserId(FF2_GetBossUserId(index));
	if(I_SkillTimes > 0)
	{
		PrintCenterText(Boss,"Skill Remaining: %i",I_SkillTimes);
		if (GetClientButtons(Boss) & var1)
		{
			for(new x=1;x<=MaxClients;x++)
					bBeenHit[Boss][x]=false;
			DoChain(Boss,float_time,var2,0);
		}
	}
}

public SetKeysBits(keys)
{
	if(keys==2)			//IN_ATTACK2
		var1 = 2048;
	else if(keys==3)	//IN_RELOAD
		var1 = 8192;
	else				//IN_ATTACK
		var1 = 1;
}

stock IsValidClient(client, bool:replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (replaycheck)
	{
		decl String:adminname[32];
	//	decl String:auth[32];
		decl String:name[32];
		new AdminId:admin;
		GetClientName(client, name, sizeof(name));
	//	GetClientAuthString(client, auth, sizeof(auth));
		if (strcmp(name, "replay", false) == 0 && IsFakeClient(client)) return false;
		if ((admin = GetUserAdmin(client)) != INVALID_ADMIN_ID)
		{
			GetAdminUsername(admin, adminname, sizeof(adminname));
			if (strcmp(adminname, "Replay", false) == 0 || strcmp(adminname, "SourceTV", false) == 0) return false;
		}
	}
	return true;
}

stock bool:ValidPlayer(client,bool:check_alive=false,bool:alivecheckbyhealth=false){
	if(client>0 && client<=MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		if(check_alive && !IsPlayerAlive(client))
		{
			return false;
		}
		if(alivecheckbyhealth&&GetClientHealth(client)<1){
			return false;
		}
		return true;
	}
	return false;
}

public bool:AimTargetFilter(entity,mask)
{
	return !(entity==ignoreClient);
}

public War3_GetTargetInViewCone(client,Float:max_distance)
{
	if(IsValidClient(client))
	{
		ignoreClient=client;
		if(max_distance<0.0)
			max_distance=0.0;
		new Float:PlayerEyePos[3];
		new Float:PlayerAimAngles[3];
		GetClientEyePosition(client,PlayerEyePos);
		GetClientEyeAngles(client,PlayerAimAngles);
		new Float:PlayerAimVector[3];
		GetAngleVectors(PlayerAimAngles,PlayerAimVector,NULL_VECTOR,NULL_VECTOR);
		new bestTarget=0;
		new Float:endpos[3];
		if(max_distance>0.0){
			ScaleVector(PlayerAimVector,max_distance);
		}
		else{
			ScaleVector(PlayerAimVector,56756.0);
			AddVectors(PlayerEyePos,PlayerAimVector,endpos);
			TR_TraceRayFilter(PlayerEyePos,endpos,MASK_ALL,RayType_EndPoint,AimTargetFilter);
			if(TR_DidHit())
			{
				new entity=TR_GetEntityIndex();
				if(entity>0 && entity<=MaxClients && IsClientConnected(entity) && IsPlayerAlive(entity) && GetClientTeam(client)!=GetClientTeam(entity) )
					bestTarget=entity;
			}
		}
		return bestTarget;
	}
	return 0;
}

public War3_Teleport(client,Float:distance)
{
	if(client>0)
	{
		if(IsPlayerAlive(client)&&!inteleportcheck[client])
		{
			new Float:angle[3];
			GetClientEyeAngles(client,angle);
			new Float:endpos[3];
			new Float:startpos[3];
			GetClientEyePosition(client,startpos);
			new Float:dir[3];
			GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(dir, distance);
			AddVectors(startpos, dir, endpos);
			GetClientAbsOrigin(client,oldpos[client]);
			ignoreClient=client;
			TR_TraceRayFilter(startpos,endpos,MASK_ALL,RayType_EndPoint,AimTargetFilter);
			TR_GetEndPosition(endpos);
			new Float:distanceteleport=GetVectorDistance(startpos,endpos);
			GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);///get dir again
			ScaleVector(dir, distanceteleport-33.0);
			
			AddVectors(startpos,dir,endpos);
			emptypos[0]=0.0;
			emptypos[1]=0.0;
			emptypos[2]=0.0;
			
			endpos[2]-=30.0;
			getEmptyLocationHull(client,endpos);
			
			if(GetVectorLength(emptypos)<1.0){
				PrintCenterText(client,"Cannot teleport there!");
				return false; //it returned 0 0 0
			}

			TeleportEntity(client,emptypos,NULL_VECTOR,NULL_VECTOR);
			EmitSoundToAll(teleportSound);
			EmitSoundToAll(teleportSound);

			teleportpos[client][0]=emptypos[0];
			teleportpos[client][1]=emptypos[1];
			teleportpos[client][2]=emptypos[2];		
			inteleportcheck[client]=true;
			CreateTimer(0.14,checkTeleport,client);
			
			decl Float:partpos[3];
			GetClientEyePosition(client, partpos);
			partpos[2]-=20.0;	
			TeleportEffects(partpos);
			emptypos[2]+=40.0;
			TeleportEffects(emptypos);

			return true;
		}
	}
	return false;
}

public Action:checkTeleport(Handle:h,any:client){
	inteleportcheck[client]=false;
	new Float:pos[3];
	
	GetClientAbsOrigin(client,pos);
	
	if(GetVectorDistance(teleportpos[client],pos)<0.001)//he didnt move in this 0.1 second
	{
		TeleportEntity(client,oldpos[client],NULL_VECTOR,NULL_VECTOR);
		PrintCenterText(client,"Cannot teleport there!");
	}
	else{
		I_SkillTimes=I_SkillTimes-1;
		PrintCenterText(client,"Skill Remaining: %i",I_SkillTimes);
	}
}

new absincarray[]={0,4,-4,8,-8,12,-12,18,-18,22,-22,25,-25};//,27,-27,30,-30,33,-33,40,-40}; //for human it needs to be smaller

public bool:getEmptyLocationHull(client,Float:originalpos[3]){
	new Float:mins[3];
	new Float:maxs[3];
	GetClientMins(client,mins);
	GetClientMaxs(client,maxs);
	new absincarraysize=sizeof(absincarray);
	new limit=5000;
	for(new x=0;x<absincarraysize;x++){
		if(limit>0){
			for(new y=0;y<=x;y++){
				if(limit>0){
					for(new z=0;z<=y;z++){
						new Float:pos[3]={0.0,0.0,0.0};
						AddVectors(pos,originalpos,pos);
						pos[0]+=float(absincarray[x]);
						pos[1]+=float(absincarray[y]);
						pos[2]+=float(absincarray[z]);
						TR_TraceHullFilter(pos,pos,mins,maxs,MASK_SOLID,CanHitThis,client);
						//new ent;
						if(!TR_DidHit(_))
						{
							AddVectors(emptypos,pos,emptypos); ///set this gloval variable
							limit=-1;
							break;
						}
						if(limit--<0){
							break;
						}
					}
					if(limit--<0){
						break;
					}
				}
			}
			if(limit--<0){
				break;
			}
		}
	}
} 

public bool:CanHitThis(entityhit, mask, any:data)
{
	if(entityhit == data )
	{// Check if the TraceRay hit the itself.
		return false; // Don't allow self to be hit, skip this result
	}
	if(IsValidClient(entityhit)&&IsValidClient(data)&&GetClientTeam(entityhit)==GetClientTeam(data)){
		return false; //skip result, prend this space is not taken cuz they on same team
	}
	return true; // It didn't hit itself
}      

public Action:DeleteParticles(Handle:timer, any:particle)
{
    if (IsValidEntity(particle))
    {
        new String:classname[32];
        GetEdictClassname(particle, classname, sizeof(classname));
        if (StrEqual(classname, "info_particle_system", false))
        {
            RemoveEdict(particle);
        }
    }
}

TeleportEffects(Float:pos[3])
{
	ShowParticle(pos, "pyro_blast", 1.0);
	ShowParticle(pos, "pyro_blast_lines", 1.0);
	ShowParticle(pos, "pyro_blast_warp", 1.0);
	ShowParticle(pos, "pyro_blast_flash", 1.0);
	ShowParticle(pos, "burninggibs", 0.5);
}

ShowParticle(Float:possie[3], String:particlename[], Float:time)
{
    new particle = CreateEntityByName("info_particle_system");
    if (IsValidEdict(particle))
    {
        TeleportEntity(particle, possie, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(particle, "effect_name", particlename);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
        CreateTimer(time, DeleteParticles, particle);
    }  
}

public DoChain(client,Float:distance,dmg,last_target)
{
	new target=0;
	new Float:target_dist=distance+1.0; // just an easy way to do this
	new caster_team=GetClientTeam(client);
	new Float:start_pos[3];
	if(last_target<=0)
		GetClientAbsOrigin(client,start_pos);
	else
		GetClientAbsOrigin(last_target,start_pos);
	for(new x=1;x<=MaxClients;x++)
	{
		if(ValidPlayer(x,true)&&!bBeenHit[client][x]&&caster_team!=GetClientTeam(x))
		{
			new Float:this_pos[3];
			GetClientAbsOrigin(x,this_pos);
			new Float:dist_check=GetVectorDistance(start_pos,this_pos);
			if(dist_check<=target_dist)
			{
				// found a candidate, whom is currently the closest
				target=x;
				target_dist=dist_check;
			}
		}
	}
	if(target<=0)
	{
		PrintCenterText(client,"No target found!");
	}
	else
	{
		// found someone
		bBeenHit[client][target]=true; // don't let them get hit twice
		War3_DealDamage(target,dmg,client,DMG_ENERGYBEAM,"ChainLightning");
		PrintCenterText(target,"You got hit by Chain Lightning!");
		start_pos[2]+=30.0; // offset for effect
		decl Float:target_pos[3],Float:vecAngles[3];
		GetClientAbsOrigin(target,target_pos);
		target_pos[2]+=30.0;
		TE_SetupBeamPoints(start_pos,target_pos,BeamSprite,HaloSprite,0,35,1.0,25.0,25.0,0,10.0,{255,100,255,255},40);
		TE_SendToAll();
		GetClientEyeAngles(target,vecAngles);
		TE_SetupBloodSprite(target_pos, vecAngles, {200, 20, 20, 255}, 28, BloodSpray, BloodDrop);
		TE_SendToAll();
		EmitSoundToAll( lightningSound , target,_,SNDLEVEL_TRAIN);
		new new_dmg=RoundFloat(float(dmg)*0.66);
		
		DoChain(client,distance,new_dmg,target);
		I_SkillTimes=I_SkillTimes-1;
		//PrintCenterText(Boss,"Skill Remaining: %i",I_SkillTimes);
	}
}

public War3_DealDamage(victim,damage,attacker,dmg_type,String:weapon[64])
{
	if(victim>0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage>0)
	{
		new String:dmg_str[16];
		IntToString(damage,dmg_str,16);
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		new pointHurt=CreateEntityByName("point_hurt");
		if(pointHurt)
		{
			DispatchKeyValue(victim,"targetname","war3_hurtme");
			DispatchKeyValue(pointHurt,"DamageTarget","war3_hurtme");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(pointHurt,"classname",weapon);
			}
			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(victim,"targetname","war3_donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}