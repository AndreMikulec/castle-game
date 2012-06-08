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

{ TGameSceneManager class and level loading. }
unit GameLevel;

interface

uses VectorMath, CastleSceneCore, CastleScene, Boxes3D,
  X3DNodes, X3DFields, GameItems, Cameras,
  GameCreatures, GameSound, Background,
  CastleUtils, CastleClassUtils, GamePlayer, GameThunder, GameObjectKinds,
  ProgressUnit, PrecalculatedAnimation,
  DOM, XmlSoundEngine, Base3D, Shape,
  Classes, CastleTimeUtils, CastleSceneManager, GLRendererShader, FGL;

type
  TLevel = class;
  TLevelClass = class of TLevel;

  TCastleSceneClass = class of TCastleScene;
  TCastlePrecalculatedAnimationClass = class of TCastlePrecalculatedAnimation;

  TLevelScene = class;

  { Invisible and non-colliding areas on the level that have some special purpose.
    What exactly this "purpose" is, is defined in each TLevelArea descendant.

    This class defines only a properties to define the area.
    For now, each area is just one TBox3D. }
  TLevelArea = class(T3D)
  private
    FId: string;
    FBox: TBox3D;

    { Area. Default value is EmptyBox3D. }
    property Box: TBox3D read FBox write FBox;
  public
    constructor Create(AOwner: TComponent); override;

    { Name used to recognize this object's area in level VRML/X3D file.

      If this object is present during ChangeLevelScene call
      then the shape with a parent named like @link(Id)
      will be removed from VRML/X3D file, and it's BoundingBox will be used
      as Box3D of this object.

      This way you can easily configure area of this object in Blender:
      just add a cube, set it's mesh name to match with this @link(Id),
      and then this cube defines Box3D of this object. }
    property Id: string read FId write FId;

    function PointInside(const Point: TVector3Single): boolean;

    function BoundingBox: TBox3D; override;

    { Called when loading level. This is the place when you
      can modify MainScene, e.g. by calling MainScene.RemoveBoxNode. }
    procedure ChangeLevelScene(MainScene: TLevelScene);
  end;

  { This defines area on the level that causes
    a Notification to be displayed when player enters inside.
    The natural use for it is to display various hint messages when player
    is close to something. }
  TLevelHintArea = class(TLevelArea)
  private
    FMessage: string;
    FMessageDone: boolean;
  public
    { Message to this display when player enters Box3D.
      Some formatting strings are allowed inside:
      @unorderedList(
        @item(%% produces InteractInputDescription in the message.)
        @item(%% produces one % in the message.)
      )
      @noAutoLinkHere }
    property Message: string read FMessage write FMessage;

    { Was the @link(Message) already displayed ? If @true,
      then it will not be displayed again (unless you will
      reset MessageDone to @false from your TLevel descendant code). }
    property MessageDone: boolean read FMessageDone write FMessageDone
      default false;

    procedure Idle(const CompSpeed: Single; var RemoveMe: TRemoveType); override;
  end;

  TLevelScene = class(TCastleScene)
  public
    { Find Blender mesh with given name, extract it's bounding box
      and remove it from scene.
      See also [http://castle-engine.sourceforge.net/castle-development.php]
      for description of CameraBox and WaterBox trick.
      Remember that this may change MainScene.BoundingBox (in case we will
      find and remove the node). }
    function RemoveBoxNode(out Box: TBox3D; const NodeName: string): boolean;

    { Like RemoveBoxNode, but raise EInternalError if not found. }
    procedure RemoveBoxNodeCheck(out Box: TBox3D; const NodeName: string);
  end;

  TGameSceneManager = class(TCastleSceneManager)
  private
    FCameraPreferredHeight: Single;
    FMoveHorizontalSpeed: Single;
    FMoveVerticalSpeed: Single;
    FSickProjection: boolean;
    FSickProjectionSpeed: TFloatTime;

    { Used only within constructor.
      We will process the scene graph, and sometimes it's not comfortable
      to remove the items while traversing --- so we will instead
      put them on this list.

      Be careful: never add here two nodes such that one may be parent
      of another, otherwise freeing one could free the other one too
      early. }
    ItemsToRemove: TX3DNodeList;

    FLevel: TLevel;

    FPlayedMusicSound: TSoundType;
    FId: string;
    FSceneFileName: string;
    FTitle: string;
    FTitleHint: string;
    FNumber: Integer;

    FMenuBackground: boolean;
    FSceneDynamicShadows: boolean;

    FResources: T3DResourceList;

    procedure TraverseForItems(Shape: TShape);
    procedure SetSickProjection(const Value: boolean);
    procedure SetSickProjectionSpeed(const Value: TFloatTime);
    procedure TraverseForCreatures(Shape: TShape);
    procedure LoadFromDOMElement(Element: TDOMElement);
  protected
    FFootstepsSound: TSoundType;

    procedure RenderFromViewEverything; override;
    procedure InitializeLights(const Lights: TLightInstancesList); override;
    procedure ApplyProjection; override;
    procedure PointingDeviceActivateFailed(const Active: boolean); override;
  public
    { Load level from file, create octrees, prepare for OpenGL etc.
      This uses ProgressUnit while loading creating octrees,
      be sure to initialize Progress.UserInterface before calling this. }
    constructor Create(
      const AId: string;
      const ASceneFileName: string;
      const ATitle: string; const ATitleHint: string; const ANumber: Integer;
      DOMElement: TDOMElement;
      AResources: T3DResourceList;
      AMenuBackground: boolean;
      LevelClass: TLevelClass); reintroduce; virtual;

    destructor Destroy; override;

    { Unique identifier for this level.
      Should be a suitable identifier in Pascal.
      @noAutoLinkHere }
    property Id: string read FId;

    { These will be used in constructor to load level.
      @groupBegin }
    property SceneFileName: string read FSceneFileName;
    { @groupEnd }

    { }
    property CameraPreferredHeight: Single read FCameraPreferredHeight;
    property MoveHorizontalSpeed: Single read FMoveHorizontalSpeed;
    property MoveVerticalSpeed: Single read FMoveVerticalSpeed;

    property PlayedMusicSound: TSoundType
      read FPlayedMusicSound write FPlayedMusicSound default stNone;

    { This is read from level XML file, stPlayerFootstepsConcrete by default. }
    property FootstepsSound: TSoundType
      read FFootstepsSound write FFootstepsSound;

    { This is the nice name of the level. }
    property Title: string read FTitle;

    property TitleHint: string read FTitleHint;

    { This is level number, shown for the player in the menu.
      This *does not* determine the order in which levels are played,
      as levels do not have to be played in linear order.
      However, they are displayed in menu in linear order, and that's
      why this is needed. }
    property Number: Integer read FNumber;

    property MenuBackground: boolean read FMenuBackground write FMenuBackground;

    { If @true, we will render dynamic shadows (shadow volumes) for
      all scene geometry. This allows the whole level to use dynamic
      shadows. It's normally read from data/levels/index.xml,
      attribute scene_dynamic_shadows. }
    property SceneDynamicShadows: boolean
      read FSceneDynamicShadows write FSceneDynamicShadows default false;

    procedure BeforeDraw; override;

    property SickProjection: boolean
      read FSickProjection write SetSickProjection;
    property SickProjectionSpeed: TFloatTime
      read FSickProjectionSpeed write SetSickProjectionSpeed;

    { Level logic. }
    property Level: TLevel read FLevel;

    function CollisionIgnoreItem(
      const Sender: TObject;
      const Triangle: P3DTriangle): boolean; override;
    function Background: TBackground; override;
  end;

  { Level logic. We use T3D descendant, since this is the comfortable
    way to add any behavior to the 3D world (it doesn't matter that
    "level logic" is not a usual 3D object --- it doesn't have to collide
    or be visible). And we add some game-specific stuff,
    like BossCreatureIndicator. }
  TLevel = class(T3D)
  private
    FAnimationTime: TFloatTime;
    FThunderEffect: TThunderEffect;
  protected
    { Scene manager containing this level. }
    SceneManager: TGameSceneManager;

    FBossCreature: TCreature;

    { Load TCastlePrecalculatedAnimation from *.kanim file, doing common tasks.
      @unorderedList(
        @item sets Attributes according to AnimationAttributesSet
        @item optionally creates triangle octree for the FirstScene and/or LastScene
        @item(call PrepareResources, with prRender, prBoundingBox, prShadowVolume
          (if shadow volumes enabled by RenderShadowsPossible))
        @item FreeExternalResources, since they will not be needed anymore
        @item TimePlaying is by default @false, so the animation is not playing.
      ) }
    function LoadLevelAnimation(
      const FileName: string;
      CreateFirstOctreeCollisions,
      CreateLastOctreeCollisions: boolean;
      const AnimationClass: TCastlePrecalculatedAnimationClass): TCastlePrecalculatedAnimation;
    function LoadLevelAnimation(
      const FileName: string;
      CreateFirstOctreeCollisions,
      CreateLastOctreeCollisions: boolean): TCastlePrecalculatedAnimation;

    { Just load TCastleScene from file, doing some common tasks:
      @unorderedList(
        @item sets Attributes according to AttributesSet
        @item optionally create triangle octree
        @item(call PrepareResources, with prRender, prBoundingBox, prShadowVolume
          (if shadow volumes enabled by RenderShadowsPossible), optionally
          with prBackground)
        @item FreeExternalResources, since they will not be needed anymore
      ) }
    function LoadLevelScene(const FileName: string;
      CreateOctreeCollisions, PrepareBackground: boolean;
      const SceneClass: TCastleSceneClass): TCastleScene;
    function LoadLevelScene(const FileName: string;
      CreateOctreeCollisions, PrepareBackground: boolean): TCastleScene;
  public
    { Create new level instance. Called when creatures and hints are already
      initialized. But before creating resources like octrees,
      so you can modify MainScene contents. }
    constructor Create(AOwner: TComponent; AWorld: T3DWorld;
      MainScene: TLevelScene; DOMElement: TDOMElement); reintroduce; virtual;
    destructor Destroy; override;
    function BoundingBox: TBox3D; override;

    { Called when new player starts game on this level.
      This is supposed to equip the player with some basic weapon/items.

      Usually level design assumes that player came to level from some
      other level in the game, so he already owns some weapon / items etc.
      But when player uses "New Game" command to get to some already
      AvailableForNewGame non-first level, this method will be called and it should
      give player some basic weapon / items suitable for starting this level.

      In TLevel class implementation of this does nothing.  }
    procedure PrepareNewPlayer(NewPlayer: TPlayer); virtual;

    { What to show on boss creature indicator.
      Default implementation in this class uses BossCreature property:
      if it's non-nil and BossCreature is alive, then indicator shows
      BossCreature life. }
    function BossCreatureIndicator(out Life, MaxLife: Single): boolean; virtual;

    { Instance of boss creature, if any, on the level. @nil if no boss creature
      exists on this level. }
    property BossCreature: TCreature read FBossCreature;

    { Time of the level, in seconds. Time 0 when level is created.
      This is updated in our Idle. }
    property AnimationTime: TFloatTime read FAnimationTime;

    { For thunder effect. nil if no thunder effect should be done for this level.

      Descendants can set this in their constructor.
      We will call it's Idle, GamePlay will call it's InitGLLight and Render,
      our destructor will free it. }
    property ThunderEffect: TThunderEffect
      read FThunderEffect write FThunderEffect;

    procedure Idle(const CompSpeed: Single; var RemoveMe: TRemoveType); override;

    { Override background of the world. Leave @nil to let scene manager
      use default (from MainScene.Background). }
    function Background: TBackground; virtual;
  end;

  TLevelClasses = specialize TFPGMap<string, TLevelClass>;

var
  LevelClasses: TLevelClasses;

implementation

uses SysUtils, GL, Triangle,
  GamePlay, CastleGLUtils, CastleFilesUtils, CastleStringUtils,
  GameVideoOptions, GameConfig, GameNotifications,
  GameInputs, GameWindow, CastleXMLUtils,
  GLRenderer, RenderingCameraUnit, Math, CastleWarnings;

{ TLevelScene ---------------------------------------------------------------- }

function TLevelScene.RemoveBoxNode(out Box: TBox3D; const NodeName: string): boolean;
var
  BoxShape: TShape;
begin
  BoxShape := Shapes.FindBlenderMesh(NodeName);
  Result := BoxShape <> nil;
  if Result then
  begin
    { When node with name NodeName is found, then we calculate our
      Box from this node (and we delete this node from the scene,
      as it should not be visible).
      This way we can comfortably set such boxes from Blender. }
    Box := BoxShape.BoundingBox;
    RemoveShapeGeometry(BoxShape);
  end;
end;

procedure TLevelScene.RemoveBoxNodeCheck(out Box: TBox3D; const NodeName: string);
begin
  if not RemoveBoxNode(Box, NodeName) then
    raise EInternalError.CreateFmt('Error: no box named "%s" found', [NodeName]);
end;

{ TLevelArea ----------------------------------------------------------------- }

constructor TLevelArea.Create(AOwner: TComponent);
begin
  inherited;
  FBox := EmptyBox3D;
  { Actually, the fact that our BoundingBox is empty also prevents collisions.
    But for some methods, knowing that Collides = false allows them to exit
    faster. }
  Collides := false;
end;

function TLevelArea.BoundingBox: TBox3D;
begin
  { This object is invisible and non-colliding. }
  Result := EmptyBox3D;
end;

procedure TLevelArea.ChangeLevelScene(MainScene: TLevelScene);
begin
  inherited;
  MainScene.RemoveBoxNodeCheck(FBox, Id);
end;

function TLevelArea.PointInside(const Point: TVector3Single): boolean;
begin
  Result := Box.PointInside(Point);
end;

{ TLevelHintArea ----------------------------------------------------------- }

procedure TLevelHintArea.Idle(const CompSpeed: Single; var RemoveMe: TRemoveType);
var
  ReplaceInteractInput: TPercentReplace;
begin
  inherited;
  if (not MessageDone) and
     (Player <> nil) and
     PointInside(Player.Position) then
  begin
    ReplaceInteractInput.C := 'i';
    ReplaceInteractInput.S := InteractInputDescription;
    Notifications.Show(SPercentReplace(Message, [ReplaceInteractInput], true));
    MessageDone := true;
  end;
end;

{ TGameSceneManager --------------------------------------------------------------------- }

constructor TGameSceneManager.Create(
  const AId: string;
  const ASceneFileName: string;
  const ATitle: string; const ATitleHint: string; const ANumber: Integer;
  DOMElement: TDOMElement;
  AResources: T3DResourceList;
  AMenuBackground: boolean;
  LevelClass: TLevelClass);

  procedure RemoveItemsToRemove;
  var
    I: Integer;
  begin
    MainScene.BeforeNodesFree;
    for I := 0 to ItemsToRemove.Count - 1 do
      ItemsToRemove.Items[I].FreeRemovingFromAllParents;
    MainScene.ChangedAll;
  end;

  { Assign Camera, knowing MainScene and APlayer.
    We need to assign Camera early, as initial Camera also is used
    when placing initial creatures on the level (to determine their
    gravity up, initial direciton etc.) }
  procedure InitializeCamera;
  var
    InitialPosition: TVector3Single;
    InitialDirection: TVector3Single;
    InitialUp: TVector3Single;
    GravityUp: TVector3Single;
    CameraRadius: Single;
    NavigationNode: TNavigationInfoNode;
    NavigationSpeed: Single;
    WalkCamera: TWalkCamera;
  begin
    MainScene.GetPerspectiveViewpoint(InitialPosition,
      InitialDirection, InitialUp, GravityUp);

    NavigationNode := MainScene.NavigationInfoStack.Top as TNavigationInfoNode;

    if (NavigationNode <> nil) and (NavigationNode.FdAvatarSize.Count >= 1) then
      CameraRadius := NavigationNode.FdAvatarSize.Items[0] else
      CameraRadius := MainScene.BoundingBox.AverageSize(false, 1) * 0.007;

    if (NavigationNode <> nil) and (NavigationNode.FdAvatarSize.Count >= 2) then
      FCameraPreferredHeight := NavigationNode.FdAvatarSize.Items[1] else
      FCameraPreferredHeight := CameraRadius * 5;
    CorrectPreferredHeight(FCameraPreferredHeight, CameraRadius,
      DefaultCrouchHeight, DefaultHeadBobbing);

    if NavigationNode <> nil then
      NavigationSpeed := NavigationNode.FdSpeed.Value else
      NavigationSpeed := 1.0;

    { Fix InitialDirection length, and set MoveXxxSpeed.

      We want to have horizontal and vertical speeds controlled independently,
      so we just normalize InitialDirection and set speeds in appropriate
      MoveXxxSpeed. }
    NormalizeTo1st(InitialDirection);
    FMoveHorizontalSpeed := NavigationSpeed;
    FMoveVerticalSpeed := 20;

    { Check and fix GravityUp. }
    if not VectorsEqual(Normalized(GravityUp),
             Vector3Single(0, 0, 1), 0.001) then
      raise EInternalError.CreateFmt(
        'Gravity up vector must be +Z, but is %s',
        [ VectorToRawStr(Normalized(GravityUp)) ]) else
      { Make GravityUp = (0, 0, 1) more "precisely" }
      GravityUp := Vector3Single(0, 0, 1);

    if Player <> nil then
      WalkCamera := GamePlay.Player.Camera else
      { Camera suitable for background level and castle-view-level.
        For actual game, camera will be taken from APlayer.Camera. }
      WalkCamera := TWalkCamera.Create(Self);

    Camera := WalkCamera;

    WalkCamera.Init(InitialPosition, InitialDirection,
      InitialUp, GravityUp, CameraPreferredHeight, CameraRadius);
    WalkCamera.CancelFallingDown;
  end;

var
  Options: TPrepareResourcesOptions;
  NewCameraBox, NewWaterBox: TBox3D;
  SI: TShapeTreeIterator;
  MainLevelScene: TLevelScene;
  I: Integer;
begin
  inherited Create(nil);

  Player := GamePlay.Player;

  UseGlobalLights := true;
  ApproximateActivation := true;
  Input_PointingDeviceActivate.Assign(CastleInput_Interact.Shortcut, false);

  FId := AId;
  FSceneFileName := ASceneFileName;
  FTitle := ATitle;
  FTitleHint := ATitleHint;
  FNumber := ANumber;
  FMenuBackground := AMenuBackground;
  FResources := T3DResourceList.Create(false);
  FResources.Assign(AResources);

  FResources.Prepare(BaseLights);

  Progress.Init(1, 'Loading level "' + Title + '"');
  try
    MainLevelScene := TLevelScene.CreateCustomCache(Self, GLContextCache);
    MainScene := MainLevelScene;
    MainScene.Load(SceneFileName);

    AttributesSet(MainScene.Attributes);
    MainScene.Attributes.UseSceneLights := true;
    if BumpMapping then
      MainScene.Attributes.BumpMapping := bmBasic else
      MainScene.Attributes.BumpMapping := bmNone;
    MainScene.Attributes.UseOcclusionQuery := UseOcclusionQuery;

    { Scene must be the first one on Items, this way MoveAllowed will
      use Scene for wall-sliding (see T3DList.MoveAllowed implementation). }
    Items.Add(MainScene);

    if Player <> nil then
      Items.Add(Player);

    LoadFromDOMElement(DOMElement);
    { call ChangeLevelScene on TLevelArea created by LoadFromDOMElement }
    for I := 0 to Items.Count - 1 do
    begin
      if Items[I] is TLevelArea then
        TLevelArea(Items[I]).ChangeLevelScene(MainLevelScene);
    end;

    InitializeCamera;

    ItemsToRemove := TX3DNodeList.Create(false);
    try
      { Initialize Items }
      SI := TShapeTreeIterator.Create(MainScene.Shapes, { OnlyActive } true);
      try
        while SI.GetNext do TraverseForItems(SI.Current);
      finally SysUtils.FreeAndNil(SI) end;

      { Initialize Creatures }
      SI := TShapeTreeIterator.Create(MainScene.Shapes, { OnlyActive } true);
      try
        while SI.GetNext do TraverseForCreatures(SI.Current);
      finally SysUtils.FreeAndNil(SI) end;

      RemoveItemsToRemove;
    finally ItemsToRemove.Free end;

    { Calculate CameraBox. }
    if not MainLevelScene.RemoveBoxNode(NewCameraBox, 'LevelBox') then
    begin
      { Set CameraBox to MainScene.BoundingBox, and make maximum Z larger. }
      NewCameraBox := MainScene.BoundingBox;
      NewCameraBox.Data[1, 2] += 4 * (NewCameraBox.Data[1, 2] - NewCameraBox.Data[0, 2]);
    end;
    CameraBox := NewCameraBox;

    if MainLevelScene.RemoveBoxNode(NewWaterBox, 'WaterBox') then
      WaterBox := NewWaterBox;

    CreateSectors(MainScene);

    { create Level after creatures and hint areas are initialized
      (some TLevel descendant constructors depend on this),
      but still before preparing resources like octrees (because we still
      may want to modify MainScene inside Level constructor). }
    FLevel := LevelClass.Create(Self, Items, MainLevelScene, DOMElement);
    Items.Add(Level);

    MainScene.CastShadowVolumes := SceneDynamicShadows;

    { calculate Options for PrepareResources }
    Options := [prRender, prBackground, prBoundingBox];
    if RenderShadowsPossible and SceneDynamicShadows then
      Options := Options + prShadowVolume;

    MainScene.PrepareResources(Options, false, BaseLights);

    MainScene.FreeResources([frTextureDataInNodes]);

    Progress.Step;
  finally
    Progress.Fini;
  end;

  { Loading octree have their own Progress, so we load them outside our
    progress. }

  if not MenuBackground then
  begin
    MainScene.TriangleOctreeProgressTitle := 'Loading level (triangle octree)';
    MainScene.ShapeOctreeProgressTitle := 'Loading level (Shape octree)';
    MainScene.Spatial := [ssRendering, ssDynamicCollisions];
    MainScene.PrepareResources([prSpatial], false, BaseLights);
  end;

  MainScene.ProcessEvents := true;

  { Needed for sick projection effect, that potentially updates
    DistortFieldOfViewY and such every frame. }
  AlwaysApplyProjection := true;
end;

destructor TGameSceneManager.Destroy;
begin
  if FResources <> nil then
  begin
    FResources.Release;
    FreeAndNil(FResources);
  end;
  inherited;
end;

procedure TGameSceneManager.LoadFromDOMElement(Element: TDOMElement);

  procedure MissingRequiredAttribute(const AttrName, ElementName: string);
  begin
    raise Exception.CreateFmt(
      'Missing required attribute "%s" of <%s> element', [AttrName, ElementName]);
  end;

  function LevelHintAreaFromDOMElement(Element: TDOMElement): TLevelHintArea;
  begin
    Result := TLevelHintArea.Create(Self);
    Result.Message := DOMGetTextData(Element);
  end;

  function LevelAreaFromDOMElement(Element: TDOMElement): TLevelArea;
  var
    Child: TDOMElement;
  begin
    Child := DOMGetOneChildElement(Element);
    if Child.TagName = 'hint' then
      Result := LevelHintAreaFromDOMElement(Child) else
      raise Exception.CreateFmt('Not allowed children element of <area>: "%s"',
        [Child.TagName]);

    if not DOMGetAttribute(Element, 'id', Result.FId) then
      MissingRequiredAttribute('id', 'area');
  end;

  function LevelObjectFromDOMElement(Element: TDOMElement): T3D;
  begin
    if Element.TagName = 'area' then
      Result := LevelAreaFromDOMElement(Element) else
    if (Element.TagName = 'resources') or
       (Element.TagName = 'bump_mapping_light') then
    begin
      { These are handled elsewhere, and don't produce any T3D. }
      Result := nil;
    end else
      raise Exception.CreateFmt('Not allowed children element of <level>: "%s"',
        [Element.TagName]);
  end;

var
  SoundName: string;
  I: TXMLElementIterator;
  NewObject: T3D;
begin
  { Load Objects }
  I := TXMLElementIterator.Create(Element);
  try
    while I.GetNext do
    begin
      NewObject := LevelObjectFromDOMElement(I.Current);
      if NewObject <> nil then
        Items.Add(NewObject);
    end;
  finally FreeAndNil(I) end;

  { Load other level properties (that are not read in
    TLevelAvailable.LoadFromDOMElement) }

  if DOMGetAttribute(Element, 'played_music_sound', SoundName) then
    PlayedMusicSound := SoundEngine.SoundFromName(SoundName) else
    PlayedMusicSound := stNone;

  if DOMGetAttribute(Element, 'footsteps_sound', SoundName) then
    FootstepsSound := SoundEngine.SoundFromName(SoundName) else
    FootstepsSound := stPlayerFootstepsConcrete;

  FSceneDynamicShadows := false; { default value }
  DOMGetBooleanAttribute(Element, 'scene_dynamic_shadows', FSceneDynamicShadows);
end;

procedure TGameSceneManager.TraverseForItems(Shape: TShape);

  procedure CreateNewItem(const ItemNodeName: string);
  var
    Resource: T3DResource;
    ItemKind: TItemKind;
    IgnoredBegin, ItemQuantityBegin: Integer;
    ItemKindQuantity, ItemKindId: string;
    ItemQuantity: Cardinal;
    ItemStubBoundingBox: TBox3D;
    ItemPosition: TVector3Single;
  begin
    { Calculate ItemKindQuantity }
    IgnoredBegin := Pos('_', ItemNodeName);
    if IgnoredBegin = 0 then
      ItemKindQuantity := ItemNodeName else
      ItemKindQuantity := Copy(ItemNodeName, 1, IgnoredBegin - 1);

    { Calculate ItemKindId, ItemQuantity }
    ItemQuantityBegin := CharsPos(['0'..'9'], ItemKindQuantity);
    if ItemQuantityBegin = 0 then
    begin
      ItemKindId := ItemKindQuantity;
      ItemQuantity := 1;
    end else
    begin
      ItemKindId := Copy(ItemKindQuantity, 1, ItemQuantityBegin - 1);
      ItemQuantity := StrToInt(SEnding(ItemKindQuantity, ItemQuantityBegin));
    end;

    Resource := AllResources.FindId(ItemKindId);
    if not (Resource is TItemKind) then
      raise Exception.CreateFmt('Resource "%s" is not an item, but is referenced in model with Item prefix',
        [ItemKindId]);
    ItemKind := TItemKind(Resource);

    ItemStubBoundingBox := Shape.BoundingBox;
    ItemPosition[0] := (ItemStubBoundingBox.Data[0, 0] + ItemStubBoundingBox.Data[1, 0]) / 2;
    ItemPosition[1] := (ItemStubBoundingBox.Data[0, 1] + ItemStubBoundingBox.Data[1, 1]) / 2;
    ItemPosition[2] := ItemStubBoundingBox.Data[0, 2];

    Items.Add(TItemOnLevel.Create(Self, TItem.Create(ItemKind, ItemQuantity),
      ItemPosition));
  end;

const
  ItemPrefix = 'Item';
begin
  if IsPrefix(ItemPrefix, Shape.BlenderMeshName) then
  begin
    { For MenuBackground, item models may be not loaded yet }
    if not MenuBackground then
      CreateNewItem(SEnding(Shape.BlenderMeshName, Length(ItemPrefix) + 1));
    { Don't remove BlenderObjectNode now --- will be removed later.
      This avoids problems with removing nodes while traversing. }
    ItemsToRemove.Add(Shape.BlenderObjectNode);
  end;
end;

procedure TGameSceneManager.TraverseForCreatures(Shape: TShape);

  procedure CreateNewCreature(const CreatureNodeName: string);
  var
    StubBoundingBox: TBox3D;
    CreaturePosition, CreatureDirection: TVector3Single;
    Resource: T3DResource;
    CreatureKind: TCreatureKind;
    CreatureKindName: string;
    IgnoredBegin: Integer;
    MaxLifeBegin: Integer;
    IsMaxLife: boolean;
    MaxLife: Single;
  begin
    { calculate CreatureKindName }
    IgnoredBegin := Pos('_', CreatureNodeName);
    if IgnoredBegin = 0 then
      CreatureKindName := CreatureNodeName else
      CreatureKindName := Copy(CreatureNodeName, 1, IgnoredBegin - 1);

    { possibly calculate MaxLife by truncating last part of CreatureKindName }
    MaxLifeBegin := CharsPos(['0'..'9'], CreatureKindName);
    IsMaxLife := MaxLifeBegin <> 0;
    if IsMaxLife then
    begin
      MaxLife := StrToFloat(SEnding(CreatureKindName, MaxLifeBegin));
      CreatureKindName := Copy(CreatureKindName, 1, MaxLifeBegin - 1);
    end;

    { calculate CreaturePosition }
    StubBoundingBox := Shape.BoundingBox;
    CreaturePosition[0] := (StubBoundingBox.Data[0, 0] + StubBoundingBox.Data[1, 0]) / 2;
    CreaturePosition[1] := (StubBoundingBox.Data[0, 1] + StubBoundingBox.Data[1, 1]) / 2;
    CreaturePosition[2] := StubBoundingBox.Data[0, 2];

    { calculate CreatureKind }
    Resource := AllResources.FindId(CreatureKindName);
    if not (Resource is TCreatureKind) then
      raise Exception.CreateFmt('Resource "%s" is not a creature, but is referenced in model with Crea prefix',
        [CreatureKindName]);
    CreatureKind := TCreatureKind(Resource);
    if not CreatureKind.Prepared then
      OnWarning(wtMajor, 'Resource', Format('Creature "%s" is initially present on the level, but was not prepared yet --- which probably means you did not add it to <resources> inside level index.xml file. This causes loading on-demand, which is less comfortable for player.',
        [CreatureKind.Id]));

    { calculate CreatureDirection }
    { TODO --- CreatureDirection configurable.
      Right now, it just points to the player start pos --- this is
      more-or-less sensible, usually. }
    CreatureDirection := VectorSubtract(Camera.GetPosition, CreaturePosition);
    if not CreatureKind.Flying then
      MakeVectorsOrthoOnTheirPlane(CreatureDirection, GravityUp);

    { make sure that MaxLife is initialized now }
    if not IsMaxLife then
    begin
      IsMaxLife := true;
      MaxLife := CreatureKind.DefaultMaxLife;
    end;

    CreatureKind.CreateCreature(Items, CreaturePosition, CreatureDirection, MaxLife);
  end;

const
  CreaturePrefix = 'Crea';
begin
  if IsPrefix(CreaturePrefix, Shape.BlenderMeshName) then
  begin
    { For MenuBackground, creature models may be not loaded yet }
    if not MenuBackground then
      CreateNewCreature(SEnding(Shape.BlenderMeshName, Length(CreaturePrefix) + 1));
    { Don't remove BlenderObjectNode now --- will be removed later.
      This avoids problems with removing nodes while traversing. }
    ItemsToRemove.Add(Shape.BlenderObjectNode);
  end;
end;

procedure TGameSceneManager.InitializeLights(const Lights: TLightInstancesList);
begin
  inherited;

  { This is used to prepare BaseLights, which may be necessary in constructor
    before we even assign Level. }
  if (Level <> nil) and (Level.ThunderEffect <> nil) then
    Level.ThunderEffect.AddLight(Lights);
end;

procedure TGameSceneManager.RenderFromViewEverything;
begin
  ShadowVolumesDraw := DebugRenderShadowVolume;
  ShadowVolumesPossible := RenderShadowsPossible;
  ShadowVolumes := RenderShadows;

  { Actually, this is needed only when "(not MenuBackground) and ShowDebugInfo".
    But it's practically free, time use isn't really noticeable. }
  ShadowVolumeRenderer.Count := true;

  inherited;
end;

procedure TGameSceneManager.BeforeDraw;
begin
  ShadowVolumesDraw := DebugRenderShadowVolume;
  ShadowVolumesPossible := RenderShadowsPossible;
  ShadowVolumes := RenderShadows;

  inherited;
end;

procedure TGameSceneManager.ApplyProjection;
var
  S, C: Extended;
begin
  Assert(Camera <> nil, 'TGameSceneManager always creates camera in constructor');

  ShadowVolumesDraw := DebugRenderShadowVolume;
  ShadowVolumesPossible := RenderShadowsPossible;
  ShadowVolumes := RenderShadows;

  DistortFieldOfViewY := 1;
  DistortViewAspect := 1;
  if SickProjection then
  begin
    SinCos(Level.AnimationTime * SickProjectionSpeed, S, C);
    DistortFieldOfViewY += C * 0.03;
    DistortViewAspect += S * 0.03;
  end;

  inherited;
end;

procedure TGameSceneManager.SetSickProjection(const Value: boolean);
begin
  if FSickProjection <> Value then
  begin
    FSickProjection := Value;
    ApplyProjectionNeeded := true;
  end;
end;

procedure TGameSceneManager.SetSickProjectionSpeed(const Value: TFloatTime);
begin
  if FSickProjectionSpeed <> Value then
  begin
    FSickProjectionSpeed := Value;
    if SickProjection then ApplyProjectionNeeded := true;
  end;
end;

procedure TGameSceneManager.PointingDeviceActivateFailed(const Active: boolean);
begin
  inherited;
  if Active then
    SoundEngine.Sound(stPlayerInteractFailed);
end;

function TGameSceneManager.CollisionIgnoreItem(
  const Sender: TObject; const Triangle: P3DTriangle): boolean;
begin
  Result :=
    (inherited CollisionIgnoreItem(Sender, Triangle)) or
    (PTriangle(Triangle)^.State.LastNodes.Material.NodeName = 'MatWater');
end;

function TGameSceneManager.Background: TBackground;
begin
  Result := Level.Background;
  if Result = nil then
    Result := inherited;
end;

{ TLevel ---------------------------------------------------------------- }

constructor TLevel.Create(AOwner: TComponent; AWorld: T3DWorld;
  MainScene: TLevelScene; DOMElement: TDOMElement);
begin
  inherited Create(AOwner);
  SceneManager := AOwner as TGameSceneManager;
  { Actually, the fact that our BoundingBox is empty also prevents collisions.
    But for some methods, knowing that Collides = false allows them to exit
    faster. }
  Collides := false;
end;

destructor TLevel.Destroy;
begin
  FreeAndNil(FThunderEffect);
  inherited;
end;

function TLevel.BoundingBox: TBox3D;
begin
  { This object is invisible and non-colliding. }
  Result := EmptyBox3D;
end;

function TLevel.BossCreatureIndicator(out Life, MaxLife: Single): boolean;
begin
  Result := (BossCreature <> nil) and (not BossCreature.Dead);
  if Result then
  begin
    Life := BossCreature.Life;
    MaxLife := BossCreature.MaxLife;
  end;
end;

procedure TLevel.PrepareNewPlayer(NewPlayer: TPlayer);
begin
  { Nothing to do in this class. }
end;

function TLevel.LoadLevelScene(const FileName: string;
  CreateOctreeCollisions, PrepareBackground: boolean;
  const SceneClass: TCastleSceneClass): TCastleScene;
var
  Options: TPrepareResourcesOptions;
begin
  Result := SceneClass.CreateCustomCache(Self, GLContextCache);
  Result.Load(FileName);
  AttributesSet(Result.Attributes);

  { calculate Options for PrepareResources }
  Options := [prRender, prBoundingBox { always needed }];
  if PrepareBackground then
    Include(Options, prBackground);
  if RenderShadowsPossible then
    Options := Options + prShadowVolume;

  Result.PrepareResources(Options, false, SceneManager.BaseLights);

  if CreateOctreeCollisions then
    Result.Spatial := [ssDynamicCollisions];

  Result.FreeResources([frTextureDataInNodes]);

  Result.ProcessEvents := true;
end;

function TLevel.LoadLevelScene(const FileName: string;
  CreateOctreeCollisions, PrepareBackground: boolean): TCastleScene;
begin
  Result := LoadLevelScene(FileName, CreateOctreeCollisions, PrepareBackground,
    TCastleScene);
end;

function TLevel.LoadLevelAnimation(
  const FileName: string;
  CreateFirstOctreeCollisions,
  CreateLastOctreeCollisions: boolean;
  const AnimationClass: TCastlePrecalculatedAnimationClass): TCastlePrecalculatedAnimation;
var
  Options: TPrepareResourcesOptions;
begin
  Result := AnimationClass.CreateCustomCache(Self, GLContextCache);
  Result.LoadFromFile(FileName, false, true);

  AttributesSet(Result.Attributes);

  { calculate Options for PrepareResources }
  Options := [prRender, prBoundingBox { always needed }];
  if RenderShadowsPossible then
    Options := Options + prShadowVolume;

  Result.PrepareResources(Options, false, SceneManager.BaseLights);

  if CreateFirstOctreeCollisions then
    Result.FirstScene.Spatial := [ssDynamicCollisions];

  if CreateLastOctreeCollisions then
    Result.LastScene.Spatial := [ssDynamicCollisions];

  Result.FreeResources([frTextureDataInNodes]);

  Result.TimePlaying := false;
end;

function TLevel.LoadLevelAnimation(
  const FileName: string;
  CreateFirstOctreeCollisions,
  CreateLastOctreeCollisions: boolean): TCastlePrecalculatedAnimation;
begin
  Result := LoadLevelAnimation(FileName,
    CreateFirstOctreeCollisions, CreateLastOctreeCollisions,
    TCastlePrecalculatedAnimation);
end;

procedure TLevel.Idle(const CompSpeed: Single; var RemoveMe: TRemoveType);
begin
  inherited;
  FAnimationTime += CompSpeed;
  if ThunderEffect <> nil then
    ThunderEffect.Idle(CompSpeed);
end;

function TLevel.Background: TBackground;
begin
  Result := nil;
end;

initialization
  if LevelClasses = nil then
    LevelClasses := TLevelClasses.Create;
finalization
  FreeAndNil(LevelClasses);
end.
