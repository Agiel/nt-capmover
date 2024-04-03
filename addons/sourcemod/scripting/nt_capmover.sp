#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.0.3"

public Plugin myinfo =
{
	name		= "NT Cap Mover",
	description = "Moves the cap zones for certain maps when cap timer is enabled",
	author		= "Agiel",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/Agiel/nt-capmover"
};

ConVar g_cvEnabled;
ConVar g_cvCapTimer;

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("sm_nt_capmover_enable", "0", "Enable custom capzone locations", _, true, 0.0, true, 1.0);
}

public void OnAllPluginsLoaded()
{
	g_cvCapTimer = FindConVar("sm_nt_wincond_captime");
}

void PrintEntry(EntityLumpEntry entry)
{
	PrintToServer("{");
	for (int j, m = entry.Length; j < m; j++)
	{
		char keybuf[32];
		char valbuf[32];
		entry.Get(j, keybuf, sizeof(keybuf), valbuf, sizeof(valbuf));
		PrintToServer("\"%s\"    \"%s\"", keybuf, valbuf);
	}
	PrintToServer("}");
}

public void OnMapInit(const char[] mapName)
{
	if (g_cvEnabled.IntValue == 0)
	{
		return;
	}

	// Read cap zone definitions
	KeyValues kv = new KeyValues("CapZones");
	char	  path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/nt-capmover/%s.capzones.txt", mapName);
	bool success = kv.ImportFromFile(path);
	if (!success)
	{
		PrintToServer("Couldn't find definition file at %s", path);
		if (g_cvCapTimer)
		{
			g_cvCapTimer.SetFloat(0.0);
		}
		delete kv;
		return;
	}

	if (!kv.GotoFirstSubKey(false))
	{
		PrintToServer("Failed to find CapZones");
		delete kv;
		return;
	}

	// Strip existing cap zones
	for (int i, n = EntityLump.Length(); i < n; i++)
	{
		EntityLumpEntry entry	 = EntityLump.Get(i);
		int				keyIndex = entry.FindKey("classname");
		if (keyIndex != -1)
		{
			char valbuffer[26];
			entry.Get(keyIndex, "", 0, valbuffer, sizeof(valbuffer));
			if (StrEqual(valbuffer, "neo_ghost_retrieval_point"))
			{
				PrintToServer("Removing:");
				PrintEntry(entry);
				EntityLump.Erase(i);
				i--;
				n--;
			}
		}
		delete entry;
	}

	float timer = 0.0;

	// Add new cap zones
	do
	{
		char name[16];
		kv.GetSectionName(name, sizeof(name));

		if (StrEqual(name, "timer"))
		{
			timer = kv.GetFloat(NULL_STRING);
		}
		else if (StrEqual(name, "CapZone"))
		{
			int				index = EntityLump.Append();
			EntityLumpEntry entry = EntityLump.Get(index);
			entry.Append("angles", "0 0 0");
			entry.Append("classname", "neo_ghost_retrieval_point");

			kv.GotoFirstSubKey(false);
			do
			{
				char key[16];
				kv.GetSectionName(key, sizeof(key));

				if (StrEqual(key, "origin"))
				{
					char origin[32];
					kv.GetString(NULL_STRING, origin, sizeof(origin));
					entry.Append("origin", origin);
				}
				else if (StrEqual(key, "team")) {
					char team[2];
					kv.GetString(NULL_STRING, team, sizeof(team));
					entry.Append("team", team);
				}
				else if (StrEqual(key, "Radius")) {
					char radius[4];
					kv.GetString(NULL_STRING, radius, sizeof(radius));
					entry.Append("Radius", radius);
				}
			}
			while (kv.GotoNextKey(false));

			PrintToServer("Adding:");
			PrintEntry(entry);

			delete entry;

			kv.GoBack();
		}
	}
	while (kv.GotoNextKey(false));

	if (g_cvCapTimer)
	{
		PrintToServer("Setting cap timer to %f", timer);
		g_cvCapTimer.SetFloat(timer);
	}

	delete kv;
}
