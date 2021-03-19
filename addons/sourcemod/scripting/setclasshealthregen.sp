#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

// Plugin metadata.
public Plugin:myinfo =  
{  
    name = "[TF2] Set class health regen",
    author = "MrFrenzoid",
    description = "Add and change health regen per class per second.",
    version = "5.0",                                                             
    url = "http://www.sourcemod.net/"
}; 

// Declaring cvars variables that we'll use to store the cvars values and use them later.
new Handle:g_cvREnabled;
new Handle:g_cvRMode;
new Handle:g_cvRTeam;
new Handle:g_cvRIncrement;

new Handle:g_cvRSoldier;
new Handle:g_cvRPyro;
new Handle:g_cvRSpy;
new Handle:g_cvRDemoman;
new Handle:g_cvRSniper;
new Handle:g_cvREngineer;
new Handle:g_cvRHeavy;
new Handle:g_cvRScout;
new Handle:g_cvRMedic;

// Executed when the plugins first launches.
public OnPluginStart()
{       
    // Creating cvars, and associating their value to each variable.
    g_cvREnabled = CreateConVar("sm_rhenabled", "1", "Sets whether the plugin is enabled.");

    g_cvRMode = CreateConVar("sm_rhmode", "0", "Sets plugins mode, 0: sm_rhincrement = additive value to the default regen health for each class for everyone, 1: Custom health value for each class from each ones cvar");
    g_cvRTeam = CreateConVar("sm_rhteam", "1", "0: apply to all teams, 1: Only RED, 2: Only Blue");

    g_cvRIncrement = CreateConVar("sm_rhincrement", "4", "Additive health added to everyone per second if sm_spmode = 1.");

    g_cvRSoldier = CreateConVar("sm_rhsoldier", "2", "Sets Soldiers regen health per second");
    g_cvRPyro = CreateConVar("sm_rhpyro", "2", "Sets Pyros regen health per second");
    g_cvRSpy = CreateConVar("sm_rhspy", "2", "Sets Spys regen health per second");
    g_cvRDemoman = CreateConVar("sm_rhdemoman", "2", "Sets Demomans regen health per second");
    g_cvRSniper = CreateConVar("sm_rhsniper", "2", "Sets Snipers regen health per second");
    g_cvREngineer = CreateConVar("sm_rhengineer", "2", "Sets Engineers regen health per second");
    g_cvRHeavy = CreateConVar("sm_rhheavy", "2", "Sets Heavys regen health per second");
    g_cvRScout = CreateConVar("sm_rhscout", "2", "Sets Scouts regen health per second");
    g_cvRMedic = CreateConVar("sm_rhmedic", "2", "Sets Medics regen health per second");

    // Autogenerates a config file on cfg/sourcemod.
    AutoExecConfig(true, "setclassregenhealth");

    // Hook an event, when the event "player_spawn" or "player_changeclass" triggers, call the function Event_UpdateRegenHp.
    HookEvent("player_spawn", Event_UpdateRegenHp);
}
 
// Executed when the player event "player_spawn" gets triggered.
public Action:Event_UpdateRegenHp(Handle:event, const String:name[], bool:dontBroadcast)
{
    // If the plugin is off, just continue.
    //  return plugin didn't change gameplay state.
    if (!GetConVarBool(g_cvREnabled))
            return Plugin_Continue;

    // Get client's index number.
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    // Get players class and team.
    new TFClassType:PlayerClass = TF2_GetPlayerClass(client);
    new TFTeam:PlayerTeam = TFTeam:GetClientTeam(client);
    
    // If the player is from any other team that g_cvRTeam is setted to, dont do anything.
    //  Return plugin didn't change gameplay state.
    if ((GetConVarInt(g_cvRTeam) == 1 && PlayerTeam != TFTeam_Red) || (GetConVarInt(g_cvRTeam) == 2 && PlayerTeam != TFTeam_Blue))
        return Plugin_Continue;

    // Depending on the mode, set everyones regen hp depending on g_cvRIncrement's value, or set each class specifically its own regen health based on the cvars.
    // If mode is 0:
    if (!GetConVarBool(g_cvRMode))
    {
        // current regen health + sm_rhincrement values.
        TF2Attrib_SetByName(client, "health regen", GetConVarFloat(g_cvRIncrement));
    }
    // If mode is 1:
    else
    {   // Depending on the player's class, set a different value for their regen health.
        switch(PlayerClass)
        {
            case TFClass_Heavy:
            {
		        TF2Attrib_SetByName(client, "health regen", GetConVarFloat(g_cvRHeavy));
            }
            case TFClass_Soldier:
            {
		        TF2Attrib_SetByName(client, "health regen", GetConVarFloat(g_cvRSoldier));
            }
            case TFClass_Pyro:
            {
		        TF2Attrib_SetByName(client, "health regen", GetConVarFloat(g_cvRPyro));
            }
            case TFClass_Spy:
            {
		        TF2Attrib_SetByName(client, "health regen", GetConVarFloat(g_cvRSpy));
            }
            case TFClass_Sniper:
            {
		        TF2Attrib_SetByName(client, "health regen", GetConVarFloat(g_cvRSniper));
            }
            case TFClass_DemoMan:
            {
		        TF2Attrib_SetByName(client, "health regen", GetConVarFloat(g_cvRDemoman));
            }
            case TFClass_Scout:
            {
		        TF2Attrib_SetByName(client, "health regen", GetConVarFloat(g_cvRScout));
            }
            case TFClass_Engineer:
            {
		        TF2Attrib_SetByName(client, "health regen", GetConVarFloat(g_cvREngineer));
            }
            case TFClass_Medic:
            {
		        TF2Attrib_SetByName(client, "health regen", GetConVarFloat(g_cvRMedic));
            }
        }
    }

    // Return plugin changed gameplay state.
    return Plugin_Changed;
}