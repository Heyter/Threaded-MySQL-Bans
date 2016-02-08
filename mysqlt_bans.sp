#include <sourcemod>
#include <sdktools>
#include "storage.sp"
#include "bans.sp"

#define PLUGIN_VERSION "1.4.1"

public Plugin myinfo = {
  name = "MySQL-T bans",
  author = "the casual trade and fun server",
  description = "Threaded SteamID based mysql bans.",
  version = PLUGIN_VERSION,
  url = "http://tf2-casual-fun.de/"
};

public void OnPluginStart()
{
  CreateConVar("sm_mybans_version", PLUGIN_VERSION, "MYSQL-T Bans Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
  AddCommandListener(OnAddBan, "sm_addban");

  Connect_to_Database();
}

public Action OnBanClient(int client, int time, int flags, const char[] reason, const char[] kick_message, const char[] command, any admin)
{
  char steamId[MAX_AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

  char playerName[MAX_NAME_LENGTH];
  GetClientName(client, playerName, sizeof(playerName));

  AddBanFor(playerName, steamId, time, reason, admin);

  return Plugin_Continue;
}

public Action OnAddBan(int admin, const char[] command, int argc)
{
  if(!CheckCommandAccess(admin, "sm_addban", ADMFLAG_BAN))
    return Plugin_Handled;

  if(argc < 2) {
    PrintToChat(admin, "[SM] Usage: %s <SteamId> <minutes|0> [reason]", command);
    return Plugin_Handled;
  }

  char arguments[256];
  GetCmdArgString(arguments, sizeof(arguments));

  char steamId[MAX_AUTH_LENGTH];
  int nextArgumentPosition = BreakString(arguments[nextArgumentPosition], steamId, sizeof(steamId));

  char banLengthAsString[10];
  nextArgumentPosition = BreakString(arguments, banLengthAsString, sizeof(banLengthAsString));

  int banLength = StringToInt(banLengthAsString);

  char reason[MAX_REASON_LENGTH];
  strcopy(arguments[nextArgumentPosition], sizeof(reason), reason);

  AddBanFor("", steamId, banLength, reason, admin);
  return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
  CheckBanStateOfClient(client);
}

public Action OnRemoveBan(const char[] steamId, int flags, const char[] command, any admin)
{
  RemoveBanOf(steamId);

  ReplyToCommand(admin, "[MYBans] User %s has been unbanned", steamId);
  LogAction(admin, 0, "%L unbanned Steam ID %s.", admin, steamId);

  return Plugin_Continue;
}
