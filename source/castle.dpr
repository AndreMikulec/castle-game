{
  Copyright 2006 Michalis Kamburelis.

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

{$apptype GUI}

program castle;

uses GLWindow, SysUtils, KambiUtils, ProgressUnit, ProgressGL, OpenAL, ALUtils,
  ParseParametersUnit, GLWinMessages, KambiGLUtils,
  CastleWindow, CastleStartMenu, CastleLevel, CastleHelp, CastleSound,
  KambiClassUtils, CastleVideoOptions, CastleInitialBackground,
  CastleCreatures;

{ parsing parameters --------------------------------------------------------- }

var
  WasParam_NoSound: boolean = false;
  WasParam_NoScreenResize: boolean = false;

const
  Options: array[0..5]of TOption =
  ( (Short:'h'; Long: 'help'; Argument: oaNone),
    (Short: #0; Long: 'no-sound'; Argument: oaNone),
    (Short:'v'; Long: 'version'; Argument: oaNone),
    (Short:'n'; Long: 'no-screen-resize'; Argument: oaNone),
    (Short: #0; Long: 'no-shadows'; Argument: oaNone),
    (Short: #0; Long: 'debug-no-creatures'; Argument: oaNone)
  );

procedure OptionProc(OptionNum: Integer; HasArgument: boolean;
  const Argument: string; const SeparateArgs: TSeparateArgs; Data: Pointer);
begin
  case OptionNum of
    0: begin
         InfoWrite(
           'castle.' +nl+
           nl+
           'Options:' +nl+
           HelpOptionHelp +nl+
           VersionOptionHelp +nl+
           OpenALOptionsHelp(true) +nl+
           '  --no-sound            Turn off sound' +nl+
           '  -n / --no-screen-resize' +nl+
           '                        Do not try to resize the screen.' +nl+
           '                        If your screen size is not ' +
             RequiredScreenSize +nl+
           '                        then will run in windowed mode.' +nl+
           '  --no-shadows          Disable initializing and using shadows.' +nl+
           nl+
           'Debug options (don''t use unless you know what you''re doing):' +nl+
           '  --debug-no-creatures  Disable loading creatures animations' +nl+
           nl+
           SProgramHelpSuffix);
         ProgramBreak;
       end;
    1: WasParam_NoSound := true;
    2: begin
         WritelnStr(Version);
         ProgramBreak;
       end;
    3: WasParam_NoScreenResize := true;
    4: RenderShadowsPossible := false;
    5: WasParam_DebugNoCreatures := true;
    else raise EInternalError.Create('OptionProc');
  end;
end;

{ main -------------------------------------------------------------------- }

begin
  { parse parameters }
  OpenALOptionsParse;
  ParseParameters(Options, OptionProc, nil);

  Glw.Width := RequiredScreenWidth;
  Glw.Height := RequiredScreenHeight;
  if WasParam_NoScreenResize or (not AllowScreenResize) then
  begin
    Glw.FullScreen :=
      (Glwm.ScreenWidth = RequiredScreenWidth) and
      (Glwm.ScreenHeight = RequiredScreenHeight);
  end else
  begin
    Glw.FullScreen := true;
    if (Glwm.ScreenWidth <> RequiredScreenWidth) or
       (Glwm.ScreenHeight <> RequiredScreenHeight) then
    begin
      Glwm.VideoResize := true;
      Glwm.VideoResizeWidth := RequiredScreenWidth;
      Glwm.VideoResizeHeight := RequiredScreenHeight;

      if Glwm.VideoResize then
        if not Glwm.TryVideoChange then
        begin
          WarningWrite('Can''t change display settings to ' +
            RequiredScreenSize + '. Will continue in windowed mode.');
          Glw.FullScreen := false;
          AllowScreenResize := false;
        end;
    end;
  end;

  { init glwindow }
  Glw.Caption := 'The Castle';
  Glw.ResizeAllowed := raOnlyAtInit;
  if RenderShadowsPossible then
    Glw.StencilBufferBits := 8;
  Glw.Init;

  { init progress }
  ProgressGLInterface.Window := Glw;
  Progress.UserInterface := ProgressGLInterface;
  { I'm turning UseDescribePosition to false, because it's usually
    confusing for the user.
    E.g. each creature is conted as PrepareRenderSteps steps,
    each item is conted as PrepareRenderSteps steps,
    when loading levels user would have to know what an "octree" is. }
  Progress.UseDescribePosition := false;

  { init OpenAL (after initing Glw and Progress, because ALContextInit
    wants to display progress of "Loading sounds") }
  DrawInitialBackground;
  ALContextInit(WasParam_NoSound);
  try
    ShowStartMenu(Glw.OnDraw);
  finally
    ALContextClose;
  end;
end.

{
  Local Variables:
  compile-command: "fpcdebug castle.dpr --exe-output-dir ../"
  kam-compile-release-command-win32: "clean_glwindow_unit; fpcrelease --exe-output-dir ../"
  kam-compile-release-command-unix: "clean_glwindow_unit; fpcrelease -dGLWINDOW_XLIB --exe-output-dir ../"
  End:
}