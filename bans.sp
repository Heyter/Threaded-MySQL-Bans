#define MAX_QUERY_LENGTH 255
#define BIG_QUERY_LENGTH 512

#define MAX_REASON_LENGTH 128
#define MAX_AUTH_LENGTH 32
#define MAX_DURATION_LENGTH 32


void AddBanFor(const char[] playerName, const char[] steamId, int banLength, const char[] reason, int admin)
{
  int stringLength = strlen(playerName) * 2 + 1;
  char[] escapedPlayerName = new char[stringLength];
  storage_connection.Escape(playerName, escapedPlayerName, stringLength);

  stringLength = strlen(steamId) * 2 + 1;
  char[] escapedSteamId = new char[stringLength];
  storage_connection.Escape(steamId, escapedSteamId, stringLength);

  stringLength = strlen(reason) * 2 + 1;
  char[] escapedReason = new char[stringLength];
  storage_connection.Escape(reason, escapedReason, stringLength);

  char adminName[MAX_NAME_LENGTH];
  bool adminIsConsole = admin == 0;
  if(adminIsConsole)
    adminName = "Console";
  else
    GetClientName(admin, adminName, sizeof(adminName));

  stringLength = strlen(adminName) * 2 + 1;
  char[] escapedAdminName = new char[stringLength];
  storage_connection.Escape(adminName, escapedAdminName, stringLength);

  char adminSteamId[MAX_AUTH_LENGTH];
  if(adminIsConsole)
    adminSteamId = "Console";
  else
    GetClientAuthId(admin, AuthId_Steam2, adminSteamId, sizeof(adminSteamId));

  stringLength = strlen(adminSteamId) * 2 + 1;
  char[] escapedAdminSteamId = new char[stringLength];
  storage_connection.Escape(adminSteamId, escapedAdminSteamId, stringLength);

  char query[BIG_QUERY_LENGTH];
  Format(query, sizeof(query), "REPLACE INTO my_bans (player_name, steam_id, ban_length, ban_reason, banned_by, admin_steam_id, timestamp) VALUES ('%s','%s','%d','%s','%s', '%s', CURRENT_TIMESTAMP);", escapedPlayerName, escapedSteamId, banLength, escapedReason, escapedAdminName, escapedAdminSteamId);
  storage_connection.Query(ClientBanned, query);

  char durationAsString[MAX_DURATION_LENGTH];
  DurationAsString(durationAsString, sizeof(durationAsString), banLength);

  LogAction(admin, 0, "%L (%s) banned Steam ID %s (%s): %s", admin, adminSteamId, steamId, durationAsString, reason);
  ReplyToCommand(admin, "[MYBans] Banned Steam ID %s (%s): %s", steamId, durationAsString, reason);
}

public void ClientBanned(Database database, DBResultSet result, const char[] error, any data)
{
  if(result == null)
    LogError("[MYBans] Query failed! %s", error);
}

void CheckBanStateOfClient(int client)
{
  if(IsFakeClient(client))
    return;

  char steamId[MAX_AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

  CheckIfClientIsBanned(client, steamId);
}

void CheckIfClientIsBanned(int client, const char[] steamId) {
  int steamIdLength = strlen(steamId) * 2 + 1;
  char[] escapedSteamId = new char[steamIdLength];
  storage_connection.Escape(steamId, escapedSteamId, steamIdLength);

  char query[MAX_QUERY_LENGTH];
  Format(query, sizeof(query), "SELECT ban_length, TIMESTAMPDIFF(SQL_TSI_MINUTE, timestamp, CURRENT_TIMESTAMP), ban_reason FROM my_bans WHERE steam_id = '%s';", escapedSteamId);

  DataPack pack = new DataPack();
  pack.WriteCell(client);
  pack.WriteString(steamId);
  pack.Reset();

  storage_connection.Query(ReceivedBanStateInfo, query, pack);
}

public void ReceivedBanStateInfo(Database database, DBResultSet result, const char[] error, any data)
{
  DataPack pack = view_as<DataPack>(data);
  int client = pack.ReadCell();

  if(client <= 0) {
    delete pack;
    return;
  }

  if(result == null) {
    LogError("[MYBans] Error during check of ban state for client %L: %s", client, error);
    if (IsClientConnected(client)) {
      KickClient(client, "Error: Reattempt connection");
    }

    delete pack;
    return;
  }

  if(result.RowCount <= 0) {
    delete pack;
    return;
  }

  result.FetchRow();
  int banLength = result.FetchInt(0);

  int minutesSinceBan = result.FetchInt(1);
  int timeRemaining = banLength - minutesSinceBan;

  if(banLength == 0 || timeRemaining > 0) {
    char durationAsString[MAX_DURATION_LENGTH];
    DurationAsString(durationAsString, sizeof(durationAsString), timeRemaining);

    char banReason[MAX_REASON_LENGTH];
    result.FetchString(2, banReason, sizeof(banReason));

    if (IsClientConnected(client)) {
      KickClient(client, "Banned (%s): %s", durationAsString, banReason);
    }
  }
  else {
    char steamId[MAX_AUTH_LENGTH];
    pack.ReadString(steamId, sizeof(steamId));

    RemoveBanOf(steamId);
    LogAction(0, 0, "Allowing %L to connect. Ban has expired.", client);
  }

  delete pack;
}

void DurationAsString(char[] buffer, int maxLength, int duration)
{
  if(duration == 0)
    strcopy(buffer, maxLength, "permanently");
  else
    Format(buffer, maxLength, "%d %s", duration, (duration == 1) ? "minute" : "minutes");
}

void RemoveBanOf(const char[] steamId)
{
  int steamIdlength = strlen(steamId) * 2 + 1;
  char[] escapedSteamId = new char[steamIdlength];
  storage_connection.Escape(steamId, escapedSteamId, steamIdlength);

  char query[MAX_QUERY_LENGTH];
  Format(query, sizeof(query), "DELETE FROM my_bans WHERE steam_id='%s';", escapedSteamId);

  storage_connection.Query(ClientUnbanned, query);
}

public void ClientUnbanned(Database database, DBResultSet result, const char[] error, any data)
{
  if(result == null)
    LogError("[MYBans] Query failed! %s", error);
}
