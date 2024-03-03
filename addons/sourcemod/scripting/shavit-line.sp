#pragma semicolon 1
#pragma newdecls required

#include <clientprefs>
#include <closestpos>
#include <sdktools>
#include <shavit/core>
#include <shavit/replay-playback>
#include <sourcemod>

int sprite;

ArrayList g_hReplayFrames[STYLE_LIMIT][TRACKS_SIZE];
ClosestPos g_hClosestPos[STYLE_LIMIT][TRACKS_SIZE];
Cookie g_cEnabledCookie;

int g_iTrack[MAXPLAYERS + 1];
int g_iStyle[MAXPLAYERS + 1];
int g_iCmdNum[MAXPLAYERS + 1];
bool g_bLineEnabled[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "shavit-line",
	author = "SeenKid / nimmy",
	description = "Shows the WR route with a path on the ground. Use the command sm_line to toggle.",
	version = "1.0.4",
	url = "https://github.com/Nimmy2222/shavit-line"
};

public void OnPluginStart()
{
	g_cEnabledCookie = new Cookie( "shavit_lines", "", CookieAccess_Private );

	Shavit_OnReplaysLoaded();
	for( int z = 1; z <= MaxClients; z++ )
	{
		if( IsClientInGame(z) && !IsFakeClient(z) )
		{
			g_iStyle[z] = Shavit_GetBhopStyle(z);
			g_iTrack[z] = Shavit_GetClientTrack(z);

			if(AreClientCookiesCached(z))
			{
				OnClientCookiesCached(z);
			}
		}
	}
	RegConsoleCmd("sm_line", Line_Command);
}

Action Line_Command(int client, int args)
{
	g_bLineEnabled[client] = !g_bLineEnabled[client];
	ReplyToCommand(client, "｢ Shavit-Line ｣ : %s by SeenKid", g_bLineEnabled[client] ? "On":"Off"); // Please, do not remove copyright message.
	char buffer[2];
	buffer[0] = view_as<char>(g_bLineEnabled[client]) + '0';
	g_cEnabledCookie.Set(client, buffer);
	return Plugin_Handled;
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}
	char szCookie[4];
	g_cEnabledCookie.Get(client, szCookie, sizeof szCookie );
	if(!szCookie[0])
	{
		szCookie[0] = '1';
	}
	g_bLineEnabled[client] = szCookie[0] == '1';
}

public void OnConfigsExecuted()
{
	// You can change this if you're using another material.
	// Directory : /cstrike/materials/
	sprite = PrecacheModel("sprites/laserbeam.vmt");
}

public void Shavit_OnReplaysLoaded()
{
	for(int style = 0; style < STYLE_LIMIT; style++)
	{
		for(int track = 0; track < TRACKS_SIZE; track++)
		{
			LoadReplay(style, track);
		}
	}
}

public void LoadReplay(int style, int track)
{
	delete g_hClosestPos[style][track];
	delete g_hReplayFrames[style][track];
	ArrayList list = Shavit_GetReplayFrames(style, track, true);
	g_hReplayFrames[style][track] = new ArrayList(sizeof(frame_t));
	if(list)
	{
		frame_t aFrame;
		int flags;

		for(int i = 0; i < list.Length; i++)
		{
			list.GetArray(i, aFrame, sizeof(frame_t));
			if ((aFrame.flags & FL_ONGROUND) && !(flags & FL_ONGROUND))
			{
				g_hReplayFrames[style][track].PushArray(aFrame);
			}
			flags = aFrame.flags;
		}
		g_hClosestPos[style][track] = new ClosestPos(g_hReplayFrames[style][track], 0, 0, Shavit_GetReplayFrameCount(style, track));
	}
	delete list;
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	g_iTrack[client] = track;
	g_iStyle[client] = newstyle;
}

public void Shavit_OnReplaySaved(int client, int style, float time, int jumps, int strafes, float sync, int track,
									float oldtime, float perfs, float avgvel, float maxvel, int timestamp, bool isbestreplay,
									bool istoolong, bool iscopy, const char[] replaypath, ArrayList frames, int preframes, int postframes, const char[] name)
{

	if((!isbestreplay && g_hReplayFrames[style][track] != INVALID_HANDLE) || istoolong)
	{
		return;
	}
	LoadReplay(style, track);
}

#define TE_TIME 1.0
#define TE_MIN 0.5
#define TE_MAX 0.5

int boxcolor[2][4] = { {255,255,255,255}, {128,0,128,255} };
public Action OnPlayerRunCmd(int client)
{
	if(!IsValidClient(client) || !g_bLineEnabled[client])
	{
		return Plugin_Continue;
	}

	if( (++g_iCmdNum[client] % 60) != 0 )
	{
		return Plugin_Continue;
	}

	g_iCmdNum[client] = 0;
	int style = g_iStyle[client];
	int track = g_iTrack[client];

	if(g_hReplayFrames[style][track] == INVALID_HANDLE || g_hClosestPos[style][track] == INVALID_HANDLE)
	{
		return Plugin_Continue;
	}

	if(g_hReplayFrames[style][track].Length == 0)
	{
		return Plugin_Continue;
	}

	float pos[3];
	GetClientAbsOrigin(client, pos);

	int closeframe = max(0, g_hClosestPos[style][track].Find(pos) - 2);
	int endframe = min(g_hReplayFrames[style][track].Length, closeframe + 12);

	frame_t aFrame;
	for(int i = closeframe ; i < endframe; i++)
	{
		g_hReplayFrames[style][track].GetArray(i, aFrame, sizeof(frame_t));
		aFrame.pos[2] += 2.5;
		DrawBox(client, aFrame.pos, boxcolor[(aFrame.flags & FL_DUCKING) ? 0:1]);
		if(i != closeframe)
		{
			DrawBeam(client, pos, aFrame.pos, TE_TIME, TE_MIN, TE_MAX, { 0, 0, 255, 255}, 0.0, 0);
		}
		pos = aFrame.pos;
	}
	return Plugin_Continue;
}

float box_offset[4][2] =
{
	{-10.0, 10.0},
	{10.0, 10.0},
	{-10.0, -10.0},
	{10.0, -10.0},
};

void DrawBox(int client, float pos[3], int color[4])
{
	float square[4][3];
	for (int z = 0; z < 4; z++)
	{
		square[z][0] = pos[0] + box_offset[z][0];
		square[z][1] = pos[1] + box_offset[z][1];
		square[z][2] = pos[2];
	}
	DrawBeam(client, square[0], square[1], TE_TIME, TE_MIN, TE_MAX, color, 0.0, 0);
	DrawBeam(client, square[0], square[2], TE_TIME, TE_MIN, TE_MAX, color, 0.0, 0);
	DrawBeam(client, square[2], square[3], TE_TIME, TE_MIN, TE_MAX, color, 0.0, 0);
	DrawBeam(client, square[1], square[3], TE_TIME, TE_MIN, TE_MAX, color, 0.0, 0);
}

void DrawBeam(int client, float startvec[3], float endvec[3], float life, float width, float endwidth, int color[4], float amplitude, int speed)
{
	TE_SetupBeamPoints(startvec, endvec, sprite, 0, 0, 66, life, width, endwidth, 0, amplitude, color, speed);
	TE_SendToClient(client);
}

int min(int a, int b)
{
    return a < b ? a : b;
}

int max(int a, int b)
{
    return a > b ? a : b;
}
