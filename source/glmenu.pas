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

{ Menu displayed in OpenGL.

  This unit is developed for "The Castle", but it's generally useful.
  The only place that will have to be fixed when moving
  this unit to general units/ is the LoadImage() paths in
  ImageSliderInit. }
unit GLMenu;

interface

uses Classes, OpenGLBmpFonts, BFNT_BitstreamVeraSans_Unit, VectorMath, Areas,
  GLWindow, OpenGLh;

const
  DefaultGLMenuKeyNextItem = K_Down;
  DefaultGLMenuKeyPreviousItem = K_Up;
  DefaultGLMenuKeySelectItem = K_Enter;
  DefaultGLMenuKeySliderIncrease = K_Right;
  DefaultGLMenuKeySliderDecrease = K_Left;

  DefaultCurrentItemBorderColor1: TVector3Single = (   1,    1,    1) { White3Single };
  DefaultCurrentItemBorderColor2: TVector3Single = ( 0.5,  0.5,  0.5) { Gray3Single };
  DefaultCurrentItemColor       : TVector3Single = (   1,    1,  0.3) { Yellow3Single };
  DefaultNonCurrentItemColor    : TVector3Single = (   1,    1,    1) { White3Single };

  DefaultSpaceBetweenItems = 10;

type
  TGLMenu = class;

  { This is something that can be attached to some menu items of TGLMenu.
    For example, a slider --- see TGLMenuSlider. }
  TGLMenuItemAccessory = class
  public
    { Return the width you will need to display yourself.

      Note that this will be asked only from FixItemsAreas
      from TGLMenu. So for example TGLMenuItemArgument
      is *not* supposed to return here something based on
      current TGLMenuItemArgument.Value,
      because we will not query GetWidth after every change of
      TGLMenuItemArgument.Value. Instead, TGLMenuItemArgument
      should return here the width of widest possible Value. }
    function GetWidth(MenuFont: TGLBitmapFont): Single; virtual; abstract;

    { Draw yourself. Note that Area.Width is for sure the same
      as you returned in GetWidth. }
    procedure Draw(const Area: TArea); virtual; abstract;

    { This will be called if user will press a key when currently
      selected item has this TGLMenuItemAccessory.

      You can use ParentMenu to call
      ParentMenu.CurrentItemAccessoryValueChanged. }
    procedure KeyDown(Key: TKey; C: char;
      ParentMenu: TGLMenu); virtual;

    { This will be called if user will click mouse when currently
      selected item has this TGLMenuItemAccessory.

      This will be called only if MouseX and MouseY will be within
      appropriate Area of this accessory. This Area is also
      passed here, so you can e.g. calculate mouse position
      relative to this accessory as (MouseX - Area.X0, MouseY - Area.Y0).

      You can use ParentMenu to call
      ParentMenu.CurrentItemAccessoryValueChanged. }
    procedure MouseDown(const MouseX, MouseY: Single; Button: TMouseButton;
      const Area: TArea; ParentMenu: TGLMenu); virtual;

    { This will be called if user will move mouse over the currently selected
      menu item and menu item will have this accessory.

      Just like with MouseDown: This will be called only if NewX and NewY
      will be within appropriate Area of accessory.
      You can use ParentMenu to call
      ParentMenu.CurrentItemAccessoryValueChanged. }
    procedure MouseMove(const NewX, NewY: Single;
      const MousePressed: TMouseButtons;
      const Area: TArea; ParentMenu: TGLMenu); virtual;
  end;

  { This is TGLMenuItemAccessory that will just display
    additional text (using some different color than Menu.CurrentItemColor)
    after the menu item. The intention is that the Value will be changeable
    by the user (while the basic item text remains constant).
    For example Value may describe "on" / "off" state of something,
    the name of some key currently assigned to some function etc. }
  TGLMenuItemArgument = class(TGLMenuItemAccessory)
  private
    FMaximumValueWidth: Single;
    FValue: string;
  public
    constructor Create(const AMaximumValueWidth: Single);

    property Value: string read FValue write FValue;

    property MaximumValueWidth: Single
      read FMaximumValueWidth write FMaximumValueWidth;

    { Calculate text width using font used by TGLMenuItemArgument. }
    class function TextWidth(const Text: string): Single;

    function GetWidth(MenuFont: TGLBitmapFont): Single; override;
    procedure Draw(const Area: TArea); override;
  end;

  TGLMenuSlider = class(TGLMenuItemAccessory)
  private
    FDisplayValue: boolean;
  protected
    procedure DrawSliderPosition(const Area: TArea; const Position: Single);

    { This returns a value of Position (for DrawSliderPosition, so in range 0..1)
      that would result in slider being drawn at XCoord screen position.
      Takes Area as the area currently occupied by the whole slider. }
    function XCoordToSliderPosition(const XCoord: Single;
      const Area: TArea): Single;

    procedure DrawSliderText(const Area: TArea; const Text: string);
  public
    constructor Create;

    function GetWidth(MenuFont: TGLBitmapFont): Single; override;
    procedure Draw(const Area: TArea); override;

    { Should the Value be displayed as text ?
      Usually useful --- but only if the Value has some meaning for the user.
      If @true, then ValueToStr is used. }
    property DisplayValue: boolean
      read FDisplayValue write FDisplayValue default true;
  end;

  TGLMenuFloatSlider = class(TGLMenuSlider)
  private
    FBeginRange: Single;
    FEndRange: Single;
    FValue: Single;
  public
    constructor Create(const ABeginRange, AEndRange, AValue: Single);

    property BeginRange: Single read FBeginRange;
    property EndRange: Single read FEndRange;

    { Current value. When setting this property, always make sure
      that it's within the allowed range. }
    property Value: Single read FValue write FValue;

    procedure Draw(const Area: TArea); override;

    procedure KeyDown(Key: TKey; C: char;
      ParentMenu: TGLMenu); override;

    procedure MouseDown(const MouseX, MouseY: Single; Button: TMouseButton;
      const Area: TArea; ParentMenu: TGLMenu); override;

    procedure MouseMove(const NewX, NewY: Single;
      const MousePressed: TMouseButtons;
      const Area: TArea; ParentMenu: TGLMenu); override;

    function ValueToStr(const AValue: Single): string; virtual;
  end;

  TGLMenuIntegerSlider = class(TGLMenuSlider)
  private
    FBeginRange: Integer;
    FEndRange: Integer;
    FValue: Integer;

    function XCoordToValue(
      const XCoord: Single; const Area: TArea): Integer;
  public
    constructor Create(const ABeginRange, AEndRange, AValue: Integer);

    property BeginRange: Integer read FBeginRange;
    property EndRange: Integer read FEndRange;

    { Current value. When setting this property, always make sure
      that it's within the allowed range. }
    property Value: Integer read FValue write FValue;

    procedure Draw(const Area: TArea); override;

    procedure KeyDown(Key: TKey; C: char;
      ParentMenu: TGLMenu); override;

    procedure MouseDown(const MouseX, MouseY: Single; Button: TMouseButton;
      const Area: TArea; ParentMenu: TGLMenu); override;

    procedure MouseMove(const NewX, NewY: Single;
      const MousePressed: TMouseButtons;
      const Area: TArea; ParentMenu: TGLMenu); override;

    function ValueToStr(const AValue: Integer): string; virtual;
  end;

  { How TGLMenu.Position will be interpreted. }
  TPositionRelative = (
    { Position coordinate specifies position of the lower (or left,
      depending whether it's applied to PositionRelativeX or PositionRelativeY)
      border of the menu. }
    prLowerBorder,
    { Position coordinate = 0 means that menu will be in the middle
      of the screen. Other positions will move menu appropriately
      --- higher values to the up (or right), lower to the down (or left). }
    prMiddle,
    { Position coordinate specifies position of the upper (or right)
      border of the menu. }
    prHigherBorder);

  { A menu displayed in OpenGL.

    Note that all 2d positions and sizes for this class are interpreted
    as pixel positions on your 2d screen (for glRaster, glBitmap etc.)
    and also as normal positions (for glTranslatef etc.) on your 2d screen.
    Smaller x positions are considered more to the left,
    smaller y positions are considered lower.
    Stating it simpler: just make sure that your OpenGL projection is
    @code(ProjectionGLOrtho(0, Glwin.Width, 0, Glwin.Height);) }
  TGLMenu = class
  private
    FItems: TStringList;
    FCurrentItem: Integer;
    FPosition: TVector2Single;
    FPositionRelativeX: TPositionRelative;
    FPositionRelativeY: TPositionRelative;
    FAreas: TDynAreaArray;
    FAccessoryAreas: TDynAreaArray;
    FAllItemsArea: TArea;
    FKeyNextItem: TKey;
    FKeyPreviousItem: TKey;
    FKeySelectItem: TKey;
    FKeySliderDecrease: TKey;
    FKeySliderIncrease: TKey;
    GLList_DrawFadeRect: TGLuint;
    MenuAnimation: Single;
    FCurrentItemBorderColor1: TVector3Single;
    FCurrentItemBorderColor2: TVector3Single;
    FCurrentItemColor: TVector3Single;
    FNonCurrentItemColor: TVector3Single;
    MaxItemWidth: Single;
    FSpaceBetweenItems: Cardinal;
    FDrawBackgroundRectangle: boolean;
    function GetCurrentItem: Integer;
    procedure SetCurrentItem(const Value: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    { Position of the lower-left corner of the menu. }
    property Position: TVector2Single read FPosition write FPosition;

    property PositionRelativeX: TPositionRelative
      read FPositionRelativeX write FPositionRelativeX default prMiddle;

    property PositionRelativeY: TPositionRelative
      read FPositionRelativeY write FPositionRelativeY default prMiddle;

    { Items of this menu.

      Note that Objects of this class have special meaning: they must
      be either nil or some TGLMenuItemAccessory instance
      (different TGLMenuItemAccessory instance for each item).
      When freeing this TGLMenu instance, note that we will also
      free all Items.Objects. }
    property Items: TStringList read FItems;

    { When Items.Count <> 0, this is always some number
      between 0 and Items.Count - 1.
      Otherwise (when Items.Count <> 0) this is always -1.

      If you assign it to wrong value (breaking conditions above),
      or if you change Items such that conditions are broken,
      it will be arbitrarily fixed.

      Changing this calls CurrentItemChanged automatically when needed. }
    property CurrentItem: Integer read GetCurrentItem write SetCurrentItem;

    { These change CurrentItem as appropriate.
      Usually you will just let this class call it internally
      (from MouseMove, KeyDown etc.) and will not need to call it yourself. }
    procedure NextItem;
    procedure PreviousItem;

    { Release things associated with OpenGL context.
      This will be also automatically called from destructor. }
    procedure CloseGL;

    { You must call FixItemsAreas between last modification of
      @unorderedList(
        @itemSpacing Compact
        @item Items
        @item Position
        @item SpaceBetweenItems
      )
      and calling one of the procedures
      @unorderedList(
        @itemSpacing Compact
        @item Draw
        @item MouseMove
        @item MouseDown
        @item MouseUp
        @item KeyDown
        @item Idle
      )
      You can call this only while OpenGL context is initialized. }
    procedure FixItemsAreas(const WindowWidth, WindowHeight: Cardinal);

    { These are initialized by FixItemsAreas.
      They are absolutely read-only for the user of this class.
      You can use them to do some graphic effects, when you e.g.
      want to draw something on the screen that is somehow positioned
      relative to some menu item or to whole menu area.
      Note that AllItemsArea includes also some outside margin. }
    property Areas: TDynAreaArray read FAreas;
    property AllItemsArea: TArea read FAllItemsArea;
    property AccessoryAreas: TDynAreaArray read FAccessoryAreas;

    procedure Draw; virtual;

    property KeyNextItem: TKey read FKeyNextItem write FKeyNextItem
      default DefaultGLMenuKeyNextItem;
    property KeyPreviousItem: TKey read FKeyPreviousItem write FKeyPreviousItem
      default DefaultGLMenuKeyPreviousItem;
    property KeySelectItem: TKey read FKeySelectItem write FKeySelectItem
      default DefaultGLMenuKeySelectItem;
    property KeySliderIncrease: TKey
      read FKeySliderIncrease write FKeySliderIncrease
      default DefaultGLMenuKeySliderIncrease;
    property KeySliderDecrease: TKey
      read FKeySliderDecrease write FKeySliderDecrease
      default DefaultGLMenuKeySliderDecrease;

    procedure KeyDown(Key: TKey; C: char);

    { Call this when user moves the mouse.
      NewX, NewY is in OpenGL 2d screen coordinates, so usually
      (when you call this from TGLWindow.OnMouseMove) you will
      have to flip the NewY like @code(Glwin.Height - NewY). }
    procedure MouseMove(const NewX, NewY: Single;
      const MousePressed: TMouseButtons);

    procedure MouseDown(const MouseX, MouseY: Single; Button: TMouseButton);
    procedure MouseUp(const MouseX, MouseY: Single; Button: TMouseButton);

    procedure Idle(const CompSpeed: Single);

    { Called when user will select CurrentItem, either with mouse
      or with keyboard. }
    procedure CurrentItemSelected; virtual;

    { This will be called when the TGLMenuItemAccessory assigned
      to CurrentItem will signal that it's value changed
      because of user interface actions (KeyDown, MouseDown etc.).

      Note that this will not be called when you just set
      Value of some property.

      In this class this just calls SomethingChanged. }
    procedure CurrentItemAccessoryValueChanged; virtual;

    { Called when CurrentItem changed.
      But *not* when CurrentItem changed because of Items.Count changes.
      In this class this just calls SomethingChanged. }
    procedure CurrentItemChanged; virtual;

    { Called when various things changed.
      E.g. color of current item changed.
      CurrentItemChanged also calls this.
      Or some TGLMenuItemAccessory may call this when some value changed. }
    procedure SomethingChanged; virtual;

    { Default value is DefaultCurrentItemBorderColor1 }
    property CurrentItemBorderColor1: TVector3Single
      read FCurrentItemBorderColor1
      write FCurrentItemBorderColor1;
    { Default value is DefaultCurrentItemBorderColor2 }
    property CurrentItemBorderColor2: TVector3Single
      read FCurrentItemBorderColor2
      write FCurrentItemBorderColor2;
    { Default value is DefaultCurrentItemColor }
    property CurrentItemColor       : TVector3Single
      read FCurrentItemColor write FCurrentItemColor;
    { Default value is DefaultNonCurrentItemColor }
    property NonCurrentItemColor    : TVector3Single
      read FNonCurrentItemColor write FNonCurrentItemColor;

    property DrawBackgroundRectangle: boolean
      read FDrawBackgroundRectangle write FDrawBackgroundRectangle
      default true;

    { Additional vertical space, in pixels, between menu items. }
    property SpaceBetweenItems: Cardinal
      read FSpaceBetweenItems write FSpaceBetweenItems
      default DefaultSpaceBetweenItems;
  end;

var
  { These fonts will be automatically initialized by any TGLMenu operation
    that require them. You can set them yourself or just let TGLMenu
    to set it.

    YOU MUST RELEASE THEM BY GLMenuCloseGL. Don't forget about it.

    @groupBegin }
  MenuFont: TGLBitmapFont;
  SliderFont: TGLBitmapFont;
  { @groupEnd }

{ This releases some fonts, images, display lists that were created
  during GLMenu lifetime when necessary. You must call this
  when you ended using GLMenu things. }
procedure GLMenuCloseGL;

implementation

uses SysUtils, KambiUtils, KambiGLUtils, Images, KambiFilesUtils,
  BFNT_BitstreamVeraSans_m10_Unit;

procedure SliderFontInit;
begin
  if SliderFont = nil then
    SliderFont := TGLBitmapFont.Create(@BFNT_BitstreamVeraSans_m10);
end;

procedure MenuFontInit;
begin
  if MenuFont = nil then
    MenuFont := TGLBitmapFont.Create(@BFNT_BitstreamVeraSans);
end;

var
  ImageSlider: TImage;
  ImageSliderPosition: TImage;
  GLList_ImageSlider: TGLuint;
  GLList_ImageSliderPosition: TGLuint;

procedure ImageSliderInit;
begin
  if ImageSlider = nil then
    ImageSlider := LoadImage(ProgramDataPath + 'data' +
      PathDelim + 'menu_bg' + PathDelim + 'menu_slider.png',
      [TRGBImage], []);

  if ImageSliderPosition = nil then
    ImageSliderPosition := LoadImage(ProgramDataPath + 'data' +
      PathDelim + 'menu_bg' + PathDelim + 'menu_slider_position.png',
      [TRGBImage], []);

  if GLList_ImageSlider = 0 then
    GLList_ImageSlider := ImageDrawToDispList(ImageSlider);

  if GLList_ImageSliderPosition = 0 then
    GLList_ImageSliderPosition := ImageDrawToDispList(ImageSliderPosition);
end;

procedure GLMenuCloseGL;
begin
  FreeAndNil(MenuFont);
  FreeAndNil(SliderFont);
  glFreeDisplayList(GLList_ImageSlider);
  glFreeDisplayList(GLList_ImageSliderPosition);
  FreeAndNil(ImageSlider);
  FreeAndNil(ImageSliderPosition);
end;

{ TGLMenuItemAccessory ------------------------------------------------------ }

procedure TGLMenuItemAccessory.KeyDown(Key: TKey; C: char;
  ParentMenu: TGLMenu);
begin
  { Nothing to do in this class. }
end;

procedure TGLMenuItemAccessory.MouseDown(
  const MouseX, MouseY: Single; Button: TMouseButton;
  const Area: TArea; ParentMenu: TGLMenu);
begin
  { Nothing to do in this class. }
end;

procedure TGLMenuItemAccessory.MouseMove(const NewX, NewY: Single;
  const MousePressed: TMouseButtons;
  const Area: TArea; ParentMenu: TGLMenu);
begin
  { Nothing to do in this class. }
end;

{ TGLMenuItemArgument -------------------------------------------------------- }

constructor TGLMenuItemArgument.Create(const AMaximumValueWidth: Single);
begin
  inherited Create;
  FMaximumValueWidth := AMaximumValueWidth;
end;

class function TGLMenuItemArgument.TextWidth(const Text: string): Single;
begin
  MenuFontInit;
  Result := MenuFont.TextWidth(Text);
end;

function TGLMenuItemArgument.GetWidth(MenuFont: TGLBitmapFont);
begin
  Result := MaximumValueWidth;
end;

procedure TGLMenuItemArgument.Draw(const Area: TArea);
begin
  MenuFontInit;

  glPushMatrix;
    glTranslatef(Area.X0, Area.Y0 + MenuFont.Descend, 0);
    glColorv(LightGreen3Single);
    glRasterPos2i(0, 0);
    MenuFont.Print(Value);
  glPopMatrix;
end;

{ TGLMenuSlider -------------------------------------------------------------- }

constructor TGLMenuSlider.Create;
begin
  inherited;
  FDisplayValue := true;
end;

function TGLMenuSlider.GetWidth(MenuFont: TGLBitmapFont): Single;
begin
  ImageSliderInit;
  Result := ImageSlider.Width;
end;

procedure TGLMenuSlider.Draw(const Area: TArea);
begin
  ImageSliderInit;

  glPushMatrix;
    glTranslatef(Area.X0, Area.Y0 + (Area.Height - ImageSlider.Height) / 2, 0);
    glRasterPos2i(0, 0);
    glCallList(GLList_ImageSlider);
  glPopMatrix;
end;

const
  ImageSliderPositionMargin = 2;

procedure TGLMenuSlider.DrawSliderPosition(const Area: TArea;
  const Position: Single);
begin
  ImageSliderInit;

  glPushMatrix;
    glTranslatef(Area.X0 + ImageSliderPositionMargin +
      MapRange(Position, 0, 1, 0,
        ImageSlider.Width - 2 * ImageSliderPositionMargin -
        ImageSliderPosition.Width),
      Area.Y0 + (Area.Height - ImageSliderPosition.Height) / 2, 0);
    glRasterPos2i(0, 0);
    glCallList(GLList_ImageSliderPosition);
  glPopMatrix;
end;

function TGLMenuSlider.XCoordToSliderPosition(
  const XCoord: Single; const Area: TArea): Single;
begin
  { I subtract below ImageSliderPosition.Width div 2
    because we want XCoord to be in the middle
    of ImageSliderPosition, not on the left. }
  Result := MapRange(XCoord - ImageSliderPosition.Width div 2,
    Area.X0 + ImageSliderPositionMargin,
    Area.X0 + ImageSlider.Width - 2 * ImageSliderPositionMargin -
    ImageSliderPosition.Width, 0, 1);

  Clamp(Result, 0, 1);
end;

procedure TGLMenuSlider.DrawSliderText(
  const Area: TArea; const Text: string);
begin
  SliderFontInit;

  glPushMatrix;
    glTranslatef(
      Area.X0 + (Area.Width - SliderFont.TextWidth(Text)) / 2,
      Area.Y0 + (Area.Height - SliderFont.RowHeight) / 2, 0);
    glColorv(Black3Single);
    glRasterPos2i(0, 0);
    SliderFont.Print(Text);
  glPopMatrix;
end;

{ TGLMenuFloatSlider --------------------------------------------------------- }

constructor TGLMenuFloatSlider.Create(
  const ABeginRange, AEndRange, AValue: Single);
begin
  inherited Create;
  FBeginRange := ABeginRange;
  FEndRange := AEndRange;
  FValue := AValue;
end;

procedure TGLMenuFloatSlider.Draw(const Area: TArea);
begin
  inherited;

  DrawSliderPosition(Area, MapRange(Value, BeginRange, EndRange, 0, 1));

  if DisplayValue then
    DrawSliderText(Area, ValueToStr(Value));
end;

procedure TGLMenuFloatSlider.KeyDown(Key: TKey; C: char;
  ParentMenu: TGLMenu);
var
  ValueChange: Single;
begin
  { TODO: TGLMenuFloatSlider should rather get "smooth" changing of Value ? }
  if Key <> K_None then
  begin
    ValueChange := (EndRange - BeginRange) / 100;

    { KeySelectItem works just like KeySliderIncrease.
      Why ? Because KeySelectItem does something with most menu items,
      so user would be surprised if it doesn't work at all with slider
      menu items. Increasing slider value seems like some sensible operation
      to do on slider menu item. }

    if (Key = ParentMenu.KeySelectItem) or
       (Key = ParentMenu.KeySliderIncrease) then
    begin
      FValue := Min(EndRange, Value + ValueChange);
      ParentMenu.CurrentItemAccessoryValueChanged;
    end else
    if Key = ParentMenu.KeySliderDecrease then
    begin
      FValue := Max(BeginRange, Value - ValueChange);
      ParentMenu.CurrentItemAccessoryValueChanged;
    end;
  end;
end;

procedure TGLMenuFloatSlider.MouseDown(
  const MouseX, MouseY: Single; Button: TMouseButton;
  const Area: TArea; ParentMenu: TGLMenu);
begin
  if Button = mbLeft then
  begin
    FValue := MapRange(XCoordToSliderPosition(MouseX, Area), 0, 1,
      BeginRange, EndRange);
    ParentMenu.CurrentItemAccessoryValueChanged;
  end;
end;

procedure TGLMenuFloatSlider.MouseMove(const NewX, NewY: Single;
  const MousePressed: TMouseButtons;
  const Area: TArea; ParentMenu: TGLMenu);
begin
  if mbLeft in MousePressed then
  begin
    FValue := MapRange(XCoordToSliderPosition(NewX, Area), 0, 1,
      BeginRange, EndRange);
    ParentMenu.CurrentItemAccessoryValueChanged;
  end;
end;

function TGLMenuFloatSlider.ValueToStr(const AValue: Single): string;
begin
  Result := Format('%f', [AValue]);
end;

{ TGLMenuIntegerSlider ------------------------------------------------------- }

constructor TGLMenuIntegerSlider.Create(
  const ABeginRange, AEndRange, AValue: Integer);
begin
  inherited Create;
  FBeginRange := ABeginRange;
  FEndRange := AEndRange;
  FValue := AValue;
end;

procedure TGLMenuIntegerSlider.Draw(const Area: TArea);
begin
  inherited;

  DrawSliderPosition(Area, MapRange(Value, BeginRange, EndRange, 0, 1));

  if DisplayValue then
    DrawSliderText(Area, ValueToStr(Value));
end;

procedure TGLMenuIntegerSlider.KeyDown(Key: TKey; C: char;
  ParentMenu: TGLMenu);
var
  ValueChange: Integer;
begin
  if Key <> K_None then
  begin
    ValueChange := 1;

    { KeySelectItem works just like KeySliderIncrease.
      Reasoning: see TGLMenuFloatSlider. }

    if (Key = ParentMenu.KeySelectItem) or
       (Key = ParentMenu.KeySliderIncrease) then
    begin
      FValue := Min(EndRange, Value + ValueChange);
      ParentMenu.CurrentItemAccessoryValueChanged;
    end else
    if Key = ParentMenu.KeySliderDecrease then
    begin
      FValue := Max(BeginRange, Value - ValueChange);
      ParentMenu.CurrentItemAccessoryValueChanged;
    end;
  end;
end;

function TGLMenuIntegerSlider.XCoordToValue(
  const XCoord: Single; const Area: TArea): Integer;
begin
  { We do additional Clamped over Round result to avoid any
    change of floating-point errors due to lack of precision. }
  Result := Clamped(Round(
    MapRange(XCoordToSliderPosition(XCoord, Area), 0, 1,
      BeginRange, EndRange)), BeginRange, EndRange);
end;

procedure TGLMenuIntegerSlider.MouseDown(
  const MouseX, MouseY: Single; Button: TMouseButton;
  const Area: TArea; ParentMenu: TGLMenu);
begin
  if Button = mbLeft then
  begin
    FValue := XCoordToValue(MouseX, Area);
    ParentMenu.CurrentItemAccessoryValueChanged;
  end;
end;

procedure TGLMenuIntegerSlider.MouseMove(const NewX, NewY: Single;
  const MousePressed: TMouseButtons;
  const Area: TArea; ParentMenu: TGLMenu);
begin
  if mbLeft in MousePressed then
  begin
    FValue := XCoordToValue(NewX, Area);
    ParentMenu.CurrentItemAccessoryValueChanged;
  end;
end;

function TGLMenuIntegerSlider.ValueToStr(const AValue: Integer): string;
begin
  Result := IntToStr(AValue);
end;

{ TGLMenu -------------------------------------------------------------------- }

constructor TGLMenu.Create;
begin
  inherited;
  FItems := TStringList.Create;
  FCurrentItem := 0;
  FAreas := TDynAreaArray.Create;
  FAccessoryAreas := TDynAreaArray.Create;

  FPositionRelativeX := prMiddle;
  FPositionRelativeY := prMiddle;

  KeyNextItem := DefaultGLMenuKeyNextItem;
  KeyPreviousItem := DefaultGLMenuKeyPreviousItem;
  KeySelectItem := DefaultGLMenuKeySelectItem;
  KeySliderIncrease := DefaultGLMenuKeySliderIncrease;
  KeySliderDecrease := DefaultGLMenuKeySliderDecrease;

  FCurrentItemBorderColor1 := DefaultCurrentItemBorderColor1;
  FCurrentItemBorderColor2 := DefaultCurrentItemBorderColor2;
  FCurrentItemColor := DefaultCurrentItemColor;
  FNonCurrentItemColor := DefaultNonCurrentItemColor;

  FSpaceBetweenItems := DefaultSpaceBetweenItems;
  FDrawBackgroundRectangle := true;
end;

destructor TGLMenu.Destroy;
var
  I: Integer;
begin
  CloseGL;

  for I := 0 to Items.Count - 1 do
    Items.Objects[I].Free;
  FreeAndNil(FItems);

  FreeAndNil(FAccessoryAreas);
  FreeAndNil(FAreas);
  inherited;
end;

function TGLMenu.GetCurrentItem: Integer;
begin
  Result := FCurrentItem;

  { Make sure that CurrentItem conditions are OK.

    Alternatively we could watch for this in SetCurrentItem, but then
    changing Items by user of this class could invalidate it.
    So it's safest to just check the conditions here. }

  if Items.Count <> 0 then
  begin
    Clamp(Result, 0, Items.Count - 1);
  end else
    Result := -1;
end;

procedure TGLMenu.SetCurrentItem(const Value: Integer);
var
  OldCurrentItem, NewCurrentItem: Integer;
begin
  OldCurrentItem := CurrentItem;
  FCurrentItem := Value;
  NewCurrentItem := CurrentItem;
  if OldCurrentItem <> NewCurrentItem then
    CurrentItemChanged;
end;

procedure TGLMenu.NextItem;
begin
  if Items.Count <> 0 then
  begin
    if CurrentItem = Items.Count - 1 then
      CurrentItem := 0 else
      CurrentItem := CurrentItem + 1;
  end;
end;

procedure TGLMenu.PreviousItem;
begin
  if Items.Count <> 0 then
  begin
    if CurrentItem = 0 then
      CurrentItem := Items.Count - 1 else
      CurrentItem := CurrentItem - 1;
  end;
end;

procedure TGLMenu.CloseGL;
begin
  glFreeDisplayList(GLList_DrawFadeRect);
end;

const
  MarginBeforeAccessory = 20;

procedure TGLMenu.FixItemsAreas(const WindowWidth, WindowHeight: Cardinal);
const
  AllItemsAreaMargin = 30;
var
  I: Integer;
  WholeItemWidth, MaxAccessoryWidth: Single;
  PositionXMove, PositionYMove: Single;
begin
  MenuFontInit;

  FAccessoryAreas.Count := Items.Count;

  { calculate FAccessoryAreas[].Width, MaxItemWidth, MaxAccessoryWidth }

  MaxItemWidth := 0.0;
  MaxAccessoryWidth := 0.0;
  for I := 0 to Items.Count - 1 do
  begin
    MaxTo1st(MaxItemWidth, MenuFont.TextWidth(Items[I]));

    if Items.Objects[I] <> nil then
      FAccessoryAreas[I].Width :=
        TGLMenuItemAccessory(Items.Objects[I]).GetWidth(MenuFont) else
      FAccessoryAreas[I].Width := 0.0;

    MaxTo1st(MaxAccessoryWidth, FAccessoryAreas[I].Width);
  end;

  { calculate FAllItemsArea Width and Height }

  FAllItemsArea.Width := MaxItemWidth;
  if MaxAccessoryWidth <> 0.0 then
    FAllItemsArea.Width += MarginBeforeAccessory + MaxAccessoryWidth;
  FAllItemsArea.Height := (MenuFont.RowHeight + SpaceBetweenItems) * Items.Count;

  FAllItemsArea.Width += 2 * AllItemsAreaMargin;
  FAllItemsArea.Height += 2 * AllItemsAreaMargin;

  { calculate Areas Widths and Heights }

  Areas.Count := 0;
  for I := 0 to Items.Count - 1 do
  begin
    if MaxAccessoryWidth <> 0.0 then
      WholeItemWidth := MaxItemWidth + MarginBeforeAccessory + MaxAccessoryWidth else
      WholeItemWidth := MenuFont.TextWidth(Items[I]);
    Areas.AppendItem(Area(0, 0, WholeItemWidth,
      MenuFont.Descend + MenuFont.RowHeight));
  end;

  { Now take into account Position, PositionRelativeX and PositionRelativeY,
    and calculate PositionXMove, PositionYMove }

  case PositionRelativeX of
    prLowerBorder: PositionXMove := Position[0];
    prMiddle: PositionXMove :=
      Position[0] + (WindowWidth - FAllItemsArea.Width) / 2;
    prHigherBorder: PositionXMove := Position[0] - FAllItemsArea.Width;
    else raise EInternalError.Create('PositionRelativeX = ?');
  end;

  case PositionRelativeY of
    prLowerBorder: PositionYMove := Position[1];
    prMiddle: PositionYMove :=
      Position[1] + (WindowHeight - FAllItemsArea.Height) / 2;
    prHigherBorder: PositionYMove := Position[1] - FAllItemsArea.Height;
    else raise EInternalError.Create('PositionRelativeY = ?');
  end;

  { Calculate positions of all areas. }

  for I := 0 to Areas.High do
  begin
    Areas[I].X0 := PositionXMove + AllItemsAreaMargin;
    Areas[I].Y0 := PositionYMove + AllItemsAreaMargin
      + (Areas.High - I) * (MenuFont.RowHeight + SpaceBetweenItems);
  end;
  FAllItemsArea.X0 := PositionXMove;
  FAllItemsArea.Y0 := PositionYMove;

  { Calculate FAccessoryAreas[].X0, Y0, Height }
  for I := 0 to Areas.High do
  begin
    FAccessoryAreas[I].X0 := Areas[I].X0 + MaxItemWidth + MarginBeforeAccessory;
    FAccessoryAreas[I].Y0 := Areas[I].Y0;
    FAccessoryAreas[I].Height := Areas[I].Height;
  end;

  { Calculate GLList_DrawFadeRect }

  if GLList_DrawFadeRect = 0 then
    GLList_DrawFadeRect := glGenLists(1);
  glNewList(GLList_DrawFadeRect, GL_COMPILE);
  try
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
      glColor4f(0, 0, 0, 0.4);
      glRectf(FAllItemsArea.X0, FAllItemsArea.Y0,
        FAllItemsArea.X0 + FAllItemsArea.Width,
        FAllItemsArea.Y0 + FAllItemsArea.Height);
    glDisable(GL_BLEND);
  finally glEndList end;
end;

procedure TGLMenu.Draw;
const
  CurrentItemBorderMargin = 5;
var
  I: Integer;
  CurrentItemBorderColor: TVector3Single;
begin
  if DrawBackgroundRectangle then
    glCallList(GLList_DrawFadeRect);

  for I := 0 to Items.Count - 1 do
  begin
    if I = CurrentItem then
    begin
      { Calculate CurrentItemBorderColor }
      if MenuAnimation <= 0.5 then
        CurrentItemBorderColor := VLerp(
          MapRange(MenuAnimation, 0, 0.5, 0, 1),
          CurrentItemBorderColor1, CurrentItemBorderColor2) else
        CurrentItemBorderColor := VLerp(
          MapRange(MenuAnimation, 0.5, 1, 0, 1),
          CurrentItemBorderColor2, CurrentItemBorderColor1);

      glColorv(CurrentItemBorderColor);
      DrawGLRectBorder(
        Areas[I].X0 - CurrentItemBorderMargin,
        Areas[I].Y0,
        Areas[I].X0 + Areas[I].Width + CurrentItemBorderMargin,
        Areas[I].Y0 + Areas[I].Height);

      glColorv(CurrentItemColor);
    end else
      glColorv(NonCurrentItemColor);

    glPushMatrix;
      glTranslatef(Areas[I].X0, Areas[I].Y0 + MenuFont.Descend, 0);
      glRasterPos2i(0, 0);
      MenuFont.Print(Items[I]);
    glPopMatrix;

    if Items.Objects[I] <> nil then
      TGLMenuItemAccessory(Items.Objects[I]).Draw(FAccessoryAreas.Items[I]);
  end;
end;

procedure TGLMenu.KeyDown(Key: TKey; C: char);

  procedure CurrentItemAccessoryKeyDown;
  begin
    if Items.Objects[CurrentItem] <> nil then
    begin
      TGLMenuItemAccessory(Items.Objects[CurrentItem]).KeyDown(
        Key, C, Self);
    end;
  end;

begin
  if Key = KeyPreviousItem then
    PreviousItem else
  if Key = KeyNextItem then
    NextItem else
  if Key = KeySelectItem then
  begin
    CurrentItemAccessoryKeyDown;
    CurrentItemSelected;
  end else
    CurrentItemAccessoryKeyDown;
end;

procedure TGLMenu.MouseMove(const NewX, NewY: Single;
  const MousePressed: TMouseButtons);
var
  NewItemIndex: Integer;
begin
  NewItemIndex := Areas.FindArea(NewX, NewY);
  if NewItemIndex <> -1 then
  begin
    if NewItemIndex <> CurrentItem then
      CurrentItem := NewItemIndex else
    { If NewItemIndex = CurrentItem and NewItemIndex <> -1,
      then user just moves mouse within current item.
      So maybe we should call TGLMenuItemAccessory.MouseMove. }
    if (Items.Objects[CurrentItem] <> nil) and
       (PointInArea(NewX, NewY, FAccessoryAreas.Items[CurrentItem])) then
      TGLMenuItemAccessory(Items.Objects[CurrentItem]).MouseMove(
        NewX, NewY, MousePressed,
        FAccessoryAreas.Items[CurrentItem], Self);
  end;
end;

procedure TGLMenu.MouseDown(const MouseX, MouseY: Single; Button: TMouseButton);
var
  NewItemIndex: Integer;
begin
  if (CurrentItem <> -1) and
     (Items.Objects[CurrentItem] <> nil) and
     (PointInArea(MouseX, MouseY, FAccessoryAreas.Items[CurrentItem])) then
  begin
    TGLMenuItemAccessory(Items.Objects[CurrentItem]).MouseDown(
      MouseX, MouseY, Button, FAccessoryAreas.Items[CurrentItem], Self);
  end;

  if Button = mbLeft then
  begin
    NewItemIndex := Areas.FindArea(MouseX, MouseY);
    if NewItemIndex <> -1 then
    begin
      CurrentItem := NewItemIndex;
      CurrentItemSelected;
    end;
  end;
end;

procedure TGLMenu.MouseUp(const MouseX, MouseY: Single; Button: TMouseButton);
begin
  { Nothing to do here for now. }
end;

procedure TGLMenu.Idle(const CompSpeed: Single);
begin
  MenuAnimation += 0.01 * CompSpeed;
  MenuAnimation := Frac(MenuAnimation);
  SomethingChanged;
end;

procedure TGLMenu.CurrentItemSelected;
begin
  { Nothing to do in this class. }
end;

procedure TGLMenu.CurrentItemChanged;
begin
  SomethingChanged;
end;

procedure TGLMenu.CurrentItemAccessoryValueChanged;
begin
  SomethingChanged;
end;

procedure TGLMenu.SomethingChanged;
begin
  { Nothing to do in this class. }
end;

end.