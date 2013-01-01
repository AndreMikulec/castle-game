{
  Copyright 2006-2012 Michalis Kamburelis.

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

  ----------------------------------------------------------------------------
}

{ }
unit GameChooseMenu;

interface

uses Classes, CastleWindow, GL, GLU, UIControls;

{ Allows user to choose one item from MenuItems.
  Displays menu using TCastleGameMenu with ControlsUnder background. }
function ChooseByMenu(ControlsUnder: TUIControlList;
  MenuItems: TStringList): Integer;

implementation

uses SysUtils, WindowModes, CastleGLUtils, CastleInputs, CastleMessages, OnScreenMenu,
  GameWindow, GameGeneralMenu, VectorMath, CastleGameNotifications,
  CastleKeysMouse;

var
  Selected: boolean;
  SelectedIndex: Integer;

type
  TChooseMenu = class(TCastleGameMenu)
    procedure Click; override;
  end;

procedure TChooseMenu.Click;
begin
  inherited;

  Selected := true;
  SelectedIndex := CurrentItem;
end;

{ global things -------------------------------------------------------------- }

var
  ChooseMenu: TChooseMenu;

procedure CloseQuery(Window: TCastleWindowBase);
begin
  MessageOK(Window, 'You can''t exit now.');
end;

function ChooseByMenu(ControlsUnder: TUIControlList;
  MenuItems: TStringList): Integer;
var
  SavedMode: TGLMode;
  I: Integer;
begin
  ChooseMenu.Items.Assign(MenuItems);
  { MenuItems.Objects may be used by called to store some information.
    Remove them now from ChooseMenu.Items, otherwise TOnScreenMenu
    would treat them as accessories. }
  for I := 0 to ChooseMenu.Items.Count - 1 do
    ChooseMenu.Items.Objects[I] := nil;
  ChooseMenu.FixItemsRectangles;

  SavedMode := TGLMode.CreateReset(Window, 0, true,
    nil, Window.OnResize, @CloseQuery);
  try
    { This shouldn't change projection matrix anyway. }
    SavedMode.RestoreProjectionMatrix := false;

    Window.OnDrawStyle := ds3D;

    { Otherwise messages don't look good, because the text is mixed
      with the menu text. }
    MessagesTheme.RectColor[3] := 1.0;

    Window.Controls.MakeSingle(TCastleOnScreenMenu, ChooseMenu);

    Window.Controls.Add(Notifications);
    Window.Controls.AddList(ControlsUnder);

    Selected := false;
    repeat
      Application.ProcessMessage(true, true);
    until Selected;

    Result := SelectedIndex;
  finally FreeAndNil(SavedMode); end;
end;

{ initialization / finalization ---------------------------------------------- }

procedure WindowOpen(const Container: IUIContainer);
begin
  ChooseMenu := TChooseMenu.Create(nil);
end;

procedure WindowClose(const Container: IUIContainer);
begin
  FreeAndNil(ChooseMenu);
end;

initialization
  OnGLContextOpen.Add(@WindowOpen);
  OnGLContextClose.Add(@WindowClose);
end.