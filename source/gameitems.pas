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
unit GameItems;

interface

uses Boxes3D, X3DNodes, CastleScene, VectorMath, CastleUtils,
  CastleClassUtils, Classes, Images, GL, GLU, CastleGLUtils, GameSound,
  PrecalculatedAnimation, CastleResources,
  CastleXMLConfig, XmlSoundEngine, Frustum, Base3D, FGL, CastleColors;

const
  DefaultItemDamageConst = 5.0;
  DefaultItemDamageRandom = 5.0;
  DefaultItemActualAttackTime = 0.0;
  DefaultItemAttackKnockbackDistance = 1.0;

type
  TItem = class;

  { Kind of item. }
  TItemKind = class(T3DResource)
  private
  { Design question: Maybe it's better making TSword a descendant of TItem,
    and not creating TItemKind class ? This seems somewhat cleaner
    from OOP approach. Then various functions/properties
    of TItemKind must be handled as "class function" of TItem.
    Answer: I once did this (see "Jamy & Nory"), but it turns out that it's
    not comfortable --- for example I would need associative array
    (like LoadedModels) to keep TItemKind.FScene value
    (to not load and not construct new GL display list each time
    I create TSword instance). }

    FSceneFileName: string;
    FScene: TCastleScene;
    FCaption: string;
    FImageFileName: string;
    FImage: TCastleImage;
    FGLList_DrawImage: TGLuint;
    FBoundingBoxRotated: TBox3D;
    FBoundingBoxRotatedCalculated: boolean;
  protected
    procedure PrepareCore(const BaseLights: TAbstractLightInstancesList;
      const DoProgress: boolean); override;
    function PrepareCoreSteps: Cardinal; override;
    procedure ReleaseCore; override;
  public
    destructor Destroy; override;

    procedure LoadFromFile(KindsConfig: TCastleConfig); override;

    property SceneFileName: string read FSceneFileName;

    { Nice caption to display. }
    property Caption: string read FCaption;

    { Note that the Scene is nil if not Prepared. }
    function Scene: TCastleScene;

    { This is a 2d image, to be used for inventory slots etc.
      When you call this for the 1st time, the image will be loaded
      from ImageFileName.

      @noAutoLinkHere }
    function Image: TCastleImage;

    property ImageFileName: string read FImageFileName;

    { OpenGL display list to draw @link(Image). }
    function GLList_DrawImage: TGLuint;

    { Use this item.

      In this class, this just prints a message "this item cannot be used".

      Implementation of this method can assume that Item is one of
      player's owned Items. Implementation of this method can change
      Item instance properties, including Quantity.
      As a very special exception, implementation of this method
      is allowed to set Quantity of Item to 0.

      Never call this method when Player.Dead. Implementation of this
      method may assume that Player is not Dead.

      Caller of this method should always be prepared to immediately
      handle the "Quantity = 0" situation by freeing given item,
      removing it from any list etc. }
    procedure Use(Item: TItem); virtual;

    { This returns Scene.BoundingBox enlarged a little (along X and Y)
      to account the fact that Scene may be rotated around +Z vector. }
    function BoundingBoxRotated: TBox3D;
  end;

  TItemPotionOfLifeKind = class(TItemKind)
    procedure Use(Item: TItem); override;
  end;

  TItemWeaponKind = class(TItemKind)
  private
    FEquippingSound: TSoundType;
    FAttackAnimation: TCastlePrecalculatedAnimation;
    FAttackAnimationFile: string;
    FReadyAnimation: TCastlePrecalculatedAnimation;
    FReadyAnimationFile: string;
    FActualAttackTime: Single;
    FSoundAttackStart: TSoundType;
  protected
    procedure PrepareCore(const BaseLights: TAbstractLightInstancesList;
      const DoProgress: boolean); override;
    function PrepareCoreSteps: Cardinal; override;
    procedure ReleaseCore; override;
  public
    { Sound to make on equipping. Each weapon can have it's own
      equipping sound. }
    property EquippingSound: TSoundType
      read FEquippingSound write FEquippingSound;

    { Animation of attack with this weapon. TimeBegin must be 0. }
    property AttackAnimation: TCastlePrecalculatedAnimation
      read FAttackAnimation;

    { Animation of keeping weapon ready. }
    property ReadyAnimation: TCastlePrecalculatedAnimation
      read FReadyAnimation;

    procedure Use(Item: TItem); override;

    { Time within AttackAnimation
      at which ActualAttack method will be called.
      Note that actually ActualAttack may be called a *very little* later
      (hopefully it shouldn't be noticeable to the player). }
    property ActualAttackTime: Single
      read FActualAttackTime write FActualAttackTime
      default DefaultItemActualAttackTime;

    { Perform real attack here.
      This may mean hurting some creature within the range,
      or shooting some missile. You can also play some sound here. }
    procedure ActualAttack(Item: TItem; World: T3DWorld); virtual; abstract;

    property SoundAttackStart: TSoundType
      read FSoundAttackStart write FSoundAttackStart default stNone;

    procedure LoadFromFile(KindsConfig: TCastleConfig); override;
  end;

  TItemShortRangeWeaponKind = class(TItemWeaponKind)
  private
    FDamageConst: Single;
    FDamageRandom: Single;
    FAttackKnockbackDistance: Single;
  public
    constructor Create(const AId: string); override;

    property DamageConst: Single read FDamageConst write FDamageConst
      default DefaultItemDamageConst;
    property DamageRandom: Single read FDamageRandom write FDamageRandom
      default DefaultItemDamageRandom;
    property AttackKnockbackDistance: Single
      read FAttackKnockbackDistance write FAttackKnockbackDistance
      default DefaultItemAttackKnockbackDistance;

    procedure LoadFromFile(KindsConfig: TCastleConfig); override;
  end;

  TItemSwordKind = class(TItemShortRangeWeaponKind)
  public
    procedure ActualAttack(Item: TItem; World: T3DWorld); override;
  end;

  TItemBowKind = class(TItemWeaponKind)
  public
    procedure ActualAttack(Item: TItem; World: T3DWorld); override;
  end;

  TItemScrollOfFlyingKind = class(TItemKind)
    procedure Use(Item: TItem); override;
  end;

  { An item. Actually, this represents a collection of
    "stacked" items that have the same properties --- see Quantity property. }
  TItem = class(TComponent)
  private
    FKind: TItemKind;
    FQuantity: Cardinal;
  public
    constructor Create(AKind: TItemKind; AQuantity: Cardinal); reintroduce;

    property Kind: TItemKind read FKind;

    { Quantity of this item.
      This must always be >= 1. }
    property Quantity: Cardinal read FQuantity write FQuantity;

    { Stackable means that two items are equal and they can be summed
      into one item by adding their Quantity values.
      Practially this means that all properties
      of both items are equal, with the exception of Quantity. }
    function Stackable(Item: TItem): boolean;

    { This splits item (with Quantity >= 2) into two items.
      It returns newly created object with the same properties
      as this object, and with Quantity set to QuantitySplit.
      And it lowers our Quantity by QuantitySplit.

      Always QuantitySplit must be >= 1 and < Quantity. }
    function Split(QuantitySplit: Cardinal): TItem;
  end;

  TItemList = class(specialize TFPGObjectList<TItem>)
  public
    { This checks is Item "stackable" with any item on the list.
      Returns index of item on the list that is stackable with given Item,
      or -1 if none. }
    function Stackable(Item: TItem): Integer;

    { Searches for item of given Kind. Returns index of first found,
      or -1 if not found. }
    function FindKind(Kind: TItemKind): Integer;
  end;

  TItemOnLevel = class(T3DTransform)
  private
    FItem: TItem;
  protected
    function GetExists: boolean; override;
  public
    constructor Create(AOwner: TComponent;
      AItem: TItem; const ATranslation: TVector3Single); reintroduce;
    destructor Destroy; override;

    { Note that this Item is owned by TItemOnLevel instance,
      so when you will free this TItemOnLevel instance,
      Item will be also freed.
      However, you can prevent that if you want --- see ExtractItem. }
    property Item: TItem read FItem;

    { This returns Item and sets Item to nil.
      This is the only way to force TItemOnLevel instance
      to *not* free associated Item object on destruction.

      Note that Item = nil is considered invalid state of this object,
      and the only thing that you should do further with this
      TItemOnLevel instance is to free it ! }
    function ExtractItem: TItem;

    { Render the item, on current Position with current rotation etc.
      Current matrix should be modelview, this pushes/pops matrix state
      (so it 1. needs one place on matrix stack,
      2. doesn't modify current matrix).

      Pass current viewing Frustum to allow optimizing this
      (when item for sure is not within Frustum, we don't have
      to push it to OpenGL). }
    procedure Render(const Frustum: TFrustum;
      const Params: TRenderParams); override;

    procedure Idle(const CompSpeed: Single; var RemoveMe: TRemoveType); override;

    function PointingDeviceActivate(const Active: boolean;
      const Distance: Single): boolean; override;

    property Collides default false;
    property Pushable default true;
    function Middle: TVector3Single; override;
  end;

  TItemOnLevelList = class(specialize TFPGObjectList<TItemOnLevel>)
  end;

var
  Sword: TItemKind;
  Bow: TItemKind;
  LifePotion: TItemKind;
  KeyItemKind: TItemKind;
  RedKeyItemKind: TItemKind;
  Quiver: TItemKind;

const
  DefaultAutoOpenInventory = true;

var
  { Automatically open inventory on pickup ?
    Saved/loaded to config file in this unit. }
  AutoOpenInventory: boolean;

  InventoryVisible: boolean;

procedure ItemsKindsInit;

implementation

uses SysUtils, CastleWindow, CastleGameWindow,
  GamePlay, CastleFilesUtils, ProgressUnit,
  GameCreatures, CastleGameNotifications, CastleGameConfig,
  CastleSceneCore, GLImages, CastleCreatures, CastleGameVideoOptions;

{ TItemKind ------------------------------------------------------------ }

destructor TItemKind.Destroy;
begin
  FreeAndNil(FImage);
  inherited;
end;

procedure TItemKind.LoadFromFile(KindsConfig: TCastleConfig);
begin
  inherited;

  FSceneFileName := KindsConfig.GetFileName('scene');
  FImageFileName := KindsConfig.GetFileName('image');

  FCaption := KindsConfig.GetValue('caption', '');
  if FCaption = '' then
    raise Exception.CreateFmt('Empty caption attribute for item "%s"', [Id]);
end;

function TItemKind.Scene: TCastleScene;
begin
  Result := FScene;
end;

function TItemKind.Image: TCastleImage;
begin
  if FImage = nil then
    FImage := LoadImage(ImageFileName, [], []);
  Result := FImage;
end;

function TItemKind.GLList_DrawImage: TGLuint;
begin
  if FGLList_DrawImage = 0 then
    FGLList_DrawImage := ImageDrawToDisplayList(Image);
  Result := FGLList_DrawImage;
end;

procedure TItemKind.Use(Item: TItem);
begin
  Notifications.Show('This item cannot be used');
end;

function TItemKind.BoundingBoxRotated: TBox3D;
var
  HorizontalSize: Single;
begin
  if not FBoundingBoxRotatedCalculated then
  begin
    FBoundingBoxRotated := Scene.BoundingBox;

    { Note that I *cannot* assume below that Scene.BoundingBox
      middle point is (0, 0, 0). So I just take the largest distance
      from point (0, 0) to any corner of the Box (distance 2D,
      only horizontally) and this tells me the horizontal sizes of the
      bounding box.

      This hurts a little (because of 1 call to Sqrt),
      that's why results of this function are cached if FBoundingBoxRotated. }
    HorizontalSize := Max(Max(
      VectorLenSqr(Vector2Single(FBoundingBoxRotated.Data[0, 0], FBoundingBoxRotated.Data[0, 1])),
      VectorLenSqr(Vector2Single(FBoundingBoxRotated.Data[1, 0], FBoundingBoxRotated.Data[0, 1])),
      VectorLenSqr(Vector2Single(FBoundingBoxRotated.Data[1, 0], FBoundingBoxRotated.Data[1, 1]))),
      VectorLenSqr(Vector2Single(FBoundingBoxRotated.Data[0, 0], FBoundingBoxRotated.Data[1, 1])));
    HorizontalSize := Sqrt(HorizontalSize);
    FBoundingBoxRotated.Data[0, 0] := -HorizontalSize;
    FBoundingBoxRotated.Data[0, 1] := -HorizontalSize;
    FBoundingBoxRotated.Data[1, 0] := +HorizontalSize;
    FBoundingBoxRotated.Data[1, 1] := +HorizontalSize;

    FBoundingBoxRotatedCalculated := true;
  end;
  Result := FBoundingBoxRotated;
end;

procedure TItemKind.PrepareCore(const BaseLights: TAbstractLightInstancesList;
  const DoProgress: boolean);
begin
  inherited;
  PrepareScene(FScene, SceneFileName, BaseLights, DoProgress);
end;

function TItemKind.PrepareCoreSteps: Cardinal;
begin
  Result := (inherited PrepareCoreSteps) + 2;
end;

procedure TItemKind.ReleaseCore;
begin
  FScene := nil;
  inherited;
end;

{ TItemPotionOfLifeKind ---------------------------------------------------- }

procedure TItemPotionOfLifeKind.Use(Item: TItem);
begin
  if Player.Life < Player.MaxLife then
  begin
    Player.Life := Min(Player.Life + 50, Player.MaxLife);
    Notifications.Show(Format('You drink "%s"', [Item.Kind.Caption]));
    Item.Quantity := Item.Quantity - 1;
    SoundEngine.Sound(stPlayerPotionDrink);
  end else
    Notifications.Show('You feel quite alright, no need to waste this potion');
end;

{ TItemWeaponKind ------------------------------------------------------------ }

procedure TItemWeaponKind.Use(Item: TItem);
begin
  Player.EquippedWeapon := Item;
end;

procedure TItemWeaponKind.PrepareCore(const BaseLights: TAbstractLightInstancesList;
  const DoProgress: boolean);
begin
  inherited;
  PreparePrecalculatedAnimation(FAttackAnimation, FAttackAnimationFile, BaseLights, DoProgress);
  PreparePrecalculatedAnimation(FReadyAnimation , FReadyAnimationFile , BaseLights, DoProgress);
end;

function TItemWeaponKind.PrepareCoreSteps: Cardinal;
begin
  Result := (inherited PrepareCoreSteps) + 2;
end;

procedure TItemWeaponKind.ReleaseCore;
begin
  FAttackAnimation := nil;
  FReadyAnimation := nil;
  inherited;
end;

procedure TItemWeaponKind.LoadFromFile(KindsConfig: TCastleConfig);
begin
  inherited;

  ActualAttackTime := KindsConfig.GetFloat('actual_attack_time',
    DefaultItemActualAttackTime);

  EquippingSound := SoundEngine.SoundFromName(
    KindsConfig.GetValue('equipping_sound', ''));
  SoundAttackStart := SoundEngine.SoundFromName(
    KindsConfig.GetValue('sound_attack_start', ''));

  FReadyAnimationFile:= KindsConfig.GetFileName('ready_animation');
  FAttackAnimationFile := KindsConfig.GetFileName('attack_animation');
end;

{ TItemShortRangeWeaponKind -------------------------------------------------- }

constructor TItemShortRangeWeaponKind.Create(const AId: string);
begin
  inherited;
  FDamageConst := DefaultItemDamageConst;
  FDamageRandom := DefaultItemDamageRandom;
  FAttackKnockbackDistance := DefaultItemAttackKnockbackDistance;
end;

procedure TItemShortRangeWeaponKind.LoadFromFile(KindsConfig: TCastleConfig);
begin
  inherited;

  DamageConst := KindsConfig.GetFloat('damage/const',
    DefaultItemDamageConst);
  DamageRandom := KindsConfig.GetFloat('damage/random',
    DefaultItemDamageRandom);
  AttackKnockbackDistance := KindsConfig.GetFloat('attack_knockback_distance',
    DefaultItemAttackKnockbackDistance);
end;

{ TItemSwordKind ------------------------------------------------------------- }

procedure TItemSwordKind.ActualAttack(Item: TItem; World: T3DWorld);
var
  WeaponBoundingBox: TBox3D;
  I: Integer;
  C: TCreature;
begin
  { Player.Direction may be multiplied by something here for long-range weapons }
  WeaponBoundingBox := Player.BoundingBox.Translate(Player.Direction);
  { Tests: Writeln('WeaponBoundingBox is ', WeaponBoundingBox.ToNiceStr); }
  { TODO: we would prefer to use World.BoxCollision for this,
    but we need to know which creature was hit. }
  for I := 0 to World.Count - 1 do
    if World[I] is TCreature then
    begin
      C := TCreature(World[I]);
      { Tests: Writeln('Creature bbox is ', C.BoundingBox.ToNiceStr); }
      if C.BoundingBox.Collision(WeaponBoundingBox) then
      begin
        C.Hurt(DamageConst + Random * DamageRandom, Player.Direction, AttackKnockbackDistance);
      end;
    end;
end;

{ TItemBowKind ------------------------------------------------------------- }

procedure TItemBowKind.ActualAttack(Item: TItem; World: T3DWorld);
var
  QuiverIndex: Integer;
begin
  QuiverIndex := Player.Items.FindKind(Quiver);
  if QuiverIndex = -1 then
  begin
    Notifications.Show('You have no arrows');
    SoundEngine.Sound(stPlayerInteractFailed);
  end else
  begin
    { delete arrow from player }
    Player.Items[QuiverIndex].Quantity :=
      Player.Items[QuiverIndex].Quantity - 1;
    if Player.Items[QuiverIndex].Quantity = 0 then
      Player.DeleteItem(QuiverIndex).Free;

    { shoot the arrow }
    Arrow.CreateCreature(Player.World, Player.Position, Player.Direction);
    SoundEngine.Sound(stArrowFired);
  end;
end;

{ TItemScrollOfFlyingKind ---------------------------------------------------- }

procedure TItemScrollOfFlyingKind.Use(Item: TItem);
begin
  Notifications.Show(Format('You cast spell from "%s"', [Item.Kind.Caption]));
  Player.FlyingModeTimeoutBegin(30.0);
  Item.Quantity := Item.Quantity - 1;
  SoundEngine.Sound(stPlayerCastFlyingSpell);
end;

{ TItem ------------------------------------------------------------ }

constructor TItem.Create(AKind: TItemKind; AQuantity: Cardinal);
begin
  inherited Create(nil);
  FKind := AKind;
  FQuantity := AQuantity;
  Assert(Quantity >= 1, 'Item''s Quantity must be >= 1');
end;

function TItem.Stackable(Item: TItem): boolean;
begin
  Result := Item.Kind = Kind;
end;

function TItem.Split(QuantitySplit: Cardinal): TItem;
begin
  Check(Between(Integer(QuantitySplit), 1, Quantity - 1),
    'You must split >= 1 and less than current Quantity');

  Result := TItem.Create(Kind, QuantitySplit);

  FQuantity -= QuantitySplit;
end;

{ TItemList ------------------------------------------------------------ }

function TItemList.Stackable(Item: TItem): Integer;
begin
  for Result := 0 to Count - 1 do
    if Items[Result].Stackable(Item) then
      Exit;
  Result := -1;
end;

function TItemList.FindKind(Kind: TItemKind): Integer;
begin
  for Result := 0 to Count - 1 do
    if Items[Result].Kind = Kind then
      Exit;
  Result := -1;
end;

{ TItemOnLevel ------------------------------------------------------------ }

constructor TItemOnLevel.Create(AOwner: TComponent;
  AItem: TItem; const ATranslation: TVector3Single);
begin
  inherited Create(AOwner);
  FItem := AItem;
  Translation := ATranslation;
  Rotation := Vector4Single(UnitVector3Single[2], 0); { angle will animate later }

  { most item models are not 2-manifold }
  CastShadowVolumes := false;

  Pushable := true;

  Add(Item.Kind.Scene);

  { Items are not collidable, player can enter them to pick them up.
    For now, this also means that creatures can pass through them,
    which isn't really troublesome now. }
  Collides := false;
end;

destructor TItemOnLevel.Destroy;
begin
  FreeAndNil(FItem);
  inherited;
end;

function TItemOnLevel.ExtractItem: TItem;
begin
  Result := Item;
  FItem := nil;
end;

procedure TItemOnLevel.Render(const Frustum: TFrustum;
  const Params: TRenderParams);
begin
  inherited;
  if GetExists and RenderBoundingBoxes and
    (not Params.Transparent) and Params.ShadowVolumesReceivers and
    Frustum.Box3DCollisionPossibleSimple(BoundingBox) then
  begin
    glPushAttrib(GL_ENABLE_BIT);
      glDisable(GL_LIGHTING);
      glEnable(GL_DEPTH_TEST);
      glColorv(Gray3Single);
      glDrawBox3DWire(BoundingBox);
    glPopAttrib;
  end;
end;

const
  ItemRadius = 1.0;

procedure TItemOnLevel.Idle(const CompSpeed: Single; var RemoveMe: TRemoveType);
const
  FallingDownSpeed = 10.0;
var
  AboveHeight: Single;
  ShiftedTranslation: TVector3Single;
  FallingDownLength: Single;
  Rot: TVector4Single;
begin
  inherited;
  if not GetExists then Exit;

  Rot := Rotation;
  Rot[3] += 2.61 * CompSpeed;
  Rotation := Rot;

  ShiftedTranslation := Translation;
  ShiftedTranslation[2] += ItemRadius;

  { Note that I'm using ShiftedTranslation, not Translation,
    and later I'm comparing "AboveHeight > ItemRadius",
    instead of "AboveHeight > 0".
    Otherwise, I risk that when item will be placed perfectly on the ground,
    it may "slip through" this ground down. }

  MyHeight(ShiftedTranslation, AboveHeight);
  if AboveHeight > ItemRadius then
  begin
    { Item falls down because of gravity. }

    FallingDownLength := CompSpeed * FallingDownSpeed;
    MinTo1st(FallingDownLength, AboveHeight - ItemRadius);

    MyMove(Vector3Single(0, 0, -FallingDownLength), true,
      { TODO: wall-sliding here breaks left life potion on gate:
        it must be corrected (possibly by correcting the large sword mesh)
        to not "slip down" from the sword. }
      false);
  end;

  if (not Player.Dead) and (not GameWin) and
    BoundingBox.Collision(Player.BoundingBox) then
  begin
    Player.PickItem(ExtractItem);
    RemoveMe := rtRemoveAndFree;
    if AutoOpenInventory then
      InventoryVisible := true;
  end;
end;

function TItemOnLevel.PointingDeviceActivate(const Active: boolean;
  const Distance: Single): boolean;
const
  VisibleItemDistance = 60.0;
var
  S: string;
begin
  Result := Active;
  if not Result then Exit;

  if Distance <= VisibleItemDistance then
  begin
    S := Format('You see an item "%s"', [Item.Kind.Caption]);
    if Item.Quantity <> 1 then
      S += Format(' (quantity %d)', [Item.Quantity]);
    Notifications.Show(S);
  end else
    Notifications.Show('You see some item, but it''s too far to tell exactly what it is');
end;

function TItemOnLevel.GetExists: boolean;
begin
  Result := (inherited GetExists) and (not DebugRenderForLevelScreenshot);
end;

function TItemOnLevel.Middle: TVector3Single;
begin
  Result := inherited Middle;
  Result[2] += ItemRadius;
end;

{ initialization / finalization ---------------------------------------- }

procedure ItemsKindsInit;
begin
  Sword := AllResources.FindId('Sword') as TItemKind;
  Bow := AllResources.FindId('Bow') as TItemKind;
  LifePotion := AllResources.FindId('LifePotion') as TItemKind;
  KeyItemKind := AllResources.FindId('Key') as TItemKind;
  RedKeyItemKind := AllResources.FindId('RedKey') as TItemKind;
  Quiver := AllResources.FindId('Quiver') as TItemKind;
end;

procedure DoInitialization;
begin
  RegisterResourceClass(TItemKind, 'Item');
  RegisterResourceClass(TItemSwordKind, 'Sword');
  RegisterResourceClass(TItemBowKind, 'Bow');
  RegisterResourceClass(TItemPotionOfLifeKind, 'LifePotion');
  RegisterResourceClass(TItemScrollOfFlyingKind, 'ScrFlying');

  AutoOpenInventory := ConfigFile.GetValue(
    'auto_open_inventory', DefaultAutoOpenInventory);
end;

procedure DoFinalization;
begin
  ConfigFile.SetDeleteValue('auto_open_inventory',
    AutoOpenInventory, DefaultAutoOpenInventory);
end;

initialization
  DoInitialization;
finalization
  DoFinalization;
end.