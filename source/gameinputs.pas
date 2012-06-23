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

{ Key/mouse shortcuts of the game. }
unit GameInputs;

interface

uses KeysMouse, Cameras, CastleUtils, CastleClassUtils, Classes,
  FGL, GenericStructList, CastleConfig;

type
  TInputGroup = (kgBasic, kgItems, kgOther);

  { A wrapper around TInputShortcut instance
    (used to describe key/mouse shortcut for given action)
    with additional properties describing the group of the action,
    action name etc.

    Note that "castle" doesn't use TInputShortcut.Character,
    it's always #0. We detect keys only by TKey, as that's enough for now
    (and detecting by character also would complicate looking for duplicates,
    as comparison TKey <-> char is not possible without knowing involved
    modifiers). }
  TInputConfiguration = class
  private
    FName: string;
    FGroup: TInputGroup;
    FShortcut: TInputShortcut;
    FConfigName: string;
    procedure ShortcutChanged(Shortcut: TInputShortcut);
  public
    { Constructor. Note that TInputShortcut instance passed here is owned
      by this object, i.e. it will be freed in our destructor. }
    constructor Create(const AName: string;
      const AConfigName: string;
      const AGroup: TInputGroup;
      const AKey1: TKey;
      const AKey2: TKey = K_None;
      const ACharacter: Char = #0;
      const AMouseButtonUse: boolean = false;
      const AMouseButton: TMouseButton = mbLeft;
      const AMouseWheel: TMouseWheelDirection = mwNone);
    destructor Destroy; override;

    property Name: string read FName;
    property ConfigName: string read FConfigName;
    property Group: TInputGroup read FGroup;

    { The key/mouse shortcut for this action.
      You can directly change fields of this action,
      but don't mess with it's OnChanged property --- we will use
      it in this class internally. }
    property Shortcut: TInputShortcut read FShortcut;

    { Add to Shortcut new key or mouse button or mouse wheel.
      Only one of them (parameters NewXxx like for TInputShortcut.IsEvent). }
    procedure AddShortcut(const NewKey: TKey;
      const NewMousePress: boolean; const NewMouseButton: TMouseButton;
      const NewMouseWheel: TMouseWheelDirection);
  end;

  TInputConfigurationList = class(specialize TFPGObjectList<TInputConfiguration>)
  private
    procedure LoadFromConfig(const Config: TCastleConfig);
    procedure SaveToConfig(const Config: TCastleConfig);
  public
    { Seeks for a Shortcut that has matching key or mouse button or mouse wheel.
      @nil if not found. }
    function SeekMatchingShortcut(const Key: TKey;
      const MousePress: boolean; const MouseButton: TMouseButton;
      const MouseWheel: TMouseWheelDirection): TInputConfiguration;
    procedure RestoreDefaults;
    function SeekConflict(out ConflictDescription: string): boolean;
  end;

  TInputChangedEvent = procedure (InputConfiguration: TInputConfiguration) of object;
  PInputChangedEvent = ^TInputChangedEvent;

  TInputChangedEventList = class(specialize TGenericStructList<TInputChangedEvent>)
  public
    procedure ExecuteAll(InputConfiguration: TInputConfiguration);
  end;

var
  { Basic shortcuts. }
  CastleInput_Attack: TInputConfiguration;
  CastleInput_Forward: TInputConfiguration;
  CastleInput_Backward: TInputConfiguration;
  CastleInput_LeftRot: TInputConfiguration;
  CastleInput_RightRot: TInputConfiguration;
  CastleInput_LeftStrafe: TInputConfiguration;
  CastleInput_RightStrafe: TInputConfiguration;
  CastleInput_UpRotate: TInputConfiguration;
  CastleInput_DownRotate: TInputConfiguration;
  CastleInput_GravityUp: TInputConfiguration;
  CastleInput_UpMove: TInputConfiguration;
  CastleInput_DownMove: TInputConfiguration;

  { Items shortcuts. }
  CastleInput_InventoryShow: TInputConfiguration;
  CastleInput_InventoryPrevious: TInputConfiguration;
  CastleInput_InventoryNext: TInputConfiguration;
  CastleInput_UseItem: TInputConfiguration;
  CastleInput_UseLifePotion: TInputConfiguration;
  CastleInput_DropItem: TInputConfiguration;

  { Other shortcuts. }
  CastleInput_ViewMessages: TInputConfiguration;
  CastleInput_SaveScreen: TInputConfiguration;
  CastleInput_CancelFlying: TInputConfiguration;
  CastleInput_FPSShow: TInputConfiguration;
  CastleInput_Interact: TInputConfiguration;
  CastleInput_DebugMenu: TInputConfiguration;

  { List of all configurable shortcuts.
    Will be created in initialization and freed in finalization of this unit.
    All TInputConfiguration instances will automatically add to this. }
  CastleAllInputs: TInputConfigurationList;
  CastleGroupInputs: array[TInputGroup] of TInputConfigurationList;

  OnInputChanged: TInputChangedEventList;

function InteractInputDescription: string;

implementation

uses SysUtils;

function InteractInputDescription: string;
begin
  Result := CastleInput_Interact.Shortcut.Description('"Interact" key');
end;

{ TInputConfigurationList ----------------------------------------------------- }

function TInputConfigurationList.SeekMatchingShortcut(
  const Key: TKey;
  const MousePress: boolean; const MouseButton: TMouseButton;
  const MouseWheel: TMouseWheelDirection): TInputConfiguration;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    Result := Items[I];
    if Result.Shortcut.IsEvent(Key, #0, MousePress, MouseButton, MouseWheel) then
      Exit;
  end;
  Result := nil;
end;

procedure TInputConfigurationList.RestoreDefaults;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Items[I].Shortcut.MakeDefault;
end;

procedure TInputConfigurationList.SaveToConfig(const Config: TCastleConfig);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    Config.SetDeleteValue('inputs/' + Items[I].ConfigName + '/key1',
      Items[I].Shortcut.Key1, Items[I].Shortcut.DefaultKey1);
    Config.SetDeleteValue('inputs/' + Items[I].ConfigName + '/key2',
      Items[I].Shortcut.Key2, Items[I].Shortcut.DefaultKey2);
    Config.SetDeleteValue('inputs/' + Items[I].ConfigName + '/mouse_button_use',
      Items[I].Shortcut.MouseButtonUse, Items[I].Shortcut.DefaultMouseButtonUse);
    Config.SetDeleteValue('inputs/' + Items[I].ConfigName + '/mouse_button',
      Ord(Items[I].Shortcut.MouseButton), Ord(Items[I].Shortcut.DefaultMouseButton));
    Config.SetDeleteValue('inputs/' + Items[I].ConfigName + '/mouse_wheel',
      Ord(Items[I].Shortcut.MouseWheel), Ord(Items[I].Shortcut.DefaultMouseWheel));
  end;
end;

procedure TInputConfigurationList.LoadFromConfig(const Config: TCastleConfig);
var
  I: Integer;
  ConflictDescription: string;
begin
  for I := 0 to Count - 1 do
  begin
    Items[I].Shortcut.Key1 := Config.GetValue(
      'inputs/' + Items[I].ConfigName + '/key1', Items[I].Shortcut.DefaultKey1);
    Items[I].Shortcut.Key2 := Config.GetValue(
      'inputs/' + Items[I].ConfigName + '/key2', Items[I].Shortcut.DefaultKey2);
    Items[I].Shortcut.MouseButtonUse := Config.GetValue(
      'inputs/' + Items[I].ConfigName + '/mouse_button_use',
      Items[I].Shortcut.DefaultMouseButtonUse);
    Items[I].Shortcut.MouseButton := TMouseButton(Config.GetValue(
      'inputs/' + Items[I].ConfigName + '/mouse_button',
      Ord(Items[I].Shortcut.DefaultMouseButton)));
    Items[I].Shortcut.MouseWheel := TMouseWheelDirection(Config.GetValue(
      'inputs/' + Items[I].ConfigName + '/mouse_wheel',
      Ord(Items[I].Shortcut.DefaultMouseWheel)));
  end;

  if SeekConflict(ConflictDescription) then
  begin
    WarningWrite(
      'Your key/mouse shortcuts layout has conflicts. This can happen if you ' +
      'just upgraded the game to newer version, and the newer version has new ' +
      'key/mouse shortcuts or has different default key/mouse shortcuts than previous ' +
      'version. It can also happen if you manually edited the configuration ' +
      'file. I will reset your key/mouse shortcuts to default now.' +nl+
      nl+
      'Detailed conflict description: ' + ConflictDescription);
    RestoreDefaults;
  end;
end;

function TInputConfigurationList.SeekConflict(
  out ConflictDescription: string): boolean;
var
  I, J: Integer;
begin
  for I := 0 to Count - 1 do
    for J := I + 1 to Count - 1 do
    begin
      if Items[J].Shortcut.IsKey(Items[I].Shortcut.Key1, #0) or
         Items[J].Shortcut.IsKey(Items[I].Shortcut.Key2, #0) or
         (Items[I].Shortcut.MouseButtonUse and
           Items[J].Shortcut.IsMouseButton(Items[I].Shortcut.MouseButton)) then
      begin
        ConflictDescription := Format('"%s" conflicts with "%s"',
          [Items[I].Name, Items[J].Name]);
        Exit(true);
      end;
    end;
  Result := false;
end;

{ TInputChangedEventList -------------------------------------------------- }

procedure TInputChangedEventList.ExecuteAll(
  InputConfiguration: TInputConfiguration);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Items[I](InputConfiguration);
end;

{ TInputConfiguration ---------------------------------------------------------- }

constructor TInputConfiguration.Create(const AName: string;
  const AConfigName: string;
  const AGroup: TInputGroup;
  const AKey1: TKey;
  const AKey2: TKey;
  const ACharacter: Char;
  const AMouseButtonUse: boolean;
  const AMouseButton: TMouseButton;
  const AMouseWheel: TMouseWheelDirection);
begin
  inherited Create;
  FName := AName;
  FConfigName := AConfigName;
  FGroup := AGroup;

  FShortcut := TInputShortcut.Create(nil);
  FShortcut.Assign(AKey1, AKey2, ACharacter, AMouseButtonUse, AMouseButton, AMouseWheel);
  FShortcut.OnChanged := @ShortcutChanged;

  CastleAllInputs.Add(Self);
  CastleGroupInputs[Group].Add(Self);
end;

destructor TInputConfiguration.Destroy;
begin
  FreeAndNil(FShortcut);
  inherited;
end;

procedure TInputConfiguration.ShortcutChanged(Shortcut: TInputShortcut);
begin
  Assert(Shortcut = Self.Shortcut);
  OnInputChanged.ExecuteAll(Self);
end;

procedure TInputConfiguration.AddShortcut(const NewKey: TKey;
  const NewMousePress: boolean; const NewMouseButton: TMouseButton;
  const NewMouseWheel: TMouseWheelDirection);
begin
  if NewMousePress then
  begin
    Shortcut.MouseButtonUse := NewMousePress;
    Shortcut.MouseButton := NewMouseButton;
  end else
  if NewMouseWheel <> mwNone then
    Shortcut.MouseWheel := NewMouseWheel else
  if Shortcut.Key1 = K_None then
    Shortcut.Key1 := NewKey else
  if Shortcut.Key2 = K_None then
    Shortcut.Key2 := NewKey else
  begin
    { We move the previous Key1 to Key2, and set Key1 to new key.
      This looks nice for user when Shortcut is displayed as the
      menu argument. }
    Shortcut.Key2 := Shortcut.Key1;
    Shortcut.Key1 := NewKey;
  end;
end;

{ initialization / finalization ---------------------------------------------- }

procedure DoInitialization;
var
  InputGroup: TInputGroup;
  ConflictDescription: string;
begin
  OnInputChanged := TInputChangedEventList.Create;
  CastleAllInputs := TInputConfigurationList.Create(true);

  for InputGroup := Low(InputGroup) to High(InputGroup) do
    CastleGroupInputs[InputGroup] := TInputConfigurationList.Create(false);

  { Order of creation below is significant: it determines the order
    of menu entries in "Configure controls". }

  { Basic shortcuts. }
  CastleInput_Attack := TInputConfiguration.Create('Attack', 'attack', kgBasic,
    K_Ctrl, K_None, #0, true, mbLeft);
  CastleInput_Forward := TInputConfiguration.Create('Move forward', 'move_forward', kgBasic,
    K_W, K_Up, #0, false, mbLeft);
  CastleInput_Backward := TInputConfiguration.Create('Move backward', 'move_backward', kgBasic,
    K_S, K_Down, #0, false, mbLeft);
  CastleInput_LeftStrafe := TInputConfiguration.Create('Move left', 'move_left', kgBasic,
    K_A, K_None, #0, false, mbLeft);
  CastleInput_RightStrafe := TInputConfiguration.Create('Move right', 'move_right', kgBasic,
    K_D, K_None, #0, false, mbLeft);
  CastleInput_LeftRot := TInputConfiguration.Create('Turn left', 'turn_left', kgBasic,
    K_Left, K_None, #0, false, mbLeft);
  CastleInput_RightRot := TInputConfiguration.Create('Turn right', 'turn_right', kgBasic,
    K_Right, K_None, #0, false, mbLeft);
  CastleInput_UpRotate := TInputConfiguration.Create('Look up', 'look_up', kgBasic,
    K_PageDown, K_None, #0, false, mbLeft);
  CastleInput_DownRotate := TInputConfiguration.Create('Look down', 'look_down', kgBasic,
    K_Delete, K_None, #0, false, mbLeft);
  CastleInput_GravityUp := TInputConfiguration.Create('Look straight', 'look_straight', kgBasic,
    K_End, K_None, #0, false, mbLeft);
  CastleInput_UpMove := TInputConfiguration.Create('Jump (or fly/swim up)', 'move_up', kgBasic,
    K_Space, K_None, #0, true, mbRight);
  CastleInput_DownMove := TInputConfiguration.Create('Crouch (or fly/swim down)', 'move_down', kgBasic,
    K_C, K_None, #0, false, mbLeft);

  { Items shortcuts. }
  CastleInput_InventoryShow := TInputConfiguration.Create('Inventory show / hide', 'inventory_toggle', kgItems,
    K_I, K_None, #0, false, mbLeft);
  CastleInput_InventoryPrevious := TInputConfiguration.Create('Select previous inventory item', 'inventory_previous', kgItems,
    K_LeftBracket, K_None, #0, false, mbLeft, mwUp);
  CastleInput_InventoryNext := TInputConfiguration.Create('Select next inventory item', 'inventory_next', kgItems,
    K_RightBracket, K_None, #0, false, mbLeft, mwDown);
  CastleInput_UseItem := TInputConfiguration.Create('Use (or equip) selected inventory item', 'item_use', kgItems,
    K_Enter, K_None, #0, false, mbLeft);
  CastleInput_UseLifePotion := TInputConfiguration.Create('Use life potion', 'life_potion_use', kgItems,
    K_L, K_None, #0, false, mbLeft);
  CastleInput_DropItem := TInputConfiguration.Create('Drop selected inventory item', 'item_drop', kgItems,
    K_R, K_None, #0, false, mbLeft);

  { Other shortcuts. }
  CastleInput_ViewMessages := TInputConfiguration.Create('View all messages', 'view_messages', kgOther,
    K_M, K_None, #0, false, mbLeft);
  CastleInput_SaveScreen := TInputConfiguration.Create('Save screen', 'save_screen', kgOther,
    K_F5, K_None, #0, false, mbLeft);
  CastleInput_CancelFlying := TInputConfiguration.Create('Cancel flying spell', 'cancel_flying', kgOther,
    K_Q, K_None, #0, false, mbLeft);
  CastleInput_FPSShow := TInputConfiguration.Create('FPS show / hide', 'fps_toggle', kgOther,
    K_Tab, K_None, #0, false, mbLeft);
  CastleInput_Interact := TInputConfiguration.Create('Interact (press button / open door etc.)', 'interact', kgOther,
    K_E, K_None, #0, false, mbLeft);
  CastleInput_DebugMenu := TInputConfiguration.Create('Debug menu', 'debug_menu', kgOther,
    K_BackQuote, K_None, #0, false, mbLeft);

  if CastleAllInputs.SeekConflict(ConflictDescription) then
    raise EInternalError.Create(
      'Default key/mouse shortcuts layout has conflicts: ' + ConflictDescription);

  Config.OnLoad.Add(@CastleAllInputs.LoadFromConfig);
  Config.OnSave.Add(@CastleAllInputs.SaveToConfig);
end;

procedure DoFinalization;
var
  InputGroup: TInputGroup;
begin
  if (CastleAllInputs <> nil) and (Config <> nil) then
  begin
    Config.OnLoad.Remove(@CastleAllInputs.LoadFromConfig);
    Config.OnSave.Remove(@CastleAllInputs.SaveToConfig);
  end;

  for InputGroup := Low(InputGroup) to High(InputGroup) do
    FreeAndNil(CastleGroupInputs[InputGroup]);

  FreeAndNil(CastleAllInputs);
  FreeAndNil(OnInputChanged);
end;

initialization
  DoInitialization;
finalization
  DoFinalization;
end.