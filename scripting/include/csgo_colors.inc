/**************************************************************************
 *                             CS:GO COLORS                               *
 *                     Автор: Феникс(komashchenko)                        *
 *                            Version: 1.6                                *
 *                  http://zizt.ru/  http://hlmod.ru/                     *
 * 03.07.2014 - V1.0: Релиз                                               *
 * 13.10.2014 - V1.1: Обнова                                              *
 * 24.10.2014 - V1.2: Обнова                                              *
 * 17.11.2014 - V1.3: Исправление ошибок                                  *
 * 23.12.2015 - V1.4: Исправление ошибок, Обнова                          *
 * 02.12.2018 - V1.5: Немного переработал, убрал лишнее                   *
 * 04.12.2018 - V1.6: Исправление ошибки с файлами перевода               *
 **************************************************************************/

#define ZCOLOR 14
static char g_sBuf[2048];

static const char color_t[ZCOLOR][] = {"{DEFAULT}", "{RED}", "{LIGHTPURPLE}", "{GREEN}", "{LIME}", "{LIGHTGREEN}", "{LIGHTRED}", "{GRAY}", "{LIGHTOLIVE}", "{OLIVE}", "{LIGHTBLUE}", "{BLUE}", "{PURPLE}", "{GRAYBLUE}"},
	color_c[ZCOLOR][] = {"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0B", "\x0C", "\x0E", "\x0A"};


stock void CGOPrintToChat(int iClient, const char[] message, any ...)
{
	SetGlobalTransTarget(iClient);
	VFormat(g_sBuf, sizeof g_sBuf, message, 3);
	
	int iLastStart = 0, i = 0;
	for(; i < ZCOLOR; i++)
	{
		ReplaceString(g_sBuf, sizeof g_sBuf, color_t[i], color_c[i], false);
	}
	
	i = 0;
	
	while(g_sBuf[i])
	{
		if(g_sBuf[i] == '\n')
		{
			g_sBuf[i] = 0;
			PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
			iLastStart = i+1;
		}
		
		i++;
	}
	
	PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
}

stock void CGOPrintToChatAll(const char[] message, any ...)
{
	int iLastStart = 0, i = 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++) if(IsClientInGame(iClient) && !IsFakeClient(iClient))
	{
		SetGlobalTransTarget(iClient);
		VFormat(g_sBuf, sizeof g_sBuf, message, 2);
		
		for(i = 0; i < ZCOLOR; i++)
		{
			ReplaceString(g_sBuf, sizeof g_sBuf, color_t[i], color_c[i], false);
		}
		
		iLastStart = 0, i = 0;
		
		while(g_sBuf[i])
		{
			if(g_sBuf[i] == '\n')
			{
				g_sBuf[i] = 0;
				PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
				iLastStart = i+1;
			}
			
			i++;
		}
		
		PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
	}
}

stock void CGOReplaceColorSay(char[] text, int maxlength)
{
	for(int i = 0; i < ZCOLOR; i++)
	{
		ReplaceString(text, maxlength, color_t[i], color_c[i], false);
	}
}

stock void GOPrintToChat(int iClient, const char[] message, any ...)
{
	SetGlobalTransTarget(iClient);
	VFormat(g_sBuf, sizeof g_sBuf, message, 3);
	
	int iLastStart = 0, i = 0;
	
	while(g_sBuf[i])
	{
		if(g_sBuf[i] == '\n')
		{
			g_sBuf[i] = 0;
			PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
			iLastStart = i+1;
		}
		
		i++;
	}
	
	PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
}

stock void GOPrintToChatAll(const char[] message, any ...)
{
	int iLastStart = 0, i = 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++) if(IsClientInGame(iClient) && !IsFakeClient(iClient))
	{
		SetGlobalTransTarget(iClient);
		VFormat(g_sBuf, sizeof g_sBuf, message, 2);
		
		iLastStart = 0, i = 0;
		
		while(g_sBuf[i])
		{
			if(g_sBuf[i] == '\n')
			{
				g_sBuf[i] = 0;
				PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
				iLastStart = i+1;
			}
			
			i++;
		}
		
		PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
	}
}