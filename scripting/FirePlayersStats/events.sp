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
	if (g_bStatsActive && g_hWeaponsKV)
	{
		int iClient = CID(hEvent.GetInt("userid"));
		if (!iClient || !g_bStatsLoad[iClient])
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
			FPS_Debug("----->> Event_WeaponFire >>----- %s", szWeapon)

			if (JumpToWeapons(iClient, szWeapon[7]))
			{
				g_hWeaponsKV.SetNum("shoots", g_hWeaponsKV.GetNum("shoots", 0) + 1);
			}
		}
	}
}

public void Event_PlayerHurt(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if (g_bStatsActive && g_hWeaponsKV)
	{
		int iAttacker = CID(hEvent.GetInt("attacker"));
		if (!iAttacker || CID(hEvent.GetInt("userid")) == iAttacker || !g_bStatsLoad[iAttacker])
		{
			return;
		}

		char szWeapon[32];
		hEvent.GetString("weapon", SZF(szWeapon));
		if (!IsKnife(szWeapon))
		{
			if (IsGrenade(szWeapon))
			{
				return;
			}
			GetClientWeapon(iAttacker, SZF(szWeapon));
		}
		else
		{
			szWeapon = "weapon_knife";
		}
		FPS_Debug("----->> Event_PlayerHurt >>----- %s", szWeapon)

		int iHitgroup = hEvent.GetInt("hitgroup");
		if (iHitgroup != HITGROUP_GENERIC && iHitgroup != HITGROUP_GEAR && JumpToWeapons(iAttacker, szWeapon[7]))
		{
			//g_hWeaponsKV.SetNum("hits", g_hWeaponsKV.GetNum("hits", 0) + 1);
			switch(iHitgroup)
			{
				case HITGROUP_HEAD, HITGROUP_NECK: g_hWeaponsKV.SetNum("hitsHead", g_hWeaponsKV.GetNum("hitsHead", 0) + 1);
				case HITGROUP_CHEST, HITGROUP_STOMACH: g_hWeaponsKV.SetNum("hitsBody", g_hWeaponsKV.GetNum("hitsBody", 0) + 1);
				case HITGROUP_LEFTARM: g_hWeaponsKV.SetNum("hitsLeftArm", g_hWeaponsKV.GetNum("hitsLeftArm", 0) + 1);
				case HITGROUP_RIGHTARM: g_hWeaponsKV.SetNum("hitsRightArm", g_hWeaponsKV.GetNum("hitsRightArm", 0) + 1);
				case HITGROUP_LEFTLEG: g_hWeaponsKV.SetNum("hitsLeftLeg", g_hWeaponsKV.GetNum("hitsLeftLeg", 0) + 1);
				case HITGROUP_RIGHTLEG: g_hWeaponsKV.SetNum("hitsRightLeg", g_hWeaponsKV.GetNum("hitsRightLeg", 0) + 1);
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
				#if USE_RANKS == 1
					CheckRank(iAssister);
				#endif
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
			if(g_fExtraPoints[CFG_TEAMKILL] && GetClientTeam(iAttacker) == GetClientTeam(iVictim))
			{
				g_fPlayerPoints[iAttacker] += g_fExtraPoints[CFG_TEAMKILL];
				#if USE_RANKS == 1
					CheckRank(iAttacker);
				#endif
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

			if (g_hWeaponsKV && !bIsGrenade)
			{
				if (!IsKnife(szWeapon))
				{
					GetClientWeapon(iAttacker, SZF(szWeapon));
				}
				else
				{
					szWeapon = "weapon_knife";
				}

				if (JumpToWeapons(iAttacker, szWeapon[7]))
				{
					g_hWeaponsKV.SetNum("kills", g_hWeaponsKV.GetNum("kills", 0) + 1);
					if (bHeadshot)
					{
						g_hWeaponsKV.SetNum("headshots", g_hWeaponsKV.GetNum("headshots", 0) + 1);
					}
					FPS_Debug("Event_Death >> g_hWeaponsKV >> Kills (%s)", bHeadshot ? "HS" : "No HS")
				}
			}

			float	fPointsAttacker = ((g_fPlayerPoints[iVictim] / g_fPlayerPoints[iAttacker]) * 5.0 + (bHeadshot ? g_fExtraPoints[CFG_HEADSHOT] : 0.0) + StreakPoints(iAttacker) * (!bIsGrenade ? GetWeaponExtraPoints(szWeapon[7]) : 0.0)),
					fDiss = (g_fPlayerPoints[iAttacker] / g_fPlayerPoints[iVictim]),
					fPointsVictim = (fPointsAttacker * g_fCoeff) * (fDiss < 0.5 && FPS_IsCalibration(iAttacker) ? fDiss : 1.0);
			FPS_Debug("Event_PlayerDeath >> Points Data: \n ----->> HS: %f \n ----->> SP: %f \n ----->> EP: %f \n ----->> DS: %f : %f", (bHeadshot ? g_fExtraPoints[CFG_HEADSHOT] : 0.0), StreakPoints(iAttacker), (!bIsGrenade ? GetWeaponExtraPoints(szWeapon[7]) : 0.0), fDiss, (fDiss < 0.5 && FPS_IsCalibration(iAttacker) ? fDiss : 1.0))
			FPS_Debug("Event_PlayerDeath >> Points >> Attacker (%N): %f / Victim (%N): %f", iAttacker, fPointsAttacker, iVictim, fPointsVictim)

			ResetIfLessZero(fPointsAttacker);
			ResetIfLessZero(fPointsVictim);

			float	fAddPointsAttacker = fPointsAttacker,
					fAddPointsVictim = fPointsVictim;
			switch(CallForward_OnFPSPointsChangePre(iAttacker, iVictim, bHeadshot, fAddPointsAttacker, fAddPointsVictim))
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

			#if USE_RANKS == 1
				CheckRank(iAttacker);
				CheckRank(iVictim);
			#endif

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
			
			int iPlayers;
			for (int i = 1; i <= MaxClients; ++i)
			{
				if (g_bStatsLoad[i])
				{
					iMaxRoundsKills[i] = 0;
					fRoundPlayerPoints[i] = g_fPlayerPoints[i];
					g_iPlayerSessionData[i][MAX_ROUNDS_KILLS] = 1;
					++iPlayers;
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
					#if USE_RANKS == 1
						CheckRank(iClient);
					#endif
				}

				FPS_Debug("Event_RoundAction (m) >> MVP: %N", iClient)
			}
		}
		case 'e':
		{
			static int iSave;
			if (g_bStatsActive && GameRules_GetProp("m_totalRoundsPlayed"))
			{
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
							#if USE_RANKS == 1
								CheckRank(i);
							#endif
						}

						if (g_iPlayerSessionData[i][MAX_ROUNDS_KILLS])
						{
							float fPoints = g_fPlayerPoints[i] - fRoundPlayerPoints[i];
							FPS_PrintToChat(i, "%t", "PrintPoints", fPoints > 0.0 ? "{GREEN}" : "{RED}", fPoints);
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

		#if USE_RANKS == 1
			CheckRank(iClient);
		#endif

		FPS_Debug("Event_OtherAction >> %s", sEvName)
	}
}
