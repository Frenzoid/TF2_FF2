#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

// Plugin metadata.
public Plugin:myinfo =  
{  
    name = "[TF2] Set class max speed",
    author = "MrFrenzoid",
    description = "Change default speed on each class, or all classed via additive health.",
    version = "5.0",                                                             
    url = "http://www.sourcemod.net/"
}; 

// Declaring cvars variables that we'll use to store the cvars values and use them later.
new Handle:g_cvSEnabled;
new Handle:g_cvSMode;
new Handle:g_cvSTeam;
new Handle:g_cvSIncrement;

new Handle:g_cvSSoldier;
new Handle:g_cvSPyro;
new Handle:g_cvSSpy;
new Handle:g_cvSDemoman;
new Handle:g_cvSSniper;
new Handle:g_cvSEngineer;
new Handle:g_cvSHeavy;
new Handle:g_cvSScout;
new Handle:g_cvSMedic;

// Executed when the plugins first launches.
public OnPluginStart()
{       
    // Creating cvars, and associating their value to each variable.
    g_cvSEnabled = CreateConVar("sm_spenabled", "1", "Sets whether the plugin is enabled.");

    g_cvSMode = CreateConVar("sm_spmode", "0", "Sets plugins mode, 0: sm_spincrement = % speed for everyone, 1: Custom speed % for each class from each ones cvar");
    g_cvSTeam = CreateConVar("sm_spteam", "1", "0: apply to all teams, 1: Only RED, 2: Only Blue");

    g_cvSIncrement = CreateConVar("sm_spincrement", "1.1", "Default % speed added to everyone if sm_spmode = 1.");

    g_cvSSoldier = CreateConVar("sm_spsoldier", "1.1", "Change speed % on Soldiers speed");
    g_cvSPyro = CreateConVar("sm_sppyro", "1.1", "Change speed % on Pyros speed");
    g_cvSSpy = CreateConVar("sm_spspy", "1.1", "Change speed % on  Spys speed");
    g_cvSDemoman = CreateConVar("sm_spdemoman", "1.1", "Change speed % on Demomans speed");
    g_cvSSniper = CreateConVar("sm_spsniper", "1.1", "Change speed % on Sniers speed");
    g_cvSEngineer = CreateConVar("sm_spengineer", "1.1", "Change speed % on Engineers speed");
    g_cvSHeavy = CreateConVar("sm_spheavy", "1.1", "Change speed % on Heavys speed");
    g_cvSScout = CreateConVar("sm_spscout", "1.1", "Change speed % on Scouts speed");
    g_cvSMedic = CreateConVar("sm_spmedic", "1.1", "Change speed % on Medics speed");

    // Autogenerates a config file on cfg/sourcemod.
    AutoExecConfig(true, "setclassmaxspeed");

    // Hook an event, when the event "player_spawn" or "player_Changeclass" triggers, call the function Event_UpdateMaxHp.
    HookEvent("player_spawn", Event_UpdateMaxSpeed);
}
 
// Executed when the player event "player_spawn" gets triggered.
public Action:Event_UpdateMaxSpeed(Handle:event, const String:name[], bool:dontBroadcast)
{
    // If the plugin is off, just continue.
    //  return plugin didn't Change gameplay state.
    if (!GetConVarBool(g_cvSEnabled))
            return Plugin_Continue;

    // Get client's index number.
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    // Get players class and team.
    new TFClassType:PlayerClass = TF2_GetPlayerClass(client);
    new TFTeam:PlayerTeam = TFTeam:GetClientTeam(client);
    
    // If the player is from any other team that g_cvSTeam is setted to, dont do anything.
    //  Return plugin didn't Change gameplay state.
    if ((GetConVarInt(g_cvSTeam) == 1 && PlayerTeam != TFTeam_Red) || (GetConVarInt(g_cvSTeam) == 2 && PlayerTeam != TFTeam_Blue))
        return Plugin_Continue;

    // Depending on the mode, set everyones max speed depending on g_cvSIncrement's value, or set each class specifically its own speed based on the cvars.
    // If mode is 0:
    if (!GetConVarBool(g_cvSMode))
    {
        // % speed value for everyone.
        TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(g_cvSIncrement));
    }
    // If mode is 1:
    else
    {   // Depending on the player's class, set a different value for their % speed.
        switch(PlayerClass)
        {
            case TFClass_Heavy:
            {
		        TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(g_cvSHeavy));
            }
            case TFClass_Soldier:
            {
		        TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(g_cvSSoldier));
            }
            case TFClass_Pyro:
            {
		        TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(g_cvSPyro));
            }
            case TFClass_Spy:
            {
		        TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(g_cvSSpy));
            }
            case TFClass_Sniper:
            {
		        TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(g_cvSSniper));
            }
            case TFClass_DemoMan:
            {
		        TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(g_cvSDemoman));
            }
            case TFClass_Scout:
            {
		        TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(g_cvSScout));
            }
            case TFClass_Engineer:
            {
		        TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(g_cvSEngineer));
            }
            case TFClass_Medic:
            {
		        TF2Attrib_SetByName(client, "move speed bonus", GetConVarFloat(g_cvSMedic));
            }
        }
    }

    // Return plugin Changed gameplay state.
    return Plugin_Changed;
}