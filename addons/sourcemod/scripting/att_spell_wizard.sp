#include <sourcemod>

#include <tf2>
#include <tf2_stocks>

#include <tf_custom_attributes>
#include <tf2wearables>

#include <stocksoup/var_strings>

#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME         "[CA] Fire Magic Spells Rage"
#define PLUGIN_AUTHOR       "Zabaniya001"
#define PLUGIN_DESCRIPTION  "Hello darling. This plugin uses Nosoop's Custom Attributes framework. This Custom Attribute lets, once you reach enough rage, utilize fire spells ( damage depends on how much rage you have )."
#define PLUGIN_VERSION      "1.0.0"
#define PLUGIN_URL          "https://alliedmods.net"

public Plugin myinfo = {
    name        =   PLUGIN_NAME,
    author      =   PLUGIN_AUTHOR,
    description =   PLUGIN_DESCRIPTION,
    version     =   PLUGIN_VERSION,
    url         =   PLUGIN_URL
};

// ||──────────────────────────────────────────────────────────────────────────||
// ||                              GLOBAL VARIABLES                            ||
// ||──────────────────────────────────────────────────────────────────────────||

enum SpellStrengthType
{
    SpellStrength_None = -1,
    SpellStrength_25 = 0,
    SpellStrength_50,
    SpellStrength_75,
    SpellStrength_100
};

enum struct weapon_t
{
    float fRage;
    float fPerc;

    float fMaxRage;

    float fDamage25Perc;
    float fDamage50Perc;
    float fDamage75Perc;
    float fDamage100Perc;

    void Init(char[] sAttribute)
    {
        this.fMaxRage       =   ReadFloatVar(sAttribute, "max_rage",        1000.0);
        this.fDamage25Perc  =   ReadFloatVar(sAttribute, "max_damage_25%",  500.0);
        this.fDamage50Perc  =   ReadFloatVar(sAttribute, "max_damage_50%",  1000.0);
        this.fDamage75Perc  =   ReadFloatVar(sAttribute, "max_damage_75%",  1500.0);
        this.fDamage100Perc =   ReadFloatVar(sAttribute, "max_damage_100%", 2000.0);

        return;
    }

    void Destroy()
    {
        this.fRage          =   0.0;
        this.fPerc          =   0.0;
        this.fMaxRage       =   0.0;
        this.fDamage25Perc  =   0.0;
        this.fDamage50Perc  =   0.0;
        this.fDamage75Perc  =   0.0;
        this.fDamage100Perc =   0.0;

        return;
    }

    float CalculatePercentage()
    {
        return 100.0 - ((FloatAbs(this.fMaxRage - this.fRage) / this.fMaxRage) * 100.0);
    }
}

weapon_t Weapon[2048];

enum struct spell_t 
{
    int iWeaponID;

    bool bInternalSpell;

    SpellStrengthType Strength;

    void Destroy()
    {
        this.iWeaponID = 0;
        this.bInternalSpell = false;
        this.Strength = SpellStrength_None;
    }
}

spell_t SpellEntities[2048];

// If you want to change, add or remove sounds, just go ahead. No need to change the code since it uses sizeof.
static const char sDeniedSounds[][] =
{
    "replay/record_fail.wav"
};

// Handle hDoAnimation;
// Handle g_hSDKSendWeaponAnim;

// ||──────────────────────────────────────────────────────────────────────────||
// ||                               SOURCEMOD API                              ||
// ||──────────────────────────────────────────────────────────────────────────||

public void OnPluginStart() 
{   
    //GameData Config = new GameData("tf2.attribute_support");

    //if(!Config)
    //    SetFailState("Failed to load gamedata (tf2.doanimation).");

    /*
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(Config, SDKConf_Signature, "CTFPlayer::DoAnimationEvent");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    hDoAnimation = EndPrepSDKCall();

    delete Config;
    */

    //StartPrepSDKCall(SDKCall_Entity);
    //PrepSDKCall_SetFromConf(Config, SDKConf_Virtual, "CTFWeaponBase::SendWeaponAnim()");
    //PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    //g_hSDKSendWeaponAnim = EndPrepSDKCall();

    HookEvent("post_inventory_application", Event_OnPostInventoryApplication);

    // In case of late load.
    for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if(IsClientInGame(iClient))
            OnClientPutInServer(iClient);
    }
    
    return;
}

public void OnMapStart()
{
    for(int i = 0; i < sizeof(sDeniedSounds); i++)
    {
        PrecacheSound(sDeniedSounds[i], true);
    }
}

public void OnClientPutInServer(int iClient)
{
    SDKHook(iClient, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
    SDKHook(iClient, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
    SDKHook(iClient, SDKHook_WeaponEquipPost,   OnWeaponEquipPost);

    return;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                                EVENTS                                    ||
// ||──────────────────────────────────────────────────────────────────────────||

public void OnEntityDestroyed(int iEntity)
{
    if(iEntity < 0 || iEntity > 2048)
        iEntity = EntRefToEntIndex(iEntity);

    if(iEntity < 0 || iEntity > 2048)
        return;

    RequestFrame(Frame_DeleteEntity, iEntity);

    return;
}

public void Frame_DeleteEntity(int iEntity)
{
    SpellEntities[iEntity].Destroy();
    Weapon[iEntity].Destroy();

    return;
}

public void OnWeaponEquipPost(int iClient, int iWeapon)
{
    char sAttributes[140];
    if(!TF2CustAttr_GetString(iWeapon, "fire wizard spells rage", sAttributes, sizeof(sAttributes)))
        return;

    Weapon[iWeapon].Init(sAttributes);

    return;
}

public void Event_OnPostInventoryApplication(Event event, const char[] name, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(event.GetInt("userid"));

    if(!IsValidClient(iClient))
        return;

    for(eTF2LoadoutSlot eSlot = TF2LoadoutSlot_Primary; eSlot < TF2LoadoutSlot_Misc3; eSlot++)
    {
        int iWeapon = TF2_GetPlayerLoadoutSlot(iClient, eSlot);

        if(!IsValidEntity(iWeapon))
            continue;

        char sAttributes[140];
        if(!TF2CustAttr_GetString(iWeapon, "fire wizard spells rage", sAttributes, sizeof(sAttributes)))
            continue;

        Weapon[iWeapon].Init(sAttributes);
    }

    return;
}

public void OnPlayerRunCmdPost(int iClient, int iButtons)
{
    if(!(iButtons & IN_ATTACK3))
        return;

    if(!IsValidClient(iClient))
        return;

    int iWeapon = TF2_GetActiveWeapon(iClient);

    if(iWeapon <= 0 || iWeapon > 2048)
        return;

    if(!Weapon[iWeapon].fMaxRage)
        return;

    static float fWarningDelay[2048];

    if(Weapon[iWeapon].fPerc < 25.0)
    {
        if(fWarningDelay[iWeapon] >= GetGameTime())
            return;

        fWarningDelay[iWeapon] = GetGameTime() + 1.0;

        EmitSoundToClient(iClient, sDeniedSounds[GetRandomInt(0, sizeof(sDeniedSounds) - 1)], _, _, SNDLEVEL_CAR);

        return;
    }

    fWarningDelay[iWeapon] = GetGameTime() + 1.0;

    // DoAnimation(iClient, 19);

    //SDK_SendWeaponAnim(iWeapon, 1754);

    ThrowSpell(iClient, iWeapon);

    return;
}

public Action OnTakeDamageAlive(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWeapon, float fDamageForce[3], float fDamagePosition[3], int iDamageCustom)
{
    if(!IsValidEntity(iVictim) || !IsValidEntity(iAttacker) || !IsValidEntity(iWeapon) || iAttacker == iVictim)
        return Plugin_Continue;

    if(!SpellEntities[iInflictor].bInternalSpell)
        return Plugin_Continue;

    int iWeaponLauncher = SpellEntities[iInflictor].iWeaponID;

    float fDamageTemp = 0.0;

    switch(SpellEntities[iInflictor].Strength)
    {
        case SpellStrength_25: 
            fDamageTemp = GetRandomFloat(Weapon[iWeaponLauncher].fDamage25Perc * 0.4, Weapon[iWeaponLauncher].fDamage25Perc);
        case SpellStrength_50:
            fDamageTemp = GetRandomFloat(Weapon[iWeaponLauncher].fDamage50Perc * 0.6, Weapon[iWeaponLauncher].fDamage50Perc);
        case SpellStrength_75:
            fDamageTemp = GetRandomFloat(Weapon[iWeaponLauncher].fDamage75Perc * 0.8, Weapon[iWeaponLauncher].fDamage75Perc);
        case SpellStrength_100:
            fDamageTemp = GetRandomFloat(Weapon[iWeaponLauncher].fDamage100Perc * 0.9, Weapon[iWeaponLauncher].fDamage100Perc);
    }

    SpellEntities[iInflictor].Destroy();

    fDamage = fDamageTemp;
    iDamageType ^= DMG_CRIT ^ DMG_PREVENT_PHYSICS_FORCE;

    return Plugin_Changed;
}

public void OnTakeDamageAlivePost(int iVictim, int iAttacker, int iInflictor, float fDamage, int iDamageType, int iWeapon, const float fDamageForce[3], const float fDamagePosition[3])
{
    if(!IsValidEntity(iVictim) || !IsValidEntity(iAttacker) || !IsValidEntity(iWeapon) || iAttacker == iVictim)
        return;

    if(!Weapon[iWeapon].fMaxRage)
        return;

    Weapon[iWeapon].fRage += fDamage;

    if(Weapon[iWeapon].fRage > Weapon[iWeapon].fMaxRage)
        Weapon[iWeapon].fRage = Weapon[iWeapon].fMaxRage;

    Weapon[iWeapon].fPerc = Weapon[iWeapon].CalculatePercentage();

    return;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                               Functions                                  ||
// ||──────────────────────────────────────────────────────────────────────────||

public void ThrowSpell(int iClient, int iWeapon)
{
    float fPercentage = Weapon[iWeapon].fPerc;

    SpellStrengthType spellStrength = SpellStrength_None;

    float fProjectileSpeedMult = 1.0;

    if(fPercentage >= 100.0)
    {
        spellStrength = SpellStrength_100;
        fProjectileSpeedMult = 0.6;
    }
    else if(fPercentage >= 75.0)
    {
        spellStrength = SpellStrength_75;
        fProjectileSpeedMult = 0.7;
    }
    else if(fPercentage >= 50.0)
    {
        spellStrength = SpellStrength_50;
        fProjectileSpeedMult = 0.8;
    }
    else if(fPercentage >= 25.0)
    {
        spellStrength = SpellStrength_25;
    }

    int iSpell  = CreateEntityByName("tf_projectile_spellfireball");

    if(!IsValidEntity(iSpell))
        return;

    SpellEntities[iSpell].bInternalSpell =  true;
    SpellEntities[iSpell].Strength       =  spellStrength;
    SpellEntities[iSpell].iWeaponID      =  iWeapon;

    Weapon[iWeapon].fRage = 0.0;
    Weapon[iWeapon].fPerc = 0.0;

    float fAng[3], fPos[3];
    GetClientEyeAngles(iClient, fAng);
    GetClientEyePosition(iClient, fPos);

    float fVel[3];
    GetAngleVectors(fAng, fVel, NULL_VECTOR, NULL_VECTOR);

    ScaleVector(fVel, 1000.0 * fProjectileSpeedMult);

    int iTeam = view_as<int>(TF2_GetClientTeam(iClient));

    SetEntPropEnt(iSpell, Prop_Send, "m_hOwnerEntity", iClient);
    SetEntPropEnt(iSpell, Prop_Send, "m_hLauncher", iClient);
    SetEntProp(iSpell, Prop_Send, "m_iTeamNum", iTeam, 1);
    SetEntProp(iSpell, Prop_Send, "m_nSkin", iTeam -2);

    SetVariantInt(iTeam);
    AcceptEntityInput(iSpell, "TeamNum", -1, -1, 0);
    SetVariantInt(iTeam);
    AcceptEntityInput(iSpell, "SetTeam", -1, -1, 0);

    DispatchSpawn(iSpell);
    TeleportEntity(iSpell, fPos, fAng, fVel);

    return;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                                   HUD                                    ||
// ||──────────────────────────────────────────────────────────────────────────||

public Action OnCustomStatusHUDUpdate(int iClient, StringMap entries)
{
    int iActiveWeapon = TF2_GetActiveWeapon(iClient);

    if(!IsValidEntity(iActiveWeapon) || !Weapon[iActiveWeapon].fMaxRage)
        return Plugin_Continue;

    char sHudPerc[64];
    char sHudMeter[40];

    int iFart = RoundToFloor(Weapon[iActiveWeapon].fPerc / 25.0);

    Format(sHudMeter, sizeof(sHudMeter), "   ");

    for(int i = 0; i < iFart; i++)
    {
        Format(sHudMeter, sizeof(sHudMeter), "%s%s", sHudMeter, "◼");
    }

    int iRest = 4 - iFart;

    for(int i = 0; i < iRest; i++)
    {
        Format(sHudMeter, sizeof(sHudMeter), "%s%s", sHudMeter, "◻");
    }

    Format(sHudPerc, sizeof(sHudPerc), "Spell: %0.f%%", Weapon[iActiveWeapon].fPerc);

    entries.SetString("ca_fireballspell_perc", sHudPerc);
    entries.SetString("ca_fireballspell_meter", sHudMeter);

    return Plugin_Changed;
}

// ||──────────────────────────────────────────────────────────────────────────||
// ||                           Internal Functions                             ||
// ||──────────────────────────────────────────────────────────────────────────||

stock bool IsValidClient(int client)
{
    if(client<=0 || client>MaxClients)
    {
        return false;
    }

    if(!IsClientInGame(client))
    {
        return false;
    }

    if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
    {
        return false;
    }
    
    return true;
}

stock int TF2_GetActiveWeapon(int iClient)
{
    return GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

/*
stock void DoAnimation(int iClient, int iEvent, int nData = 0)
{
    SDKCall(hDoAnimation, iClient, iEvent, nData);

    return;
}

void SDK_SendWeaponAnim(int weapon, int anim)
{
    if (g_hSDKSendWeaponAnim != null)
        SDKCall(g_hSDKSendWeaponAnim, weapon, anim);
}
*/