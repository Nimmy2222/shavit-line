#pragma semicolon 1
#pragma newdecls required

#include <clientprefs>
#include <closestpos>
#include <sdktools>
#include <shavit>
#include <sourcemod>

int sprite;

ArrayList g_hReplayFrames[TRACKS_SIZE][STYLE_LIMIT];
ClosestPos hClosestPos[TRACKS_SIZE][STYLE_LIMIT];
Cookie lines_settings;

int cTrack[MAXPLAYERS + 1];
int cStyle[MAXPLAYERS + 1];
int ticks[MAXPLAYERS + 1];
bool drawLines[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "shavit-line",
	author = "SeenKid / nimmy",
	description = "Shows the WR route with a path on the ground. Use the command sm_line to toggle.",
	version = "1.0.3",
	url = "https://github.com/Nimmy2222/shavit-line"
};

public void OnPluginStart() {
	lines_settings = new Cookie( "shavit_lines", "", CookieAccess_Private );
	
	Shavit_OnReplaysLoaded();
	for( int z = 1; z <= MaxClients; z++ ) {
		if( IsClientInGame(z) && !IsFakeClient(z) ) {
			cStyle[z] = Shavit_GetBhopStyle(z);
			cTrack[z] = Shavit_GetClientTrack(z);
			
			if( AreClientCookiesCached(z) ) {
				OnClientCookiesCached(z);
			}
		}
	}
	RegConsoleCmd( "sm_line", line_callback );
}

Action line_callback(int client, int args) {
	drawLines[client] = !drawLines[client];
	// Please, do not remove copyright message.
	ReplyToCommand(client, "｢ Shavit-Line ｣ : %s by SeenKid", drawLines[client] ? "On":"Off");
	char buffer[2];
	buffer[0] = view_as<char>(drawLines[client]) + '0';
	lines_settings.Set(client, buffer);
	return Plugin_Handled;
}

public void OnClientCookiesCached(int client) {
	if( !IsFakeClient(client) ) {
		char szCookie[4];
		lines_settings.Get(client, szCookie, sizeof szCookie );
		if( !szCookie[0] ) {
			szCookie[0] = '1';
		}
		drawLines[client] = szCookie[0] == '1';
	}
}

public void OnConfigsExecuted() {
	// You can change this if you're using another material.
	// Directory : /cstrike/materials/
	sprite = PrecacheModel("sprites/laserbeam.vmt");
}

public void Shavit_OnReplaysLoaded() {
	for( int z; z < TRACKS_SIZE; z++ ) {
		for( int v; v < STYLE_LIMIT; v++ ) {		
			delete hClosestPos[z][v];
			delete g_hReplayFrames[z][v];
			ArrayList list = Shavit_GetReplayFrames(v, z);
			g_hReplayFrames[z][v] = new ArrayList(sizeof(frame_t));
			if(list) {
				frame_t aFrame;
				int flags;
				for(int i = 0; i < Shavit_GetReplayFrameCount(v,z); i++) {
					list.GetArray(i, aFrame, sizeof(frame_t));
					if ((aFrame.flags & FL_ONGROUND) && !(flags & FL_ONGROUND)) {
						g_hReplayFrames[z][v].PushArray(aFrame);
					}
					flags = aFrame.flags;
				}
				hClosestPos[z][v] = new ClosestPos(g_hReplayFrames[z][v], 0, 0, Shavit_GetReplayFrameCount(v,z));	
			}
			delete list;
		}
	}
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual) {
	cTrack[client] = track;
	cStyle[client] = newstyle;
}

public void Shavit_OnReplaySaved(int client, int style, float time, int jumps, int strafes, float sync, int track, 
									float oldtime, float perfs, float avgvel, float maxvel, int timestamp, bool isbestreplay, 
									bool istoolong, bool iscopy, const char[] replaypath, ArrayList frames, int preframes, int postframes, const char[] name) {
	if(!isbestreplay || istoolong) {
		return;
	}
	delete hClosestPos[track][style];
	delete g_hReplayFrames[track][style];

	ArrayList list = Shavit_GetReplayFrames(track, style);
	g_hReplayFrames[style][track] = new ArrayList(sizeof(frame_t));
	if(list) {
		frame_t aFrame;
		int flags;
		for(int i = 0; i < Shavit_GetReplayFrameCount(track, style); i++) {
			list.GetArray(i, aFrame, sizeof(frame_t));
			if (aFrame.flags & FL_ONGROUND && !(flags & FL_ONGROUND)) {
				g_hReplayFrames[style][track].PushArray(aFrame);
				flags = aFrame.flags;
			}
		}
		hClosestPos[track][style] = new ClosestPos(g_hReplayFrames[style][track], 0, 0, Shavit_GetReplayFrameCount(track,style));	
	}
	delete list;
}

#define TE_TIME 1.0
#define TE_MIN 0.5
#define TE_MAX 0.5

int boxcolor[2][4] = { {255,255,255,255}, {128,0,128,255} };
public Action OnPlayerRunCmd(int client) {
	if(!IsValidClient(client) || !drawLines[client]) {
		return Plugin_Continue;
	}

	if( (++ticks[client] % 60) != 0 ) {
		return Plugin_Continue;
	}

	ticks[client] = 0;
	int style = cStyle[client];
	int track = cTrack[client];
	ArrayList list = g_hReplayFrames[track][style];
	if(list == INVALID_HANDLE || hClosestPos[track][style] == INVALID_HANDLE) {
		return Plugin_Continue;	
	}

	float pos[3];
	GetClientAbsOrigin(client, pos);

	int closeframe = max(0, hClosestPos[track][style].Find(pos) - 4);
	int endframe = min(list.Length, closeframe + 10);

	bool draw;
	frame_t aFrame;
	for(int i = closeframe ; i < endframe; i++ ) {
		list.GetArray(i, aFrame, sizeof(frame_t));
		aFrame.pos[2] += 2.5;
		DrawBox(client, aFrame.pos, boxcolor[(aFrame.flags & FL_DUCKING) ? 0:1]);
		if( draw ) {
			DrawBeam(client, pos, aFrame.pos, TE_TIME, TE_MIN, TE_MAX, { 0, 0, 255, 255}, 0.0, 0);
		} else {
			draw = true;
		}
		pos = aFrame.pos;
	}
	return Plugin_Continue;	
}

float box_offset[4][2] = {
	{-10.0, 10.0},  
	{10.0, 10.0},   
	{-10.0, -10.0}, 
	{10.0, -10.0},  
};

void DrawBox(int client, float pos[3], int color[4] ) {
	float square[4][3];
	for (int z = 0; z < 4; z++) {
		square[z][0] = pos[0] + box_offset[z][0];
		square[z][1] = pos[1] + box_offset[z][1];
		square[z][2] = pos[2];
	}
	DrawBeam(client, square[0], square[1], TE_TIME, TE_MIN, TE_MAX, color, 0.0, 0);
	DrawBeam(client, square[0], square[2], TE_TIME, TE_MIN, TE_MAX, color, 0.0, 0);
	DrawBeam(client, square[2], square[3], TE_TIME, TE_MIN, TE_MAX, color, 0.0, 0);
	DrawBeam(client, square[1], square[3], TE_TIME, TE_MIN, TE_MAX, color, 0.0, 0);
}

void DrawBeam(int client, float startvec[3], float endvec[3], float life, float width, float endwidth, int color[4], float amplitude, int speed) {
	TE_SetupBeamPoints(startvec, endvec, sprite, 0, 0, 66, life, width, endwidth, 0, amplitude, color, speed);
	TE_SendToClient(client);
}

int min(int a, int b) {
    return a < b ? a : b;
}

int max(int a, int b) {
    return a > b ? a : b;
}
