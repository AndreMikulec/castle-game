{
  Copyright 2006-2010 Michalis Kamburelis.

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

{ This keeps global Glw (window) variable. }

unit CastleWindow;

interface

uses GLWindow, VRMLGLRenderer, OpenGLTTFonts;

var
  { @noAutoLinkHere }
  Window: TGLUIWindow;

var
  GLContextCache: TVRMLGLRendererContextCache;

  { Just a generally usable OpenGL outline (3D) font. }
  Font3d: TGLOutlineFont;

implementation

uses SysUtils, VRMLNodes, GLAntiAliasing, UIControls;

{ initialization / finalization ---------------------------------------------- }

const
  Font3dFamily = ffSans;
  Font3dBold = false;
  Font3dItalic = false;

procedure GLWindowOpen(Window: TGLWindow);
begin
  Font3d := GLContextCache.Fonts_IncReference(
    Font3dFamily, Font3dBold, Font3dItalic,
    TNodeFontStyle_2.ClassTTF_Font(Font3dFamily, Font3dBold, Font3dItalic));

  AntiAliasingGLOpen;
  AntiAliasingEnable;
end;

procedure GLWindowClose(Window: TGLWindow);
begin
  if (GLContextCache <> nil) and (Font3d <> nil) then
  begin
    GLContextCache.Fonts_DecReference(Font3dFamily, Font3dBold, Font3dItalic);
    Font3d := nil;
  end;
end;

initialization
  Window := TGLUIWindow.Create(nil);
  Window.SetDemoOptions(K_None, #0, false);
  Window.OnDrawStyle := ds3D;

  GLContextCache := TVRMLGLRendererContextCache.Create;

  Window.OnOpenList.Add(@GLWindowOpen);
  Window.OnCloseList.Add(@GLWindowClose);
finalization
  { Fonts_DecReference must be called before freeing GLContextCache.
    It's called from Window.Close. But Window.Close may be called when
    FreeAndNil(Window) below, so to make sure we call Fonts_DecReference
    (by our GLWindowClose) right now. }
  GLWindowClose(Window);

  FreeAndNil(GLContextCache);
  FreeAndNil(Window);
end.
