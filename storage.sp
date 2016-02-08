#define MAX_QUERY_LENGTH 255
#define BIG_QUERY_LENGTH 512

Database storage_connection = null;
Database Storage_Connection()
{
  if(storage_connection == null) {
    Connect_to_Database();
  }

  return storage_connection;
}

void Connect_to_Database()
{
  if(SQL_CheckConfig("threaded-bans"))
    Database.Connect(ConnectedToDatabase, "threaded-bans");
  else
    Database.Connect(ConnectedToDatabase, "default");
}

public void ConnectedToDatabase(Database database, const char[] error, any data)
{
  if (database == null)
    LogError("[MYBans] Error during connection to database: %s", error);
  else {
    storage_connection = database;
    SetupStorage(database);
  }
}

void SetupStorage(Database connection) {
  CreateTableIfNotExists(connection);
  UpdateTableIfNeeded(connection);
}

void CreateTableIfNotExists(Database connection)
{
  char query[BIG_QUERY_LENGTH];

  Format(query,sizeof(query), "%s%s%s%s%s%s%s%s%s%s%s",
    "CREATE TABLE IF NOT EXISTS `my_bans` (",
      "`id` int(11) NOT NULL auto_increment,",
      "`steam_id` varchar(32) NOT NULL,",
      "`player_name` varchar(65) NOT NULL,",
      "`ban_length` int(1) NOT NULL default '0',",
      "`ban_reason` varchar(100) NOT NULL,",
      "`banned_by` varchar(100) NOT NULL,",
      "`timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP,",
      "PRIMARY KEY  (`id`),",
      "UNIQUE KEY `steam_id` (`steam_id`)",
    ") ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;"
  );

  connection.Query(DatabaseCreated, query);
}

public void DatabaseCreated(Database database, DBResultSet result, const char[] error, any data)
{
  if(result == null)
    LogError("[MYBans] Error during table creation: %s", error);
}

void UpdateTableIfNeeded(Database connection) {
  connection.Query(NeedUpdate, "SHOW COLUMNS FROM my_bans LIKE admin_steam_id;");
}

public void NeedUpdate(Database database, DBResultSet result, const char[] error, any data)
{
  if(result == null)
    LogError("[MYBans] Error during table update: %s", error);
  else if(result.RowCount <= 0)
    UpdateTable(database);
}

void UpdateTable(Database connection) {
  char query[MAX_QUERY_LENGTH];

  Format(query, sizeof(query), "%s%s",
    "ALTER TABLE my_bans ",
    "ADD COLUMN admin_steam_id varchar(32) NOT NULL;");

  connection.Query(UpdateFinished, query);
}

public void UpdateFinished(Database database, DBResultSet result, const char[] error, any data)
{
  if(result == null)
    LogError("[MYBans] Error during table update: %s", error);
}
