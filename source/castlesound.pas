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
unit CastleSound;

interface

uses Classes, VectorMath, ALSourceAllocator, SysUtils;

var
  SoundInitializationReport: string;

const
  MaxSoundImportance             = MaxInt;
  LevelEventSoundImportance      = 100000;
  PlayerSoundImportance          = 10000;
  DefaultCreatureSoundImportance = 1000;
  MinorNonSpatialSoundImportance = 100;

type
  TSoundType = (
    { Special sound type that indicates that there is actually none sound.
      @link(Sound) and @link(Sound3d) will do nothing when called with
      this sound type. }
    stNone,

    { Player sounds.
      @groupBegin }
    stPlayerSuddenPain,
    stPlayerPotionDrink,
    stPlayerCastFlyingSpell,
    stPlayerPickItem,
    stPlayerDropItem,
    stPlayerDies,
    stPlayerSwimmingChange,
    stPlayerSwimming,
    stPlayerDrowning,
    stPlayerFalledDown,
    stPlayerFootstepsConcrete,
    stPlayerFootstepsGrass,
    stPlayerInteractFailed,
    { @groupEnd }

    { Items sounds.
      @groupBegin }
    stSwordEquipping,
    stSwordAttackStart,
    stArrowFired,
    stArrowHit,
    stKeyUse,
    stBowAttackStart,
    stBowEquipping,
    { @groupEnd }

    { Levels sounds.
      @groupBegin }
    stGateMusic,
    stCastleHallSymbolMoving,
    stCastleHallMusic,
    stCagesMusic,
    stThunder,
    stStairsBlockerDestroyed,
    stTeleport,
    stSacrilegeAmbush,
    stEvilLaugh,
    stDoomE1M1Music,
    stDoorOpen,
    stDoorClose,
    stElevator,
    { @groupEnd }

    { Creatures sounds.
      @groupBegin }
    stCreatureFalledDown,
    stAlienSuddenPain,
    stAlienDying,
    stWerewolfSuddenPain,
    stWerewolfAttackStart,
    stWerewolfActualAttackHit,
    stWerewolfHowling,
    stWerewolfDying,
    stBallMissileFired,
    stBallMissileExplode,
    stBallMissileIdle,
    stGhostSuddenPain,
    stGhostAttackStart,
    stGhostDying,
    stSpiderActualAttackHit,
    stSpiderSuddenPain,
    stSpiderAttackStart,
    stSpiderDying,
    stSpiderAppears,
    stSpiderQueenActualAttackHit,
    stSpiderQueenSuddenPain,
    stSpiderQueenAttackStart,
    stSpiderQueenDying,
    stThrownWebFired,
    stThrownWebHit,
    stThrownWebIdle,
    { @groupEnd }

    { Others.
      @groupBegin }
    stIntroMusic,
    stMenuCurrentItemChanged,
    stMenuCurrentItemSelected,
    stSaveScreen,
    stGameWinMusic
    { @groupEnd });

{ Call this always to initialize OpenAL and OpenAL context,
  and load sound files. This sets SoundInitializationReport
  and ALActive.

  You can set ALCDevice before calling this.
  Note that this unit saves/restores ALCDevice value to/from config file. }
procedure ALContextInit(WasParam_NoSound: boolean);

{ This will call RefreshUsed on internal ALSourceAllocator,
  see TALSourceAllocator.RefreshUsed for info.
  It's silently ignored when not ALActive. }
procedure ALRefreshUsedSources;

{ Call this always to release OpenAL things.
  This is ignored if not ALActive. }
procedure ALContextClose;

{ If ALActive, then will append some info about current OpenAL used. }
procedure AppendALInformation(S: TStrings);

{ Play given sound. This should be used to play sounds
  that are not spatial actually, i.e. have no place in 3D space.

  Returns used TALAllocatedSource (or nil if none was available).
  You don't have to do anything with this returned TALAllocatedSource.

  @noAutoLinkHere }
function Sound(SoundType: TSoundType;
  const Looping: boolean = false): TALAllocatedSource;

{ Play given sound at appropriate position in 3D space.

  Returns used TALAllocatedSource (or nil if none was available).
  You don't have to do anything with this returned TALAllocatedSource.

  @noAutoLinkHere }
function Sound3d(SoundType: TSoundType;
  const Position: TVector3Single;
  const Looping: boolean = false): TALAllocatedSource; overload;

{ }
function GetSoundVolume: Single;
procedure SetSoundVolume(const Value: Single);

{ Sound volume, affects all sounds (effects and music).
  This must always be within 0..1 range.
  0.0 means that there are no effects (this case should be optimized). }
property SoundVolume: Single read GetSoundVolume write SetSoundVolume;

function GetMusicVolume: Single;
procedure SetMusicVolume(const Value: Single);

{ Music volume. This must always be within 0..1 range.
  0.0 means that there is no music (this case should be optimized).}
property MusicVolume: Single read GetMusicVolume write SetMusicVolume;

type
  TMusicPlayer = class
  private
    FPlayedSound: TSoundType;
    procedure SetPlayedSound(const Value: TSoundType);

    { This is nil if we don't play music right now
      (because OpenAL is not initialized, or PlayedSound = stNone,
      or PlayerSound.FileName = '' (not implemented)). }
    FAllocatedSource: TALAllocatedSource;

    procedure AllocatedSourceUsingEnd(Sender: TALAllocatedSource);

    { Called by ALInitContext. You should check here if
      PlayedSound <> stNone and eventually initialize FAllocatedSource. }
    procedure AllocateSource;
  public
    destructor Destroy; override;

    { Currently played music.
      Set to stNone to stop playing music.
      Set to anything else to play that music.

      Changing value of this property (when both the old and new values
      are <> stNone and are different) restarts playing the music. }
    property PlayedSound: TSoundType read FPlayedSound write SetPlayedSound
      default stNone;
  end;

var
  { This is the only allowed instance of TMusicPlayer class,
    created and destroyed in this unit's init/fini. }
  MusicPlayer: TMusicPlayer;

{ When changing Min/MaxAllocatedSources, remember to always keep
  MinAllocatedSources <= MaxAllocatedSources. }

{ }
function GetALMinAllocatedSources: Cardinal;
procedure SetALMinAllocatedSources(const Value: Cardinal);

const
  DefaultALMinAllocatedSources = 4;

property ALMinAllocatedSources: Cardinal
  read GetALMinAllocatedSources write SetALMinAllocatedSources;

function GetALMaxAllocatedSources: Cardinal;
procedure SetALMaxAllocatedSources(const Value: Cardinal);

const
  DefaultALMaxAllocatedSources = 16;

property ALMaxAllocatedSources: Cardinal
  read GetALMaxAllocatedSources write SetALMaxAllocatedSources;

procedure ReadSoundInfos;

{ Return sound with given name.
  Available names are defined in implementation of this unit,
  and inside ../data/sounds/index.xml.
  Always for SoundName = '' it will return stNone.
  @raises Exception On invalid SoundName }
function SoundFromName(const SoundName: string): TSoundType;

implementation

uses CastleConfig, ProgressUnit, OpenAL, ALUtils, KambiUtils,
  KambiFilesUtils, CastleLog, DOM, XMLRead, KambiXMLUtils,
  SoundFile, VorbisFile, KambiStringUtils;

const
  { Each sound has a unique name, used to identify sound in sounds/index.xml file.
    For stNone sound name is always ''. }
  SoundNames: array [TSoundType] of string =
  ( '',
    'player_sudden_pain',
    'player_potion_drink',
    'player_cast_flying_spell',
    'player_pick_item',
    'player_drop_item',
    'player_dies',
    'player_swimming_change',
    'player_swimming',
    'player_drowning',
    'player_falled_down',
    'player_footsteps_concrete',
    'player_footsteps_grass',
    'player_interact_failed',
    'sword_equipping',
    'sword_attack_start',
    'arrow_fired',
    'arrow_hit',
    'key_use',
    'bow_equipping',
    'bow_attack_start',
    'gate_music',
    'castle_hall_symbol_moving',
    'castle_hall_music',
    'cages_music_with_rain',
    'thunder',
    'stairs_blocker_destroyed',
    'teleport',
    'sacrilege_ambush',
    'evil_laugh',
    'doom_e1m1',
    'door_open',
    'door_close',
    'elevator',
    'creature_falled_down',
    'alien_sudden_pain',
    'alien_dying',
    'werewolf_sudden_pain',
    'werewolf_attack_start',
    'werewolf_actual_attack_hit',
    'werewolf_howling',
    'werewolf_dying',
    'ball_missile_fired',
    'ball_missile_explode',
    'ball_missile_idle',
    'ghost_sudden_pain',
    'ghost_attack_start',
    'ghost_dying',
    'spider_actual_attack_hit',
    'spider_sudden_pain',
    'spider_attack_start',
    'spider_dying',
    'spider_appears',
    'spider_queen_actual_attack_hit',
    'spider_queen_sudden_pain',
    'spider_queen_attack_start',
    'spider_queen_dying',
    'thrown_web_fired',
    'thrown_web_hit',
    'thrown_web_idle',
    'intro_music',
    'menu_current_item_changed',
    'menu_current_item_selected',
    'save_screen',
    'game_win_music'
  );

type
  TSoundInfo = record
    { '' means that this sound is not implemented and will have
      no OpenAL buffer associated with it. }
    FileName: string;

    { XxxGain are mapped directly on respective OpenAL source properties.
      Note that Gain and MaxGain > 1 are allowed (because OpenAL allows them),
      although OpenAL may clip them for the resulting sound (after all
      calculations taking into account 3d position will be done).

      When sound is used for MusicPlayer.PlayedSound:
      1. MinGain, MaxGain are ignored
      2. Gain is always multiplied by MusicVolume when setting AL_GAIN
         of the music source. }
    Gain, MinGain, MaxGain: Single;

    { Importance, as passed to TALSourceAllocator.
      This is ignored when sound is used for MusicPlayer.PlayedSound. }
    DefaultImportance: Cardinal;
  end;

var
  { Properties of sounds.

    For the actual game, as used by end-user, SoundInfos is a constant.

    However, for the sake of debugging/testing the game,
    and for content designers, the actual values of SoundInfos are loaded
    at initialization from sounds/index.xml file, and later can be changed by
    "Reload sounds/index.xml" command. }
  SoundInfos: array[TSoundType] of TSoundInfo;

  { Values on this array are useful only when ALContextInited
    and only for sounds with SoundInfos[].FileName <> ''. }
  SoundBuffers: array[TSoundType] of TALuint;

  { When SourceAllocator <> nil, these correspond to it's properties. }
  FALMinAllocatedSources: Cardinal;
  FALMaxAllocatedSources: Cardinal;

  SourceAllocator: TALSourceAllocator;

procedure ALContextInit(WasParam_NoSound: boolean);
var
  ST: TSoundType;
begin
  Assert(not ALActive);

  if WasParam_NoSound then
    SoundInitializationReport :=
      'Sound disabled by --no-sound command-line option' else
  if not TryBeginAL(false) then
    SoundInitializationReport :=
      'OpenAL initialization failed : ' +ALActivationErrorMessage +nl+
      'SOUND IS DISABLED' else
  begin
    SoundInitializationReport :=
      'OpenAL initialized, sound enabled';

    ReadSoundInfos;

    try
      SourceAllocator := TALSourceAllocator.Create(
        FALMinAllocatedSources, FALMaxAllocatedSources);

      alListenerf(AL_GAIN, SoundVolume);

      Progress.Init(Ord(High(TSoundType)) + 1, 'Loading sounds');
      try
        for ST := Low(TSoundType) to High(TSoundType) do
        begin
          if SoundInfos[ST].FileName <> '' then
          begin
            SoundBuffers[ST] := TALSoundFile.alCreateBufferDataFromFile(
              ProgramDataPath + PathDelim + 'data' + PathDelim +
              'sounds' + PathDelim + SoundInfos[ST].FileName);
          end;
          Progress.Step;
        end;
      finally Progress.Fini; end;

      MusicPlayer.AllocateSource;

      CheckAL('initializing sounds (ALContextInit)');
    except
      { If loading sounds above will fail, we have to finish already initialized
        things here before reraising exception. }
      FreeAndNil(SourceAllocator);
      EndAL;
      raise;
    end;
  end;

  if WasParam_DebugLog then
    WritelnLog(ltSoundInitialization, SoundInitializationReport);
end;

procedure ALContextClose;
var
  ST: TSoundType;
begin
  if ALActive then
  begin
    FreeAndNil(SourceAllocator);

    for ST := Low(TSoundType) to High(TSoundType) do
      if SoundInfos[ST].FileName <> '' then
        alDeleteBuffers(1, @SoundBuffers[ST]);

    { EndAL may take a while on Unix OpenAL, so provide feedback
      for user here (otherwise he (she?) may think that program hanged. }
    Progress.Init(1, 'Closing sound device, please wait');
    try
      EndAL;
      Progress.Step;
    finally Progress.Fini; end;
  end;
end;

procedure ALRefreshUsedSources;
begin
  if SourceAllocator <> nil then
    SourceAllocator.RefreshUsed;
end;

{ Set common properties for spatialized and non-spatialized
  sound effects. If Spatial = true, you have to always set this sound's
  AL_POSITION after calling this. }
procedure alCommonSourceSetup(ALSource: TALuint;
  const Looping: boolean;
  const Spatial: boolean;
  const ALBuffer: TALuint; const Gain, MinGain, MaxGain: Single); overload;
begin
  alSourcei(ALSource, AL_BUFFER, ALBuffer);
  alSourcei(ALSource, AL_LOOPING, BoolToAL[Looping]);
  alSourcef(ALSource, AL_GAIN, Gain);
  alSourcef(ALSource, AL_MIN_GAIN, MinGain);
  alSourcef(ALSource, AL_MAX_GAIN, MaxGain);

  if Spatial then
  begin
    { Set attenuation by distance. }
    alSourcef(ALSource, AL_ROLLOFF_FACTOR, 0.1);
    alSourcef(ALSource, AL_REFERENCE_DISTANCE, 2.0);

    alSourcei(ALSource, AL_SOURCE_RELATIVE, AL_FALSE);
  end else
  begin
    { No attenuation by distance. }
    alSourcef(ALSource, AL_ROLLOFF_FACTOR, 0);

    { Although AL_ROLLOFF_FACTOR := 0 turns off
      attenuation by distance, we still have to turn off
      any changes from player's orientation (so that the sound
      is not played on left or right side, but normally).
      That's why setting source position exactly on the player
      is needed here. }
    alSourcei(ALSource, AL_SOURCE_RELATIVE, AL_TRUE);
    alSourceVector3f(ALSource, AL_POSITION, Vector3Single(0, 0, 0));
  end;
end;

procedure alCommonSourceSetup(ALSource: TALuint; SoundType: TSoundType;
  const Looping: boolean;
  const Spatial: boolean); overload;
begin
  alCommonSourceSetup(ALSource, Looping, Spatial, SoundBuffers[SoundType],
    SoundInfos[SoundType].Gain,
    SoundInfos[SoundType].MinGain,
    SoundInfos[SoundType].MaxGain);
end;

function Sound(SoundType: TSoundType;
  const Looping: boolean): TALAllocatedSource;
begin
  Result := nil;

  if ALActive and (SoundInfos[SoundType].FileName <> '') then
  begin
    Result := SourceAllocator.AllocateSource(
      SoundInfos[SoundType].DefaultImportance);
    if Result <> nil then
    begin
      alCommonSourceSetup(Result.ALSource, SoundType, Looping, false);
      alSourcePlay(Result.ALSource);
    end;
  end;
end;

function Sound3d(SoundType: TSoundType;
  const Position: TVector3Single;
  const Looping: boolean): TALAllocatedSource;
begin
  Result := nil;

  if ALActive and (SoundInfos[SoundType].FileName <> '') then
  begin
    Result := SourceAllocator.AllocateSource(
      SoundInfos[SoundType].DefaultImportance);
    if Result <> nil then
    begin
      alCommonSourceSetup(Result.ALSource, SoundType, Looping, true);
      alSourceVector3f(Result.ALSource, AL_POSITION, Position);
      alSourcePlay(Result.ALSource);
    end;
  end;
end;

const
  DefaultSoundVolume = 0.5;

var
  FSoundVolume: Single;

function GetSoundVolume: Single;
begin
  Result := FSoundVolume;
end;

procedure SetSoundVolume(const Value: Single);
begin
  if Value <> FSoundVolume then
  begin
    FSoundVolume := Value;
    if ALActive then
      alListenerf(AL_GAIN, SoundVolume);
  end;
end;

procedure AppendALInformation(S: TStrings);
begin
  if ALActive then
  begin
    S.Append('');
    S.Append('Version : ' + alGetString(AL_VERSION));
    S.Append('Renderer : ' + alGetString(AL_RENDERER));
    S.Append('Vendor : ' + alGetString(AL_VENDOR));
    S.Append('Extensions : ' + alGetString(AL_EXTENSIONS));
    S.Append('');
    S.Append(Format('Allocated OpenAL sources: %d (min %d, max %d)',
      [ SourceAllocator.AllocatedSources.Count,
        SourceAllocator.MinAllocatedSources,
        SourceAllocator.MaxAllocatedSources ]));
    S.Append('');
    S.Append('OggVorbis handling method: ' + TSoundOggVorbis.VorbisMethod);
    S.Append('vorbisfile library available: ' + BoolToStr[VorbisFileInited]);
  end;
end;

{ TMusicPlayer --------------------------------------------------------------- }

destructor TMusicPlayer.Destroy;
begin
  if FAllocatedSource <> nil then
    FAllocatedSource.DoUsingEnd;
  inherited;
end;

procedure TMusicPlayer.AllocateSource;
begin
  if ALActive and (SoundInfos[PlayedSound].FileName <> '') then
  begin
    FAllocatedSource := SourceAllocator.AllocateSource(MaxSoundImportance);
    if FAllocatedSource <> nil then
    begin
      alCommonSourceSetup(FAllocatedSource.ALSource, true, false,
        SoundBuffers[PlayedSound],
        MusicVolume * SoundInfos[PlayedSound].Gain, 0, 1);

      { This is a workaround needed on Apple OpenAL implementation
        (although I think that at some time I experienced similar
        problems (that would be cured by this workaround) on Linux
        (Loki OpenAL implementation)).

        The problem: music on some
        levels doesn't play. This happens seemingly random: sometimes
        when you load a level music starts playing, sometimes it's
        silent. Then when you go to another level, then go back to the
        same level, music plays.

        Investigation: I found that sometimes changing the buffer
        of the sound doesn't work immediately. Simple
          Writeln(SoundBuffers[PlayedSound], ' ',
            alGetSource1ui(FAllocatedSource.ALSource, AL_BUFFER));
        right after alCommonSourceSetup shows this (may output
        two different values). Then if you wait a little, OpenAL
        reports correct buffer. This probably means that OpenAL
        internally finishes some tasks related to loading buffer
        into source. Whatever it is, it seems that it doesn't
        occur (or rather, is not noticeable) on normal game sounds
        that are short --- but it's noticeable delay with larger
        sounds, like typical music. (in any case, I can move
        this workaround to alCommonSourceSetup at some point,
        should the need arise).

        So the natural workaround below follows. For OpenAL implementations
        that immediately load the buffer, this will not cause any delay. }
      while SoundBuffers[PlayedSound] <>
        alGetSource1ui(FAllocatedSource.ALSource, AL_BUFFER) do
        Delay(10);

      alSourcePlay(FAllocatedSource.ALSource);

      FAllocatedSource.OnUsingEnd :=
        {$ifdef FPC_OBJFPC} @ {$endif} AllocatedSourceUsingEnd;
    end;
  end;
end;

procedure TMusicPlayer.SetPlayedSound(const Value: TSoundType);
begin
  if Value <> FPlayedSound then
  begin
    if FAllocatedSource <> nil then
    begin
      FAllocatedSource.DoUsingEnd;
      { AllocatedSourceUsingEnd should set FAllocatedSource to nil. }
      Assert(FAllocatedSource = nil);
    end;

    FPlayedSound := Value;

    AllocateSource;
  end;
end;

procedure TMusicPlayer.AllocatedSourceUsingEnd(Sender: TALAllocatedSource);
begin
  Assert(Sender = FAllocatedSource);
  FAllocatedSource.OnUsingEnd := nil;
  FAllocatedSource := nil;
end;

{ Other non-class things ----------------------------------------------------- }

const
  DefaultMusicVolume = 1.0;

var
  FMusicVolume: Single;

function GetMusicVolume: Single;
begin
  Result := FMusicVolume;
end;

procedure SetMusicVolume(const Value: Single);
begin
  if Value <> FMusicVolume then
  begin
    FMusicVolume := Value;
    if MusicPlayer.FAllocatedSource <> nil then
      alSourcef(MusicPlayer.FAllocatedSource.ALSource,
        AL_GAIN, MusicVolume * SoundInfos[MusicPlayer.PlayedSound].Gain);
  end;
end;

function GetALMinAllocatedSources: Cardinal;
begin
  Result := FALMinAllocatedSources;
end;

procedure SetALMinAllocatedSources(const Value: Cardinal);
begin
  if Value <> FALMinAllocatedSources then
  begin
    FALMinAllocatedSources := Value;
    if SourceAllocator <> nil then
      SourceAllocator.MinAllocatedSources := FALMinAllocatedSources;
  end;
end;

function GetALMaxAllocatedSources: Cardinal;
begin
  Result := FALMaxAllocatedSources;
end;

procedure SetALMaxAllocatedSources(const Value: Cardinal);
begin
  if Value <> FALMaxAllocatedSources then
  begin
    FALMaxAllocatedSources := Value;
    if SourceAllocator <> nil then
      SourceAllocator.MaxAllocatedSources := FALMaxAllocatedSources;
  end;
end;

procedure ReadSoundInfos;

  { Seaches for sound with given Name. Case-sensitive.
    Returns given TSoundType.
    @raises Exception When given Name is not found }
  function SoundByName(const Name: string): TSoundType;
  begin
    for Result := Low(Result) to High(Result) do
      if SoundNames[Result] = Name then
        Exit;
    raise Exception.CreateFmt('Sound name "%s" not found', [Name]);
  end;

var
  ST: TSoundType;
  SoundConfig: TXMLDocument;
  SoundNode: TDOMNode;
  SoundElement: TDOMElement;
  SoundElements: TDOMNodeList;
  S: string;
  I: Integer;
begin
  ReadXMLFile(SoundConfig, ProgramDataPath + 'data' +
    PathDelim + 'sounds' + PathDelim + 'index.xml');
  try
    Check(SoundConfig.DocumentElement.TagName = 'sounds',
      'Root node of sounds/index.xml must be <sounds>');

    { Init all SoundInfos to default values }
    for ST := Succ(stNone) to High(ST) do
    begin
      SoundInfos[ST].FileName := SoundNames[ST] + '.wav';
      SoundInfos[ST].Gain := 1;
      SoundInfos[ST].MinGain := 0;
      SoundInfos[ST].MaxGain := 1;
      SoundInfos[ST].DefaultImportance := MaxSoundImportance;
    end;

    SoundElements := SoundConfig.DocumentElement.ChildNodes;
    try
      for I := 0 to SoundElements.Count - 1 do
      begin
        SoundNode := SoundElements.Item[I];
        if SoundNode.NodeType = ELEMENT_NODE then
        begin
          SoundElement := SoundNode as TDOMElement;
          Check(SoundElement.TagName = 'sound',
            'Each child of sounds/index.xml root node must be the <sound> element');

          ST := SoundByName(SoundElement.GetAttribute('name'));

          { I retrieve FileNameNode using DOMGetAttribute
            (that internally uses SoundElement.Attributes.GetNamedItem),
            because I have to distinguish between the case when file_name
            attribute is not present (in this case FileName is left as it was)
            and when it's present as set to empty string.
            Standard SoundElement.GetAttribute wouldn't allow me this. }
          DOMGetAttribute(SoundElement, 'file_name', SoundInfos[ST].FileName);

          DOMGetSingleAttribute(SoundElement, 'gain', SoundInfos[ST].Gain);
          DOMGetSingleAttribute(SoundElement, 'min_gain', SoundInfos[ST].MinGain);
          DOMGetSingleAttribute(SoundElement, 'max_gain', SoundInfos[ST].MaxGain);

          if DOMGetAttribute(SoundElement, 'default_importance', S) then
            case ArrayPosStr(S,
              [ 'max',
                'level_event',
                'player',
                'default_creature',
                'minor_non_spatial' ]) of
              -1: SoundInfos[ST].DefaultImportance := StrToInt(S);
              0: SoundInfos[ST].DefaultImportance := MaxSoundImportance;
              1: SoundInfos[ST].DefaultImportance := LevelEventSoundImportance;
              2: SoundInfos[ST].DefaultImportance := PlayerSoundImportance;
              3: SoundInfos[ST].DefaultImportance := DefaultCreatureSoundImportance;
              4: SoundInfos[ST].DefaultImportance := MinorNonSpatialSoundImportance;
              else raise EInternalError.Create('20061125-case ArrayPosStr');
            end;
        end;
      end;
    finally SoundElements.Release; end;
  finally
    FreeAndNil(SoundConfig);
  end;
end;

function SoundFromName(const SoundName: string): TSoundType;
begin
  for Result := Low(Result) to High(Result) do
    if SoundName = SoundNames[Result] then
      Exit;
  raise Exception.CreateFmt('Unknown sound name "%s"', [SoundName]);
end;

initialization
  MusicPlayer := TMusicPlayer.Create;

  FSoundVolume := ConfigFile.GetFloat('sound/volume', DefaultSoundVolume);
  FMusicVolume   := ConfigFile.GetFloat('sound/music/volume', DefaultMusicVolume);
  FALMinAllocatedSources := ConfigFile.GetValue(
    'sound/allocated_sources/min', DefaultALMinAllocatedSources);
  FALMaxAllocatedSources := ConfigFile.GetValue(
    'sound/allocated_sources/max', DefaultALMaxAllocatedSources);
  ALCDevice := ConfigFile.GetValue('sound/device', BestALCDevice);
finalization
  ConfigFile.SetDeleteFloat('sound/volume', SoundVolume, DefaultSoundVolume);
  ConfigFile.SetDeleteFloat('sound/music/volume', MusicVolume, DefaultMusicVolume);
  ConfigFile.SetDeleteValue('sound/allocated_sources/min',
    FALMinAllocatedSources, DefaultALMinAllocatedSources);
  ConfigFile.SetDeleteValue('sound/allocated_sources/max',
    FALMaxAllocatedSources, DefaultALMaxAllocatedSources);
  ConfigFile.SetDeleteValue('sound/device', ALCDevice, BestALCDevice);

  FreeAndNil(MusicPlayer);
end.