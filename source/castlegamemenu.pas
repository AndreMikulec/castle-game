{
  Copyright 2006,2007 Michalis Kamburelis.

  This file is part of "castle".

  "castle" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "castle" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "castle"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

{ }
unit CastleGameMenu;

interface

uses GLWindow;

procedure ShowGameMenu(ADrawUnderMenu: TDrawFunc);

implementation

uses SysUtils, Classes, KambiUtils, KambiStringUtils, GLWinModes,
  GL, GLU, GLExt, KambiGLUtils, GLWinMessages, CastleWindow,
  VectorMath, CastleHelp, CastlePlay, CastleGeneralMenu,
  CastleControlsMenu, CastleInputs, CastleCreatures, CastleChooseMenu,
  CastleItems, GLMenu, RaysWindow, CastleVideoOptions, CastleLevel,
  CastleSound, VRMLNodes, KambiClassUtils, CastleTimeMessages,
  GLSoundMenu;

{ TCastleMenu descendants interface ------------------------------------------ }

type
  TGameMenu = class(TCastleMenu)
    constructor Create(AOwner: TComponent); override;
    procedure CurrentItemSelected; override;
  end;

  TGameSoundMenu = class(TCastleMenu)
  public
    SoundInfo: TGLSoundInfoMenuItem;
    SoundVolume: TGLSoundVolumeMenuItem;
    MusicVolume: TGLMusicVolumeMenuItem;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CurrentItemSelected; override;
    procedure CurrentItemAccessoryValueChanged; override;
  end;

{ ----------------------------------------------------------------------------
  global vars (used by TCastleMenu descendants implementation) }

var
  UserQuit: boolean;
  DrawUnderMenu: TDrawFunc;
  CurrentMenu: TCastleMenu;
  GameMenu: TGameMenu;
  GameSoundMenu: TGameSoundMenu;

{ TGameMenu ------------------------------------------------------------ }

constructor TGameMenu.Create(AOwner: TComponent);
begin
  inherited;

  Items.Add('Back to game');
  Items.Add('View last game messages');
  Items.Add('Configure controls');
  Items.Add('Sound options');
  Items.Add('End game');

  FixItemsAreas(Glw.Width, Glw.Height);
end;

procedure TGameMenu.CurrentItemSelected;
begin
  inherited;

  case CurrentItem of
    0: UserQuit := true;
    1: ViewGameMessages;
    2: ShowControlsMenuEscape(DrawUnderMenu, nil, true, true, UserQuit);
    3: SetCurrentMenu(CurrentMenu, GameSoundMenu);
    4: { At first I did here GameCancel(false), but tests (with Mama)
         show that it's too easy to select this and accidentaly
         end the game. }
       GameCancel(true);
    else raise EInternalError.Create('Menu item unknown');
  end;
end;

{ TGameSoundMenu ------------------------------------------------------------- }

constructor TGameSoundMenu.Create(AOwner: TComponent);
begin
  inherited;

  SoundInfo := TGLSoundInfoMenuItem.Create(Glw, Self, SoundEngine);
  SoundVolume := TGLSoundVolumeMenuItem.Create(Glw, Self, SoundEngine);
  MusicVolume := TGLMusicVolumeMenuItem.Create(Glw, Self, SoundEngine);
  Items.Add('Back to game menu');

  FixItemsAreas(Glw.Width, Glw.Height);
end;

destructor TGameSoundMenu.Destroy;
begin
  FreeAndNil(SoundInfo);
  FreeAndNil(SoundVolume);
  FreeAndNil(MusicVolume);
  inherited;
end;

procedure TGameSoundMenu.CurrentItemSelected;
begin
  inherited;

  case CurrentItem of
    0: SoundInfo.Selected;
    1: ;
    2: ;
    3: SetCurrentMenu(CurrentMenu, GameMenu);
    else raise EInternalError.Create('Menu item unknown');
  end;
end;

procedure TGameSoundMenu.CurrentItemAccessoryValueChanged;
begin
  case CurrentItem of
    1: SoundVolume.AccessoryValueChanged;
    2: MusicVolume.AccessoryValueChanged;
  end;
end;

{ global things -------------------------------------------------------------- }

procedure Draw2d(Draw2DData: Pointer);
begin
  glLoadIdentity;
  glRasterPos2i(0, 0);
  CurrentMenu.Draw(false);
end;

procedure Draw(Glwin: TGLWindow);
begin
  DrawUnderMenu(Glwin);

  glPushAttrib(GL_ENABLE_BIT);
    glDisable(GL_LIGHTING);
    glProjectionPushPopOrtho2D(@Draw2d, nil,
      0, Glwin.Width, 0, Glwin.Height);
  glPopAttrib;
end;

{$I castlemenucallbacks.inc}

procedure ShowGameMenu(ADrawUnderMenu: TDrawFunc);
var
  SavedMode: TGLMode;
begin
  DrawUnderMenu := ADrawUnderMenu;

  GameSoundMenu.SoundVolume.RefreshAccessory;
  GameSoundMenu.MusicVolume.RefreshAccessory;

  SavedMode := TGLMode.Create(Glw, 0, true);
  try
    { This is needed, because when changing ViewAngleDegX we will call
      Glw.OnResize to set new projection matrix, and this
      new projection matrix should stay for the game. }
    SavedMode.RestoreProjectionMatrix := false;

    TGLWindowState.SetStandardState(Glw, @Draw, @CloseQuery, Glw.OnResize,
      nil, false, true { FPSActive should not be needed anymore, but I leave it. },
      false, K_None, #0, false, nil);

    { Otherwise messages don't look good, because the text is mixed
      with the menu text. }
    GLWinMessagesTheme.RectColor[3] := 1.0;

    Glw.OnKeyDown := @KeyDown;
    Glw.OnMouseDown := @MouseDown;
    Glw.OnIdle := @Idle;

    SetCurrentMenu(CurrentMenu, GameMenu);

    UserQuit := false;
    repeat
      Glwm.ProcessMessage(true);
    until GameEnded or UserQuit;
  finally FreeAndNil(SavedMode); end;
end;

{ initialization / finalization ---------------------------------------------- }

procedure InitGLW(Glwin: TGLWindow);
begin
  GameMenu := TGameMenu.Create(nil);
  GameSoundMenu := TGameSoundMenu.Create(nil);
end;

procedure CloseGLW(Glwin: TGLWindow);
begin
  FreeAndNil(GameMenu);
  FreeAndNil(GameSoundMenu);
end;

initialization
  Glw.OnInitList.Add(@InitGLW);
  Glw.OnCloseList.Add(@CloseGLW);
finalization
end.