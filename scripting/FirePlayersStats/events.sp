#define HITGROUP_GENERIC	0
#define HITGROUP_HEAD		1
#define HITGROUP_CHEST		2
#define HITGROUP_STOMACH	3
#define HITGROUP_LEFTARM	4
#define HITGROUP_RIGHTARM	5
#define HITGROUP_LEFTLEG	6
#define HITGROUP_RIGHTLEG	7
#define HITGROUP_NECK		8
#define HITGROUP_GEAR		10

static int		iMaxRoundsKills[MAXPLAYERS+1];
static float	fRoundPlayerPoints[MAXPLAYERS+1];

void HookEvents()
{
	HookEvent("weapon_fire", 		Event_WeaponFire);
	HookEvent("player_hurt", 		Event_PlayerHurt);
	HookEvent("player_death", 		Event_PlayerDeath);

	HookEvent("round_prestart",		Event_RoundAction, EventHookMode_PostNoCopy);
	HookEvent("round_mvp",			Event_RoundAction);
	HookEvent("round_end",			Event_RoundAction);

	HookEvent("bomb_planted",		Event_OtherAction);
	HookEvent("bomb_defused",		Event_OtherAction);
	HookEvent("bomb_dropped",		Event_OtherAction);
	HookEvent("bomb_pickup",		Event_OtherAction);
	HookEvent("hostage_killed",		Event_OtherAction);
	HookEvent("hostage_rescued",	Event_OtherAction);
}

public void Event_WeaponFire(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (g_bStatsActive)
	{
		int iClient = CID(hEvent.GetInt("userid"));
		if (!iClient || !g_bStatsLoad[iClient] || !g_hWeaponsData[iClient])
		{
			return;
		}

		char szWeapon[32];
		hEvent.GetString("weapon", SZF(szWeapon));
		if (!IsGrenade(szWeapon[7]))
		{
			if (IsKnife(szWeapon[7]))
			{
				szWeapon = "weapon_knife";
			}
			FPS_Debug("----->> Event_WeaponFire >>----- %s", szWeapon[7])

			int iArray[W_SIZE];
			iArray[W_SHOOTS]++;
			WriteWeaponData(iClient, szWeapon[7], iArray);
		}
	}
}

public void Event_PlayerHurt(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (g_bStatsActive)
	{
		int iAttacker = CID(hEvent.GetInt("attacker"));
		if (!iAttacker || CID(hEvent.GetInt("userid")) == iAttacker || !g_bStatsLoad[iAttacker] || !g_hWeaponsData[iAttacker])
		{
			return;
		}

		char szWeapon[32];
		hEvent.GetString("weapon", SZF(szWeapon));
		if (!IsGrenade(szWeapon))
		{
			if (!IsKnife(szWeapon))
			{
				GetClientWeapon(iAttacker, SZF(szWeapon));
			}
			else
			{
				szWeapon = "weapon_knife";
			}
			FPS_Debug("----->> Event_PlayerHurt >>----- %s", szWeapon[7])

			int iHitgroup = hEvent.GetInt("hitgroup");
			if (iHitgroup != HITGROUP_GENERIC && iHitgroup != HITGROUP_GEAR)
			{
				int iArray[W_SIZE];
				switch(iHitgroup)
				{
					case HITGROUP_HEAD:		iArray[W_HITS_HEAD]++;
					case HITGROUP_NECK:		iArray[W_HITS_NECK]++;
					case HITGROUP_CHEST:	iArray[W_HITS_CHEST]++;
					case HITGROUP_STOMACH:	iArray[W_HITS_STOMACH]++;
					case HITGROUP_LEFTARM:	iArray[W_HITS_LEFT_ARM]++;
					case HITGROUP_RIGHTARM:	iArray[W_HITS_RIGHT_ARM]++;
					case HITGROUP_LEFTLEG:	iArray[W_HITS_LEFT_LEG]++;
					case HITGROUP_RIGHTLEG:	iArray[W_HITS_RIGHT_LEG]++;
				}
				WriteWeaponData(iAttacker, szWeapon[7], iArray);
			}
		}
	}
}

public void Event_PlayerDeath(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (g_bStatsActive)
	{
		if (g_fExtraPoints[CFG_ASSIST])
		{
			int iAssister = CID(hEvent.GetInt("assister"));
			if (iAssister && g_bStatsLoad[iAssister])
			{
				g_iPlayerData[iAssister][ASSISTS]++;
				g_fPlayerPoints[iAssister] += g_fExtraPoints[CFG_ASSIST];
				CheckRank(iAssister);
			}
		}

		int iVictim = CID(hEvent.GetInt("userid")),
			iAttacker = CID(hEvent.GetInt("attacker"));
		if (!iVictim || !iAttacker || !g_bStatsLoad[iVictim] || !g_bStatsLoad[iAttacker])
		{
			return;
		}

		if (iVictim != iAttacker)
		{
			if(!g_bTeammatesAreEnemies && g_fExtraPoints[CFG_TEAMKILL] && GetClientTeam(iAttacker) == GetClientTeam(iVictim))
			{
				g_fPlayerPoints[iAttacker] += g_fExtraPoints[CFG_TEAMKILL];
				CheckRank(iAttacker);
				FPS_Debug("Event_PlayerDeath >> TeamKill >> Attacker: %f", g_fPlayerPoints[iAttacker])
				return;
			}

			iMaxRoundsKills[iAttacker]++;
			g_iPlayerData[iAttacker][KILLS]++;
			g_iPlayerData[iVictim][DEATHS]++;

			char	szWeapon[32];
			hEvent.GetString("weapon", SZF(szWeapon));
			bool	bHeadshot = hEvent.GetBool("headshot"),
					bIsGrenade = IsGrenade(szWeapon);

			if (g_hWeaponsData[iAttacker] && !bIsGrenade)
			{
				if (IsKnife(szWeapon))
				{
					szWeapon = "knife";
				}

				int iArray[W_SIZE];
				iArray[W_KILLS]++;
				if (bHeadshot)
				{
					iArray[W_HEADSHOTS]++;
				}
				FPS_Debug("Event_Death >> Weapon: %s >> HS: %s", szWeapon, bHeadshot ? "TRUE" : "FALSE")
				WriteWeaponData(iAttacker, szWeapon, iArray);
			}

			float	fPointsAttacker	= (g_fPlayerPoints[iVictim] / g_fPlayerPoints[iAttacker]) * 5.0,
					fDiss			= g_fPlayerPoints[iAttacker] / g_fPlayerPoints[iVictim],
					fPointsVictim	= fPointsAttacker * g_fCoeff * (fDiss < 0.5 && FPS_IsCalibration(iAttacker) ? fDiss : 1.0),
					fExtPoints		= GetWeaponExtraPoints(szWeapon, bIsGrenade),
					fHeadshot		= bHeadshot ? g_fExtraPoints[CFG_HEADSHOT] : 0.0,
					fStreak;

			#if USE_STREAK_POINTS == 1
				fStreak = StreakPoints(iAttacker);
			#endif

			fPointsAttacker	= (fPointsAttacker * fExtPoints) + fHeadshot + fStreak;
			FPS_Debug("Event_PlayerDeath >> Points Data: \n ----->> EP: %f \n ----->> HS: %f \n ----->> ST: %f \n ----->> DS: %f", fExtPoints, fHeadshot, fStreak, fDiss)
			FPS_Debug("Event_PlayerDeath >> Points >> Attacker (%N): %f / Victim (%N): %f", iAttacker, fPointsAttacker, iVictim, fPointsVictim)

			ResetIfLessZero(fPointsAttacker);
			ResetIfLessZero(fPointsVictim);

			float	fAddPointsAttacker = fPointsAttacker,
					fAddPointsVictim = fPointsVictim;
			switch(CallForward_OnFPSPointsChangePre(iAttacker, iVictim, hEvent, fAddPointsAttacker, fAddPointsVictim))
			{
				case Plugin_Continue:
				{
					g_fPlayerPoints[iAttacker] += fPointsAttacker;
					g_fPlayerPoints[iVictim] -= fPointsVictim;
				}
				case Plugin_Changed:
				{
					g_fPlayerPoints[iAttacker] += fAddPointsAttacker;
					g_fPlayerPoints[iVictim] -= fAddPointsVictim;
					FPS_Debug("Event_PlayerDeath >> Points Pre Changed >> Attacker (%N): %f / Victim (%N): %f", iAttacker, fAddPointsAttacker, iVictim, fAddPointsVictim)
				}
				default:
				{
					return;
				}
			}

			CheckRank(iAttacker);
			CheckRank(iVictim);

			CallForward_OnFPSPointsChange(iAttacker, iVictim, g_fPlayerPoints[iAttacker], g_fPlayerPoints[iVictim]);
			return;
		}
		g_fPlayerPoints[iVictim] += g_fExtraPoints[CFG_SUICIDE];
	}
}

public void Event_RoundAction(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	switch(sEvName[6])
	{
		case 'p':
		{
			if (g_bBlockStatsOnWarmup && GameRules_GetProp("m_bWarmupPeriod"))
			{
				FPS_PrintToChatAll("%t", "StatsWarmupBlocked");
				g_bStatsActive = false;
				return;
			}

			if (g_bDisableStatisPerRound)
			{
				g_bStatsActive = false;
				g_bDisableStatisPerRound = false;
				return;
			}

			if (g_iGameType[0] == 1 && g_iGameType[1] == 2)
			{
				g_bStatsActive = true;
				FPS_Debug("Event_RoundAction (s) >> Stats %s (Randomspawn)", g_bStatsActive ? "ON" : "OFF")
				return;
			}
			
			int iPlayers;
			for (int i = 1; i <= MaxClients; ++i)
			{
				if (g_bStatsLoad[i])
				{
					iMaxRoundsKills[i] = 0;
					fRoundPlayerPoints[i] = g_fPlayerPoints[i];
					g_iPlayerSessionData[i][MAX_ROUNDS_KILLS] = 1;

					if (GetClientTeam(i) > 1)
					{
						++iPlayers;
					}
				}
			}
			g_bStatsActive = (iPlayers >= g_iMinPlayers);
			if (!g_bStatsActive)
			{
				FPS_PrintToChatAll("%t", "NoPlayersForStatsWork", g_iMinPlayers);
			}

			FPS_Debug("Event_RoundAction (s) >> Stats %s", g_bStatsActive ? "ON" : "OFF")
		}
		case 'm':
		{
			if (g_bStatsActive && g_fExtraPoints[CFG_MVP_PLAYER])
			{
				int iClient = CID(hEvent.GetInt("userid"));
				if (iClient && g_bStatsLoad[iClient])
				{
					g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_MVP_PLAYER];
					CheckRank(iClient);
				}

				FPS_Debug("Event_RoundAction (m) >> MVP: %N", iClient)
			}
		}
		case 'e':
		{
			if (g_bStatsActive && g_iGameType[0] != 1 && g_iGameType[1] != 2 && GameRules_GetProp("m_totalRoundsPlayed"))
			{
				static int iSave;
				bool bSave = !(++iSave%g_iSaveInterval);
				int iTeam, iWinTeam = GetEventInt(hEvent, "winner");

				for (int i = 1; i <= MaxClients; ++i)
				{
					if (g_bStatsLoad[i] && (iTeam = GetClientTeam(i)) > 1)
					{
						if (iMaxRoundsKills[i] > g_iPlayerData[i][MAX_ROUNDS_KILLS])
						{
							g_iPlayerData[i][MAX_ROUNDS_KILLS] = iMaxRoundsKills[i];
						}

						if (g_iPlayerSessionData[i][MAX_ROUNDS_KILLS] && iWinTeam > 1)
						{
							if (iTeam == iWinTeam)
							{
								g_iPlayerData[i][ROUND_WIN]++;
								g_fPlayerPoints[i] += g_fExtraPoints[CFG_WIN_ROUND];
							}
							else
							{
								g_iPlayerData[i][ROUND_LOSE]++;
								g_fPlayerPoints[i] += g_fExtraPoints[CFG_LOSE_ROUND];
							}
							
							CheckRank(i);
						}

						if (g_iPlayerSessionData[i][MAX_ROUNDS_KILLS])
						{
							float fPoints = g_fPlayerPoints[i] - fRoundPlayerPoints[i];
							FPS_PrintToChat(i, "%t", "PrintPoints", g_fPlayerPoints[i], fPoints > 0.0 ? COLOR_POINTS_ADDED : COLOR_POINTS_REDUCED, fPoints);
						}

						if (bSave)
						{
							FPS_Debug("Call Save Function >> %N | %i", i, iSave)
							SavePlayerData(i);
						}
					}
				}

				if (bSave)
				{
					LoadTopData();
					for (int i = 1; i < MaxClients; ++i)
					{
						if (g_bStatsLoad[i])
						{
							GetPlayerPosition(i);
						}
					}
					CallForward_OnFPSSecondDataUpdated();
				}

				FPS_Debug("Event_RoundAction (e) >> ----------------")
			}
		}
	}
}

public void Event_OtherAction(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (g_bStatsActive)
	{
		int iClient = CID(hEvent.GetInt("userid"));
		if (!iClient || !g_bStatsLoad[iClient])
		{
			return;
		}

		switch(sEvName[0])
		{
			case 'b':
			{
				switch(sEvName[6])
				{
					case 'l': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_BOMB_PLANTED];
					case 'e': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_BOMB_DEFUSED];
					case 'r': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_BOMB_DROPPED];
					case 'i': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_BOMB_PICK_UP];
				}
			}
			case 'h':
			{
				switch(sEvName[8])
				{
					case 'k': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_HOSTAGE_KILLED];
					case 'r': g_fPlayerPoints[iClient] += g_fExtraPoints[CFG_HOSTAGE_RESCUED];
				}
			}
		}

		CheckRank(iClient);

		FPS_Debug("Event_OtherAction >> %s", sEvName)
	}
}
